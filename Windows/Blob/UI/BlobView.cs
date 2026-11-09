using System;
using System.Globalization;
using System.Windows;
using System.Windows.Media;
using Blob.Core;

namespace Blob.UI;

/// <summary>
/// The character: a grey continuous-corner body with two eyes, moving by mood.
/// Call Tick every frame with the time and where to look (-1…1).
/// </summary>
public sealed class BlobView : FrameworkElement
{
    private static readonly Brush Body = Freeze(new SolidColorBrush(Color.FromRgb(0x94, 0x94, 0x98)));
    private static readonly Brush Eye = Brushes.Black;
    private static readonly Brush Zed = Freeze(new SolidColorBrush(Color.FromArgb(0xB0, 0xC8, 0xC8, 0xCD)));
    private static readonly Geometry BodyShape = Shapes.Squircle(0.09, 0.2, 1.12, 1, 0.36);

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
        SnapsToDevicePixels = false;
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

    protected override void OnRender(DrawingContext dc)
    {
        var p = _pose;
        var lookX = _lookX * p.LookGain + p.EyeShift;
        var lookY = _lookY * p.LookGain;
        var rot = p.Rot + _lookX * 3 * p.LookGain;

        dc.PushTransform(new ScaleTransform(Size, Size));
        // Same transform order as the Mac and the website: move, rotate about the feet, squash from the feet.
        dc.PushTransform(new TranslateTransform(p.Dx, p.Dy));
        dc.PushTransform(new RotateTransform(rot, 0.65, 1.2));
        dc.PushTransform(new ScaleTransform(p.Sx, p.Sy, 0.65, 1.2));
        dc.DrawGeometry(Body, null, BodyShape);

        var ew = 0.13 * p.EyeScale;
        var eh = Math.Max(0.035, 0.2 * p.EyeScale * p.EyeOpen);
        var ox = lookX * 0.1;
        var oy = -0.05 + lookY * 0.07;
        foreach (var x in new[] { 0.65 - 0.12 - ew, 0.65 + 0.12 })
        {
            var r = Math.Min(ew, eh) / 2;
            dc.DrawRoundedRectangle(Eye, null, new Rect(x + ox, 0.7 - eh / 2 + oy, ew, eh), r, r);
        }
        dc.Pop(); dc.Pop(); dc.Pop();

        if (p.Z > 0.01)
        {
            var f = _t % 2.4 / 2.4;
            dc.PushOpacity(p.Z * (1 - f));
            var text = new FormattedText("z", CultureInfo.InvariantCulture, FlowDirection.LeftToRight,
                new Typeface(new FontFamily("Segoe UI"), FontStyles.Normal, FontWeights.Bold, FontStretches.Normal), 0.42, Zed, 1.0);
            dc.DrawText(text, new Point(0.65 + 0.5 + 0.15 * f, 0.7 - 0.55 - 0.4 * f - 0.3));
            dc.Pop();
        }
        dc.Pop();
    }

    private static Brush Freeze(Brush b) { b.Freeze(); return b; }
}
