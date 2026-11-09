using Microsoft.Win32;
using Blob.Core;

namespace Blob.Services;

/// <summary>Launch at sign-in, through the current user's Run key (no admin needed).</summary>
public static class StartupService
{
    private const string Key = @"Software\Microsoft\Windows\CurrentVersion\Run";

    public static bool IsEnabled
    {
        get
        {
            using var k = Registry.CurrentUser.OpenSubKey(Key);
            return k?.GetValue("Blob") is string s && s.Contains(Paths.Exe, System.StringComparison.OrdinalIgnoreCase);
        }
    }

    public static void Set(bool on)
    {
        using var k = Registry.CurrentUser.CreateSubKey(Key);
        if (on) k.SetValue("Blob", $"\"{Paths.Exe}\"");
        else k.DeleteValue("Blob", false);
    }
}
