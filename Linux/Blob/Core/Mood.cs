using System;

namespace Blob.Core;

public enum Mood { Idle, Curious, Happy, Busy, Alarmed, Sleepy }

/// <summary>One frame of Blob's body language.</summary>
public struct Pose
{
    public double Sx, Sy, Dx, Dy, Rot, EyeOpen, EyeScale, EyeShift, LookGain, Z;

    public static Pose Base => new() { Sx = 1, Sy = 1, EyeOpen = 1, EyeScale = 1, LookGain = 1 };

    public static Pose Lerp(Pose a, Pose b, double t)
    {
        double M(double x, double y) => x + (y - x) * t;
        return new Pose
        {
            Sx = M(a.Sx, b.Sx), Sy = M(a.Sy, b.Sy), Dx = M(a.Dx, b.Dx), Dy = M(a.Dy, b.Dy), Rot = M(a.Rot, b.Rot),
            EyeOpen = M(a.EyeOpen, b.EyeOpen), EyeScale = M(a.EyeScale, b.EyeScale), EyeShift = M(a.EyeShift, b.EyeShift),
            LookGain = M(a.LookGain, b.LookGain), Z = M(a.Z, b.Z),
        };
    }
}

/// <summary>Blob's motion engine, ported from Blob/Core/Character/Mood.swift (same numbers as the Mac and the website).</summary>
public static class Moods
{
    private const double Tau = 2 * Math.PI;
    private static double Fract(double x) => x - Math.Floor(x);

    public static double Blink(double t)
    {
        const double period = 4.6;
        var cycle = Math.Floor(t / period);
        var local = t - cycle * period;
        static double Dip(double x) => x >= 0 && x < 0.14 ? Math.Abs(Math.Cos(Math.PI * x / 0.14)) : 1;
        var first = Dip(local);
        var second = ((long)cycle % 3 + 3) % 3 == 0 ? Dip(local - 0.22) : 1;
        return Math.Min(first, second);
    }

    public static Pose Pose(Mood mood, double t)
    {
        double S(double period, double phase = 0) => Math.Sin(Tau * t / period + phase);
        var p = Core.Pose.Base;
        switch (mood)
        {
            case Mood.Idle:
            {
                var b = S(3.6);
                p.Sy = 1 + 0.028 * b; p.Sx = 1 - 0.018 * b;
                p.EyeShift = 0.25 * S(9.0); p.EyeOpen = Blink(t);
                break;
            }
            case Mood.Curious:
            {
                var b = S(2.8);
                p.Sy = 1.04 + 0.02 * b; p.Sx = 0.98; p.Dy = -0.04;
                p.Rot = 5 + 2 * S(4.2); p.EyeScale = 1.18; p.LookGain = 1.4; p.EyeOpen = Blink(t + 1.3);
                break;
            }
            case Mood.Happy:
            {
                var phase = Fract(t * 2.0);
                var air = Math.Sin(Math.PI * phase);
                var land = Math.Pow(1 - air, 6);
                p.Dy = -0.16 * air; p.Sy = 1 - 0.1 * land + 0.04 * air; p.Sx = 1 + 0.08 * land - 0.02 * air;
                p.Rot = 3 * S(1.0); p.EyeOpen = 0.5; p.LookGain = 0.6;
                break;
            }
            case Mood.Busy:
                p.Rot = 4 * S(0.42); p.Sx = 1 + 0.03 * S(0.21); p.Sy = 1 - 0.03 * S(0.21);
                p.EyeShift = S(1.4); p.EyeOpen = 0.78 * Blink(t + 0.7); p.LookGain = 0.2;
                break;
            case Mood.Alarmed:
            {
                var e = Math.Exp(-3.2 * Fract(t / 1.2));
                p.Dy = -0.22 * e; p.Sy = 1 + 0.12 * e; p.Sx = 1 - 0.06 * e;
                p.Dx = 0.05 * e * S(0.09); p.Rot = 8 * e * S(0.16); p.EyeScale = 1.35; p.LookGain = 0.3;
                break;
            }
            case Mood.Sleepy:
            {
                var b = S(5.2);
                p.Sy = 0.9 + 0.035 * b; p.Sx = 1.06 - 0.02 * b; p.Dy = 0.04; p.Rot = -5;
                p.EyeOpen = 0.1; p.LookGain = 0; p.Z = 1;
                break;
            }
        }
        return p;
    }

    /// <summary>Damped 0→1 with a little overshoot, for blending from one mood to the next.</summary>
    public static double SpringProgress(double dt)
    {
        if (dt <= 0) return 0;
        if (dt >= 1.4) return 1;
        return 1 - Math.Exp(-6.5 * dt) * Math.Cos(9.5 * dt);
    }
}
