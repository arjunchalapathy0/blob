using System;

namespace Blob.Core;

/// <summary>A spring preset in SwiftUI terms: response (seconds) and damping fraction.</summary>
public readonly record struct SpringPreset(double Response, double Damping);

/// <summary>The Mac app's springs (Blob/Core/Springs.swift), so both versions move the same way.</summary>
public static class Springs
{
    public static readonly SpringPreset Open = new(0.42, 0.74);
    public static readonly SpringPreset Close = new(0.34, 0.90);
    public static readonly SpringPreset Snap = new(0.30, 0.82);
    public static readonly SpringPreset Soft = new(0.55, 0.85);
    public static readonly SpringPreset Wobble = new(0.38, 0.58);
}

/// <summary>A damped spring, stepped with semi-implicit Euler in small substeps (stable at any frame rate).</summary>
public sealed class Spring
{
    private double _k, _c;
    public double Value { get; private set; }
    public double Velocity { get; private set; }
    public double Target { get; private set; }

    public Spring(double value, SpringPreset? preset = null)
    {
        Value = Target = value;
        Use(preset ?? Springs.Snap);
    }

    public void Use(SpringPreset p)
    {
        _k = Math.Pow(2 * Math.PI / p.Response, 2);
        _c = 4 * Math.PI * p.Damping / p.Response;
    }

    public void To(double target, SpringPreset? preset = null)
    {
        if (preset is { } p) Use(p);
        Target = target;
    }

    public void Jump(double value)
    {
        Value = Target = value;
        Velocity = 0;
    }

    public bool Settled => Math.Abs(Value - Target) < 0.01 && Math.Abs(Velocity) < 0.01;

    public double Step(double dt)
    {
        var remaining = Math.Min(dt, 0.1);
        while (remaining > 0)
        {
            var h = Math.Min(remaining, 1.0 / 240);
            var force = -_k * (Value - Target) - _c * Velocity;
            Velocity += force * h;
            Value += Velocity * h;
            remaining -= h;
        }
        if (Settled) Jump(Target);
        return Value;
    }
}
