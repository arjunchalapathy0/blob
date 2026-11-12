using System;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Threading;
using Blob.Core;
using Blob.Services;

namespace Blob.UI;

/// <summary>Blob's settings, in an ordinary window.</summary>
public sealed class SettingsWindow : Window
{
    private readonly Services.Services _s;
    private readonly StackPanel _col = new() { Margin = new Thickness(26, 22, 26, 26), Spacing = 6 };
    private readonly TextBlock _whisper = Note(" ");
    private readonly TextBlock _update = Note(" ");
    private readonly Button _updateButton = new();
    private readonly Button _whisperButton = new() { Content = "Download Whisper now" };
    private readonly TextBlock _claude = Note(" ");
    private readonly Button _claudeButton = new();

    public SettingsWindow(Services.Services s)
    {
        _s = s;
        Title = "Blob Settings";
        Width = 540;
        SizeToContent = SizeToContent.Height;
        MaxHeight = 660;
        CanResize = false;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;
        FontFamily = Ui.Font;
        using (var icon = StartupService.Icon())
            if (icon != null) Icon = new WindowIcon(icon);
        Content = new ScrollViewer { Content = _col };
        Build();
        Sync();

        void OnChange() => Dispatcher.UIThread.Post(Sync);
        _s.Agent.Changed += OnChange;
        _s.Updates.Changed += OnChange;
        Closed += (_, _) => { _s.Agent.Changed -= OnChange; _s.Updates.Changed -= OnChange; };
    }

    private void Build()
    {
        var p = Prefs.Current;

        Section("General");
        Toggle("Open Blob when I sign in", StartupService.IsEnabled, StartupService.Set);
        Toggle("Show Blob in the apps menu", StartupService.InMenu, on => { if (on) StartupService.AddToMenu(); else StartupService.RemoveAll(); });
        Toggle("Keep the notch open when the pointer leaves", p.StayOpen, v => Prefs.Update(x => x.StayOpen = v));
        Toggle("Play a sound when a timer ends", p.TimerSound, v => Prefs.Update(x => x.TimerSound = v));
        Toggle("Keep a clipboard history (in memory only)", p.ClipboardHistory, v => Prefs.Update(x => x.ClipboardHistory = v));

        Section("Talk to Blob");
        if (VoiceKey.IsSupported)
        {
            Toggle("Hold a key to talk", p.VoiceKey, v => Prefs.Update(x => x.VoiceKey = v));
            var key = new ComboBox { Width = 280, Margin = new Thickness(28, 0, 0, 4), ItemsSource = new[] { "Right Alt", "Right Ctrl (if Right Alt is AltGr)" } };
            key.SelectedIndex = p.TalkKey == "RightCtrl" ? 1 : 0;
            key.SelectionChanged += (_, _) => Prefs.Update(x => x.TalkKey = key.SelectedIndex == 1 ? "RightCtrl" : "RightAlt");
            _col.Children.Add(key);
        }
        else
        {
            _col.Children.Add(Note("On Wayland, apps can’t see keys pressed in other apps, so Blob can’t watch Right Alt here. " +
                                   "Hold the microphone button in the notch, or add a keyboard shortcut in your desktop’s settings that runs:"));
        }
        _col.Children.Add(Note(VoiceKey.IsSupported ? "A keyboard shortcut works too. Press once to start, again to stop:" : ""));
        _col.Children.Add(new SelectableTextBlock
        {
            Text = $"{Paths.Exe} --toggle-talk",
            FontFamily = new FontFamily("monospace"), FontSize = 12.5, TextWrapping = TextWrapping.Wrap,
            Margin = new Thickness(0, 0, 0, 6),
        });
        _col.Children.Add(Note(VoiceRecorder.HasRecorder
            ? "Microphone: ready. It only records while you hold the key or button."
            : "Microphone: no recorder found. Install pulseaudio-utils or alsa-utils."));
        _col.Children.Add(_whisper);
        _whisperButton.Click += (_, _) => _ = _s.Agent.WarmUpAsync();
        _col.Children.Add(_whisperButton);

        Section("Claude Code");
        _col.Children.Add(Note(_s.Agent.ClaudeInstalled
            ? "Claude Code is installed. Blob uses your own Claude subscription to do things."
            : "Claude Code isn’t installed. Blob needs it to do things on your computer."));
        if (!_s.Agent.ClaudeInstalled) Action("How to install Claude Code", () => Tools.Open("https://claude.com/claude-code"));
        _col.Children.Add(_claude);
        _claudeButton.Click += (_, _) =>
        {
            try
            {
                if (ClaudeHookInstaller.IsInstalled && !ClaudeHookInstaller.NeedsUpdate) ClaudeHookInstaller.Uninstall();
                else ClaudeHookInstaller.Install();
            }
            catch (Exception e) { _claude.Text = e.Message; }
            Sync();
        };
        _col.Children.Add(_claudeButton);
        _col.Children.Add(Note("Connecting adds hooks to ~/.claude/settings.json that run Blob with --claude-hook. A backup is saved next to it."));

        Section("Updates");
        _col.Children.Add(_update);
        _updateButton.Click += (_, _) => _ = _s.Updates.IsAvailable ? _s.Updates.UpdateAsync() : _s.Updates.CheckAsync();
        _col.Children.Add(_updateButton);

        var quit = new Button { Content = "Quit Blob", HorizontalAlignment = HorizontalAlignment.Right, Margin = new Thickness(0, 18, 0, 0) };
        quit.Click += (_, _) => App.Quit();
        _col.Children.Add(quit);
    }

    /// <summary>Refreshes the lines that change while the window is open.</summary>
    private void Sync()
    {
        _whisper.Text = $"Speech to text (Whisper, on this computer): {_s.Agent.WhisperStatus}";
        _whisperButton.IsVisible = !_s.Agent.Transcriber.IsReady && !_s.Agent.WhisperStatus.StartsWith("Downloading") && !_s.Agent.WhisperStatus.StartsWith("Loading");
        _update.Text = $"Blob {UpdateService.CurrentVersion} (build {UpdateService.CurrentBuild}). {_s.Updates.Status}";
        _updateButton.Content = _s.Updates.IsAvailable ? "Update now" : "Check now";
        _updateButton.IsEnabled = !_s.Updates.IsUpdating;
        var installed = ClaudeHookInstaller.IsInstalled;
        var stale = ClaudeHookInstaller.NeedsUpdate;
        _claude.Text = installed ? (stale ? "Sessions: connected, but pointing at an older copy of Blob." : "Sessions: connected. They show in the notch.") : "Sessions: not connected.";
        _claudeButton.Content = installed && !stale ? "Disconnect" : "Connect Claude Code";
    }

    private void Section(string title) => _col.Children.Add(new TextBlock
    {
        Text = title, FontSize = 16, FontWeight = FontWeight.SemiBold,
        Margin = new Thickness(0, _col.Children.Count == 0 ? 0 : 18, 0, 2),
    });

    private void Toggle(string label, bool value, Action<bool> set)
    {
        var box = new CheckBox { Content = label, IsChecked = value };
        box.IsCheckedChanged += (_, _) => set(box.IsChecked == true);
        _col.Children.Add(box);
    }

    private static TextBlock Note(string text) => new()
    {
        Text = text, TextWrapping = TextWrapping.Wrap, FontSize = 13, Opacity = 0.7, IsVisible = text.Length > 0,
    };

    private void Action(string label, Action run)
    {
        var button = new Button { Content = label };
        button.Click += (_, _) => run();
        _col.Children.Add(button);
    }
}
