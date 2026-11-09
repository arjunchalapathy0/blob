using System;
using System.IO;
using System.Threading.Tasks;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using Windows.Media.Control;

namespace Blob.Services;

/// <summary>
/// Whatever Windows says is playing (Spotify, a browser tab, Media Player…), through the same
/// system media controls the volume flyout uses.
/// </summary>
public sealed class NowPlayingService
{
    private readonly Dispatcher _ui;
    private GlobalSystemMediaTransportControlsSessionManager? _manager;
    private GlobalSystemMediaTransportControlsSession? _session;

    public string Title { get; private set; } = "";
    public string Artist { get; private set; } = "";
    public bool IsPlaying { get; private set; }
    public BitmapImage? Artwork { get; private set; }
    public bool HasTrack => !string.IsNullOrEmpty(Title);

    public event Action? Changed;

    public NowPlayingService(Dispatcher ui) => _ui = ui;

    public async Task StartAsync()
    {
        try
        {
            _manager = await GlobalSystemMediaTransportControlsSessionManager.RequestAsync();
            _manager.CurrentSessionChanged += (_, _) => Attach();
            Attach();
        }
        catch
        {
            // Media controls unavailable (e.g. N editions without the Media Feature Pack).
        }
    }

    private void Attach()
    {
        if (_session != null)
        {
            _session.MediaPropertiesChanged -= OnProps;
            _session.PlaybackInfoChanged -= OnPlayback;
        }
        _session = _manager?.GetCurrentSession();
        if (_session != null)
        {
            _session.MediaPropertiesChanged += OnProps;
            _session.PlaybackInfoChanged += OnPlayback;
        }
        _ = Refresh();
    }

    private void OnProps(GlobalSystemMediaTransportControlsSession s, MediaPropertiesChangedEventArgs e) => _ = Refresh();
    private void OnPlayback(GlobalSystemMediaTransportControlsSession s, PlaybackInfoChangedEventArgs e) => _ = Refresh();

    private async Task Refresh()
    {
        var session = _session;
        string title = "", artist = "";
        var playing = false;
        byte[]? art = null;
        if (session != null)
        {
            try
            {
                var props = await session.TryGetMediaPropertiesAsync();
                title = props?.Title ?? "";
                artist = props?.Artist ?? "";
                playing = session.GetPlaybackInfo()?.PlaybackStatus == GlobalSystemMediaTransportControlsSessionPlaybackStatus.Playing;
                if (props?.Thumbnail != null)
                {
                    using var stream = await props.Thumbnail.OpenReadAsync();
                    using var net = stream.AsStreamForRead();
                    using var ms = new MemoryStream();
                    await net.CopyToAsync(ms);
                    art = ms.ToArray();
                }
            }
            catch { }
        }
        await _ui.InvokeAsync(() =>
        {
            Title = title;
            Artist = artist;
            IsPlaying = playing && title.Length > 0;
            Artwork = art is { Length: > 0 } ? Decode(art) : null;
            Changed?.Invoke();
        });
    }

    private static BitmapImage? Decode(byte[] data)
    {
        try
        {
            var img = new BitmapImage();
            img.BeginInit();
            img.CacheOption = BitmapCacheOption.OnLoad;
            img.DecodePixelWidth = 160;
            img.StreamSource = new MemoryStream(data);
            img.EndInit();
            img.Freeze();
            return img;
        }
        catch { return null; }
    }

    public void PlayPause() => _ = _session?.TryTogglePlayPauseAsync();
    public void Next() => _ = _session?.TrySkipNextAsync();
    public void Previous() => _ = _session?.TrySkipPreviousAsync();
}
