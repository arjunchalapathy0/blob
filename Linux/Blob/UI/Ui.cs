using System;
using Avalonia;
using Avalonia.Automation;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Layout;
using Avalonia.Media;

namespace Blob.UI;

/// <summary>Blob's colours: black surface, white ink at a few strengths, one grey for the character.</summary>
public static class Ink
{
    public static readonly IBrush Primary = Brushes.White;
    public static readonly IBrush Secondary = new SolidColorBrush(Color.FromArgb(0xA3, 0xFF, 0xFF, 0xFF)).ToImmutable();
    public static readonly IBrush Tertiary = new SolidColorBrush(Color.FromArgb(0x6B, 0xFF, 0xFF, 0xFF)).ToImmutable();
    public static readonly IBrush Fill = new SolidColorBrush(Color.FromRgb(0x1C, 0x1C, 0x1E)).ToImmutable();
    public static readonly IBrush FillStrong = new SolidColorBrush(Color.FromRgb(0x2C, 0x2C, 0x2E)).ToImmutable();
    public static readonly IBrush Clear = Brushes.Transparent;
}

/// <summary>
/// Anything clickable inside the notch: a rounded shape that brightens under the pointer and dips when pressed.
/// </summary>
public sealed class Pressable : Border
{
    private bool _pressed;
    private IBrush _rest = Ink.Clear;
    private IBrush _hover = Ink.FillStrong;

    public event Action? Click;
    /// <summary>For press-and-hold controls (the microphone button).</summary>
    public event Action? Down;
    public event Action? Up;

    public Pressable()
    {
        Cursor = new Cursor(StandardCursorType.Hand);
        Background = _rest;
        RenderTransformOrigin = RelativePoint.Center;
    }

    public void Colours(IBrush rest, IBrush hover)
    {
        _rest = rest;
        _hover = hover;
        Background = IsPointerOver ? hover : rest;
    }

    protected override void OnPointerEntered(PointerEventArgs e)
    {
        base.OnPointerEntered(e);
        Background = _hover;
    }

    protected override void OnPointerExited(PointerEventArgs e)
    {
        base.OnPointerExited(e);
        Background = _rest;
        if (_pressed) Release(false);
    }

    protected override void OnPointerPressed(PointerPressedEventArgs e)
    {
        base.OnPointerPressed(e);
        if (!e.GetCurrentPoint(this).Properties.IsLeftButtonPressed) return;
        _pressed = true;
        RenderTransform = new ScaleTransform(0.94, 0.94);
        Opacity = 0.8;
        Down?.Invoke();
        e.Handled = true;
    }

    protected override void OnPointerReleased(PointerReleasedEventArgs e)
    {
        base.OnPointerReleased(e);
        if (!_pressed) return;
        var inside = new Rect(Bounds.Size).Contains(e.GetPosition(this));
        Release(inside);
        e.Handled = true;
    }

    private void Release(bool click)
    {
        _pressed = false;
        RenderTransform = null;
        Opacity = 1;
        Up?.Invoke();
        if (click) Click?.Invoke();
    }
}

/// <summary>Small builders so the panels read like layout, not plumbing.</summary>
public static class Ui
{
    public static readonly FontFamily Font = new("fonts:Inter#Inter, Inter, Cantarell, Ubuntu, Noto Sans, sans-serif");

    public static TextBlock Text(string text, double size = 13, IBrush? brush = null, FontWeight weight = FontWeight.Normal, bool wrap = false) => new()
    {
        Text = text,
        FontSize = size,
        FontFamily = Font,
        Foreground = brush ?? Ink.Primary,
        FontWeight = weight,
        TextWrapping = wrap ? TextWrapping.Wrap : TextWrapping.NoWrap,
        TextTrimming = wrap ? TextTrimming.None : TextTrimming.CharacterEllipsis,
        VerticalAlignment = VerticalAlignment.Center,
    };

    /// <summary>A pill with a label. Prominent pills are white with black text.</summary>
    public static Pressable Pill(string title, Action onClick, bool prominent = false)
    {
        var label = Text(title, 12, prominent ? Brushes.Black : Ink.Primary, FontWeight.SemiBold);
        var pill = new Pressable { CornerRadius = new CornerRadius(999), Padding = new Thickness(12, 6), Child = label };
        if (prominent) pill.Colours(Brushes.White, new SolidColorBrush(Color.FromRgb(0xE6, 0xE6, 0xEA)));
        else pill.Colours(Ink.FillStrong, new SolidColorBrush(Color.FromRgb(0x3A, 0x3A, 0x3D)));
        pill.Click += onClick;
        AutomationProperties.SetName(pill, title);
        return pill;
    }

    /// <summary>An icon on a round target, with a tooltip saying what it does.</summary>
    public static Pressable IconButton(string icon, string tip, Action onClick, double size = 28, double iconSize = 14, IBrush? brush = null)
    {
        var button = new Pressable
        {
            Width = size, Height = size, CornerRadius = new CornerRadius(size / 2),
            Child = Icons.Make(icon, iconSize, brush ?? Ink.Secondary),
        };
        button.Click += onClick;
        ToolTip.SetTip(button, tip);
        AutomationProperties.SetName(button, tip);
        return button;
    }

    public static StackPanel Row(double gap, params Control[] children)
    {
        var s = new StackPanel { Orientation = Orientation.Horizontal, Spacing = gap, VerticalAlignment = VerticalAlignment.Center };
        s.Children.AddRange(children);
        return s;
    }

    public static StackPanel Column(double gap, params Control[] children)
    {
        var s = new StackPanel { Orientation = Orientation.Vertical, Spacing = gap };
        s.Children.AddRange(children);
        return s;
    }

    /// <summary>A centred empty state: a line in white, a line in grey, and maybe something to click.</summary>
    public static Control Empty(string title, string detail, Control? extra = null)
    {
        var heading = Text(title, 14, Ink.Primary, FontWeight.SemiBold);
        var body = Text(detail, 13, Ink.Secondary, wrap: true);
        heading.TextAlignment = body.TextAlignment = TextAlignment.Center;
        heading.HorizontalAlignment = body.HorizontalAlignment = HorizontalAlignment.Center;
        var col = Column(4, heading, body);
        col.HorizontalAlignment = HorizontalAlignment.Center;
        col.VerticalAlignment = VerticalAlignment.Center;
        col.MaxWidth = 400;
        if (extra != null)
        {
            extra.Margin = new Thickness(0, 12, 0, 0);
            extra.HorizontalAlignment = HorizontalAlignment.Center;
            col.Children.Add(extra);
        }
        return col;
    }

    public static ScrollViewer Scroll(Control content) => new()
    {
        Content = content,
        VerticalScrollBarVisibility = Avalonia.Controls.Primitives.ScrollBarVisibility.Auto,
        HorizontalScrollBarVisibility = Avalonia.Controls.Primitives.ScrollBarVisibility.Disabled,
    };
}
