using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace Blob.UI;

/// <summary>Small builders so the panels read like layout, not plumbing.</summary>
public static class Ui
{
    public static Brush Ink => (Brush)Application.Current.Resources["Ink"];
    public static Brush Ink2 => (Brush)Application.Current.Resources["Ink2"];
    public static Brush Ink3 => (Brush)Application.Current.Resources["Ink3"];
    public static FontFamily Font => (FontFamily)Application.Current.Resources["UiFont"];
    public static FontFamily Icons => (FontFamily)Application.Current.Resources["IconFont"];

    public static TextBlock Text(string text, double size = 13, Brush? brush = null, FontWeight? weight = null, bool wrap = false) => new()
    {
        Text = text,
        FontSize = size,
        FontFamily = Font,
        Foreground = brush ?? Ink,
        FontWeight = weight ?? FontWeights.Normal,
        TextWrapping = wrap ? TextWrapping.Wrap : TextWrapping.NoWrap,
        TextTrimming = wrap ? TextTrimming.None : TextTrimming.CharacterEllipsis,
        VerticalAlignment = VerticalAlignment.Center,
    };

    public static TextBlock Icon(string glyph, double size = 14, Brush? brush = null) => new()
    {
        Text = glyph,
        FontFamily = Icons,
        FontSize = size,
        Foreground = brush ?? Ink,
        VerticalAlignment = VerticalAlignment.Center,
    };

    public static Button Button(object content, Action onClick, string style = "NotchButton", string? tip = null)
    {
        var b = new Button { Content = content, Style = (Style)Application.Current.Resources[style] };
        if (tip != null)
        {
            b.ToolTip = tip;
            System.Windows.Automation.AutomationProperties.SetName(b, tip);
        }
        b.Click += (_, _) => onClick();
        return b;
    }

    public static Button IconButton(string glyph, string tip, Action onClick) => Button(glyph, onClick, "IconButton", tip);

    public static StackPanel Row(double gap, params UIElement[] children)
    {
        var s = new StackPanel { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };
        for (var i = 0; i < children.Length; i++)
        {
            if (i > 0 && children[i] is FrameworkElement fe) fe.Margin = new Thickness(gap, fe.Margin.Top, fe.Margin.Right, fe.Margin.Bottom);
            s.Children.Add(children[i]);
        }
        return s;
    }

    public static StackPanel Column(double gap, params UIElement[] children)
    {
        var s = new StackPanel { Orientation = Orientation.Vertical };
        for (var i = 0; i < children.Length; i++)
        {
            if (i > 0 && children[i] is FrameworkElement fe) fe.Margin = new Thickness(fe.Margin.Left, gap, fe.Margin.Right, fe.Margin.Bottom);
            s.Children.Add(children[i]);
        }
        return s;
    }

    /// <summary>A centred empty state: a line in white and a line in grey.</summary>
    public static UIElement Empty(string title, string detail, UIElement? extra = null)
    {
        var col = Column(4, Text(title, 14, Ink, FontWeights.SemiBold), Text(detail, 13, Ink2, wrap: true));
        col.HorizontalAlignment = HorizontalAlignment.Center;
        col.VerticalAlignment = VerticalAlignment.Center;
        col.MaxWidth = 380;
        foreach (var c in col.Children) if (c is TextBlock t) t.TextAlignment = TextAlignment.Center;
        if (extra is FrameworkElement fe)
        {
            fe.Margin = new Thickness(0, 14, 0, 0);
            fe.HorizontalAlignment = HorizontalAlignment.Center;
            col.Children.Add(fe);
        }
        return col;
    }
}
