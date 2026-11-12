using System;
using System.Collections.ObjectModel;
using System.Linq;
using System.Threading.Tasks;
using Avalonia.Controls;
using Avalonia.Input.Platform;
using Avalonia.Threading;
using Blob.Core;

namespace Blob.Services;

public sealed class ClipItem
{
    public required string Text { get; init; }
    public DateTime When { get; init; } = DateTime.Now;
    public bool Pinned { get; set; }
}

/// <summary>
/// Recent text copies, kept in memory only. Anything a password manager marks as secret
/// (the "x-kde-passwordManagerHint" format KeePassXC, Bitwarden and others set) is skipped.
/// On Wayland an app only sees the clipboard while it has focus, so history there is patchy.
/// </summary>
public sealed class ClipboardService
{
    private readonly DispatcherTimer _poll = new() { Interval = TimeSpan.FromMilliseconds(1200) };
    private IClipboard? _clipboard;
    private string _last = "";
    private bool _busy;

    public ObservableCollection<ClipItem> Items { get; } = new();
    public event Action? Copied;

    public void Start(TopLevel owner)
    {
        _clipboard = owner.Clipboard;
        _poll.Tick += async (_, _) => await Check();
        Apply();
        Prefs.Changed += Apply;
    }

    private void Apply()
    {
        if (Prefs.Current.ClipboardHistory) _poll.Start(); else _poll.Stop();
    }

    private async Task Check()
    {
        if (_busy || _clipboard == null) return;
        _busy = true;
        try
        {
            // The older calls are used on purpose: the newer TryGetTextAsync doesn't read text from
            // apps that only offer UTF8_STRING (checked against xclip), and these do.
#pragma warning disable CS0618
            var text = await _clipboard.GetTextAsync();
            if (string.IsNullOrWhiteSpace(text) || text == _last) return;
            _last = text;
            var formats = await _clipboard.GetFormatsAsync();
#pragma warning restore CS0618
            if (formats != null && formats.Any(f => f.Contains("passwordManagerHint", StringComparison.OrdinalIgnoreCase))) return;
            if (text.Length > 20_000) return;
            var existing = Items.FirstOrDefault(i => i.Text == text);
            if (existing != null) Items.Remove(existing);
            Items.Insert(PinnedCount(), new ClipItem { Text = text, Pinned = existing?.Pinned ?? false });
            while (Items.Count > 40)
            {
                var last = Items.LastOrDefault(i => !i.Pinned);
                if (last == null) break;
                Items.Remove(last);
            }
            if (existing == null) Copied?.Invoke();
        }
        catch (Exception e) { if (Environment.GetEnvironmentVariable("BLOB_DEBUG") != null) Console.Error.WriteLine("clipboard: " + e); }
        finally { _busy = false; }
    }

    private int PinnedCount() => Items.Count(i => i.Pinned);

    public async void CopyAgain(ClipItem item)
    {
        if (_clipboard == null) return;
        _last = item.Text;
        try { await _clipboard.SetTextAsync(item.Text); } catch { }
    }

    public void TogglePin(ClipItem item)
    {
        item.Pinned = !item.Pinned;
        Items.Remove(item);
        Items.Insert(item.Pinned ? 0 : PinnedCount(), item);
    }

    public void Clear()
    {
        foreach (var i in Items.Where(i => !i.Pinned).ToList()) Items.Remove(i);
    }
}
