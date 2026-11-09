using System;
using System.Collections.ObjectModel;
using System.Linq;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;

namespace Blob.Services;

public sealed class ClipItem
{
    public required string Text { get; init; }
    public DateTime When { get; init; } = DateTime.Now;
    public bool Pinned { get; set; }
}

/// <summary>
/// Recent text copies. Anything a password manager marks as private (the standard
/// "ExcludeClipboardContentFromMonitorProcessing" / "Clipboard Viewer Ignore" formats, or
/// "CanIncludeInClipboardHistory" = 0) is skipped. Kept in memory only.
/// </summary>
public sealed class ClipboardService
{
    private const int WM_CLIPBOARDUPDATE = 0x031D;
    private HwndSource? _source;
    private bool _ignoreNext;

    public ObservableCollection<ClipItem> Items { get; } = new();
    public event Action? Copied;

    public void Start(Window owner)
    {
        var handle = new WindowInteropHelper(owner).EnsureHandle();
        _source = HwndSource.FromHwnd(handle);
        _source?.AddHook(Hook);
        AddClipboardFormatListener(handle);
    }

    private IntPtr Hook(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        if (msg == WM_CLIPBOARDUPDATE) OnUpdate();
        return IntPtr.Zero;
    }

    private void OnUpdate()
    {
        if (_ignoreNext) { _ignoreNext = false; return; }
        try
        {
            var data = Clipboard.GetDataObject();
            if (data == null || IsPrivate(data) || !data.GetDataPresent(DataFormats.UnicodeText)) return;
            var text = data.GetData(DataFormats.UnicodeText) as string;
            if (string.IsNullOrWhiteSpace(text)) return;
            var existing = Items.FirstOrDefault(i => i.Text == text);
            if (existing != null) Items.Remove(existing);
            Items.Insert(PinnedCount(), new ClipItem { Text = text, Pinned = existing?.Pinned ?? false });
            while (Items.Count > 40)
            {
                var last = Items.LastOrDefault(i => !i.Pinned);
                if (last == null) break;
                Items.Remove(last);
            }
            Copied?.Invoke();
        }
        catch (COMException) { /* someone else has the clipboard open; try next time */ }
        catch (ExternalException) { }
    }

    private int PinnedCount() => Items.Count(i => i.Pinned);

    private static bool IsPrivate(IDataObject data)
    {
        if (data.GetDataPresent("ExcludeClipboardContentFromMonitorProcessing")) return true;
        if (data.GetDataPresent("Clipboard Viewer Ignore")) return true;
        if (data.GetDataPresent("CanIncludeInClipboardHistory") &&
            data.GetData("CanIncludeInClipboardHistory") is System.IO.MemoryStream ms &&
            ms.Length >= 4 && BitConverter.ToInt32(ms.ToArray(), 0) == 0) return true;
        return false;
    }

    public void CopyAgain(ClipItem item)
    {
        _ignoreNext = false;
        try { Clipboard.SetText(item.Text); } catch { }
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

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool AddClipboardFormatListener(IntPtr hwnd);
}
