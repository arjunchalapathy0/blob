using System;
using System.IO;
using System.Text.Json;

namespace Blob.Core;

/// <summary>Settings, saved as JSON in %APPDATA%\Blob\settings.json.</summary>
public sealed class Prefs
{
    public bool StayOpen { get; set; }
    public bool VoiceKey { get; set; } = true;
    /// <summary>"RightAlt" or "RightCtrl". Right Alt is AltGr on some keyboard layouts.</summary>
    public string TalkKey { get; set; } = "RightAlt";
    public bool LockWithHello { get; set; }
    public bool TimerSound { get; set; } = true;
    public bool ShowOnAllScreens { get; set; }

    public static Prefs Current { get; private set; } = Load();
    public static event Action? Changed;

    private static string FilePath => Path.Combine(Paths.Roaming, "settings.json");

    private static Prefs Load()
    {
        try
        {
            if (File.Exists(FilePath))
                return JsonSerializer.Deserialize<Prefs>(File.ReadAllText(FilePath)) ?? new Prefs();
        }
        catch { }
        return new Prefs();
    }

    public static void Update(Action<Prefs> change)
    {
        change(Current);
        try
        {
            File.WriteAllText(FilePath, JsonSerializer.Serialize(Current, new JsonSerializerOptions { WriteIndented = true }));
        }
        catch { }
        Changed?.Invoke();
    }
}
