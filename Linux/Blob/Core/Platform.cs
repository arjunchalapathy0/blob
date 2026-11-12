using System;
using System.IO;

namespace Blob.Core;

/// <summary>What kind of Linux Blob is running on.</summary>
public static class Platform
{
    private static bool? _chromeOs;

    /// <summary>
    /// True inside a Chromebook's Linux development environment (Crostini). There, ChromeOS's own
    /// window manager places Linux windows, so Blob opens as a small ordinary window instead of a
    /// notch, and other apps' keys can't be watched.
    /// </summary>
    public static bool IsChromeOS => _chromeOs ??= Detect();

    private static bool Detect()
    {
        // For testing on other machines: BLOB_CHROMEOS=1 or 0.
        if (Environment.GetEnvironmentVariable("BLOB_CHROMEOS") is { Length: > 0 } forced) return forced == "1";
        try
        {
            return File.Exists("/dev/.cros_milestone")
                || Directory.Exists("/opt/google/cros-containers")
                || File.Exists("/etc/apt/sources.list.d/cros.list");
        }
        catch { return false; }
    }

    /// <summary>The ChromeOS setting that lets Linux apps use the microphone.</summary>
    public const string ChromeOSMicSetting = "Settings → About ChromeOS → Developers → Linux development environment → Allow Linux to access your microphone";
}
