using System;
using System.Linq;
using System.Threading;
using System.Windows;
using Blob.Services;
using Blob.UI;
using Forms = System.Windows.Forms;

namespace Blob;

public partial class App : Application
{
    private static Services.Services? _services;
    private static NotchWindow? _notch;
    private static SettingsWindow? _settings;
    private Mutex? _single;
    private Forms.NotifyIcon? _tray;

    protected override async void OnStartup(StartupEventArgs e)
    {
        _single = new Mutex(true, @"Local\BlobNotchApp", out var first);
        if (!first)
        {
            Shutdown(0);
            return;
        }

        base.OnStartup(e);
        DispatcherUnhandledException += (_, args) =>
        {
            try { System.IO.File.AppendAllText(System.IO.Path.Combine(Core.Paths.Local, "crash.log"), $"{DateTime.Now}\n{args.Exception}\n\n"); } catch { }
            args.Handled = true;
        };

        _services = new Services.Services(Dispatcher);
        _notch = new NotchWindow(_services);
        _notch.Show();
        _services.Clipboard.Start(_notch);
        _services.Claude.Start();
        _services.Agent.Start();
        _services.Updates.Start();
        await _services.Music.StartAsync();
        await _services.Lock.RefreshAsync();
        _services.Timers.Finished += t => _services.Notices.Show(Glyphs.Timer, "Time’s up", 5);

        // Keep the Claude Code hook pointing at this copy if Blob moved.
        if (ClaudeHookInstaller.NeedsUpdate) { try { ClaudeHookInstaller.Install(); } catch { } }

        SetUpTray();

        // First run: say hello so people know where Blob lives.
        if (!System.IO.File.Exists(System.IO.Path.Combine(Core.Paths.Roaming, "settings.json")))
        {
            Core.Prefs.Update(_ => { });
            StartupService.Set(true);
            _services.Notices.Show(Glyphs.Ask, "Hi! I live up here", 5);
        }
    }

    private void SetUpTray()
    {
        _tray = new Forms.NotifyIcon { Text = "Blob", Visible = true };
        try
        {
            var stream = GetResourceStream(new Uri("pack://application:,,,/Assets/Blob.ico"))?.Stream;
            if (stream != null) _tray.Icon = new System.Drawing.Icon(stream);
        }
        catch { }
        var menu = new Forms.ContextMenuStrip();
        menu.Items.Add("Open Blob", null, (_, _) => _notch?.OpenPanel());
        menu.Items.Add("Settings…", null, (_, _) => ShowSettings());
        menu.Items.Add("Check for updates", null, async (_, _) => { if (_services != null) await _services.Updates.CheckAsync(); });
        menu.Items.Add(new Forms.ToolStripSeparator());
        menu.Items.Add("Quit Blob", null, (_, _) => Shutdown());
        _tray.ContextMenuStrip = menu;
        _tray.MouseClick += (_, args) => { if (args.Button == Forms.MouseButtons.Left) _notch?.OpenPanel(); };
    }

    public static void ShowSettings()
    {
        if (_services == null) return;
        if (_settings == null)
        {
            _settings = new SettingsWindow(_services);
            _settings.Closed += (_, _) => _settings = null;
        }
        _settings.Show();
        _settings.Activate();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        if (_tray != null) { _tray.Visible = false; _tray.Dispose(); }
        _single?.Dispose();
        base.OnExit(e);
    }
}
