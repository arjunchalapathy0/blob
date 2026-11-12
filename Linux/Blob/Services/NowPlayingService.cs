using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Text.Json;
using System.Threading.Tasks;
using Avalonia.Media.Imaging;
using Avalonia.Threading;

namespace Blob.Services;

/// <summary>
/// Whatever is playing in any app that speaks MPRIS (Spotify, browsers, VLC, most players),
/// read over D-Bus with busctl, which ships with systemd. Without busctl this stays empty.
/// </summary>
public sealed class NowPlayingService
{
    private const string Prefix = "org.mpris.MediaPlayer2.";
    private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromSeconds(8) };

    private readonly string? _busctl = Tools.Find("busctl");
    private string? _player;
    private string _artUrl = "";

    public string Title { get; private set; } = "";
    public string Artist { get; private set; } = "";
    public bool IsPlaying { get; private set; }
    public Bitmap? Artwork { get; private set; }
    public bool HasTrack => Title.Length > 0;
    public bool Available => _busctl != null;

    public event Action? Changed;

    public void Start()
    {
        if (_busctl == null) return;
        _ = Task.Run(async () =>
        {
            while (true)
            {
                try { await Refresh(); } catch { }
                await Task.Delay(IsPlaying ? 1500 : 2500);
            }
        });
    }

    private Task<string?> Bus(params string[] args) =>
        Tools.RunAsync(_busctl!, new[] { "--user", "--json=short" }.Concat(args), 2000);

    private async Task Refresh()
    {
        var namesJson = await Bus("call", "org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "ListNames");
        var players = new List<string>();
        if (namesJson != null)
        {
            using var doc = JsonDocument.Parse(namesJson);
            foreach (var n in doc.RootElement.GetProperty("data")[0].EnumerateArray())
                if (n.GetString() is { } name && name.StartsWith(Prefix)) players.Add(name);
        }

        (string Player, string Title, string Artist, bool Playing, string Art)? best = null;
        // The player we were already showing goes first, so two players don't fight over the notch.
        foreach (var player in players.OrderBy(p => p == _player ? 0 : 1))
        {
            var json = await Bus("call", player, "/org/mpris/MediaPlayer2", "org.freedesktop.DBus.Properties", "GetAll", "s", "org.mpris.MediaPlayer2.Player");
            if (json == null) continue;
            var track = Parse(player, json);
            if (track == null) continue;
            if (track.Value.Playing) { best = track; break; }
            best ??= track;
        }

        var art = best?.Art ?? "";
        Bitmap? bitmap = Artwork;
        if (art != _artUrl)
        {
            bitmap = await LoadArt(art);
            _artUrl = art;
        }
        var title = best?.Title ?? "";
        var artist = best?.Artist ?? "";
        var playing = best?.Playing ?? false;
        if (title == Title && artist == Artist && playing == IsPlaying && ReferenceEquals(bitmap, Artwork) && best?.Player == _player) return;
        Dispatcher.UIThread.Post(() =>
        {
            _player = best?.Player;
            Title = title;
            Artist = artist;
            IsPlaying = playing && title.Length > 0;
            Artwork = bitmap;
            Changed?.Invoke();
        });
    }

    /// <summary>busctl prints GetAll as {"type":"a{sv}","data":[{name:{"type":…,"data":…}}]}.</summary>
    public static (string Player, string Title, string Artist, bool Playing, string Art)? Parse(string player, string json)
    {
        using var doc = JsonDocument.Parse(json);
        var props = doc.RootElement.GetProperty("data")[0];
        var playing = props.TryGetProperty("PlaybackStatus", out var status) && status.GetProperty("data").GetString() == "Playing";
        string title = "", artist = "", art = "";
        if (props.TryGetProperty("Metadata", out var meta) && meta.GetProperty("data") is { ValueKind: JsonValueKind.Object } m)
        {
            if (m.TryGetProperty("xesam:title", out var t) && t.GetProperty("data").ValueKind == JsonValueKind.String) title = t.GetProperty("data").GetString() ?? "";
            if (m.TryGetProperty("xesam:artist", out var a) && a.GetProperty("data").ValueKind == JsonValueKind.Array)
                artist = string.Join(", ", a.GetProperty("data").EnumerateArray().Select(x => x.GetString()).Where(x => !string.IsNullOrEmpty(x)));
            if (m.TryGetProperty("mpris:artUrl", out var u) && u.GetProperty("data").ValueKind == JsonValueKind.String) art = u.GetProperty("data").GetString() ?? "";
        }
        if (title.Length == 0) return null;
        return (player, title, artist, playing, art);
    }

    private static async Task<Bitmap?> LoadArt(string url)
    {
        try
        {
            if (url.StartsWith("file://"))
            {
                var path = Uri.UnescapeDataString(new Uri(url).AbsolutePath);
                return File.Exists(path) ? Decode(await File.ReadAllBytesAsync(path)) : null;
            }
            if (url.StartsWith("https://")) return Decode(await Http.GetByteArrayAsync(url));
        }
        catch { }
        return null;
    }

    private static Bitmap? Decode(byte[] data)
    {
        try
        {
            using var ms = new MemoryStream(data);
            return Bitmap.DecodeToWidth(ms, 224);
        }
        catch { return null; }
    }

    private void Send(string member)
    {
        var player = _player;
        if (_busctl == null || player == null) return;
        _ = Tools.RunAsync(_busctl, new[] { "--user", "call", player, "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player", member }, 2000)
            .ContinueWith(_ => Refresh());
    }

    public void PlayPause() => Send("PlayPause");
    public void Next() => Send("Next");
    public void Previous() => Send("Previous");
}
