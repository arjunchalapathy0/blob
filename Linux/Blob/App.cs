using System;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Styling;
using Avalonia.Themes.Fluent;
using Avalonia.Threading;
using Blob.Services;
using Blob.UI;

namespace Blob;

public sealed class App : Application
{
    private static Services.Services? _services;
    private static NotchWindow? _notch;
    private static SettingsWindow? _settings;
    private static IClassicDesktopStyleApplicationLifetime? _desktop;

    /// <summary>A command given on the command line when Blob wasn't running yet.</summary>
    public static string? PendingCommand { get; set; }

    public override void Initialize()
    {
        Name = "Blob";
        Styles.Add(new FluentTheme());
        RequestedThemeVariant = ThemeVariant.Dark;
    }

    public override void OnFrameworkInitializationCompleted()
    {
        if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
        {
            _desktop = desktop;
            var s = _services = new Services.Services();
            _notch = new NotchWindow(s);
            _notch.Show();

            s.Clipboard.Start(_notch);
            s.Claude.Start();
            s.Agent.Start();
            s.Music.Start();
            s.Updates.Start();
            s.Timers.Finished += _ => s.Notices.Show("timer", "Time’s up", 5);
            s.Updates.RestartRequested += () => desktop.Shutdown();

            // Keep the Claude Code hook and the menu entries pointing at this copy if Blob moved.
            if (ClaudeHookInstaller.NeedsUpdate) { try { ClaudeHookInstaller.Install(); } catch { } }
            StartupService.Refresh();

            Ipc.Listen(Handle);
            desktop.Exit += (_, _) => Ipc.Close();
            SetUpTray();

            if (PendingCommand is { } pending)
                DispatcherTimer.RunOnce(() => Handle(pending), TimeSpan.FromMilliseconds(1200));
        }
        base.OnFrameworkInitializationCompleted();
    }

    /// <summary>Commands from the tray, and from `blob --…` run while Blob is already up.</summary>
    private static void Handle(string command)
    {
        if (_services == null) return;
        if (command.StartsWith("ask "))
        {
            var text = command[4..].Trim();
            _notch?.OpenPanel("Ask");
            if (text.Length > 0) _services.Agent.Run(text);
            return;
        }
        switch (command)
        {
            case "open": _notch?.OpenPanel(); break;
            case "toggle-talk": _services.Agent.ToggleListening(); break;
            case "talk-start": _services.Agent.BeginListening(); break;
            case "talk-stop": _services.Agent.EndListening(); break;
            case "settings": ShowSettings(); break;
            case "quit": _desktop?.Shutdown(); break;
        }
    }

    private void SetUpTray()
    {
        try
        {
            var menu = new NativeMenu();
            void Add(string title, Action run)
            {
                var item = new NativeMenuItem(title);
                item.Click += (_, _) => run();
                menu.Add(item);
            }
            Add("Open Blob", () => Handle("open"));
            Add("Settings…", ShowSettings);
            Add("Check for updates", () => _ = _services?.Updates.CheckAsync());
            menu.Add(new NativeMenuItemSeparator());
            Add("Quit Blob", () => Handle("quit"));

            var tray = new TrayIcon { ToolTipText = "Blob", Menu = menu };
            using (var icon = StartupService.Icon())
                if (icon != null) tray.Icon = new WindowIcon(icon);
            tray.Clicked += (_, _) => Handle("open");
            TrayIcon.SetIcons(this, new TrayIcons { tray });
        }
        catch { /* no tray on this desktop: the gear in the notch opens Settings */ }
    }

    public static void ShowSettings()
    {
        if (_services == null) return;
        _notch?.CloseNow();
        if (_settings == null)
        {
            _settings = new SettingsWindow(_services);
            _settings.Closed += (_, _) => _settings = null;
        }
        _settings.Show();
        _settings.Activate();
    }

    public static void Quit() => _desktop?.Shutdown();
}
