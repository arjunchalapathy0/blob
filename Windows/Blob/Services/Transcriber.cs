using System;
using System.IO;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Blob.Core;
using Whisper.net;
using Whisper.net.Ggml;

namespace Blob.Services;

/// <summary>Speech to text on this PC with Whisper (base.en, about 150 MB, downloaded once).</summary>
public sealed class Transcriber
{
    private WhisperFactory? _factory;
    private readonly SemaphoreSlim _gate = new(1, 1);

    public static string ModelPath => Path.Combine(Paths.Local, "models", "ggml-base.en.bin");
    public bool IsReady => _factory != null;

    public async Task PrepareAsync(CancellationToken ct = default)
    {
        await _gate.WaitAsync(ct);
        try
        {
            if (_factory != null) return;
            if (!File.Exists(ModelPath))
            {
                Directory.CreateDirectory(Path.GetDirectoryName(ModelPath)!);
                var partial = ModelPath + ".part";
                await using (var model = await WhisperGgmlDownloader.GetGgmlModelAsync(GgmlType.BaseEn, QuantizationType.NoQuantization, ct))
                await using (var file = File.Create(partial))
                    await model.CopyToAsync(file, ct);
                File.Move(partial, ModelPath, true);
            }
            _factory = WhisperFactory.FromPath(ModelPath);
        }
        finally { _gate.Release(); }
    }

    public async Task<string> TranscribeAsync(byte[] wav, CancellationToken ct = default)
    {
        await PrepareAsync(ct);
        using var processor = _factory!.CreateBuilder().WithLanguage("en").Build();
        using var stream = new MemoryStream(wav);
        var text = new StringBuilder();
        await foreach (var segment in processor.ProcessAsync(stream, ct))
            text.Append(segment.Text);
        var result = text.ToString().Trim();
        // Whisper's way of saying "nothing was said".
        return result is "[BLANK_AUDIO]" or "(silence)" or "[ Silence ]" ? "" : result;
    }
}
