using System;
using System.IO;
using System.Reflection;
using Blob.Core;

namespace Blob.Services;

/// <summary>Start at sign-in, and a place in the apps menu, both through .desktop files in the user's own folders.</summary>
public static class StartupService
{
    private static string AutostartFile => Path.Combine(Paths.ConfigHome, "autostart", "blob.desktop");
    private static string MenuFile => Path.Combine(Paths.DataHome, "applications", "blob.desktop");
    private static string IconFile => Path.Combine(Paths.DataHome, "icons", "hicolor", "256x256", "apps", "blob.png");

    public static bool IsEnabled => File.Exists(AutostartFile) && File.ReadAllText(AutostartFile).Contains(Paths.Exe);

    public static void Set(bool on)
    {
        try
        {
            if (on)
            {
                Directory.CreateDirectory(Path.GetDirectoryName(AutostartFile)!);
                File.WriteAllText(AutostartFile, Entry() + "X-GNOME-Autostart-enabled=true\nX-GNOME-Autostart-Delay=3\n");
            }
            else if (File.Exists(AutostartFile)) File.Delete(AutostartFile);
        }
        catch { }
    }

    public static bool InMenu => File.Exists(MenuFile) && File.ReadAllText(MenuFile).Contains(Paths.Exe);

    /// <summary>Adds (or refreshes) Blob's entry and icon in the apps menu.</summary>
    public static void AddToMenu()
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(IconFile)!);
            using (var icon = Icon())
            using (var file = File.Create(IconFile))
                icon?.CopyTo(file);
            Directory.CreateDirectory(Path.GetDirectoryName(MenuFile)!);
            File.WriteAllText(MenuFile, Entry());
        }
        catch { }
    }

    /// <summary>Blob's icon, which travels inside the program.</summary>
    public static Stream? Icon() => Assembly.GetExecutingAssembly().GetManifestResourceStream("Blob.png");

    /// <summary>Takes Blob back out of the apps menu and sign-in.</summary>
    public static void RemoveAll()
    {
        foreach (var file in new[] { AutostartFile, MenuFile, IconFile })
        {
            try { if (File.Exists(file)) File.Delete(file); } catch { }
        }
    }

    /// <summary>Keeps existing entries pointing at this copy of Blob after it moves or updates.</summary>
    public static void Refresh()
    {
        if (File.Exists(MenuFile) && !InMenu) AddToMenu();
        if (File.Exists(AutostartFile) && !IsEnabled) Set(true);
    }

    private static string Entry() =>
        "[Desktop Entry]\n" +
        "Type=Application\n" +
        "Name=Blob\n" +
        "Comment=Lives at the top of your screen and does what you say\n" +
        $"Exec=\"{Paths.Exe}\"\n" +
        $"Icon={(File.Exists(IconFile) ? IconFile : "blob")}\n" +
        "Terminal=false\n" +
        "Categories=Utility;\n" +
        "StartupNotify=false\n";
}
