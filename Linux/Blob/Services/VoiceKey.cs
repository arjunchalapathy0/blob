using System;
using Avalonia.Threading;
using Blob.Core;

namespace Blob.Services;

/// <summary>
/// Hold-to-talk on Right Alt (or Right Ctrl). On X11 the keyboard state can be read without
/// grabbing anything, so the key still works in other apps. Holding it with another key
/// (a shortcut, or AltGr typing) cancels, so typing is never disturbed.
///
/// On Wayland, apps can't see keys pressed in other apps. There, bind a keyboard shortcut to
/// `blob --toggle-talk` instead, or hold the microphone button in the notch.
/// </summary>
public sealed class VoiceKey
{
    private const int HoldDelayMs = 220;

    // Often enough that a quick tap of another key (a shortcut) is never missed.
    private readonly DispatcherTimer _poll = new() { Interval = TimeSpan.FromMilliseconds(12) };
    private bool _down, _listening, _spoiled;
    private DateTime _downAt;

    public event Action? Began;
    public event Action? Ended;
    public event Action? Cancelled;

    /// <summary>Whether the key can be watched in this session.</summary>
    public static bool IsSupported => X11.Available && !X11.IsWayland && !Platform.IsChromeOS;

    public VoiceKey()
    {
        _poll.Tick += (_, _) => Poll();
    }

    public void Start()
    {
        if (IsSupported) _poll.Start();
    }

    public void Stop()
    {
        _poll.Stop();
        if (_listening) { _listening = false; Cancelled?.Invoke(); }
        _down = false;
    }

    private static (int Key, int Ignore) Codes()
    {
        if (Prefs.Current.TalkKey == "RightCtrl") return (X11.Keycode(X11.XK_Control_R), 0);
        // Right Alt, or the same physical key when the layout makes it AltGr.
        var key = X11.Keycode(X11.XK_Alt_R);
        if (key == 0) key = X11.Keycode(X11.XK_ISO_Level3_Shift);
        return (key, 0);
    }

    private void Poll()
    {
        var (key, ignore) = Codes();
        if (!X11.TryReadKey(key, ignore, out var down, out var other)) return;

        if (down && !_down)
        {
            _down = true;
            _spoiled = other;
            _downAt = DateTime.Now;
        }
        else if (down && _down)
        {
            if (other && !_spoiled)
            {
                // Another key while holding: it's a shortcut or AltGr typing, not talking.
                _spoiled = true;
                if (_listening) { _listening = false; Cancelled?.Invoke(); }
            }
            else if (!_listening && !_spoiled && (DateTime.Now - _downAt).TotalMilliseconds >= HoldDelayMs)
            {
                _listening = true;
                Began?.Invoke();
            }
        }
        else if (!down && _down)
        {
            _down = false;
            if (_listening) { _listening = false; Ended?.Invoke(); }
        }
    }
}
