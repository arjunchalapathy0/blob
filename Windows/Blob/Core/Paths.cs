using System;
using System.IO;

namespace Blob.Core;

public static class Paths
{
    public static string Home => Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);

    /// <summary>%APPDATA%\Blob — settings.</summary>
    public static string Roaming => Ensure(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Blob"));

    /// <summary>%LOCALAPPDATA%\Blob — the Whisper model, logs, downloads.</summary>
    public static string Local => Ensure(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Blob"));

    /// <summary>~\.blob\claude — one status file per Claude Code session (same place as on the Mac).</summary>
    public static string ClaudeStatus => Path.Combine(Home, ".blob", "claude");

    public static string Exe => Environment.ProcessPath ?? Path.Combine(AppContext.BaseDirectory, "Blob.exe");

    private static string Ensure(string dir)
    {
        Directory.CreateDirectory(dir);
        return dir;
    }
}
