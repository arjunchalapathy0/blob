using System;
using System.Diagnostics;
using System.IO;
using System.Threading.Tasks;

namespace Blob.Services;

/// <summary>
/// Records the default microphone at 16 kHz mono (what Whisper wants), in memory, through
/// whichever recorder the system has: parecord (PulseAudio/PipeWire), arecord (ALSA) or pw-record.
/// </summary>
public sealed class VoiceRecorder
{
    private Process? _process;
    private MemoryStream? _pcm;
    private Task? _pump;
    private DateTime _started;

    public float Level { get; private set; }

    private static (string File, string[] Args)? Recorder()
    {
        if (Tools.Find("parecord") is { } pa)
            return (pa, new[] { "--raw", "--format=s16le", "--rate=16000", "--channels=1", "--latency-msec=40", "--client-name=Blob" });
        if (Tools.Find("arecord") is { } alsa)
            return (alsa, new[] { "-q", "-t", "raw", "-f", "S16_LE", "-r", "16000", "-c", "1" });
        if (Tools.Find("pw-record") is { } pw)
            return (pw, new[] { "--raw", "--format=s16", "--rate=16000", "--channels=1", "-" });
        return null;
    }

    public static bool HasRecorder => Recorder() != null;

    public void Start()
    {
        Cancel();
        var recorder = Recorder() ?? throw new InvalidOperationException("No recorder found. Install pulseaudio-utils or alsa-utils.");
        var psi = new ProcessStartInfo(recorder.File) { UseShellExecute = false, RedirectStandardOutput = true, RedirectStandardError = true };
        foreach (var a in recorder.Args) psi.ArgumentList.Add(a);
        var process = Process.Start(psi) ?? throw new InvalidOperationException("Couldn't start the recorder.");
        var pcm = new MemoryStream();
        _process = process;
        _pcm = pcm;
        _started = DateTime.Now;
        _ = process.StandardError.ReadToEndAsync();
        _pump = Task.Run(async () =>
        {
            var buffer = new byte[3200]; // 100 ms
            var stream = process.StandardOutput.BaseStream;
            try
            {
                int n;
                while ((n = await stream.ReadAsync(buffer)) > 0)
                {
                    lock (pcm) pcm.Write(buffer, 0, n);
                    float peak = 0;
                    for (var i = 0; i + 1 < n; i += 2)
                    {
                        var s = Math.Abs(BitConverter.ToInt16(buffer, i) / 32768f);
                        if (s > peak) peak = s;
                    }
                    Level = Math.Min(1, peak * 1.6f);
                }
            }
            catch { }
        });
    }

    /// <summary>Stops and returns the recording as a WAV file's bytes, and how long it was.</summary>
    public async Task<(byte[] Wav, TimeSpan Duration)?> StopAsync()
    {
        var process = _process;
        var pcm = _pcm;
        var pump = _pump;
        if (process == null || pcm == null) return null;
        _process = null; _pcm = null; _pump = null;
        var duration = DateTime.Now - _started;
        try { if (!process.HasExited) process.Kill(); } catch { }
        if (pump != null) await Task.WhenAny(pump, Task.Delay(500));
        process.Dispose();
        Level = 0;
        byte[] data;
        lock (pcm) data = pcm.ToArray();
        return (Wav(data), duration);
    }

    public void Cancel()
    {
        try { if (_process is { HasExited: false }) _process.Kill(); } catch { }
        _process?.Dispose();
        _process = null; _pcm = null; _pump = null; Level = 0;
    }

    /// <summary>Wraps 16 kHz mono 16-bit samples in a WAV header.</summary>
    private static byte[] Wav(byte[] pcm)
    {
        using var ms = new MemoryStream(44 + pcm.Length);
        using var w = new BinaryWriter(ms);
        w.Write("RIFF"u8); w.Write(36 + pcm.Length); w.Write("WAVE"u8);
        w.Write("fmt "u8); w.Write(16); w.Write((short)1); w.Write((short)1);
        w.Write(16000); w.Write(16000 * 2); w.Write((short)2); w.Write((short)16);
        w.Write("data"u8); w.Write(pcm.Length); w.Write(pcm);
        w.Flush();
        return ms.ToArray();
    }
}
