using System;
using System.Collections.Generic;
using System.Linq;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.Shapes;
using Avalonia.Input;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Threading;
using Blob.Core;
using Blob.Services;

namespace Blob.UI;

/// <summary>
/// The notch: a black shape hanging from the top-centre of the screen, with Blob inside.
/// Closed it's a small pill; with something going on it grows wings (music, a timer, Claude);
/// hover it and it peeks, keep hovering (or click) and it opens into panels.
///
/// The window is see-through and larger than the shape. Only the shape itself takes the mouse
/// (an X11 input shape), so clicks beside it go to whatever is underneath.
/// </summary>
public sealed class NotchWindow : Window
{
    private const double NotchWinW = 760, NotchWinH = 360;
    private const double ClosedW = 190, ClosedH = 32, WingW = 340, PeekGrow = 18, PeekH = 38;
    private const double OpenW = 680, OpenH = 300;
    private const double Ears = 8;

    private readonly Services.Services _s;
    private readonly Path _shape = new() { Fill = Brushes.Black };
    private readonly Panel _content = new();
    private readonly Panel _closed = new() { Height = PeekH, VerticalAlignment = VerticalAlignment.Top, Background = Brushes.Transparent };
    private readonly Grid _open = new() { RowDefinitions = new RowDefinitions("38,*") };
    private readonly BlobView _miniBlob = new(17) { HorizontalAlignment = HorizontalAlignment.Left, VerticalAlignment = VerticalAlignment.Center };
    private readonly BlobView _headBlob = new(18);
    private readonly StackPanel _wing = new() { Orientation = Orientation.Horizontal, Spacing = 6, HorizontalAlignment = HorizontalAlignment.Right, VerticalAlignment = VerticalAlignment.Center };
    private readonly ContentControl _wingIcon = new() { VerticalAlignment = VerticalAlignment.Center };
    private readonly TextBlock _wingText = Ui.Text("", 12, Ink.Primary, FontWeight.SemiBold);
    private readonly StackPanel _bars = new() { Orientation = Orientation.Horizontal, Spacing = 3, VerticalAlignment = VerticalAlignment.Center };
    private readonly Border[] _barRects;
    private readonly TextBlock _title = Ui.Text("", 13.5, Ink.Secondary, FontWeight.SemiBold);
    private readonly StackPanel _tabs = new() { Orientation = Orientation.Horizontal, Spacing = 2, VerticalAlignment = VerticalAlignment.Center };
    private readonly ContentControl _panelHost = new() { Margin = new Thickness(0, 6, 0, 0) };
    private readonly Pressable _pin;
    private readonly List<IPanel> _panels;
    private readonly Dictionary<IPanel, Pressable> _tabButtons = new();
    private readonly AskPanel _ask;
    private readonly WelcomePanel _welcome;
    private IPanel _current;

    private readonly Spring _w = new(ClosedW, Springs.Snap);
    private readonly Spring _h = new(ClosedH, Springs.Snap);
    private readonly Spring _br = new(12, Springs.Snap);
    private readonly Spring _openness = new(0, Springs.Soft);

    private enum Stage { Closed, Peek, Open }
    private Stage _stage = Stage.Closed;
    private bool _hovering;
    private readonly DispatcherTimer _hoverTimer = new();
    private Stage _hoverNext = Stage.Peek;
    private readonly DispatcherTimer _leaveTimer = new() { Interval = TimeSpan.FromMilliseconds(320) };
    /// <summary>Closes a notch that was opened from outside (a command, the tray) and then left alone.</summary>
    private readonly DispatcherTimer _lingerTimer = new() { Interval = TimeSpan.FromSeconds(8) };
    private readonly DateTime _start = DateTime.Now;
    private DateTime _lastFrame = DateTime.Now;
    private double _geomW = -1, _geomH = -1, _geomBr = -1;
    private X11.XRectangle _inputRect;
    private IntPtr _xid;
    private bool _composited = true;

    private enum Wing { None, Listening, Working, Notice, ClaudeWaiting, TimerRang, Timer, ClaudeWorking, Music }
    private Wing _wingKind = Wing.None;
    private string _wingIconName = "";
    private string _agentSignature = "";
    private DateTime _agentChangedAt = DateTime.Now;

    private int _pointerX, _pointerY, _frame;
    private DateTime _lastActivity = DateTime.Now;

    private bool Welcoming => !Prefs.Current.Welcomed;

    /// <summary>
    /// On a Chromebook, ChromeOS places Linux windows itself and won't keep one on top or see-through,
    /// so Blob is a small ordinary window there: always open, moved and closed like any other app.
    /// </summary>
    private readonly bool _windowed = Platform.IsChromeOS;
    private double WinW => _windowed ? OpenW : NotchWinW;
    private double WinH => _windowed ? OpenH : NotchWinH;

    public NotchWindow(Services.Services services)
    {
        _s = services;
        Title = "Blob";
        CanResize = false;
        if (_windowed)
        {
            SystemDecorations = SystemDecorations.Full;
            Background = Brushes.Black;
            ShowInTaskbar = true;
            ShowActivated = true;
            using var icon = StartupService.Icon();
            if (icon != null) Icon = new WindowIcon(icon);
        }
        else
        {
            SystemDecorations = SystemDecorations.None;
            TransparencyLevelHint = new[] { WindowTransparencyLevel.Transparent };
            Background = Brushes.Transparent;
            ShowInTaskbar = false;
            ShowActivated = false;
            Topmost = true;
        }
        Width = WinW;
        Height = WinH;
        _content.Width = WinW;
        _content.Height = WinH;
        _closed.Width = WinW;
        FontFamily = Ui.Font;

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
        _welcome = new WelcomePanel(_s.Agent, FinishWelcome);

        _barRects = Enumerable.Range(0, 4).Select(_ => new Border
        {
            Width = 3, Height = 14, CornerRadius = new CornerRadius(1.5), Background = Brushes.White,
            RenderTransformOrigin = RelativePoint.Center, RenderTransform = new ScaleTransform(1, 0.2),
        }).ToArray();
        _bars.Children.AddRange(_barRects);

        _pin = Ui.IconButton("pin", "Keep open", () => Prefs.Update(p => p.StayOpen = !p.StayOpen), 28, 12);

        var root = new Panel { Width = WinW, Height = WinH, Background = _windowed ? Brushes.Black : Brushes.Transparent };
        root.Children.Add(_shape);
        root.Children.Add(_content);
        _content.Children.Add(_closed);
        _content.Children.Add(_open);
        Content = root;

        BuildClosed();
        BuildOpen();
        Select(_ask);

        // The X server only delivers the pointer over the notch itself, so the window's own
        // enter and leave are exactly "over the notch" and "left it".
        PointerEntered += (_, _) => Hover(true);
        PointerExited += (_, _) => Hover(false);
        _closed.PointerPressed += (_, _) => { SetStage(Stage.Open); FocusAsk(); };
        _hoverTimer.Tick += HoverStep;
        _leaveTimer.Tick += (_, _) => { _leaveTimer.Stop(); MaybeClose(); };
        _lingerTimer.Tick += (_, _) =>
        {
            // Still busy, or you're typing: check again later.
            MaybeClose();
            if (_stage != Stage.Open || _hovering) _lingerTimer.Stop();
        };
        KeyDown += (_, e) => { if (e.Key == Key.Escape && !Welcoming && !_windowed) SetStage(Stage.Closed); };
        Deactivated += (_, _) => { if (!_hovering) MaybeClose(); };
        // As a window, closing it quits Blob (ChromeOS shows no tray icon to bring it back from).
        if (_windowed) Closed += (_, _) => App.Quit();

        Opened += (_, _) =>
        {
            _xid = TryGetPlatformHandle()?.Handle ?? IntPtr.Zero;
            _composited = X11.HasCompositor();
            if (!_windowed) X11.MakeFloatingEverywhere(_xid);
            Place();
            _geomW = -1; // force the first shape update
            RequestAnimationFrame(Frame);
            if (_windowed) SetStage(Stage.Open);
            else if (Welcoming) DispatcherTimer.RunOnce(() => SetStage(Stage.Open), TimeSpan.FromMilliseconds(900));
        };
        Screens.Changed += (_, _) => Place();
        Prefs.Changed += () =>
        {
            Icons.Tint((Control)_pin.Child!, Prefs.Current.StayOpen ? Ink.Primary : Ink.Secondary);
            if (_stage == Stage.Open) RefreshCurrent();
        };

        _s.Agent.Changed += () =>
        {
            // The microphone level changes twenty times a second; only rebuild when something visible did.
            var a = _s.Agent;
            var signature = $"{a.State}|{a.Steps.Count}|{a.Reply.Length}|{a.Error}|{a.Request}|{a.WhisperStatus}";
            if (signature == _agentSignature) return;
            _agentSignature = signature;
            _agentChangedAt = DateTime.Now;
            if (_stage == Stage.Open && _current == _ask && !Welcoming) _ask.Refresh();
        };
        _s.Music.Changed += () => RefreshIf<MusicPanel>();
        _s.Timers.Changed += () => RefreshIf<TimersPanel>();
        _s.Claude.Changed += () => RefreshIf<ClaudePanel>();
    }

    // Layout

    /// <summary>Top-centre of the main screen, just under a top panel if the desktop has one.</summary>
    private void Place()
    {
        if (_windowed) return; // ChromeOS decides where windows go.
        var screen = Screens.Primary ?? Screens.All.FirstOrDefault();
        if (screen == null) return;
        var area = screen.WorkingArea;
        var width = (int)Math.Round(WinW * screen.Scaling);
        Position = new PixelPoint(area.X + (area.Width - width) / 2, area.Y);
    }

    private void BuildClosed()
    {
        _closed.Cursor = new Cursor(StandardCursorType.Hand);
        _closed.Children.Add(_miniBlob);
        _wing.Children.Add(_wingIcon);
        _wingText.MaxWidth = 150;
        _wing.Children.Add(_wingText);
        _wing.Children.Add(_bars);
        _closed.Children.Add(_wing);
        Avalonia.Automation.AutomationProperties.SetName(_closed, "Blob. Click to open.");
    }

    private void BuildOpen()
    {
        _open.Width = OpenW - 44;
        _open.Height = OpenH - 22;
        _open.Margin = new Thickness((WinW - OpenW) / 2 + 22, _windowed ? 8 : 4, 0, 0);
        _open.HorizontalAlignment = HorizontalAlignment.Left;
        _open.VerticalAlignment = VerticalAlignment.Top;

        foreach (var p in _panels)
        {
            var panel = p;
            var tab = new Pressable { Width = 32, Height = 26, CornerRadius = new CornerRadius(13), Child = Icons.Make(p.Icon, 14, Ink.Secondary) };
            tab.Click += () => Select(panel);
            tab.PointerEntered += (_, _) => { if (!Welcoming) { _title.Text = panel.Title; _title.Foreground = Ink.Primary; } };
            tab.PointerExited += (_, _) => { if (!Welcoming) { _title.Text = _current.Title; _title.Foreground = Ink.Secondary; } };
            ToolTip.SetTip(tab, p.Title);
            Avalonia.Automation.AutomationProperties.SetName(tab, p.Title);
            _tabButtons[p] = tab;
            _tabs.Children.Add(tab);
        }
        var settings = Ui.IconButton("settings", "Settings", App.ShowSettings, 28, 13);
        Icons.Tint((Control)_pin.Child!, Prefs.Current.StayOpen ? Ink.Primary : Ink.Secondary);
        _pin.IsVisible = !_windowed; // a window stays open anyway

        var left = Ui.Row(8, _headBlob, _title);
        var right = Ui.Row(6, _tabs, new Border { Width = 1, Height = 14, Background = Ink.FillStrong }, _pin, settings);
        right.HorizontalAlignment = HorizontalAlignment.Right;
        var head = new Panel();
        head.Children.Add(left);
        head.Children.Add(right);
        _open.Children.Add(head);

        Grid.SetRow(_panelHost, 1);
        _open.Children.Add(_panelHost);
        _open.Opacity = 0;
        _open.IsHitTestVisible = false;
    }

    private void Select(IPanel panel)
    {
        _current = panel;
        foreach (var (p, tab) in _tabButtons)
        {
            var on = p == panel && !Welcoming;
            if (on) tab.Colours(Brushes.White, Brushes.White); else tab.Colours(Ink.Clear, Ink.FillStrong);
            Icons.Tint((Control)tab.Child!, on ? Brushes.Black : Ink.Secondary);
        }
        ShowCurrent();
        if (panel == _ask && _stage == Stage.Open && IsActive) FocusAsk();
    }

    private void ShowCurrent()
    {
        _tabs.Opacity = Welcoming ? 0.4 : 1;
        _tabs.IsHitTestVisible = !Welcoming;
        if (Welcoming)
        {
            _title.Text = "Welcome";
            _welcome.Refresh();
            _panelHost.Content = _welcome.View;
            return;
        }
        _title.Text = _current.Title;
        _title.Foreground = Ink.Secondary;
        _current.Refresh();
        _panelHost.Content = _current.View;
    }

    private void RefreshCurrent()
    {
        if (Welcoming) _welcome.Refresh(); else _current.Refresh();
    }

    private void RefreshIf<T>() where T : IPanel
    {
        if (_current is T && _stage == Stage.Open && !Welcoming) _current.Refresh();
    }

    private void FinishWelcome()
    {
        Prefs.Update(p => p.Welcomed = true);
        Select(_current);
        MaybeClose();
    }

    private void FocusAsk()
    {
        if (Welcoming || _current != _ask) return;
        Dispatcher.UIThread.Post(() => { Activate(); _ask.Input.Focus(); }, DispatcherPriority.Input);
    }

    // Open and close

    private void Hover(bool inside)
    {
        _hovering = inside;
        _lastActivity = DateTime.Now;
        if (inside)
        {
            _leaveTimer.Stop();
            if (_stage == Stage.Closed)
            {
                _hoverTimer.Stop();
                _hoverTimer.Interval = TimeSpan.FromMilliseconds(60);
                _hoverNext = Stage.Peek;
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
        if (_hoverNext == Stage.Peek && _stage == Stage.Closed)
        {
            SetStage(Stage.Peek);
            _hoverTimer.Interval = TimeSpan.FromMilliseconds(300);
            _hoverNext = Stage.Open;
            _hoverTimer.Start();
        }
        else if (_hoverNext == Stage.Open && _stage == Stage.Peek)
        {
            SetStage(Stage.Open);
        }
    }

    private void MaybeClose()
    {
        if (_windowed || _hovering || _stage == Stage.Closed) return;
        if (_stage == Stage.Open)
        {
            if (Prefs.Current.StayOpen || Welcoming) return;
            // Don't snatch the panel away mid-sentence or mid-request, or before the answer has been up a moment.
            if (_current == _ask && (_s.Agent.IsBusy || (IsActive && !string.IsNullOrEmpty(_ask.Input.Text)))) return;
            if (_current == _ask && _s.Agent.State == AgentService.Phase.Done && (DateTime.Now - _agentChangedAt).TotalSeconds < 5 && _lingerTimer.IsEnabled) return;
        }
        SetStage(Stage.Closed);
    }

    /// <summary>Opens the notch from outside (the tray icon, or `blob --open`).</summary>
    public void OpenPanel(string? title = null)
    {
        var panel = _panels.FirstOrDefault(p => p.Title == title);
        if (panel != null) Select(panel);
        if (_windowed)
        {
            if (WindowState == WindowState.Minimized) WindowState = WindowState.Normal;
            Activate();
            FocusAsk();
            return;
        }
        SetStage(Stage.Open);
        // Opened without the pointer on it: it stays for a while, then closes by itself.
        _leaveTimer.Stop();
        _lingerTimer.Stop();
        _lingerTimer.Start();
        FocusAsk();
    }

    /// <summary>Closes the notch at once (Settings is about to open underneath it).</summary>
    public void CloseNow()
    {
        if (!Welcoming && !_windowed) SetStage(Stage.Closed);
    }

    private void SetStage(Stage stage)
    {
        if (stage == _stage) return;
        _stage = stage;
        var preset = stage == Stage.Open ? Springs.Open : stage == Stage.Peek ? Springs.Snap : Springs.Close;
        _w.Use(preset); _h.Use(preset); _br.Use(preset);
        _openness.To(stage == Stage.Open ? 1 : 0, stage == Stage.Open ? Springs.Soft : Springs.Close);
        _open.IsHitTestVisible = stage == Stage.Open;
        if (stage == Stage.Open) ShowCurrent();
    }

    // Every frame

    private void Frame(TimeSpan _)
    {
        try { Step(); } catch { /* a bad frame shouldn't stop the next one */ }
        RequestAnimationFrame(Frame);
    }

    private void Step()
    {
        var now = DateTime.Now;
        var dt = Math.Min(0.05, (now - _lastFrame).TotalSeconds);
        _lastFrame = now;
        var t = (now - _start).TotalSeconds;

        _wingKind = PickWing();
        var wide = _wingKind != Wing.None;
        var baseW = wide ? WingW : ClosedW;
        switch (_stage)
        {
            case Stage.Open: _w.To(OpenW); _h.To(OpenH); _br.To(30); break;
            case Stage.Peek: _w.To(baseW + PeekGrow); _h.To(PeekH); _br.To(14); break;
            default: _w.To(baseW); _h.To(ClosedH); _br.To(12); break;
        }
        _w.Step(dt); _h.Step(dt); _br.Step(dt); _openness.Step(dt);

        double w = _w.Value, h = _h.Value, br = _br.Value;
        if (Math.Abs(w - _geomW) > 0.05 || Math.Abs(h - _geomH) > 0.05 || Math.Abs(br - _geomBr) > 0.05)
        {
            var geometry = Shapes.Notch((WinW - w) / 2 - Ears, 0, w + 2 * Ears, h, Ears, br);
            if (_windowed)
            {
                // The window itself is the black surface; nothing to shape.
                _shape.IsVisible = false;
                _content.Clip = null;
            }
            else
            {
                _shape.Data = geometry;
                _content.Clip = geometry;
            }
            _geomW = w; _geomH = h; _geomBr = br;
            UpdateInputShape(w, h, br);
        }

        // Closed content fades as the notch opens; the panels fade in behind it.
        var o = Math.Clamp(_openness.Value, 0, 1);
        _closed.Opacity = 1 - Math.Clamp(o * 2.2, 0, 1);
        _closed.IsHitTestVisible = _stage != Stage.Open;
        _closed.Height = h < 60 ? Math.Max(1, h) : PeekH;
        _open.Opacity = Math.Clamp((o - 0.35) / 0.65, 0, 1);
        _miniBlob.Margin = new Thickness(wide ? (WinW - w) / 2 + 14 : (WinW - _miniBlob.Width) / 2, 0, 0, 0);
        _wing.Margin = new Thickness(0, 0, (WinW - w) / 2 + 16, 0);
        _wing.IsVisible = wide;
        UpdateWing(t);

        // Blob: its mood, and its eyes on the pointer.
        if (++_frame % 3 == 0 && X11.TryGetPointer(out var px, out var py) && (px != _pointerX || py != _pointerY))
        {
            _pointerX = px; _pointerY = py;
            _lastActivity = now;
        }
        var mood = PickMood(now);
        _miniBlob.Mood = mood;
        _headBlob.Mood = mood;
        if (_open.Opacity > 0)
        {
            var (hx, hy) = Look(_headBlob);
            _headBlob.Tick(t, hx, hy);
            if (Welcoming && _welcome.Blob is { } hello)
            {
                var (wx, wy) = Look(hello);
                hello.Tick(t, wx, wy);
            }
        }
        if (_closed.Opacity > 0)
        {
            var (mx, my) = Look(_miniBlob);
            _miniBlob.Tick(t, mx, my);
        }
    }

    /// <summary>Tells the X server which part of the window is the notch. The rest lets clicks through.</summary>
    private void UpdateInputShape(double w, double h, double br)
    {
        if (_xid == IntPtr.Zero || _windowed) return;
        var scale = RenderScaling;
        var rect = new X11.XRectangle(((WinW - w) / 2 - Ears - 3) * scale, 0, (w + 2 * Ears + 6) * scale, (h + 3) * scale);
        if (rect.X == _inputRect.X && rect.Width == _inputRect.Width && rect.Height == _inputRect.Height) return;
        _inputRect = rect;
        X11.SetInputShape(_xid, new[] { rect });

        if (_composited) return;
        // Nothing is compositing: cut the window itself to the notch, row by row, so it isn't a black slab.
        var rows = new List<X11.XRectangle>();
        var bottom = Math.Max(1, h * scale);
        var radius = Math.Min(br, h) * scale;
        for (var y = 0; y < bottom; y += 2)
        {
            var inset = 0.0;
            var fromBottom = bottom - y;
            if (fromBottom < radius)
            {
                var d = radius - fromBottom;
                inset = radius - Math.Sqrt(Math.Max(0, radius * radius - d * d));
            }
            rows.Add(new X11.XRectangle((WinW - w) / 2 * scale + inset, y, w * scale - 2 * inset, 2));
        }
        X11.SetBoundingShape(_xid, rows.ToArray());
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
        string icon = "", text = "";
        var bars = false;
        switch (_wingKind)
        {
            case Wing.Listening: icon = "mic"; bars = true; break;
            case Wing.Working: text = _s.Agent.State == AgentService.Phase.Transcribing ? "Listening back…" : _s.Agent.CurrentStep; break;
            case Wing.Notice: icon = _s.Notices.Icon ?? ""; text = _s.Notices.Text ?? ""; break;
            case Wing.ClaudeWaiting: icon = "code"; text = "Claude needs you"; break;
            case Wing.TimerRang: icon = "timer"; text = "Time’s up"; break;
            case Wing.Timer: icon = "timer"; text = TimerService.Format(_s.Timers.Soonest!.Left); break;
            case Wing.ClaudeWorking: icon = "code"; text = _s.Claude.Working!.Detail; break;
            case Wing.Music: bars = true; break;
        }
        if (icon != _wingIconName)
        {
            _wingIconName = icon;
            _wingIcon.Content = icon.Length > 0 ? Icons.Make(icon, 13, Ink.Primary) : null;
        }
        _wingIcon.IsVisible = icon.Length > 0;
        if (_wingText.Text != text) _wingText.Text = text;
        _wingText.IsVisible = text.Length > 0;
        _bars.IsVisible = bars;
        if (!bars) return;
        for (var i = 0; i < _barRects.Length; i++)
        {
            var v = _wingKind == Wing.Listening
                ? 0.2 + 0.8 * _s.Agent.Level * (0.6 + 0.4 * Math.Sin(t * 18 + i * 1.7))
                : 0.3 + 0.7 * Math.Abs(Math.Sin(t * (5.1 + i * 1.3) + i));
            ((ScaleTransform)_barRects[i].RenderTransform!).ScaleY = Math.Clamp(v, 0.15, 1);
        }
    }

    private Mood PickMood(DateTime now)
    {
        switch (_wingKind)
        {
            case Wing.Listening: return Mood.Curious;
            case Wing.Working:
            case Wing.ClaudeWorking: return Mood.Busy;
            case Wing.ClaudeWaiting:
            case Wing.TimerRang: return Mood.Alarmed;
            case Wing.Music: return Mood.Happy;
        }
        if (_hovering || _stage != Stage.Closed) return Mood.Curious;
        return (now - _lastActivity).TotalSeconds > 600 ? Mood.Sleepy : Mood.Idle;
    }

    private (double, double) Look(Control blob)
    {
        if (_pointerX == 0 && _pointerY == 0) return (0, 0);
        try
        {
            var centre = blob.PointToScreen(new Point(blob.Bounds.Width / 2, blob.Bounds.Height / 2));
            var scale = RenderScaling;
            return ((_pointerX - centre.X) / (260 * scale), (_pointerY - centre.Y) / (260 * scale));
        }
        catch { return (0, 0); }
    }
}
