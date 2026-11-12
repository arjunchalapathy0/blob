using System;
using System.Linq;
using Avalonia;
using Avalonia.Automation;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Layout;
using Avalonia.Media;
using Blob.Core;
using Blob.Services;

namespace Blob.UI;

/// <summary>Everything the open notch can show. Each panel rebuilds from its service when it changes.</summary>
public interface IPanel
{
    string Title { get; }
    string Icon { get; }
    Control View { get; }
    void Refresh();
}

public sealed class AskPanel : IPanel
{
    private static readonly string[] Suggestions = { "Put on some music", "What’s on my screen?", "Open my Downloads" };

    private readonly AgentService _agent;
    private readonly Grid _root = new() { RowDefinitions = new RowDefinitions("*,Auto") };
    private readonly ContentControl _body = new();
    private readonly TextBox _input;
    private readonly ContentControl _action = new();

    public string Title => "Ask";
    public string Icon => "ask";
    public Control View => _root;
    public TextBox Input => _input;

    public AskPanel(AgentService agent)
    {
        _agent = agent;
        _root.Children.Add(_body);

        _input = new TextBox
        {
            Watermark = "Tell Blob what to do…",
            FontFamily = Ui.Font,
            FontSize = 14,
            Foreground = Ink.Primary,
            Background = Ink.Fill,
            BorderThickness = new Thickness(0),
            CornerRadius = new CornerRadius(18),
            Padding = new Thickness(16, 8, 12, 8),
            MinHeight = 36,
            VerticalContentAlignment = VerticalAlignment.Center,
            AcceptsReturn = false,
        };
        AutomationProperties.SetName(_input, "Tell Blob what to do");
        _input.KeyDown += (_, e) =>
        {
            if (e.Key != Key.Enter) return;
            Send();
            e.Handled = true;
        };
        _input.TextChanged += (_, _) => RefreshAction();

        // Hold to talk with the mouse: works everywhere, including where the key can't be watched.
        var mic = Ui.IconButton("mic", "Hold to talk", () => { }, 36, 15);
        mic.Colours(Ink.Fill, Ink.FillStrong);
        mic.Down += () => _agent.BeginListening();
        mic.Up += () => _agent.EndListening();

        var bar = new Grid { ColumnDefinitions = new ColumnDefinitions("*,Auto,Auto"), ColumnSpacing = 6, Margin = new Thickness(0, 10, 0, 0) };
        bar.Children.Add(_input);
        Grid.SetColumn(mic, 1);
        bar.Children.Add(mic);
        Grid.SetColumn(_action, 2);
        bar.Children.Add(_action);
        Grid.SetRow(bar, 1);
        _root.Children.Add(bar);
        Refresh();
    }

    private void Send()
    {
        var text = _input.Text?.Trim();
        if (string.IsNullOrEmpty(text)) return;
        _input.Text = "";
        _agent.Run(text);
    }

    private void RefreshAction()
    {
        Pressable button;
        if (_agent.State == AgentService.Phase.Working)
            button = Ui.IconButton("stop", "Stop", _agent.Cancel, 36, 13, Ink.Primary);
        else if (string.IsNullOrEmpty(_input.Text) && _agent.Request.Length > 0)
            button = Ui.IconButton("plus", "New conversation", _agent.NewConversation, 36, 14);
        else
            button = Ui.IconButton("send", "Send", Send, 36, 14, string.IsNullOrEmpty(_input.Text) ? Ink.Tertiary : Ink.Primary);
        button.Colours(Ink.Fill, Ink.FillStrong);
        _action.Content = button;
    }

    public void Refresh()
    {
        RefreshAction();
        if (!_agent.ClaudeInstalled)
        {
            _body.Content = Ui.Empty("Blob needs Claude Code to do things.",
                "Install Claude Code, sign in once with your Claude account, then come back.",
                Ui.Pill("How to install", () => Tools.Open("https://claude.com/claude-code"), true));
            return;
        }
        var key = Prefs.Current.TalkKey == "RightCtrl" ? "Right Ctrl" : "Right Alt";
        var canHoldKey = VoiceKey.IsSupported && Prefs.Current.VoiceKey;
        switch (_agent.State)
        {
            case AgentService.Phase.Idle when _agent.Request.Length == 0:
                var chips = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 6 };
                foreach (var text in Suggestions)
                {
                    var request = text;
                    chips.Children.Add(Ui.Pill(text, () => _agent.Run(request)));
                }
                _body.Content = Ui.Empty("Tell Blob what to do on your computer.",
                    canHoldKey ? $"Type below, or hold {key} and talk." : "Type below, or hold the microphone and talk.", chips);
                return;
            case AgentService.Phase.Listening:
                _body.Content = Ui.Empty("Listening…", "Let go when you’re done.");
                return;
            case AgentService.Phase.Transcribing:
                _body.Content = Ui.Empty("One sec…",
                    _agent.WhisperStatus.StartsWith("Downloading") ? "Downloading Whisper, about 150 MB. Only this once." : "Turning that into words.");
                return;
        }

        var col = new StackPanel { Spacing = 6 };
        col.Children.Add(Ui.Text(_agent.Request, 13, Ink.Tertiary, FontWeight.SemiBold, wrap: true));
        var steps = _agent.Steps.TakeLast(4).ToList();
        for (var i = 0; i < steps.Count; i++)
        {
            var current = i == steps.Count - 1 && _agent.State == AgentService.Phase.Working;
            var dot = new Border { Width = 4, Height = 4, CornerRadius = new CornerRadius(2), Background = current ? Ink.Primary : Ink.Tertiary, VerticalAlignment = VerticalAlignment.Center };
            col.Children.Add(Ui.Row(8, dot, Ui.Text(steps[i], 13, current ? Ink.Primary : Ink.Secondary)));
        }
        if (_agent.State == AgentService.Phase.Working && _agent.Steps.Count == 0)
            col.Children.Add(Ui.Text("Thinking…", 13, Ink.Secondary));
        if (_agent.State == AgentService.Phase.Failed && _agent.Error != null)
            col.Children.Add(Ui.Text(_agent.Error, 13.5, Ink.Secondary, wrap: true));
        else if (_agent.Reply.Length > 0)
        {
            var reply = Ui.Text(_agent.Reply.Trim(), 14, Ink.Primary, wrap: true);
            reply.Margin = new Thickness(0, 4, 0, 0);
            col.Children.Add(reply);
        }
        _body.Content = Ui.Scroll(col);
    }
}

public sealed class MusicPanel : IPanel
{
    private readonly NowPlayingService _music;
    private readonly ContentControl _root = new();
    public string Title => "Now Playing";
    public string Icon => "music";
    public Control View => _root;

    public MusicPanel(NowPlayingService music) { _music = music; Refresh(); }

    public void Refresh()
    {
        if (!_music.HasTrack)
        {
            _root.Content = Ui.Empty("Nothing playing",
                _music.Available
                    ? "Play something in Spotify, a browser, VLC, or any app that shows in your desktop’s media controls."
                    : "Now Playing reads the desktop’s media controls with busctl, which this system doesn’t have.");
            return;
        }
        var art = new Border
        {
            Width = 112, Height = 112, CornerRadius = new CornerRadius(16), ClipToBounds = true,
            Background = _music.Artwork != null ? new ImageBrush(_music.Artwork) { Stretch = Stretch.UniformToFill } : Ink.Fill,
        };
        if (_music.Artwork == null) art.Child = Icons.Make("music", 34, Ink.Tertiary);
        var controls = Ui.Row(6,
            Ui.IconButton("previous", "Previous", _music.Previous, 40, 17, Ink.Secondary),
            Ui.IconButton(_music.IsPlaying ? "pause" : "play", _music.IsPlaying ? "Pause" : "Play", _music.PlayPause, 44, 22, Ink.Primary),
            Ui.IconButton("next", "Next", _music.Next, 40, 17, Ink.Secondary));
        controls.Margin = new Thickness(-10, 12, 0, 0);
        var info = Ui.Column(2,
            Ui.Text(_music.Title, 18, Ink.Primary, FontWeight.SemiBold),
            Ui.Text(_music.Artist, 14, Ink.Secondary),
            controls);
        info.VerticalAlignment = VerticalAlignment.Center;
        var row = new Grid { ColumnDefinitions = new ColumnDefinitions("Auto,*"), ColumnSpacing = 20, VerticalAlignment = VerticalAlignment.Center };
        row.Children.Add(art);
        Grid.SetColumn(info, 1);
        row.Children.Add(info);
        _root.Content = row;
    }
}

public sealed class TimersPanel : IPanel
{
    private readonly TimerService _timers;
    private readonly StackPanel _list = new() { Spacing = 4, Margin = new Thickness(0, 10, 0, 0) };
    private readonly StackPanel _root = new();
    private int _shown = -1;
    public string Title => "Timers";
    public string Icon => "timer";
    public Control View => _view;
    private readonly Control _view;

    public TimersPanel(TimerService timers)
    {
        _timers = timers;
        var presets = new WrapPanel();
        foreach (var m in new[] { 1, 3, 5, 10, 15, 25, 45, 60 })
        {
            var pill = Ui.Pill(m < 60 ? $"{m} min" : "1 hour", () => _timers.Start(TimeSpan.FromMinutes(m)));
            pill.Margin = new Thickness(0, 0, 6, 6);
            presets.Children.Add(pill);
        }
        _root.Children.Add(presets);
        _root.Children.Add(_list);
        _view = Ui.Scroll(_root);
        Refresh();
    }

    public void Refresh()
    {
        var timers = _timers.Timers.OrderBy(t => t.Ends).ToList();
        // Rebuild rows only when the set changes; otherwise just tick the digits.
        if (timers.Count != _shown)
        {
            _shown = timers.Count;
            _list.Children.Clear();
            if (timers.Count == 0)
                _list.Children.Add(Ui.Text("Pick one. It counts down in the notch and says “Time’s up”.", 13, Ink.Secondary, wrap: true));
            foreach (var t in timers)
            {
                var timer = t;
                var digits = Ui.Text(TimerService.Format(t.Left), 20, Ink.Primary, FontWeight.SemiBold);
                digits.Tag = timer;
                digits.MinWidth = 64;
                var cancel = Ui.IconButton("close", "Cancel timer", () => _timers.Cancel(timer), 26, 11);
                var row = new Grid { ColumnDefinitions = new ColumnDefinitions("Auto,*,Auto"), ColumnSpacing = 12 };
                row.Children.Add(digits);
                var label = Ui.Text(t.Label + " timer", 13, Ink.Secondary);
                Grid.SetColumn(label, 1);
                row.Children.Add(label);
                Grid.SetColumn(cancel, 2);
                row.Children.Add(cancel);
                _list.Children.Add(new Border { Background = Ink.Fill, CornerRadius = new CornerRadius(12), Padding = new Thickness(12, 6, 6, 6), Child = row });
            }
            return;
        }
        foreach (var border in _list.Children.OfType<Border>())
            if (border.Child is Grid { Children: [TextBlock { Tag: BlobTimer t } digits, ..] })
                digits.Text = TimerService.Format(t.Left);
    }
}

public sealed class ClipboardPanel : IPanel
{
    private readonly ClipboardService _clips;
    private readonly NoticeCenter _notices;
    private readonly ContentControl _root = new();
    public string Title => "Clipboard";
    public string Icon => "clipboard";
    public Control View => _root;

    public ClipboardPanel(ClipboardService clips, NoticeCenter notices)
    {
        _clips = clips;
        _notices = notices;
        _clips.Items.CollectionChanged += (_, _) => Refresh();
        Refresh();
    }

    public void Refresh()
    {
        if (!Prefs.Current.ClipboardHistory)
        {
            _root.Content = Ui.Empty("Clipboard history is off", "Turn it on in Settings.");
            return;
        }
        if (_clips.Items.Count == 0)
        {
            _root.Content = Ui.Empty("Nothing copied yet", "Text you copy shows up here. Copies from password managers are skipped.");
            return;
        }
        var col = new StackPanel { Spacing = 4 };
        foreach (var item in _clips.Items)
        {
            var clip = item;
            var line = item.Text.Replace("\r", " ").Replace("\n", " ").Trim();
            var copy = new Pressable { CornerRadius = new CornerRadius(10), Padding = new Thickness(12, 7), Child = Ui.Text(line, 13) };
            copy.Colours(Ink.Fill, Ink.FillStrong);
            copy.Click += () =>
            {
                _clips.CopyAgain(clip);
                _notices.Show("copy", "Copied", 1.5);
            };
            AutomationProperties.SetName(copy, "Copy again: " + line);
            var pin = Ui.IconButton("pin", item.Pinned ? "Unpin" : "Pin", () => { _clips.TogglePin(clip); Refresh(); }, 28, 12,
                item.Pinned ? Ink.Primary : Ink.Tertiary);
            var row = new Grid { ColumnDefinitions = new ColumnDefinitions("*,Auto"), ColumnSpacing = 4 };
            row.Children.Add(copy);
            Grid.SetColumn(pin, 1);
            row.Children.Add(pin);
            col.Children.Add(row);
        }
        var clear = Ui.Pill("Clear", () => _clips.Clear());
        clear.HorizontalAlignment = HorizontalAlignment.Left;
        clear.Margin = new Thickness(0, 6, 0, 0);
        col.Children.Add(clear);
        _root.Content = Ui.Scroll(col);
    }
}

public sealed class ClaudePanel : IPanel
{
    private readonly ClaudeStatusService _claude;
    private readonly ContentControl _root = new();
    public string Title => "Claude Code";
    public string Icon => "code";
    public Control View => _root;

    public ClaudePanel(ClaudeStatusService claude) { _claude = claude; Refresh(); }

    public void Refresh()
    {
        if (!ClaudeHookInstaller.IsInstalled || ClaudeHookInstaller.NeedsUpdate)
        {
            _root.Content = Ui.Empty("Keep an eye on Claude Code",
                "Blob adds small hooks to Claude Code’s settings so it can show working, done, or waiting on you, for every session.",
                Ui.Pill(ClaudeHookInstaller.NeedsUpdate ? "Reconnect" : "Connect Claude Code", () =>
                {
                    try { ClaudeHookInstaller.Install(); } catch { }
                    Refresh();
                }, true));
            return;
        }
        if (_claude.Sessions.Count == 0)
        {
            _root.Content = Ui.Empty("No sessions right now", "Start Claude Code in a terminal and it shows up here.");
            return;
        }
        var col = new StackPanel { Spacing = 4 };
        foreach (var s in _claude.Sessions)
        {
            var waiting = s.State == "waiting";
            var state = s.State switch { "waiting" => "Needs you", "working" => "Working", "done" => "Done", _ => "Idle" };
            var badge = new Border
            {
                CornerRadius = new CornerRadius(999), Padding = new Thickness(9, 3),
                Background = waiting ? Brushes.White : Ink.FillStrong, VerticalAlignment = VerticalAlignment.Center,
                Child = Ui.Text(state, 11, waiting ? Brushes.Black : Ink.Secondary, FontWeight.SemiBold),
            };
            var names = Ui.Column(0, Ui.Text(s.Name, 13.5, Ink.Primary, FontWeight.SemiBold), Ui.Text(s.Detail, 12, Ink.Secondary));
            var row = new Grid { ColumnDefinitions = new ColumnDefinitions("*,Auto"), ColumnSpacing = 10 };
            row.Children.Add(names);
            Grid.SetColumn(badge, 1);
            row.Children.Add(badge);
            col.Children.Add(new Border { Background = Ink.Fill, CornerRadius = new CornerRadius(12), Padding = new Thickness(12, 7), Child = row });
        }
        _root.Content = Ui.Scroll(col);
    }
}

/// <summary>First run: who Blob is, and what it needs before it can help.</summary>
public sealed class WelcomePanel
{
    private readonly AgentService _agent;
    private readonly Action _done;
    private readonly ContentControl _root = new();
    public Control View => _root;

    public WelcomePanel(AgentService agent, Action done)
    {
        _agent = agent;
        _done = done;
        Refresh();
    }

    public void Refresh()
    {
        var claude = _agent.ClaudeInstalled;
        var recorder = VoiceRecorder.HasRecorder;
        var key = VoiceKey.IsSupported;

        var hello = Ui.Column(6,
            new BlobView(34) { Mood = Mood.Happy, HorizontalAlignment = HorizontalAlignment.Left, Tag = "welcome-blob" },
            Ui.Text("Hi, I’m Blob.", 18, Ink.Primary, FontWeight.SemiBold),
            Ui.Text(key ? "I live up here. Hover to open me, or hold Right Alt and tell me what to do."
                        : "I live up here. Hover to open me, then type or hold the microphone.", 12.5, Ink.Secondary, wrap: true));
        hello.Width = 200;
        hello.VerticalAlignment = VerticalAlignment.Center;

        var rows = new StackPanel { Spacing = 4 };
        rows.Children.Add(Row("code", "Claude Code", "Lets me do things, on your own Claude plan.", claude,
            "Get it", () => Tools.Open("https://claude.com/claude-code")));
        rows.Children.Add(Row("mic", "Microphone", recorder ? "Only records while you hold the key or button." : "Install pulseaudio-utils or alsa-utils.", recorder,
            "How", () => Tools.Open("https://blobnotch.app/#get")));
        rows.Children.Add(Row("ask", "Talk key", key ? "Hold Right Alt anywhere." : "On Wayland, bind a shortcut to: blob --toggle-talk", key,
            "Settings", App.ShowSettings));
        var footer = new Grid { ColumnDefinitions = new ColumnDefinitions("*,Auto"), Margin = new Thickness(2, 4, 2, 0) };
        footer.Children.Add(Ui.Text("All of this is in Settings too.", 11.5, Ink.Tertiary));
        var go = Ui.Pill(claude ? "Let’s go" : "Later", _done, true);
        Grid.SetColumn(go, 1);
        footer.Children.Add(go);
        rows.Children.Add(footer);
        rows.VerticalAlignment = VerticalAlignment.Center;

        var grid = new Grid { ColumnDefinitions = new ColumnDefinitions("Auto,*"), ColumnSpacing = 22 };
        grid.Children.Add(hello);
        Grid.SetColumn(rows, 1);
        grid.Children.Add(rows);
        _root.Content = grid;
    }

    private static Control Row(string icon, string title, string detail, bool ready, string action, Action run)
    {
        var mark = Icons.Make(ready ? "check" : icon, 14, ready ? Ink.Primary : Ink.Secondary);
        var names = Ui.Column(0, Ui.Text(title, 13, Ink.Primary, FontWeight.SemiBold), Ui.Text(detail, 11.5, Ink.Secondary));
        Control trailing = ready ? Ui.Text("Ready", 11.5, Ink.Tertiary, FontWeight.SemiBold) : Ui.Pill(action, run);
        trailing.VerticalAlignment = VerticalAlignment.Center;
        var row = new Grid { ColumnDefinitions = new ColumnDefinitions("Auto,*,Auto"), ColumnSpacing = 10 };
        row.Children.Add(mark);
        Grid.SetColumn(names, 1);
        row.Children.Add(names);
        Grid.SetColumn(trailing, 2);
        row.Children.Add(trailing);
        return new Border { Background = Ink.Fill, CornerRadius = new CornerRadius(12), Padding = new Thickness(12, 6, 8, 6), Child = row };
    }
}
