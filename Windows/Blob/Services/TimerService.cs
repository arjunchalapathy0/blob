using System;
using System.Collections.Generic;
using System.Linq;
using System.Media;
using System.Windows.Threading;
using Blob.Core;

namespace Blob.Services;

public sealed class BlobTimer
{
    public required string Label { get; init; }
    public required TimeSpan Length { get; init; }
    public DateTime Ends { get; set; }
    public TimeSpan Left => Ends - DateTime.Now > TimeSpan.Zero ? Ends - DateTime.Now : TimeSpan.Zero;
}

/// <summary>Several timers at once. The soonest one shows in the notch until it says "Time's up".</summary>
public sealed class TimerService
{
    private readonly DispatcherTimer _tick;
    public List<BlobTimer> Timers { get; } = new();
    public DateTime? RangAt { get; private set; }
    public event Action? Changed;
    public event Action<BlobTimer>? Finished;

    public TimerService()
    {
        _tick = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(250) };
        _tick.Tick += (_, _) => Tick();
        _tick.Start();
    }

    public BlobTimer? Soonest => Timers.OrderBy(t => t.Ends).FirstOrDefault();
    public bool Ringing => RangAt is { } r && DateTime.Now - r < TimeSpan.FromSeconds(6);

    public void Start(TimeSpan length, string? label = null)
    {
        Timers.Add(new BlobTimer
        {
            Label = label ?? Format(length),
            Length = length,
            Ends = DateTime.Now + length,
        });
        Changed?.Invoke();
    }

    public void Cancel(BlobTimer t)
    {
        Timers.Remove(t);
        Changed?.Invoke();
    }

    private void Tick()
    {
        var done = Timers.Where(t => t.Left == TimeSpan.Zero).ToList();
        foreach (var t in done)
        {
            Timers.Remove(t);
            RangAt = DateTime.Now;
            if (Prefs.Current.TimerSound) SystemSounds.Asterisk.Play();
            Finished?.Invoke(t);
        }
        Changed?.Invoke();
    }

    public static string Format(TimeSpan t) =>
        t.TotalHours >= 1 ? $"{(int)t.TotalHours}:{t.Minutes:00}:{t.Seconds:00}" : $"{(int)t.TotalMinutes}:{t.Seconds:00}";
}
