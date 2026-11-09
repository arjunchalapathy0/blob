using System;
using System.Windows.Threading;

namespace Blob.Services;

/// <summary>A short message in the notch's wing ("Copied", "Update ready"…), then it goes away.</summary>
public sealed class NoticeCenter
{
    private readonly DispatcherTimer _timer = new();
    public string? Glyph { get; private set; }
    public string? Text { get; private set; }
    public event Action? Changed;

    public NoticeCenter()
    {
        _timer.Tick += (_, _) => { _timer.Stop(); Text = null; Glyph = null; Changed?.Invoke(); };
    }

    /// <param name="glyph">A Segoe Fluent Icons character.</param>
    public void Show(string glyph, string text, double seconds = 2)
    {
        Glyph = glyph;
        Text = text;
        _timer.Stop();
        _timer.Interval = TimeSpan.FromSeconds(seconds);
        _timer.Start();
        Changed?.Invoke();
    }
}

/// <summary>Segoe Fluent Icons / MDL2 code points used around the app.</summary>
public static class Glyphs
{
    public const string Check = "", Copy = "", Warning = "", Mic = "", Download = "",
        Music = "", Timer = "", Clipboard = "", Ask = "", Code = "", Settings = "",
        Play = "", Pause = "", Next = "", Previous = "", Lock = "", Pin = "",
        Close = "", Send = "", Ear = "";
}
