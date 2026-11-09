using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using Blob.Core;

namespace Blob.Services;

/// <summary>
/// Runs when Claude Code calls `Blob.exe --claude-hook`. Reads the hook JSON from stdin and writes
/// one small status file per session to ~\.blob\claude\ (the same format as the Mac app).
/// Never prints and always exits 0, so it can't get in Claude Code's way.
/// </summary>
public static class ClaudeHook
{
    public const string Marker = "--claude-hook";

    public static void Run()
    {
        try { RunInner(); } catch { }
    }

    private static void RunInner()
    {
        if (Environment.GetEnvironmentVariable("BLOB_ASK") != null) return;
        string input;
        using (var stdin = Console.OpenStandardInput())
        using (var reader = new StreamReader(stdin, Encoding.UTF8))
            input = reader.ReadToEnd();
        if (JsonNode.Parse(input) is not JsonObject json) return;
        var sessionId = (string?)json["session_id"];
        if (string.IsNullOrEmpty(sessionId)) return;
        var ev = (string?)json["hook_event_name"] ?? "";
        var safe = new string(sessionId.Where(c => char.IsLetterOrDigit(c) || c is '-' or '_').Take(80).ToArray());
        Directory.CreateDirectory(Paths.ClaudeStatus);
        var file = Path.Combine(Paths.ClaudeStatus, safe + ".json");

        if (ev == "SessionEnd")
        {
            File.Delete(file);
            return;
        }

        string? previous = null;
        try { previous = (string?)JsonNode.Parse(File.ReadAllText(file))?["state"]; } catch { }

        string state, detail;
        switch (ev)
        {
            case "SessionStart": state = "idle"; detail = "Ready"; break;
            case "UserPromptSubmit": state = "working"; detail = "Thinking"; break;
            case "PreToolUse": state = "working"; detail = ToolLabel((string?)json["tool_name"], json["tool_input"] as JsonObject); break;
            case "PostToolUse": state = "working"; detail = "Thinking"; break;
            case "Notification":
                var message = (string?)json["message"] ?? "Needs your input";
                if (previous is "done" or "idle" && message.Contains("waiting for your input", StringComparison.OrdinalIgnoreCase)) return;
                state = "waiting"; detail = message; break;
            case "Stop": state = "done"; detail = "Finished"; break;
            default: return;
        }

        var record = new JsonObject
        {
            ["session_id"] = sessionId,
            ["cwd"] = (string?)json["cwd"] ?? "",
            ["state"] = state,
            ["detail"] = detail,
            ["updated"] = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() / 1000.0,
        };
        var tmp = file + ".tmp";
        File.WriteAllText(tmp, record.ToJsonString());
        File.Move(tmp, file, true);
    }

    private static string ToolLabel(string? tool, JsonObject? input)
    {
        string? FileName() => ((string?)input?["file_path"]) is { } p ? Path.GetFileName(p.Replace('/', '\\')) : null;
        var name = tool ?? "tool";
        return name switch
        {
            "Read" => FileName() is { } f ? $"Reading {f}" : "Reading",
            "Edit" or "MultiEdit" or "Write" => FileName() is { } f ? $"Editing {f}" : "Editing",
            "Bash" or "PowerShell" => "Running a command",
            "Grep" or "Glob" => "Searching",
            "WebFetch" or "WebSearch" => "Browsing",
            "Task" or "Agent" => "Delegating",
            "TodoWrite" => "Planning",
            _ when name.StartsWith("mcp__") => $"Using {name.Split("__").Skip(1).FirstOrDefault() ?? "a tool"}",
            _ => name,
        };
    }
}

/// <summary>Adds or removes Blob's entries in ~\.claude\settings.json, leaving everything else as is.</summary>
public static class ClaudeHookInstaller
{
    private static readonly string[] Events =
        { "SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse", "Notification", "Stop", "SessionEnd" };

    public static string SettingsPath => Path.Combine(Paths.Home, ".claude", "settings.json");

    /// <summary>Forward slashes: Claude Code runs hooks through Git Bash on Windows, which reads them fine.</summary>
    public static string Command => $"\"{Paths.Exe.Replace('\\', '/')}\" {ClaudeHook.Marker}";

    public static bool IsInstalled => Commands().Any(c => c.Contains(ClaudeHook.Marker));
    public static bool NeedsUpdate => IsInstalled && Commands().Where(c => c.Contains(ClaudeHook.Marker)).Any(c => c != Command);

    private static IEnumerable<string> Commands()
    {
        if (Load()["hooks"] is not JsonObject hooks) yield break;
        foreach (var (_, value) in hooks)
            if (value is JsonArray list)
                foreach (var entry in list)
                    if (entry?["hooks"] is JsonArray inner)
                        foreach (var h in inner)
                            if ((string?)h?["command"] is { } c) yield return c;
    }

    public static void Install()
    {
        var root = Load();
        BackupOnce();
        var hooks = Strip(root["hooks"] as JsonObject);
        foreach (var ev in Events)
        {
            var list = hooks[ev] as JsonArray ?? new JsonArray();
            hooks.Remove(ev);
            var entry = new JsonObject
            {
                ["hooks"] = new JsonArray(new JsonObject { ["type"] = "command", ["command"] = Command, ["timeout"] = 5 }),
            };
            if (ev is "PreToolUse" or "PostToolUse") entry["matcher"] = "*";
            list.Add(entry);
            hooks[ev] = list;
        }
        root.Remove("hooks");
        root["hooks"] = hooks;
        Save(root);
    }

    public static void Uninstall()
    {
        var root = Load();
        var hooks = Strip(root["hooks"] as JsonObject);
        root.Remove("hooks");
        if (hooks.Count > 0) root["hooks"] = hooks;
        Save(root);
    }

    private static JsonObject Strip(JsonObject? hooks)
    {
        var output = new JsonObject();
        if (hooks == null) return output;
        foreach (var (ev, value) in hooks)
        {
            if (value is not JsonArray list) { output[ev] = value?.DeepClone(); continue; }
            var cleaned = new JsonArray();
            foreach (var entry in list)
            {
                if (entry is not JsonObject e) continue;
                var inner = new JsonArray();
                foreach (var h in e["hooks"] as JsonArray ?? new JsonArray())
                    if (!(((string?)h?["command"])?.Contains(ClaudeHook.Marker) ?? false)) inner.Add(h?.DeepClone());
                if (inner.Count == 0) continue;
                var copy = (JsonObject)e.DeepClone();
                copy["hooks"] = inner;
                cleaned.Add(copy);
            }
            if (cleaned.Count > 0) output[ev] = cleaned;
        }
        return output;
    }

    private static JsonObject Load()
    {
        try
        {
            if (File.Exists(SettingsPath) && JsonNode.Parse(File.ReadAllText(SettingsPath)) is JsonObject o) return o;
        }
        catch { }
        return new JsonObject();
    }

    private static void Save(JsonObject root)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(SettingsPath)!);
        File.WriteAllText(SettingsPath, root.ToJsonString(new JsonSerializerOptions { WriteIndented = true }));
    }

    private static void BackupOnce()
    {
        var backup = SettingsPath + ".blob-backup";
        if (File.Exists(SettingsPath) && !File.Exists(backup)) File.Copy(SettingsPath, backup);
    }
}
