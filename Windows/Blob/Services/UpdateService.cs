using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Net.Http;
using System.Reflection;
using System.Text.Json;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Threading;
using Blob.Core;

namespace Blob.Services;

/// <summary>Checks blobnotch.app/windows/version.json, downloads the new zip, swaps the files and relaunches.</summary>
public sealed class UpdateService
{
    public static readonly Uri Feed = new("https://blobnotch.app/windows/version.json");
    private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromMinutes(10) };

    private readonly NoticeCenter _notices;
    private FeedInfo? _latest;

    public string Status { get; private set; } = "Not checked yet";
    public bool IsAvailable { get; private set; }
    public bool IsUpdating { get; private set; }
    public event Action? Changed;

    public UpdateService(NoticeCenter notices) => _notices = notices;

    private sealed record FeedInfo(string version, int build, string url, string? notes);

    /// <summary>The build number CI stamps into the last part of the version (1.1.0.&lt;build&gt;).</summary>
    public static int CurrentBuild => Math.Max(0, Assembly.GetExecutingAssembly().GetName().Version?.Revision ?? 0);

    public static string CurrentVersion
    {
        get
        {
            var v = Assembly.GetExecutingAssembly().GetName().Version;
            return v == null ? "1.0" : $"{v.Major}.{v.Minor}.{v.Build}";
        }
    }

    public void Start()
    {
        var timer = new DispatcherTimer { Interval = TimeSpan.FromHours(6) };
        timer.Tick += async (_, _) => await CheckAsync();
        timer.Start();
        _ = Task.Delay(15000).ContinueWith(_ => Application.Current.Dispatcher.BeginInvoke(async () => await CheckAsync()));
    }

    public async Task CheckAsync()
    {
        if (IsUpdating) return;
        Status = "Checking…";
        Changed?.Invoke();
        try
        {
            var json = await Http.GetStringAsync(new Uri(Feed, "?t=" + DateTime.UtcNow.Ticks));
            _latest = JsonSerializer.Deserialize<FeedInfo>(json);
            var wasAvailable = IsAvailable;
            IsAvailable = _latest != null && _latest.build > CurrentBuild;
            Status = IsAvailable ? $"Blob {_latest!.version} is ready" + (_latest.notes is { Length: > 0 } n ? $": {n}" : "") : "Up to date";
            if (IsAvailable && !wasAvailable) _notices.Show(Glyphs.Download, "Update ready", 3);
        }
        catch
        {
            Status = "Couldn’t reach blobnotch.app";
        }
        Changed?.Invoke();
    }

    public async Task UpdateAsync()
    {
        if (IsUpdating || _latest == null) return;
        IsUpdating = true;
        Status = "Downloading…";
        Changed?.Invoke();
        _notices.Show(Glyphs.Download, "Updating…", 900);
        try
        {
            var work = Path.Combine(Path.GetTempPath(), "blob-update-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(work);
            var zip = Path.Combine(work, "Blob.zip");
            await using (var s = await Http.GetStreamAsync(new Uri(Feed, _latest.url)))
            await using (var f = File.Create(zip))
                await s.CopyToAsync(f);
            var unpacked = Path.Combine(work, "new");
            ZipFile.ExtractToDirectory(zip, unpacked);
            // The zip holds a "Blob" folder (or the files directly).
            var source = File.Exists(Path.Combine(unpacked, "Blob.exe")) ? unpacked : Path.Combine(unpacked, "Blob");
            if (!File.Exists(Path.Combine(source, "Blob.exe"))) throw new InvalidDataException("The download didn’t contain Blob.exe.");

            var target = AppContext.BaseDirectory.TrimEnd('\\');
            var script = Path.Combine(work, "install.cmd");
            File.WriteAllText(script,
                "@echo off\r\n" +
                $":wait\r\ntasklist /FI \"PID eq {Environment.ProcessId}\" | find \"{Environment.ProcessId}\" >nul && (timeout /t 1 /nobreak >nul & goto wait)\r\n" +
                $"robocopy \"{source}\" \"{target}\" /E /R:5 /W:1 /NFL /NDL /NJH /NJS >nul\r\n" +
                $"start \"\" \"{Path.Combine(target, "Blob.exe")}\"\r\n");
            Process.Start(new ProcessStartInfo("cmd.exe", $"/c \"{script}\"") { CreateNoWindow = true, UseShellExecute = false });
            Application.Current.Shutdown();
        }
        catch (Exception e)
        {
            IsUpdating = false;
            Status = $"Update failed: {e.Message}";
            _notices.Show(Glyphs.Warning, "Update failed", 3);
            Changed?.Invoke();
        }
    }
}
