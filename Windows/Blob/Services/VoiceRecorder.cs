using System;
using System.IO;
using NAudio.Wave;

namespace Blob.Services;

/// <summary>Records the default microphone at 16 kHz mono (what Whisper wants), in memory.</summary>
public sealed class VoiceRecorder
{
    private WaveInEvent? _wave;
    private MemoryStream? _buffer;
    private WaveFileWriter? _writer;
    private DateTime _started;

    public float Level { get; private set; }

    public static bool HasMicrophone => WaveInEvent.DeviceCount > 0;

    public void Start()
    {
        Cancel();
        _buffer = new MemoryStream();
        _wave = new WaveInEvent { WaveFormat = new WaveFormat(16000, 16, 1), BufferMilliseconds = 50 };
        _writer = new WaveFileWriter(new NonClosing(_buffer), _wave.WaveFormat);
        _wave.DataAvailable += (_, e) =>
        {
            _writer?.Write(e.Buffer, 0, e.BytesRecorded);
            float peak = 0;
            for (var i = 0; i + 1 < e.BytesRecorded; i += 2)
            {
                var s = Math.Abs(BitConverter.ToInt16(e.Buffer, i) / 32768f);
                if (s > peak) peak = s;
            }
            Level = Math.Min(1, peak * 1.6f);
        };
        _wave.StartRecording();
        _started = DateTime.Now;
    }

    /// <summary>Stops and returns the WAV bytes and how long it was.</summary>
    public (byte[] Wav, TimeSpan Duration)? Stop()
    {
        if (_wave == null || _writer == null || _buffer == null) return null;
        _wave.StopRecording();
        _wave.Dispose();
        _writer.Flush();
        _writer.Dispose();
        var bytes = _buffer.ToArray();
        var duration = DateTime.Now - _started;
        _wave = null; _writer = null; _buffer = null; Level = 0;
        return (bytes, duration);
    }

    public void Cancel()
    {
        try { _wave?.StopRecording(); } catch { }
        _wave?.Dispose();
        _writer?.Dispose();
        _wave = null; _writer = null; _buffer = null; Level = 0;
    }

    /// <summary>Keeps WaveFileWriter from closing the memory stream so the header can be finalised.</summary>
    private sealed class NonClosing : Stream
    {
        private readonly Stream _s;
        public NonClosing(Stream s) => _s = s;
        public override bool CanRead => _s.CanRead;
        public override bool CanSeek => _s.CanSeek;
        public override bool CanWrite => _s.CanWrite;
        public override long Length => _s.Length;
        public override long Position { get => _s.Position; set => _s.Position = value; }
        public override void Flush() => _s.Flush();
        public override int Read(byte[] buffer, int offset, int count) => _s.Read(buffer, offset, count);
        public override long Seek(long offset, SeekOrigin origin) => _s.Seek(offset, origin);
        public override void SetLength(long value) => _s.SetLength(value);
        public override void Write(byte[] buffer, int offset, int count) => _s.Write(buffer, offset, count);
        protected override void Dispose(bool disposing) => Flush();
    }
}
