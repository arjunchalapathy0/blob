using System;
using System.IO;

namespace Blob.Core;

/// <summary>Where Blob keeps things, following the XDG folders.</summary>
public static class Paths
{
    public static string Home => Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);

    private static string Xdg(string variable, string fallback)
    {
        var value = Environment.GetEnvironmentVariable(variable);
        return string.IsNullOrWhiteSpace(value) || !Path.IsPathRooted(value) ? Path.Combine(Home, fallback) : value;
    }

    /// <summary>~/.config/blob — settings.</summary>
    public static string Config => Ensure(Path.Combine(Xdg("XDG_CONFIG_HOME", ".config"), "blob"));

    /// <summary>~/.local/share/blob — the Whisper model and the installed copy of Blob.</summary>
    public static string Data => Ensure(Path.Combine(Xdg("XDG_DATA_HOME", ".local/share"), "blob"));

    /// <summary>~/.cache/blob — logs and downloads.</summary>
    public static string Cache => Ensure(Path.Combine(Xdg("XDG_CACHE_HOME", ".cache"), "blob"));

    public static string ConfigHome => Xdg("XDG_CONFIG_HOME", ".config");
    public static string DataHome => Xdg("XDG_DATA_HOME", ".local/share");

    /// <summary>The socket a second copy of Blob uses to talk to the running one.</summary>
    public static string Socket =>
        Path.Combine(Environment.GetEnvironmentVariable("XDG_RUNTIME_DIR") is { Length: > 0 } run && Directory.Exists(run) ? run : Path.GetTempPath(),
            $"blob-{Environment.UserName}.sock");

    /// <summary>~/.blob/claude — one status file per Claude Code session (same place as on the Mac).</summary>
    public static string ClaudeStatus => Path.Combine(Home, ".blob", "claude");

    public static string Exe => Environment.ProcessPath ?? Path.Combine(AppContext.BaseDirectory, "Blob");

    private static string Ensure(string dir)
    {
        Directory.CreateDirectory(dir);
        return dir;
    }
}
