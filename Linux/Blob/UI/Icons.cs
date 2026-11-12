using System.Collections.Generic;
using Avalonia.Controls;
using Avalonia.Controls.Shapes;
using Avalonia.Layout;
using Avalonia.Media;

namespace Blob.UI;

/// <summary>
/// Small monochrome line icons on a 16×16 grid with a 1.6 stroke, the same drawings the website uses
/// (Linux has no icon font everyone shares, so Blob brings its own).
/// </summary>
public static class Icons
{
    private static readonly Dictionary<string, string> Lines = new()
    {
        ["mic"] = "M8 2.2a2.2 2.2 0 0 1 2.2 2.2v3.4a2.2 2.2 0 1 1-4.4 0V4.4A2.2 2.2 0 0 1 8 2.2Z M4 7.6a4 4 0 0 0 8 0 M8 11.6v2.2",
        ["check"] = "M3.4 8.4l3 3 6.2-6.6",
        ["warn"] = "M8 2.5l6 10.5H2L8 2.5Z M8 6.6v3 M8 11.3v.1",
        ["ear"] = "M5 6.2a3 3 0 1 1 5.8 1.1c-.6 1.4-2 1.8-2 3.4a1.8 1.8 0 0 1-3.4.7",
        ["copy"] = "M5.5 5.5h7v7h-7z M3.5 10.5v-7h7",
        ["timer"] = "M8 14a5.2 5.2 0 1 0 0-10.4A5.2 5.2 0 0 0 8 14Z M8 6v3l1.8 1.2 M6.4 1.8h3.2",
        ["music"] = "M6 12.2a1.8 1.8 0 1 1-1.8-1.8H6V3.2l6-1.2v8.4a1.8 1.8 0 1 1-1.8-1.8H12",
        ["clipboard"] = "M5 3h6v1.8H5z M4 3.6H3v10.4h10V3.6h-1 M5.5 8h5 M5.5 10.6h3",
        ["code"] = "M8 2c.4 3 1.6 4.6 5 6-3.4 1.4-4.6 3-5 6-.4-3-1.6-4.6-5-6 3.4-1.4 4.6-3 5-6Z",
        ["ask"] = "M2.5 7v2 M5 5.5v5 M7.5 3v10 M10 5.5v5 M12.5 7v2",
        ["send"] = "M8 13V3.5 M3.8 7.7 8 3.5l4.2 4.2",
        ["plus"] = "M8 3.5v9 M3.5 8h9",
        ["down"] = "M8 3v9.5 M3.8 8.3 8 12.5l4.2-4.2",
        ["close"] = "M4 4l8 8 M12 4l-8 8",
        ["pin"] = "M6 2.5h4l-.6 4 2.1 2.2H4.5l2.1-2.2z M8 8.7v4.8",
        ["settings"] = "M8 10.2a2.2 2.2 0 1 0 0-4.4 2.2 2.2 0 0 0 0 4.4Z M8 1.8v1.7 M8 12.5v1.7 M1.8 8h1.7 M12.5 8h1.7 M3.6 3.6l1.2 1.2 M11.2 11.2l1.2 1.2 M3.6 12.4l1.2-1.2 M11.2 4.8l1.2-1.2",
    };

    private static readonly Dictionary<string, string> Solids = new()
    {
        ["play"] = "M5 3.2v9.6l8-4.8z",
        ["pause"] = "M4.2 3.4h2.8v9.2H4.2z M9 3.4h2.8v9.2H9z",
        ["stop"] = "M4.4 4.4h7.2v7.2H4.4z",
        ["next"] = "M3.4 3.8v8.4L10 8z M11 3.8h1.8v8.4H11z",
        ["previous"] = "M12.6 3.8v8.4L6 8z M3.2 3.8H5v8.4H3.2z",
    };

    private static readonly Dictionary<string, Geometry> Cache = new();

    private static Geometry? Shape(string data)
    {
        if (Cache.TryGetValue(data, out var g)) return g;
        try { g = Geometry.Parse(data); } catch { return null; }
        Cache[data] = g;
        return g;
    }

    /// <summary>An icon as a control, `size` pixels square.</summary>
    public static Control Make(string name, double size = 14, IBrush? brush = null)
    {
        brush ??= Brushes.White;
        var path = new Path { Stretch = Stretch.None };
        if (Solids.TryGetValue(name, out var solid))
        {
            path.Data = Shape(solid);
            path.Fill = brush;
        }
        else if (Lines.TryGetValue(name, out var line))
        {
            path.Data = Shape(line);
            path.Stroke = brush;
            path.StrokeThickness = 1.6;
            path.StrokeLineCap = PenLineCap.Round;
            path.StrokeJoin = PenLineJoin.Round;
        }
        var canvas = new Canvas { Width = 16, Height = 16 };
        canvas.Children.Add(path);
        return new Viewbox
        {
            Width = size, Height = size, Child = canvas, Stretch = Stretch.Uniform,
            VerticalAlignment = VerticalAlignment.Center, IsHitTestVisible = false,
        };
    }

    /// <summary>Recolours an icon made by <see cref="Make"/>.</summary>
    public static void Tint(Control icon, IBrush brush)
    {
        if (icon is Viewbox { Child: Canvas canvas } && canvas.Children.Count > 0 && canvas.Children[0] is Path path)
        {
            if (path.Fill != null) path.Fill = brush;
            if (path.Stroke != null) path.Stroke = brush;
        }
    }
}
