using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows.Threading;
using Blob.Core;

namespace Blob.Services;

/// <summary>
/// Hold-to-talk on Right Alt (or Right Ctrl). A low-level keyboard hook sees the key go down and up
/// without taking it away from other apps. Holding it with another key (a shortcut, or AltGr typing)
/// cancels, so typing is never disturbed.
/// </summary>
public sealed class VoiceKey : IDisposable
{
    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100, WM_KEYUP = 0x0101, WM_SYSKEYDOWN = 0x0104, WM_SYSKEYUP = 0x0105;
    private const int VK_RMENU = 0xA5, VK_RCONTROL = 0xA3, VK_LCONTROL = 0xA2;
    private const int HoldDelayMs = 220;

    private readonly Dispatcher _ui;
    private readonly LowLevelKeyboardProc _proc;
    private IntPtr _hook;
    private bool _down, _listening, _spoiled;
    private DispatcherTimer? _hold;

    public event Action? Began;
    public event Action? Ended;
    public event Action? Cancelled;

    public VoiceKey(Dispatcher ui)
    {
        _ui = ui;
        _proc = Callback;
    }

    private int Key => Prefs.Current.TalkKey == "RightCtrl" ? VK_RCONTROL : VK_RMENU;

    public void Start()
    {
        if (_hook != IntPtr.Zero) return;
        using var module = Process.GetCurrentProcess().MainModule;
        _hook = SetWindowsHookEx(WH_KEYBOARD_LL, _proc, GetModuleHandle(module?.ModuleName), 0);
    }

    public void Stop()
    {
        if (_hook != IntPtr.Zero) UnhookWindowsHookEx(_hook);
        _hook = IntPtr.Zero;
    }

    private IntPtr Callback(int nCode, IntPtr wParam, IntPtr lParam)
    {
        if (nCode >= 0)
        {
            var vk = Marshal.ReadInt32(lParam);
            var msg = (int)wParam;
            var isDown = msg is WM_KEYDOWN or WM_SYSKEYDOWN;
            var isUp = msg is WM_KEYUP or WM_SYSKEYUP;
            // AltGr sends a fake Left Ctrl alongside Right Alt; ignore it.
            if (vk == VK_LCONTROL && Key == VK_RMENU) return CallNextHookEx(_hook, nCode, wParam, lParam);

            if (vk == Key)
            {
                if (isDown && !_down)
                {
                    _down = true;
                    _spoiled = false;
                    _ui.BeginInvoke(StartHoldTimer);
                }
                else if (isUp && _down)
                {
                    _down = false;
                    var wasListening = _listening;
                    _listening = false;
                    _ui.BeginInvoke(() => { _hold?.Stop(); if (wasListening) Ended?.Invoke(); });
                    // Releasing Alt alone would open the focused app's menu bar; a harmless key in between prevents that.
                    if (wasListening && vk == VK_RMENU) TapUnassignedKey();
                }
            }
            else if (_down && isDown)
            {
                // Another key while holding: it's a shortcut or AltGr typing, not talking.
                _spoiled = true;
                if (_listening)
                {
                    _listening = false;
                    _ui.BeginInvoke(() => Cancelled?.Invoke());
                }
            }
        }
        return CallNextHookEx(_hook, nCode, wParam, lParam);
    }

    private void StartHoldTimer()
    {
        _hold?.Stop();
        _hold = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(HoldDelayMs) };
        _hold.Tick += (_, _) =>
        {
            _hold?.Stop();
            if (_down && !_spoiled)
            {
                _listening = true;
                Began?.Invoke();
            }
        };
        _hold.Start();
    }

    private static void TapUnassignedKey()
    {
        var inputs = new INPUT[2];
        inputs[0].type = 1; inputs[0].u.ki.wVk = 0xE8;
        inputs[1].type = 1; inputs[1].u.ki.wVk = 0xE8; inputs[1].u.ki.dwFlags = 2; // KEYEVENTF_KEYUP
        SendInput(2, inputs, Marshal.SizeOf<INPUT>());
    }

    public void Dispose() => Stop();

    private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);

    [StructLayout(LayoutKind.Sequential)]
    private struct KEYBDINPUT { public ushort wVk; public ushort wScan; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }

    [StructLayout(LayoutKind.Sequential)]
    private struct MOUSEINPUT { public int dx; public int dy; public uint mouseData; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }

    [StructLayout(LayoutKind.Explicit)]
    private struct InputUnion { [FieldOffset(0)] public MOUSEINPUT mi; [FieldOffset(0)] public KEYBDINPUT ki; }

    [StructLayout(LayoutKind.Sequential)]
    private struct INPUT
    {
        public uint type;
        public InputUnion u;
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);
    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);
    [DllImport("user32.dll")]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    private static extern IntPtr GetModuleHandle(string? lpModuleName);
    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);
}
