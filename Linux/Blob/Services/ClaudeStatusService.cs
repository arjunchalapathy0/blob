using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json.Nodes;
using Avalonia.Threading;
using Blob.Core;

namespace Blob.Services;

public sealed record ClaudeSession(string Id, string Folder, string State, string Detail, DateTime Updated)
{
    public string Name => string.IsNullOrEmpty(Folder) ? "Claude Code" : Path.GetFileName(Folder.TrimEnd('/'));
}

/// <summary>Watches ~/.blob/claude/ (written by the hook) and keeps a list of live sessions.</summary>
public sealed class ClaudeStatusService
{
    private FileSystemWatcher? _watcher;
    private readonly DispatcherTimer _debounce;

    public List<ClaudeSession> Sessions { get; private set; } = new();
    public event Action? Changed;

    public ClaudeStatusService()
    {
        _debounce = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(120) };
        _debounce.Tick += (_, _) => { _debounce.Stop(); Reload(); };
    }

    public void Start()
    {
        Directory.CreateDirectory(Paths.ClaudeStatus);
        void Poke() => Dispatcher.UIThread.Post(() => { _debounce.Stop(); _debounce.Start(); });
        try
        {
            _watcher = new FileSystemWatcher(Paths.ClaudeStatus, "*.json")
            {
                NotifyFilter = NotifyFilters.FileName | NotifyFilters.LastWrite | NotifyFilters.Size,
                EnableRaisingEvents = true,
            };
            _watcher.Changed += (_, _) => Poke();
            _watcher.Created += (_, _) => Poke();
            _watcher.Deleted += (_, _) => Poke();
            _watcher.Renamed += (_, _) => Poke();
        }
        catch { /* out of inotify watches: the sweep below still picks changes up */ }
        // Also catches sessions that went quiet (closed terminals never send SessionEnd).
        var sweep = new DispatcherTimer { Interval = TimeSpan.FromSeconds(_watcher == null ? 2 : 30) };
        sweep.Tick += (_, _) => Reload();
        sweep.Start();
        Reload();
    }

    private void Reload()
    {
        var list = new List<ClaudeSession>();
        try
        {
            foreach (var file in Directory.EnumerateFiles(Paths.ClaudeStatus, "*.json"))
            {
                try
                {
                    var o = JsonNode.Parse(File.ReadAllText(file));
                    if (o == null) continue;
                    var updated = DateTimeOffset.FromUnixTimeMilliseconds((long)(((double?)o["updated"] ?? 0) * 1000)).LocalDateTime;
                    if (DateTime.Now - updated > TimeSpan.FromHours(6)) { File.Delete(file); continue; }
                    list.Add(new ClaudeSession((string?)o["session_id"] ?? "", (string?)o["cwd"] ?? "",
                        (string?)o["state"] ?? "idle", (string?)o["detail"] ?? "", updated));
                }
                catch { }
            }
        }
        catch { }
        Sessions = list.OrderByDescending(s => s.Updated).ToList();
        Changed?.Invoke();
    }

    public ClaudeSession? Waiting => Sessions.FirstOrDefault(s => s.State == "waiting");
    public ClaudeSession? Working => Sessions.FirstOrDefault(s => s.State == "working");
}
