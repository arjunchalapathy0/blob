using System;
using System.Diagnostics;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using Blob.Core;
using Blob.Services;

namespace Blob.UI;

/// <summary>Blob's settings, in a plain Windows window.</summary>
public sealed class SettingsWindow : Window
{
    private readonly Services.Services _s;
    private readonly StackPanel _col = new() { Margin = new Thickness(24) };

    public SettingsWindow(Services.Services s)
    {
        _s = s;
        Title = "Blob Settings";
        Width = 520;
        SizeToContent = SizeToContent.Height;
        MaxHeight = 820;
        ResizeMode = ResizeMode.NoResize;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;
        FontFamily = new FontFamily("Segoe UI Variable Text, Segoe UI");
        FontSize = 14;
        try { Icon = System.Windows.Media.Imaging.BitmapFrame.Create(new Uri("pack://application:,,,/Assets/Blob.ico")); } catch { }
        Content = new ScrollViewer { Content = _col, VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
        Build();
        _s.Agent.Changed += Rebuild;
        _s.Updates.Changed += Rebuild;
        Closed += (_, _) => { _s.Agent.Changed -= Rebuild; _s.Updates.Changed -= Rebuild; };
    }

    private void Rebuild() => Dispatcher.BeginInvoke(Build);

    private void Build()
    {
        _col.Children.Clear();
        var p = Prefs.Current;

        Section("General");
        Toggle("Open Blob when I sign in to Windows", StartupService.IsEnabled, v => StartupService.Set(v));
        Toggle("Keep the notch open when the pointer leaves", p.StayOpen, v => Prefs.Update(x => x.StayOpen = v));
        Toggle("Play a sound when a timer ends", p.TimerSound, v => Prefs.Update(x => x.TimerSound = v));

        Section("Talk to Blob");
        Toggle("Hold a key to talk", p.VoiceKey, v => Prefs.Update(x => x.VoiceKey = v));
        var key = new ComboBox { Width = 200, HorizontalAlignment = HorizontalAlignment.Left, Margin = new Thickness(26, 4, 0, 4) };
        key.Items.Add("Right Alt");
        key.Items.Add("Right Ctrl (if Right Alt is AltGr)");
        key.SelectedIndex = p.TalkKey == "RightCtrl" ? 1 : 0;
        key.SelectionChanged += (_, _) => Prefs.Update(x => x.TalkKey = key.SelectedIndex == 1 ? "RightCtrl" : "RightAlt");
        _col.Children.Add(key);
        Note($"Whisper (speech to text, on this PC): {_s.Agent.WhisperStatus}");
        if (!_s.Agent.Transcriber.IsReady)
            Action("Download Whisper now", () => _ = _s.Agent.WarmUpAsync());
        Note(_s.Agent.ClaudeInstalled
            ? "Claude Code is installed. Blob uses your own Claude subscription to do things."
            : "Claude Code isn’t installed. Blob needs it (and Git for Windows) to do things on your PC.");
        if (!_s.Agent.ClaudeInstalled) Action("How to install Claude Code", () => Open("https://code.claude.com/docs"));

        Section("Privacy");
        Toggle("Lock Clipboard and Ask with Windows Hello", p.LockWithHello, v => Prefs.Update(x => x.LockWithHello = v));
        Note($"{_s.Lock.Availability}. Windows Hello uses your face on PCs with an IR camera, or a fingerprint or PIN.");

        Section("Claude Code");
        var installed = ClaudeHookInstaller.IsInstalled;
        Note(installed
            ? (ClaudeHookInstaller.NeedsUpdate ? "Connected, but pointing at an older copy of Blob." : "Connected. Sessions show in the notch.")
            : "Not connected.");
        Action(installed && !ClaudeHookInstaller.NeedsUpdate ? "Disconnect" : "Connect Claude Code", () =>
        {
            try
            {
                if (installed && !ClaudeHookInstaller.NeedsUpdate) ClaudeHookInstaller.Uninstall(); else ClaudeHookInstaller.Install();
            }
            catch (Exception e) { MessageBox.Show(this, e.Message, "Blob"); }
            Build();
        });
        Note("Adds hooks to ~\\.claude\\settings.json that run Blob with --claude-hook. A backup is saved next to it.");

        Section("Updates");
        Note($"Blob {UpdateService.CurrentVersion} (build {UpdateService.CurrentBuild}). {_s.Updates.Status}");
        if (_s.Updates.IsAvailable) Action("Update now", () => _ = _s.Updates.UpdateAsync());
        else Action("Check now", () => _ = _s.Updates.CheckAsync());

        var quit = new Button { Content = "Quit Blob", Padding = new Thickness(14, 4, 14, 4), HorizontalAlignment = HorizontalAlignment.Right, Margin = new Thickness(0, 24, 0, 0) };
        quit.Click += (_, _) => Application.Current.Shutdown();
        _col.Children.Add(quit);
    }

    private void Section(string title)
    {
        _col.Children.Add(new TextBlock
        {
            Text = title, FontSize = 16, FontWeight = FontWeights.SemiBold,
            Margin = new Thickness(0, _col.Children.Count == 0 ? 0 : 22, 0, 6),
        });
    }

    private void Toggle(string label, bool value, Action<bool> set)
    {
        var c = new CheckBox { Content = label, IsChecked = value, Margin = new Thickness(0, 4, 0, 4) };
        c.Checked += (_, _) => set(true);
        c.Unchecked += (_, _) => set(false);
        _col.Children.Add(c);
    }

    private void Note(string text) => _col.Children.Add(new TextBlock
    {
        Text = text, TextWrapping = TextWrapping.Wrap, Foreground = Brushes.DimGray, FontSize = 13, Margin = new Thickness(0, 4, 0, 4),
    });

    private void Action(string label, Action run)
    {
        var b = new Button { Content = label, Padding = new Thickness(14, 4, 14, 4), HorizontalAlignment = HorizontalAlignment.Left, Margin = new Thickness(0, 4, 0, 4) };
        b.Click += (_, _) => run();
        _col.Children.Add(b);
    }

    private static void Open(string url)
    {
        try { Process.Start(new ProcessStartInfo(url) { UseShellExecute = true }); } catch { }
    }
}
