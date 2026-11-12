using System;
using System.Linq;
using Avalonia;
using Blob.Services;

namespace Blob;

public static class Program
{
    private const string Help =
        "Blob lives at the top of your screen and does what you say.\n\n" +
        "  blob                   start Blob, or open it if it is already running\n" +
        "  blob --toggle-talk     start listening; run it again to stop (bind this to a keyboard shortcut)\n" +
        "  blob --ask \"…\"         ask Blob to do something\n" +
        "  blob --settings        open Settings\n" +
        "  blob --quit            quit Blob\n" +
        "  blob --install         add Blob to the apps menu and start it at sign-in\n" +
        "  blob --uninstall       undo --install, and disconnect Claude Code\n" +
        "  blob --version\n";

    [STAThread]
    public static int Main(string[] args)
    {
        // Claude Code runs `blob --claude-hook` on every tool call: record the status and
        // leave before any window code loads, so it adds almost no time to Claude's work.
        if (args.Contains(ClaudeHook.Marker))
        {
            ClaudeHook.Run();
            return 0;
        }

        var first = args.FirstOrDefault() ?? "";
        switch (first)
        {
            case "--help" or "-h":
                Console.Write(Help);
                return 0;
            case "--version":
                Console.WriteLine($"Blob {UpdateService.CurrentVersion} (build {UpdateService.CurrentBuild})");
                return 0;
            case "--install":
                StartupService.AddToMenu();
                StartupService.Set(true);
                Console.WriteLine("Blob is in your apps menu and will start when you sign in.");
                return 0;
            case "--uninstall":
                Ipc.TrySend("quit");
                StartupService.RemoveAll();
                try { ClaudeHookInstaller.Uninstall(); } catch { }
                Console.WriteLine("Removed Blob from the apps menu, sign-in and Claude Code.");
                return 0;
            case "--self-test":
                return SelfTest.Run();
        }

        string command = first switch
        {
            "--toggle-talk" => "toggle-talk",
            "--talk-start" => "talk-start",
            "--talk-stop" => "talk-stop",
            "--settings" => "settings",
            "--quit" => "quit",
            "--ask" => "ask " + string.Join(' ', args.Skip(1)),
            _ => "open",
        };

        // One Blob per user: if one is running, hand it the command and leave.
        if (Ipc.TrySend(command)) return 0;
        if (command == "quit") return 0;

        if (string.IsNullOrEmpty(Environment.GetEnvironmentVariable("DISPLAY")))
        {
            Console.Error.WriteLine("Blob needs a graphical session (no DISPLAY is set).");
            return 1;
        }

        App.PendingCommand = command == "open" ? null : command;
        return BuildAvaloniaApp().StartWithClassicDesktopLifetime(args, Avalonia.Controls.ShutdownMode.OnExplicitShutdown);
    }

    public static AppBuilder BuildAvaloniaApp() =>
        AppBuilder.Configure<App>()
            .UsePlatformDetect()
            .WithInterFont()
            .With(new X11PlatformOptions { EnableMultiTouch = false });
}

/// <summary>Checks the pieces that can only go wrong on a real machine. Prints what it finds.</summary>
internal static class SelfTest
{
    public static int Run()
    {
        var ok = true;
        void Line(string name, bool good, string detail)
        {
            Console.WriteLine($"{(good ? "ok  " : "FAIL")} {name}: {detail}");
            ok &= good;
        }
        Line("display", X11.Available, X11.Available ? (X11.IsWayland ? "X11 through XWayland" : "X11") : "no X display");
        Line("compositor", true, X11.HasCompositor() ? "yes" : "none (Blob will cut its window to shape)");
        try
        {
            var languages = Whisper.net.WhisperFactory.GetSupportedLanguages().Count();
            Line("whisper", languages > 0, $"native library loaded, {languages} languages");
        }
        catch (Exception e) { Line("whisper", false, e.GetType().Name + ": " + e.Message); }
        Line("recorder", true, VoiceRecorder.HasRecorder ? "found" : "none (install pulseaudio-utils or alsa-utils to talk)");
        Line("claude", true, ClaudeCli.Locate()?.File ?? "not installed");
        Line("media", true, Tools.Find("busctl") ?? "busctl not found (Now Playing will be empty)");
        Line("talk key", true, VoiceKey.IsSupported ? "can watch Right Alt" : "can't watch keys here; bind a shortcut to `blob --toggle-talk`");
        return ok ? 0 : 1;
    }
}
