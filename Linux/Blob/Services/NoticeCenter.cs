using System;
using Avalonia.Threading;

namespace Blob.Services;

/// <summary>A short message in the notch's wing ("Copied", "Update ready"…), then it goes away.</summary>
public sealed class NoticeCenter
{
    private readonly DispatcherTimer _timer = new();
    /// <summary>The name of an icon in <see cref="UI.Icons"/>.</summary>
    public string? Icon { get; private set; }
    public string? Text { get; private set; }
    public event Action? Changed;

    public NoticeCenter()
    {
        _timer.Tick += (_, _) => { _timer.Stop(); Text = null; Icon = null; Changed?.Invoke(); };
    }

    public void Show(string icon, string text, double seconds = 2)
    {
        Icon = icon;
        Text = text;
        _timer.Stop();
        _timer.Interval = TimeSpan.FromSeconds(seconds);
        _timer.Start();
        Changed?.Invoke();
    }
}
