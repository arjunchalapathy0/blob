using System;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using Blob.Core;
using Blob.Services;

namespace Blob.UI;

/// <summary>Everything the open notch can show. Each panel rebuilds from its service when it changes.</summary>
public interface IPanel
{
    string Title { get; }
    string Glyph { get; }
    bool Lockable { get; }
    UIElement View { get; }
    void Refresh();
}

public sealed class AskPanel : IPanel
{
    private readonly AgentService _agent;
    private readonly Grid _root = new();
    private readonly ContentControl _body = new();
    private readonly TextBox _input = new();
    private readonly TextBlock _placeholder;

    public string Title => "Ask";
    public string Glyph => Glyphs.Ask;
    public bool Lockable => true;
    public UIElement View => _root;
    public TextBox Input => _input;

    public AskPanel(AgentService agent)
    {
        _agent = agent;
        _root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        _root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        _root.Children.Add(_body);

        _input.Style = (Style)Application.Current.Resources["NotchText"];
        _input.KeyDown += (_, e) =>
        {
            if (e.Key == Key.Enter && !string.IsNullOrWhiteSpace(_input.Text))
            {
                _agent.Run(_input.Text.Trim());
                _input.Text = "";
                e.Handled = true;
            }
        };
        _placeholder = Ui.Text("Tell Blob what to do…", 14, Ui.Ink3);
        _placeholder.IsHitTestVisible = false;
        _placeholder.Margin = new Thickness(15, 0, 0, 0);
        _input.TextChanged += (_, _) => _placeholder.Visibility = _input.Text.Length == 0 ? Visibility.Visible : Visibility.Collapsed;
        System.Windows.Automation.AutomationProperties.SetName(_input, "Tell Blob what to do");

        var send = Ui.IconButton(Glyphs.Send, "Send", () =>
        {
            if (string.IsNullOrWhiteSpace(_input.Text)) return;
            _agent.Run(_input.Text.Trim());
            _input.Text = "";
        });
        var bar = new Grid { Margin = new Thickness(0, 10, 0, 0) };
        bar.ColumnDefinitions.Add(new ColumnDefinition());
        bar.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        bar.Children.Add(_input);
        bar.Children.Add(_placeholder);
        send.Margin = new Thickness(6, 0, 0, 0);
        Grid.SetColumn(send, 1);
        bar.Children.Add(send);
        Grid.SetRow(bar, 1);
        _root.Children.Add(bar);
        Refresh();
    }

    public void Refresh()
    {
        if (!_agent.ClaudeInstalled)
        {
            _body.Content = Ui.Empty("Blob needs Claude Code to do things.",
                "Install Claude Code, sign in once with your Claude account, then come back.",
                Ui.Button("How to install", () => Open("https://code.claude.com/docs")));
            return;
        }
        switch (_agent.State)
        {
            case AgentService.Phase.Idle when _agent.Request.Length == 0:
                var key = Prefs.Current.TalkKey == "RightCtrl" ? "Right Ctrl" : "Right Alt";
                // A few things to try, one click each.
                var suggestions = new WrapPanel { HorizontalAlignment = HorizontalAlignment.Center };
                foreach (var text in new[] { "Put on some music", "What’s on my screen?", "Open my Downloads" })
                {
                    var request = text;
                    var chip = Ui.Button(text, () => _agent.Run(request));
                    chip.Margin = new Thickness(3, 0, 3, 0);
                    chip.FontSize = 12;
                    suggestions.Children.Add(chip);
                }
                _body.Content = Ui.Empty("Tell Blob what to do on your PC.",
                    Prefs.Current.VoiceKey ? $"Type below, or hold {key} and talk." : "Type below.", suggestions);
                return;
            case AgentService.Phase.Listening:
                _body.Content = Ui.Empty("Listening…", "Let go when you’re done.");
                return;
            case AgentService.Phase.Transcribing:
                _body.Content = Ui.Empty("One sec…", _agent.WhisperStatus.StartsWith("Downloading") ? _agent.WhisperStatus : "Turning that into words.");
                return;
        }

        var col = new StackPanel();
        col.Children.Add(Ui.Text(_agent.Request, 15, Ui.Ink, FontWeights.SemiBold, wrap: true));
        foreach (var (step, i) in _agent.Steps.TakeLast(4).Select((s, i) => (s, i)))
        {
            var last = i == Math.Min(4, _agent.Steps.Count) - 1 && _agent.State == AgentService.Phase.Working;
            var row = Ui.Row(8, Ui.Icon(last ? "" : Glyphs.Check, 11, Ui.Ink3), Ui.Text(step, 13, last ? Ui.Ink : Ui.Ink2));
            row.Margin = new Thickness(0, 6, 0, 0);
            col.Children.Add(row);
        }
        if (_agent.State == AgentService.Phase.Working && _agent.Steps.Count == 0)
            col.Children.Add(new TextBlock { Text = "Thinking…", Foreground = Ui.Ink2, FontFamily = Ui.Font, Margin = new Thickness(0, 6, 0, 0) });
        if (_agent.Reply.Length > 0)
        {
            var reply = Ui.Text(_agent.Reply.Trim(), 14, Ui.Ink, wrap: true);
            reply.Margin = new Thickness(0, 10, 0, 0);
            col.Children.Add(reply);
        }
        if (_agent.State == AgentService.Phase.Failed && _agent.Error != null)
        {
            var err = Ui.Text(_agent.Error, 13, Ui.Ink2, wrap: true);
            err.Margin = new Thickness(0, 10, 0, 0);
            col.Children.Add(err);
        }
        var actions = _agent.State == AgentService.Phase.Working
            ? Ui.Row(6, Ui.Button("Stop", _agent.Cancel))
            : Ui.Row(6, Ui.Button("New conversation", _agent.NewConversation));
        actions.Margin = new Thickness(0, 12, 0, 0);
        col.Children.Add(actions);
        _body.Content = new ScrollViewer { Content = col, VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
    }

    private static void Open(string url)
    {
        try { System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo(url) { UseShellExecute = true }); } catch { }
    }
}

public sealed class MusicPanel : IPanel
{
    private readonly NowPlayingService _music;
    private readonly ContentControl _root = new();
    public string Title => "Now Playing";
    public string Glyph => Glyphs.Music;
    public bool Lockable => false;
    public UIElement View => _root;

    public MusicPanel(NowPlayingService music) { _music = music; Refresh(); }

    public void Refresh()
    {
        if (!_music.HasTrack)
        {
            _root.Content = Ui.Empty("Nothing playing", "Play something in Spotify, a browser, or any app that shows in Windows’ media controls.");
            return;
        }
        var art = new Border
        {
            Width = 112, Height = 112, CornerRadius = new CornerRadius(14),
            Background = _music.Artwork != null ? new ImageBrush(_music.Artwork) { Stretch = Stretch.UniformToFill } : (Brush)Application.Current.Resources["Raised"],
        };
        var controls = Ui.Row(4,
            Ui.IconButton(Glyphs.Previous, "Previous", _music.Previous),
            Ui.IconButton(_music.IsPlaying ? Glyphs.Pause : Glyphs.Play, _music.IsPlaying ? "Pause" : "Play", _music.PlayPause),
            Ui.IconButton(Glyphs.Next, "Next", _music.Next));
        foreach (var c in controls.Children.OfType<Button>()) { c.FontSize = 18; c.Width = 40; c.Height = 40; c.Foreground = Ui.Ink; }
        controls.Margin = new Thickness(-8, 14, 0, 0);
        var info = Ui.Column(2,
            Ui.Text(_music.Title, 18, Ui.Ink, FontWeights.SemiBold),
            Ui.Text(_music.Artist, 14, Ui.Ink2),
            controls);
        info.Margin = new Thickness(20, 0, 0, 0);
        info.VerticalAlignment = VerticalAlignment.Center;
        var row = new DockPanel { VerticalAlignment = VerticalAlignment.Center };
        row.Children.Add(art);
        row.Children.Add(info);
        _root.Content = row;
    }
}

public sealed class TimersPanel : IPanel
{
    private readonly TimerService _timers;
    private readonly ContentControl _root = new();
    public string Title => "Timers";
    public string Glyph => Glyphs.Timer;
    public bool Lockable => false;
    public UIElement View => _root;

    public TimersPanel(TimerService timers) { _timers = timers; Refresh(); }

    public void Refresh()
    {
        var presets = new WrapPanel();
        foreach (var m in new[] { 1, 3, 5, 10, 15, 25, 45, 60 })
        {
            var b = Ui.Button(m < 60 ? $"{m} min" : "1 hour", () => _timers.Start(TimeSpan.FromMinutes(m)));
            b.Margin = new Thickness(0, 0, 6, 6);
            presets.Children.Add(b);
        }
        var col = new StackPanel();
        col.Children.Add(presets);
        if (_timers.Timers.Count == 0)
        {
            var hint = Ui.Text("Pick one. It counts down in the notch and says “Time’s up”.", 13, Ui.Ink2, wrap: true);
            hint.Margin = new Thickness(0, 10, 0, 0);
            col.Children.Add(hint);
        }
        foreach (var t in _timers.Timers.OrderBy(t => t.Ends))
        {
            var row = new DockPanel { Margin = new Thickness(0, 10, 0, 0) };
            var cancel = Ui.IconButton(Glyphs.Close, "Cancel timer", () => _timers.Cancel(t));
            DockPanel.SetDock(cancel, Dock.Right);
            row.Children.Add(cancel);
            var digits = Ui.Text(TimerService.Format(t.Left), 22, Ui.Ink, FontWeights.SemiBold);
            digits.FontFamily = new FontFamily("Segoe UI Variable Display, Segoe UI");
            row.Children.Add(Ui.Row(12, digits, Ui.Text(t.Label + " timer", 13, Ui.Ink2)));
            col.Children.Add(row);
        }
        _root.Content = new ScrollViewer { Content = col, VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
    }
}

public sealed class ClipboardPanel : IPanel
{
    private readonly ClipboardService _clips;
    private readonly NoticeCenter _notices;
    private readonly ContentControl _root = new();
    public string Title => "Clipboard";
    public string Glyph => Glyphs.Clipboard;
    public bool Lockable => true;
    public UIElement View => _root;

    public ClipboardPanel(ClipboardService clips, NoticeCenter notices)
    {
        _clips = clips;
        _notices = notices;
        _clips.Items.CollectionChanged += (_, _) => Refresh();
        Refresh();
    }

    public void Refresh()
    {
        if (_clips.Items.Count == 0)
        {
            _root.Content = Ui.Empty("Nothing copied yet", "Text you copy shows up here. Copies from password managers are skipped.");
            return;
        }
        var col = new StackPanel();
        foreach (var item in _clips.Items)
        {
            var line = item.Text.Replace("\r", " ").Replace("\n", " ").Trim();
            var copy = Ui.Button(Ui.Text(line, 13), () =>
            {
                _clips.CopyAgain(item);
                _notices.Show(Glyphs.Copy, "Copied", 1.5);
            });
            copy.HorizontalContentAlignment = HorizontalAlignment.Left;
            copy.Background = Brushes.Transparent;
            var pin = Ui.IconButton(Glyphs.Pin, item.Pinned ? "Unpin" : "Pin", () => { _clips.TogglePin(item); Refresh(); });
            if (item.Pinned) pin.Foreground = Ui.Ink;
            var row = new DockPanel();
            DockPanel.SetDock(pin, Dock.Right);
            row.Children.Add(pin);
            row.Children.Add(copy);
            col.Children.Add(row);
        }
        var clear = Ui.Button("Clear", () => _clips.Clear());
        clear.HorizontalAlignment = HorizontalAlignment.Left;
        clear.Margin = new Thickness(0, 8, 0, 0);
        col.Children.Add(clear);
        _root.Content = new ScrollViewer { Content = col, VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
    }
}

public sealed class ClaudePanel : IPanel
{
    private readonly ClaudeStatusService _claude;
    private readonly ContentControl _root = new();
    public string Title => "Claude Code";
    public string Glyph => Glyphs.Code;
    public bool Lockable => false;
    public UIElement View => _root;

    public ClaudePanel(ClaudeStatusService claude) { _claude = claude; Refresh(); }

    public void Refresh()
    {
        if (!ClaudeHookInstaller.IsInstalled || ClaudeHookInstaller.NeedsUpdate)
        {
            _root.Content = Ui.Empty("Keep an eye on Claude Code",
                "Blob adds small hooks to Claude Code’s settings so it can show working, done, or waiting on you, for every session.",
                Ui.Button(ClaudeHookInstaller.NeedsUpdate ? "Reconnect" : "Connect Claude Code", () =>
                {
                    try { ClaudeHookInstaller.Install(); } catch { }
                    Refresh();
                }));
            return;
        }
        if (_claude.Sessions.Count == 0)
        {
            _root.Content = Ui.Empty("No sessions right now", "Start Claude Code in a terminal and it shows up here.");
            return;
        }
        var col = new StackPanel();
        foreach (var s in _claude.Sessions)
        {
            var dot = new Border
            {
                Width = 8, Height = 8, CornerRadius = new CornerRadius(4), Margin = new Thickness(0, 0, 10, 0),
                Background = s.State switch { "waiting" => Brushes.White, "working" => Ui.Ink2, _ => Ui.Ink3 },
            };
            var state = s.State switch { "waiting" => "Needs you", "working" => s.Detail, "done" => "Finished", _ => "Ready" };
            var row = Ui.Row(0, dot, Ui.Column(0, Ui.Text(s.Name, 14, Ui.Ink, FontWeights.SemiBold), Ui.Text(state, 12, Ui.Ink2)));
            row.Margin = new Thickness(0, 0, 0, 12);
            col.Children.Add(row);
        }
        _root.Content = new ScrollViewer { Content = col, VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
    }
}
