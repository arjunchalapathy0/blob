using System;
using System.Runtime.InteropServices;

namespace Blob.Services;

/// <summary>
/// The few things Blob needs from the X server directly: which keys are down, where the pointer
/// is, and which part of its window takes the mouse. Works on X11, and through XWayland.
/// Everything here is called from the UI thread, on Blob's own connection.
/// </summary>
internal static class X11
{
    private const string LibX11 = "libX11.so.6";
    private const string LibXext = "libXext.so.6";

    private static IntPtr _display;
    private static bool _tried;

    public static IntPtr Display
    {
        get
        {
            if (!_tried)
            {
                _tried = true;
                try { _display = XOpenDisplay(IntPtr.Zero); } catch { _display = IntPtr.Zero; }
            }
            return _display;
        }
    }

    public static bool Available => Display != IntPtr.Zero;

    /// <summary>True when the session is Wayland (Blob then runs through XWayland).</summary>
    public static bool IsWayland =>
        !string.IsNullOrEmpty(Environment.GetEnvironmentVariable("WAYLAND_DISPLAY")) ||
        string.Equals(Environment.GetEnvironmentVariable("XDG_SESSION_TYPE"), "wayland", StringComparison.OrdinalIgnoreCase);

    /// <summary>Without a compositor a see-through window is drawn black, so Blob cuts its window to shape instead.</summary>
    public static bool HasCompositor()
    {
        if (!Available) return true;
        try { return XGetSelectionOwner(Display, XInternAtom(Display, "_NET_WM_CM_S0", false)) != IntPtr.Zero; }
        catch { return true; }
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct XRectangle
    {
        public short X, Y;
        public ushort Width, Height;
        public XRectangle(double x, double y, double w, double h)
        {
            X = (short)Math.Floor(x); Y = (short)Math.Floor(y);
            Width = (ushort)Math.Max(0, Math.Ceiling(w)); Height = (ushort)Math.Max(0, Math.Ceiling(h));
        }
    }

    private const int ShapeBounding = 0, ShapeInput = 2, ShapeSet = 0;

    /// <summary>Only these rectangles (in window pixels) take the mouse; clicks elsewhere fall through.</summary>
    public static void SetInputShape(IntPtr window, XRectangle[] rects) => SetShape(window, ShapeInput, rects);

    /// <summary>Cuts the window itself to these rectangles (used when nothing can composite transparency).</summary>
    public static void SetBoundingShape(IntPtr window, XRectangle[] rects) => SetShape(window, ShapeBounding, rects);

    private static void SetShape(IntPtr window, int kind, XRectangle[] rects)
    {
        if (!Available || window == IntPtr.Zero) return;
        try
        {
            XShapeCombineRectangles(Display, window, kind, 0, 0, rects, rects.Length, ShapeSet, 0);
            XFlush(Display);
        }
        catch { }
    }

    /// <summary>Marks the window as a floating utility on every workspace, so tiling window managers leave it alone.</summary>
    public static void MakeFloatingEverywhere(IntPtr window)
    {
        if (!Available || window == IntPtr.Zero) return;
        try
        {
            var atom = XInternAtom(Display, "ATOM", false);
            var cardinal = XInternAtom(Display, "CARDINAL", false);
            XChangeProperty(Display, window, XInternAtom(Display, "_NET_WM_WINDOW_TYPE", false), atom, 32, 0,
                new[] { XInternAtom(Display, "_NET_WM_WINDOW_TYPE_UTILITY", false) }, 1);
            XChangeProperty(Display, window, XInternAtom(Display, "_NET_WM_DESKTOP", false), cardinal, 32, 0,
                new[] { new IntPtr(unchecked((int)0xFFFFFFFF)) }, 1);
            XFlush(Display);
        }
        catch { }
    }

    /// <summary>The pointer's position on the screen, in pixels.</summary>
    public static bool TryGetPointer(out int x, out int y)
    {
        x = y = 0;
        if (!Available) return false;
        try
        {
            return XQueryPointer(Display, XDefaultRootWindow(Display), out _, out _, out x, out y, out _, out _, out _);
        }
        catch { return false; }
    }

    private static readonly byte[] Keys = new byte[32];

    /// <summary>Reads the keyboard: returns whether `keycode` is down, and whether any other key is.</summary>
    public static bool TryReadKey(int keycode, int ignoreKeycode, out bool down, out bool otherDown)
    {
        down = otherDown = false;
        if (!Available || keycode <= 0) return false;
        try
        {
            XQueryKeymap(Display, Keys);
            for (var i = 8; i < 256; i++)
            {
                if ((Keys[i >> 3] & (1 << (i & 7))) == 0) continue;
                if (i == keycode) down = true;
                else if (i != ignoreKeycode) otherDown = true;
            }
            return true;
        }
        catch { return false; }
    }

    public const ulong XK_Alt_R = 0xFFEA, XK_Control_R = 0xFFE4, XK_Control_L = 0xFFE3, XK_ISO_Level3_Shift = 0xFE03;

    public static int Keycode(ulong keysym)
    {
        if (!Available) return 0;
        try { return XKeysymToKeycode(Display, new UIntPtr(keysym)); } catch { return 0; }
    }

    [DllImport(LibX11)] private static extern IntPtr XOpenDisplay(IntPtr name);
    [DllImport(LibX11)] private static extern int XFlush(IntPtr display);
    [DllImport(LibX11)] private static extern IntPtr XDefaultRootWindow(IntPtr display);
    [DllImport(LibX11)] private static extern IntPtr XInternAtom(IntPtr display, string name, bool onlyIfExists);
    [DllImport(LibX11)] private static extern IntPtr XGetSelectionOwner(IntPtr display, IntPtr selection);
    [DllImport(LibX11)] private static extern int XQueryKeymap(IntPtr display, [Out] byte[] keys);
    [DllImport(LibX11)] private static extern byte XKeysymToKeycode(IntPtr display, UIntPtr keysym);
    [DllImport(LibX11)]
    private static extern bool XQueryPointer(IntPtr display, IntPtr window, out IntPtr root, out IntPtr child,
        out int rootX, out int rootY, out int winX, out int winY, out uint mask);
    [DllImport(LibX11)]
    private static extern int XChangeProperty(IntPtr display, IntPtr window, IntPtr property, IntPtr type, int format, int mode, IntPtr[] data, int count);
    [DllImport(LibXext)]
    private static extern void XShapeCombineRectangles(IntPtr display, IntPtr window, int kind, int xOff, int yOff,
        [In] XRectangle[] rects, int count, int op, int ordering);
}
