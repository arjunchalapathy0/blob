using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Shapes;
using System.Windows.Threading;
using Blob.Core;
using Blob.Services;

namespace Blob.UI;

/// <summary>
/// The notch: a black shape hanging from the top-centre of the screen, with Blob inside.
/// Closed it's a small pill; with something going on it grows wings (music, a timer, Claude);
/// hover it and it peeks, keep hovering (or click) and it opens into panels.
/// The window is transparent and larger than the shape; Windows passes clicks on the
/// transparent part straight through to whatever is underneath.
/// </summary>
public sealed class NotchWindow : Window
{
    // Sizes in device-independent pixels.
    private const double WinW = 760, WinH = 380;
    private const double ClosedW = 190, ClosedH = 32, WingW = 340, PeekGrow = 18, PeekH = 38;
    private const double OpenW = 640, OpenH = 300;
    private const double Ears = 8;

    private readonly Services.Services _s;
    private readonly Path _shape = new() { Fill = Brushes.Black };
    private readonly Grid _content = new();
    private readonly Grid _closed = new();
    private readonly Grid _open = new();
    private readonly BlobView _miniBlob = new(17);
    private readonly BlobView _headBlob = new(20);
    private readonly TextBlock _wingText = new();
    private readonly TextBlock _wingGlyph = new();
    private readonly StackPanel _bars = new() { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };
    private readonly Rectangle[] _barRects;
    private readonly TextBlock _title = Ui.Text("", 14, null, FontWeights.SemiBold);
    private readonly StackPanel _tabs = new() { Orientation = Orientation.Horizontal };
    private readonly ContentControl _panelHost = new();
    private readonly List<IPanel> _panels;
    private readonly AskPanel _ask;
    private IPanel _current;

    private readonly Spring _w = new(ClosedW, Springs.Snap);
    private readonly Spring _h = new(ClosedH, Springs.Snap);
    private readonly Spring _br = new(12, Springs.Snap);
    private readonly Spring _openness = new(0, Springs.Soft);

    private enum Stage { Closed, Peek, Open }
    private Stage _stage = Stage.Closed;
    private bool _hovering;
    private readonly DispatcherTimer _hoverTimer = new();
    private readonly DispatcherTimer _leaveTimer = new() { Interval = TimeSpan.FromMilliseconds(320) };
    private DateTime _start = DateTime.Now, _lastFrame = DateTime.Now;
    private double _lastGeomW = -1, _lastGeomH = -1, _lastGeomBr = -1;
    private bool _wingWide;
    private Wing _wing = Wing.None;

    private enum Wing { None, Listening, Working, Notice, ClaudeWaiting, TimerRang, Timer, ClaudeWorking, Music }

    public NotchWindow(Services.Services services)
    {
        _s = services;
        Title = "Blob";
        WindowStyle = WindowStyle.None;
        AllowsTransparency = true;
        Background = Brushes.Transparent;
        ResizeMode = ResizeMode.NoResize;
        ShowInTaskbar = false;
        ShowActivated = false;
        Topmost = true;
        Width = WinW;
        Height = WinH;
        UseLayoutRounding = true;

        _ask = new AskPanel(_s.Agent);
        _panels = new List<IPanel>
        {
            _ask,
            new MusicPanel(_s.Music),
            new TimersPanel(_s.Timers),
            new ClipboardPanel(_s.Clipboard, _s.Notices),
            new ClaudePanel(_s.Claude),
        };
        _current = _ask;

        _barRects = Enumerable.Range(0, 4).Select(_ => new Rectangle
        {
            Width = 3, Height = 14, RadiusX = 1.5, RadiusY = 1.5, Fill = Brushes.White,
            Margin = new Thickness(1.5, 0, 1.5, 0), RenderTransformOrigin = new Point(0.5, 0.5),
            RenderTransform = new ScaleTransform(1, 0.2),
        }).ToArray();
        foreach (var r in _barRects) _bars.Children.Add(r);

        var root = new Canvas { Width = WinW, Height = WinH };
        root.Children.Add(_shape);
        _content.Width = WinW;
        _content.Height = WinH;
        root.Children.Add(_content);
        _content.Children.Add(_closed);
        _content.Children.Add(_open);
        Content = root;

        BuildClosed();
        BuildOpen();
        SelectPanel(_ask);

        // Hover anywhere on the black shape (transparent parts don't receive the mouse).
        root.MouseEnter += (_, _) => OnHover(true);
        root.MouseLeave += (_, _) => OnHover(false);
        _closed.MouseLeftButtonDown += (_, _) => SetStage(Stage.Open);
        _hoverTimer.Tick += HoverStep;
        _leaveTimer.Tick += (_, _) => { _leaveTimer.Stop(); MaybeClose(); };
        KeyDown += (_, e) => { if (e.Key == Key.Escape) SetStage(Stage.Closed); };
        Deactivated += (_, _) => { if (!_hovering && !Prefs.Current.StayOpen) SetStage(Stage.Closed); };

        Loaded += (_, _) => Place();
        SourceInitialized += (_, _) => MakeToolWindow();
        Microsoft.Win32.SystemEvents.DisplaySettingsChanged += (_, _) => Dispatcher.BeginInvoke(Place);

        _s.Agent.Changed += () =>
        {
            if (_s.Agent.State == AgentService.Phase.Working && _stage == Stage.Closed) { /* the wing shows progress */ }
            if (_current == _ask) _ask.Refresh();
        };
        _s.Music.Changed += () => RefreshIf<MusicPanel>();
        _s.Timers.Changed += () => RefreshIf<TimersPanel>();
        _s.Claude.Changed += () => RefreshIf<ClaudePanel>();
        _s.Timers.Finished += _ => { };

        CompositionTarget.Rendering += OnFrame;
    }

    // Layout

    private void Place()
    {
        var area = SystemParameters.WorkArea;
        var screenW = SystemParameters.PrimaryScreenWidth;
        Left = (screenW - WinW) / 2;
        Top = 0;
        // If the taskbar is at the top, hang just below it.
        if (area.Top > 0) Top = area.Top;
    }

    private void BuildClosed()
    {
        _closed.Width = WinW;
        _closed.Height = PeekH;
        _closed.VerticalAlignment = VerticalAlignment.Top;
        _closed.Background = Brushes.Transparent;
        _closed.Cursor = Cursors.Hand;

        _miniBlob.HorizontalAlignment = HorizontalAlignment.Left;
        _miniBlob.VerticalAlignment = VerticalAlignment.Center;
        _closed.Children.Add(_miniBlob);

        _wingGlyph.FontFamily = Ui.Icons;
        _wingGlyph.FontSize = 12;
        _wingGlyph.Foreground = Brushes.White;
        _wingGlyph.Margin = new Thickness(0, 0, 6, 0);
        _wingText.FontFamily = Ui.Font;
        _wingText.FontSize = 12;
        _wingText.FontWeight = FontWeights.SemiBold;
        _wingText.Foreground = Brushes.White;
        _wingText.MaxWidth = 116;
        _wingText.TextTrimming = TextTrimming.CharacterEllipsis;
        var right = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Right,
            VerticalAlignment = VerticalAlignment.Center,
        };
        right.Children.Add(_wingGlyph);
        right.Children.Add(_wingText);
        right.Children.Add(_bars);
        right.Name = "Right";
        _closed.Children.Add(right);
        AutomationName(_closed, "Blob. Click to open.");
    }

    private void BuildOpen()
    {
        _open.Width = OpenW - 48;
        _open.Height = OpenH - 24;
        _open.Margin = new Thickness((WinW - OpenW) / 2 + 24, 6, 0, 0);
        _open.HorizontalAlignment = HorizontalAlignment.Left;
        _open.VerticalAlignment = VerticalAlignment.Top;
        _open.RowDefinitions.Add(new RowDefinition { Height = new GridLength(40) });
        _open.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });

        var head = new DockPanel();
        foreach (var p in _panels)
        {
            var panel = p;
            var b = Ui.IconButton(p.Glyph, p.Title, () => SelectPanel(panel));
            b.Tag = p;
            _tabs.Children.Add(b);
        }
        _tabs.Children.Add(Ui.IconButton(Glyphs.Settings, "Settings", () => App.ShowSettings()));
        var pin = Ui.IconButton(Glyphs.Pin, "Keep open", () => Prefs.Update(p => p.StayOpen = !p.StayOpen));
        _tabs.Children.Add(pin);
        Prefs.Changed += () => pin.Foreground = Prefs.Current.StayOpen ? Ui.Ink : Ui.Ink2;
        pin.Foreground = Prefs.Current.StayOpen ? Ui.Ink : Ui.Ink2;
        DockPanel.SetDock(_tabs, Dock.Right);
        head.Children.Add(_tabs);
        head.Children.Add(Ui.Row(8, _headBlob, _title));
        _open.Children.Add(head);

        _panelHost.Margin = new Thickness(0, 8, 0, 0);
        Grid.SetRow(_panelHost, 1);
        _open.Children.Add(_panelHost);
        _open.Opacity = 0;
        _open.IsHitTestVisible = false;
    }

    private async void SelectPanel(IPanel panel)
    {
        _current = panel;
        _title.Text = panel.Title;
        foreach (var b in _tabs.Children.OfType<Button>().Where(b => b.Tag is IPanel))
            b.Foreground = b.Tag == panel ? Ui.Ink : Ui.Ink2;
        if (panel.Lockable && _s.Lock.IsLocked)
        {
            _panelHost.Content = Ui.Empty("Locked", "Unlock with Windows Hello to see this.",
                Ui.Button("Unlock", async () =>
                {
                    if (await _s.Lock.UnlockAsync(new WindowInteropHelper(this).Handle)) SelectPanel(panel);
                }));
            return;
        }
        panel.Refresh();
        _panelHost.Content = panel.View;
        if (panel == _ask && _stage == Stage.Open)
        {
            await Dispatcher.InvokeAsync(() => { Activate(); _ask.Input.Focus(); }, DispatcherPriority.Input);
        }
    }

    private void RefreshIf<T>() where T : IPanel
    {
        if (_current is T && _stage == Stage.Open && !(_current.Lockable && _s.Lock.IsLocked)) _current.Refresh();
    }

    // Open / close

    private void OnHover(bool inside)
    {
        _hovering = inside;
        if (inside)
        {
            _leaveTimer.Stop();
            if (_stage == Stage.Closed)
            {
                _hoverTimer.Stop();
                _hoverTimer.Interval = TimeSpan.FromMilliseconds(60);
                _hoverTimer.Tag = Stage.Peek;
                _hoverTimer.Start();
            }
        }
        else
        {
            _hoverTimer.Stop();
            _leaveTimer.Start();
        }
    }

    private void HoverStep(object? sender, EventArgs e)
    {
        _hoverTimer.Stop();
        if (!_hovering) return;
        if (_hoverTimer.Tag is Stage.Peek && _stage == Stage.Closed)
        {
            SetStage(Stage.Peek);
            _hoverTimer.Interval = TimeSpan.FromMilliseconds(300);
            _hoverTimer.Tag = Stage.Open;
            _hoverTimer.Start();
        }
        else if (_hoverTimer.Tag is Stage.Open && _stage == Stage.Peek)
        {
            SetStage(Stage.Open);
        }
    }

    private void MaybeClose()
    {
        if (_hovering) return;
        if (_stage == Stage.Open && (Prefs.Current.StayOpen || IsKeyboardFocusWithin && _ask.Input.Text.Length > 0)) return;
        SetStage(Stage.Closed);
    }

    public void OpenPanel(string? title = null)
    {
        var panel = _panels.FirstOrDefault(p => p.Title == title);
        if (panel != null) SelectPanel(panel);
        SetStage(Stage.Open);
        Activate();
    }

    private void SetStage(Stage stage)
    {
        if (stage == _stage) return;
        _stage = stage;
        var preset = stage == Stage.Open ? Springs.Open : stage == Stage.Peek ? Springs.Snap : Springs.Close;
        _w.Use(preset); _h.Use(preset); _br.Use(preset);
        _openness.To(stage == Stage.Open ? 1 : 0, stage == Stage.Open ? Springs.Soft : Springs.Close);
        _open.IsHitTestVisible = stage == Stage.Open;
        if (stage == Stage.Open)
        {
            if (_current.Lockable && _s.Lock.IsLocked) SelectPanel(_current);
            else { _current.Refresh(); _panelHost.Content = _current.View; }
            if (_current == _ask) Dispatcher.BeginInvoke(() => { Activate(); _ask.Input.Focus(); }, DispatcherPriority.Input);
        }
    }

    // Every frame

    private void OnFrame(object? sender, EventArgs e)
    {
        var now = DateTime.Now;
        var dt = Math.Min(0.05, (now - _lastFrame).TotalSeconds);
        _lastFrame = now;
        var t = (now - _start).TotalSeconds;

        _wing = PickWing();
        _wingWide = _wing != Wing.None;
        var baseW = _wingWide ? WingW : ClosedW;
        switch (_stage)
        {
            case Stage.Open: _w.To(OpenW); _h.To(OpenH); _br.To(30); break;
            case Stage.Peek: _w.To(baseW + PeekGrow); _h.To(PeekH); _br.To(14); break;
            default: _w.To(baseW); _h.To(ClosedH); _br.To(12); break;
        }
        _w.Step(dt); _h.Step(dt); _br.Step(dt); _openness.Step(dt);

        var w = _w.Value; var h = _h.Value; var br = _br.Value;
        if (Math.Abs(w - _lastGeomW) > 0.05 || Math.Abs(h - _lastGeomH) > 0.05 || Math.Abs(br - _lastGeomBr) > 0.05)
        {
            var geom = Shapes.Notch((WinW - w) / 2 - Ears, 0, w + 2 * Ears, h, Ears, br);
            _shape.Data = geom;
            _content.Clip = geom;
            _lastGeomW = w; _lastGeomH = h; _lastGeomBr = br;
        }

        // Closed content sits in the top 32–38 px; fades as the notch opens.
        var o = Math.Clamp(_openness.Value, 0, 1);
        _closed.Opacity = 1 - Math.Clamp(o * 2.2, 0, 1);
        _closed.Height = h < 60 ? h : PeekH;
        _open.Opacity = Math.Clamp((o - 0.35) / 0.65, 0, 1);
        _miniBlob.Margin = new Thickness(_wingWide ? (WinW - w) / 2 + 14 : (WinW - _miniBlob.Width) / 2, 0, 0, 0);
        if (_closed.Children.OfType<StackPanel>().FirstOrDefault() is { } right)
        {
            right.Margin = new Thickness(0, 0, (WinW - w) / 2 + 14, 0);
            right.Visibility = _wingWide ? Visibility.Visible : Visibility.Collapsed;
        }
        UpdateWing(t);

        // Blob: mood, and eyes on the pointer.
        var mood = PickMood();
        _miniBlob.Mood = mood;
        _headBlob.Mood = mood;
        var (lx, ly) = LookAt(_miniBlob);
        _miniBlob.Tick(t, lx, ly);
        if (_open.Opacity > 0) _headBlob.Tick(t, lx, ly);
    }

    private Wing PickWing()
    {
        var a = _s.Agent;
        if (a.State == AgentService.Phase.Listening) return Wing.Listening;
        if (a.State is AgentService.Phase.Transcribing or AgentService.Phase.Working) return Wing.Working;
        if (_s.Notices.Text != null) return Wing.Notice;
        if (_s.Claude.Waiting != null) return Wing.ClaudeWaiting;
        if (_s.Timers.Ringing) return Wing.TimerRang;
        if (_s.Timers.Soonest != null) return Wing.Timer;
        if (_s.Claude.Working != null) return Wing.ClaudeWorking;
        if (_s.Music.IsPlaying) return Wing.Music;
        return Wing.None;
    }

    private void UpdateWing(double t)
    {
        string glyph = "", text = "";
        var bars = false;
        switch (_wing)
        {
            case Wing.Listening: bars = true; break;
            case Wing.Working: text = _s.Agent.State == AgentService.Phase.Transcribing ? "Listening back…" : _s.Agent.CurrentStep; break;
            case Wing.Notice: glyph = _s.Notices.Glyph ?? ""; text = _s.Notices.Text ?? ""; break;
            case Wing.ClaudeWaiting: glyph = Glyphs.Code; text = "Claude needs you"; break;
            case Wing.TimerRang: glyph = Glyphs.Timer; text = "Time’s up"; break;
            case Wing.Timer: text = TimerService.Format(_s.Timers.Soonest!.Left); break;
            case Wing.ClaudeWorking: glyph = Glyphs.Code; text = _s.Claude.Working!.Detail; break;
            case Wing.Music: bars = true; break;
        }
        if (_wingGlyph.Text != glyph) _wingGlyph.Text = glyph;
        _wingGlyph.Visibility = glyph.Length > 0 ? Visibility.Visible : Visibility.Collapsed;
        if (_wingText.Text != text) _wingText.Text = text;
        _wingText.Visibility = text.Length > 0 ? Visibility.Visible : Visibility.Collapsed;
        _bars.Visibility = bars ? Visibility.Visible : Visibility.Collapsed;
        if (bars)
        {
            for (var i = 0; i < _barRects.Length; i++)
            {
                double v = _wing == Wing.Listening
                    ? 0.2 + 0.8 * _s.Agent.Level * (0.6 + 0.4 * Math.Sin(t * 18 + i * 1.7))
                    : 0.3 + 0.7 * Math.Abs(Math.Sin(t * (5.1 + i * 1.3) + i));
                ((ScaleTransform)_barRects[i].RenderTransform).ScaleY = Math.Clamp(v, 0.15, 1);
            }
        }
    }

    private Mood PickMood()
    {
        switch (_wing)
        {
            case Wing.Listening: return Mood.Curious;
            case Wing.Working: return Mood.Busy;
            case Wing.ClaudeWaiting:
            case Wing.TimerRang: return Mood.Alarmed;
            case Wing.ClaudeWorking: return Mood.Busy;
            case Wing.Music: return Mood.Happy;
        }
        if (_hovering || _stage != Stage.Closed) return Mood.Curious;
        return IdleSeconds() > 600 ? Mood.Sleepy : Mood.Idle;
    }

    private (double, double) LookAt(FrameworkElement blob)
    {
        if (!GetCursorPos(out var p) || PresentationSource.FromVisual(this) == null) return (0, 0);
        try
        {
            var center = blob.PointToScreen(new Point(blob.ActualWidth / 2, blob.ActualHeight / 2));
            var scale = VisualTreeHelper.GetDpi(this).DpiScaleX;
            return ((p.X - center.X) / (260 * scale), (p.Y - center.Y) / (260 * scale));
        }
        catch { return (0, 0); }
    }

    // Win32

    private void MakeToolWindow()
    {
        var hwnd = new WindowInteropHelper(this).Handle;
        var ex = GetWindowLong(hwnd, GWL_EXSTYLE);
        SetWindowLong(hwnd, GWL_EXSTYLE, ex | WS_EX_TOOLWINDOW);
    }

    private static double IdleSeconds()
    {
        var info = new LASTINPUTINFO { cbSize = (uint)Marshal.SizeOf<LASTINPUTINFO>() };
        return GetLastInputInfo(ref info) ? (Environment.TickCount - (int)info.dwTime) / 1000.0 : 0;
    }

    private static void AutomationName(UIElement e, string name) => System.Windows.Automation.AutomationProperties.SetName(e, name);

    private const int GWL_EXSTYLE = -20, WS_EX_TOOLWINDOW = 0x80;
    [StructLayout(LayoutKind.Sequential)] private struct POINT { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)] private struct LASTINPUTINFO { public uint cbSize; public uint dwTime; }
    [DllImport("user32.dll")] private static extern bool GetCursorPos(out POINT p);
    [DllImport("user32.dll")] private static extern bool GetLastInputInfo(ref LASTINPUTINFO info);
    [DllImport("user32.dll")] private static extern int GetWindowLong(IntPtr hWnd, int nIndex);
    [DllImport("user32.dll")] private static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);
}
