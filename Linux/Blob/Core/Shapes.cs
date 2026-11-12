using System;
using Avalonia;
using Avalonia.Media;

namespace Blob.Core;

/// <summary>The notch outline and Blob's body, with the same continuous corners as the Mac app.</summary>
public static class Shapes
{
    private const double K = 1.28;

    /// <summary>
    /// A notch hanging from the top edge: flared "ears" at the top corners (topRadius),
    /// continuous rounded corners at the bottom (bottomRadius).
    /// </summary>
    public static Geometry Notch(double x, double y, double w, double h, double topRadius, double bottomRadius)
    {
        var tr = Math.Max(0, Math.Min(topRadius, Math.Min(w / 4, h / 2)));
        var br = Math.Max(0, Math.Min(bottomRadius, Math.Min((w - 2 * tr) / (2 * K), (h - tr) / K)));
        double minX = x, minY = y, maxX = x + w, maxY = y + h, left = minX + tr, right = maxX - tr;
        var g = new StreamGeometry();
        using (var c = g.Open())
        {
            c.BeginFigure(new Point(minX, minY), true);
            c.CubicBezierTo(new Point(minX + tr * 0.62, minY), new Point(left, minY + tr * 0.38), new Point(left, minY + tr));
            c.LineTo(new Point(left, maxY - br * K));
            c.CubicBezierTo(new Point(left, maxY - br * 0.26), new Point(left + br * 0.26, maxY), new Point(left + br * K, maxY));
            c.LineTo(new Point(right - br * K, maxY));
            c.CubicBezierTo(new Point(right - br * 0.26, maxY), new Point(right, maxY - br * 0.26), new Point(right, maxY - br * K));
            c.LineTo(new Point(right, minY + tr));
            c.CubicBezierTo(new Point(right, minY + tr * 0.38), new Point(maxX - tr * 0.62, minY), new Point(maxX, minY));
            c.EndFigure(true);
        }
        return g;
    }

    /// <summary>A continuous-corner rounded rectangle (Blob's body).</summary>
    public static Geometry Squircle(double x, double y, double w, double h, double r)
    {
        var rr = Math.Min(r, Math.Min(w / (2 * K), h / (2 * K)));
        double a = rr * K, b = rr * 0.26;
        var g = new StreamGeometry();
        using (var c = g.Open())
        {
            c.BeginFigure(new Point(x + a, y), true);
            c.LineTo(new Point(x + w - a, y));
            c.CubicBezierTo(new Point(x + w - b, y), new Point(x + w, y + b), new Point(x + w, y + a));
            c.LineTo(new Point(x + w, y + h - a));
            c.CubicBezierTo(new Point(x + w, y + h - b), new Point(x + w - b, y + h), new Point(x + w - a, y + h));
            c.LineTo(new Point(x + a, y + h));
            c.CubicBezierTo(new Point(x + b, y + h), new Point(x, y + h - b), new Point(x, y + h - a));
            c.LineTo(new Point(x, y + a));
            c.CubicBezierTo(new Point(x, y + b), new Point(x + b, y), new Point(x + a, y));
            c.EndFigure(true);
        }
        return g;
    }
}
