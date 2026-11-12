using System;
using System.Globalization;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Media;
using Blob.Core;

namespace Blob.UI;

/// <summary>
/// The character: a grey continuous-corner body with two eyes, moving by mood.
/// Call Tick every frame with the time and where to look (-1…1).
/// </summary>
public sealed class BlobView : Control
{
    private static readonly IBrush Body = new SolidColorBrush(Color.FromRgb(0x94, 0x94, 0x98)).ToImmutable();
    private static readonly IBrush Eye = Brushes.Black;
    private static readonly IBrush Zed = new SolidColorBrush(Color.FromArgb(0xB0, 0xC8, 0xC8, 0xCD)).ToImmutable();
    private static readonly Geometry BodyShape = Shapes.Squircle(0.09, 0.2, 1.12, 1, 0.36);
    private static readonly Typeface ZedFace = new(FontFamily.Default, FontStyle.Normal, FontWeight.Bold);

    private Mood _mood = Mood.Idle, _previous = Mood.Idle;
    private double _changedAt = -10;
    private Pose _pose = Pose.Base;
    private double _lookX, _lookY, _t;

    public double Size { get; }

    public BlobView(double size)
    {
        Size = size;
        Width = size * 1.3;
        Height = size * 1.2;
        IsHitTestVisible = false;
        ClipToBounds = false;
    }

    public Mood Mood
    {
        get => _mood;
        set
        {
            if (value == _mood) return;
            _previous = _mood;
            _mood = value;
            _changedAt = _t;
        }
    }

    public void Tick(double t, double lookX, double lookY)
    {
        _t = t;
        _pose = Pose.Lerp(Moods.Pose(_previous, t), Moods.Pose(_mood, t), Moods.SpringProgress(t - _changedAt));
        _lookX = Math.Clamp(lookX, -1, 1);
        _lookY = Math.Clamp(lookY, -1, 1);
        InvalidateVisual();
    }

    private static Matrix About(Matrix m, double cx, double cy) =>
        Matrix.CreateTranslation(-cx, -cy) * m * Matrix.CreateTranslation(cx, cy);

    public override void Render(DrawingContext dc)
    {
        var p = _pose;
        var lookX = _lookX * p.LookGain + p.EyeShift;
        var lookY = _lookY * p.LookGain;
        var rot = (p.Rot + _lookX * 3 * p.LookGain) * Math.PI / 180;

        // Same order as the Mac and the website: squash from the feet, rotate about the feet, move, then size.
        using (dc.PushTransform(Matrix.CreateScale(Size, Size)))
        using (dc.PushTransform(Matrix.CreateTranslation(p.Dx, p.Dy)))
        using (dc.PushTransform(About(Matrix.CreateRotation(rot), 0.65, 1.2)))
        using (dc.PushTransform(About(Matrix.CreateScale(p.Sx, p.Sy), 0.65, 1.2)))
        {
            dc.DrawGeometry(Body, null, BodyShape);
            var ew = 0.13 * p.EyeScale;
            var eh = Math.Max(0.035, 0.2 * p.EyeScale * p.EyeOpen);
            var ox = lookX * 0.1;
            var oy = -0.05 + lookY * 0.07;
            var r = Math.Min(ew, eh) / 2;
            dc.DrawRectangle(Eye, null, new Rect(0.65 - 0.12 - ew + ox, 0.7 - eh / 2 + oy, ew, eh), r, r);
            dc.DrawRectangle(Eye, null, new Rect(0.65 + 0.12 + ox, 0.7 - eh / 2 + oy, ew, eh), r, r);
        }

        if (p.Z > 0.01)
        {
            var f = _t % 2.4 / 2.4;
            var text = new FormattedText("z", CultureInfo.InvariantCulture, FlowDirection.LeftToRight, ZedFace, 0.42 * Size, Zed);
            using (dc.PushOpacity(p.Z * (1 - f)))
                dc.DrawText(text, new Point((0.65 + 0.5 + 0.15 * f) * Size, (0.7 - 0.55 - 0.4 * f - 0.3) * Size));
        }
    }
}
