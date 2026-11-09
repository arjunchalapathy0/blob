using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json.Nodes;
using System.Windows.Threading;
using Blob.Core;

namespace Blob.Services;

public sealed record ClaudeSession(string Id, string Folder, string State, string Detail, DateTime Updated)
{
    public string Name => string.IsNullOrEmpty(Folder) ? "Claude Code" : Path.GetFileName(Folder.TrimEnd('\\', '/'));
}

/// <summary>Watches ~\.blob\claude\ (written by the hook) and keeps a list of live sessions.</summary>
public sealed class ClaudeStatusService
{
    private readonly Dispatcher _ui;
    private FileSystemWatcher? _watcher;
    private readonly DispatcherTimer _debounce;

    public List<ClaudeSession> Sessions { get; private set; } = new();
    public event Action? Changed;

    public ClaudeStatusService(Dispatcher ui)
    {
        _ui = ui;
        _debounce = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(120) };
        _debounce.Tick += (_, _) => { _debounce.Stop(); Reload(); };
    }

    public void Start()
    {
        Directory.CreateDirectory(Paths.ClaudeStatus);
        _watcher = new FileSystemWatcher(Paths.ClaudeStatus, "*.json")
        {
            NotifyFilter = NotifyFilters.FileName | NotifyFilters.LastWrite | NotifyFilters.Size,
            EnableRaisingEvents = true,
        };
        FileSystemEventHandler poke = (_, _) => _ui.BeginInvoke(() => { _debounce.Stop(); _debounce.Start(); });
        _watcher.Changed += poke;
        _watcher.Created += poke;
        _watcher.Deleted += poke;
        _watcher.Renamed += (_, _) => _ui.BeginInvoke(() => { _debounce.Stop(); _debounce.Start(); });
        // Also catch sessions that went quiet (closed terminals never send SessionEnd).
        var sweep = new DispatcherTimer { Interval = TimeSpan.FromSeconds(30) };
        sweep.Tick += (_, _) => Reload();
        sweep.Start();
        Reload();
    }

    private void Reload()
    {
        var list = new List<ClaudeSession>();
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
        Sessions = list.OrderByDescending(s => s.Updated).ToList();
        Changed?.Invoke();
    }

    public ClaudeSession? Waiting => Sessions.FirstOrDefault(s => s.State == "waiting");
    public ClaudeSession? Working => Sessions.FirstOrDefault(s => s.State == "working");
    public ClaudeSession? JustDone => Sessions.FirstOrDefault(s => s.State == "done" && DateTime.Now - s.Updated < TimeSpan.FromSeconds(8));
}
