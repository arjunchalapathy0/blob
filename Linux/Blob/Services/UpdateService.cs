using System;
using System.Diagnostics;
using System.IO;
using System.Net.Http;
using System.Reflection;
using System.Text.Json;
using System.Threading.Tasks;
using Avalonia.Threading;
using Blob.Core;

namespace Blob.Services;

/// <summary>Checks blobnotch.app/linux/version.json, downloads the new build, swaps the files and relaunches.</summary>
public sealed class UpdateService
{
    public static readonly Uri Feed = new("https://blobnotch.app/linux/version.json");
    private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromMinutes(10) };

    private readonly NoticeCenter _notices;
    private FeedInfo? _latest;

    public string Status { get; private set; } = "Not checked yet";
    public bool IsAvailable { get; private set; }
    public bool IsUpdating { get; private set; }
    public event Action? Changed;
    /// <summary>Raised when the new copy is in place and Blob should quit so it can start.</summary>
    public event Action? RestartRequested;

    public UpdateService(NoticeCenter notices) => _notices = notices;

    private sealed record FeedInfo(string version, int build, string url, string? notes);

    /// <summary>The build number CI stamps into the last part of the version (1.0.0.&lt;build&gt;).</summary>
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
        DispatcherTimer.RunOnce(async () => await CheckAsync(), TimeSpan.FromSeconds(15));
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
            if (IsAvailable && !wasAvailable) _notices.Show("down", "Update ready", 3);
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
        _notices.Show("down", "Updating…", 900);
        try
        {
            var work = Path.Combine(Paths.Cache, "update-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(work);
            var archive = Path.Combine(work, "Blob-Linux.tar.gz");
            await using (var s = await Http.GetStreamAsync(new Uri(Feed, _latest.url)))
            await using (var f = File.Create(archive))
                await s.CopyToAsync(f);
            var tar = Tools.Find("tar") ?? throw new InvalidOperationException("tar isn’t installed.");
            if (await Tools.RunAsync(tar, new[] { "-xzf", archive, "-C", work }, 60_000) == null)
                throw new InvalidDataException("Couldn’t unpack the download.");
            var source = Path.Combine(work, "Blob");
            if (!File.Exists(Path.Combine(source, "Blob"))) throw new InvalidDataException("The download didn’t contain Blob.");

            // A running program's file can be replaced on Linux: write the new one beside it, then rename over it.
            var target = AppContext.BaseDirectory;
            foreach (var file in Directory.GetFiles(source))
            {
                var destination = Path.Combine(target, Path.GetFileName(file));
                var staged = destination + ".new";
                File.Copy(file, staged, true);
                if (OperatingSystem.IsLinux()) File.SetUnixFileMode(staged, File.GetUnixFileMode(file));
                File.Move(staged, destination, true);
            }
            try { Directory.Delete(work, true); } catch { }
            Ipc.Close();
            Process.Start(new ProcessStartInfo(Path.Combine(target, "Blob")) { UseShellExecute = false });
            RestartRequested?.Invoke();
        }
        catch (Exception e)
        {
            IsUpdating = false;
            Status = $"Update failed: {e.Message}";
            _notices.Show("warn", "Update failed", 3);
            Changed?.Invoke();
        }
    }
}
