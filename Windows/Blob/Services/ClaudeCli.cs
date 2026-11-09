using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.Json.Nodes;
using System.Threading;
using System.Threading.Tasks;
using Blob.Core;

namespace Blob.Services;

public abstract record AgentEvent
{
    public sealed record Reset : AgentEvent;
    public sealed record Text(string Value) : AgentEvent;
    public sealed record Final(string Value) : AgentEvent;
    public sealed record Failure(string Message) : AgentEvent;
    public sealed record Step(string Label) : AgentEvent;
    public sealed record Session(string Id) : AgentEvent;
}

/// <summary>
/// Runs Claude Code (the user's own subscription, no API key) as Blob's hands, and turns its
/// stream-json output into steps and a short reply. Same flags as the Mac app.
/// </summary>
public static class ClaudeCli
{
    /// <summary>How to start Claude Code: the native claude.exe, or node + the npm package's cli.js.</summary>
    public sealed record Launcher(string File, string[] Prefix);

    public static Launcher? Locate()
    {
        var path = Environment.GetEnvironmentVariable("PATH")?.Split(';') ?? Array.Empty<string>();
        var dirs = new List<string>
        {
            Path.Combine(Paths.Home, ".local", "bin"),
            Path.Combine(Paths.Home, ".claude", "local"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "npm"),
        };
        dirs.AddRange(path);
        foreach (var d in dirs.Where(d => !string.IsNullOrWhiteSpace(d)))
        {
            var exe = Path.Combine(d.Trim(), "claude.exe");
            if (File.Exists(exe)) return new Launcher(exe, Array.Empty<string>());
        }
        // npm install -g @anthropic-ai/claude-code: run its cli.js with node directly
        // (going through claude.cmd would mangle the JSON arguments).
        var npm = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "npm",
            "node_modules", "@anthropic-ai", "claude-code", "cli.js");
        if (File.Exists(npm))
        {
            foreach (var d in path.Where(d => !string.IsNullOrWhiteSpace(d)))
            {
                var node = Path.Combine(d.Trim(), "node.exe");
                if (File.Exists(node)) return new Launcher(node, new[] { npm });
            }
            var pf = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "nodejs", "node.exe");
            if (File.Exists(pf)) return new Launcher(pf, new[] { npm });
        }
        return null;
    }

    private const string AgentPrompt =
        "You are Blob, the user's assistant living at the top of their Windows PC's screen. They speak or type short " +
        "requests (often transcribed speech, so expect small transcription errors) and you carry them out on this PC.\n\n" +
        "How to act on the PC:\n" +
        "- Run PowerShell with `powershell -NoProfile -Command \"...\"`. `Start-Process 'app or URL or file'` opens " +
        "things; `Start-Process 'spotify:'`, `Start-Process 'ms-settings:'` and other URI schemes open apps.\n" +
        "- To control apps, use PowerShell with COM objects (e.g. Shell.Application, WScript.Shell SendKeys) or " +
        "UI Automation via System.Windows.Automation.\n" +
        "- To see the screen, run: powershell -NoProfile -Command \"Add-Type -AssemblyName System.Windows.Forms,System.Drawing; " +
        "$b=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds; $i=New-Object System.Drawing.Bitmap $b.Width,$b.Height; " +
        "$g=[System.Drawing.Graphics]::FromImage($i); $g.CopyFromScreen($b.Location,[System.Drawing.Point]::Empty,$b.Size); " +
        "$i.Save(\\\"$env:TEMP\\blob-screen.png\\\")\" and then Read %TEMP%\\blob-screen.png.\n\n" +
        "Rules:\n" +
        "- Act directly and quickly; don't ask clarifying questions unless the request is truly ambiguous.\n" +
        "- Before anything destructive or hard to undo (deleting or overwriting files, emptying the Recycle Bin, " +
        "closing apps with unsaved work), anything sent to other people (messages, emails, posts), purchases, or " +
        "changing security/privacy settings: do NOT do it. Say exactly what you would do and ask the user to " +
        "confirm; their next request continues this conversation.\n" +
        "- Never run as administrator, and never touch passwords or credentials.\n" +
        "- When finished, reply in one or two short plain sentences saying what you did or found. The reply is " +
        "shown in a tiny notch: no Markdown headings, no lists unless asked.";

    public static Task Agent(Launcher cli, string request, string? resume, Action<AgentEvent> onEvent, CancellationToken ct)
    {
        var args = new List<string>
        {
            "-p", request,
            "--allowedTools", "Bash,PowerShell,Read,Write,Edit,Glob,Grep,WebFetch,WebSearch",
            "--disallowedTools", "Bash(rm -rf:*),Bash(rm -fr:*),Bash(format:*),Bash(diskpart:*)",
            "--permission-mode", "acceptEdits",
            "--max-turns", "40",
            "--append-system-prompt", AgentPrompt,
        };
        if (resume != null) { args.Add("--resume"); args.Add(resume); }
        return Run(cli, args, request, onEvent, ct);
    }

    private static async Task Run(Launcher cli, List<string> arguments, string label, Action<AgentEvent> onEvent, CancellationToken ct)
    {
        var psi = new ProcessStartInfo(cli.File)
        {
            WorkingDirectory = Paths.Home,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            RedirectStandardInput = true,
            CreateNoWindow = true,
            StandardOutputEncoding = Encoding.UTF8,
            StandardErrorEncoding = Encoding.UTF8,
        };
        foreach (var a in cli.Prefix) psi.ArgumentList.Add(a);
        foreach (var a in arguments) psi.ArgumentList.Add(a);
        foreach (var a in new[] { "--output-format", "stream-json", "--verbose", "--include-partial-messages",
                                  "--settings", "{\"disableAllHooks\": true}" })
            psi.ArgumentList.Add(a);
        psi.Environment["BLOB_ASK"] = "1";

        var log = new StringBuilder($"{DateTime.Now} request: {label}\n");
        using var p = Process.Start(psi) ?? throw new InvalidOperationException("Couldn't start Claude Code.");
        p.StandardInput.Close();
        var stderrTask = p.StandardError.ReadToEndAsync();
        using var reg = ct.Register(() => { try { p.Kill(true); } catch { } });
        var gotResult = false;
        var sentSession = false;
        string? line;
        while ((line = await p.StandardOutput.ReadLineAsync()) != null)
        {
            log.AppendLine(line);
            foreach (var ev in Parse(line))
            {
                if (ev is AgentEvent.Final or AgentEvent.Failure) gotResult = true;
                if (ev is AgentEvent.Session) { if (sentSession) continue; sentSession = true; }
                onEvent(ev);
            }
        }
        await p.WaitForExitAsync(CancellationToken.None);
        ct.ThrowIfCancellationRequested();
        var stderr = await stderrTask;
        log.AppendLine($"exit {p.ExitCode}\n{stderr}");
        try { File.WriteAllText(Path.Combine(Paths.Local, "ask.log"), log.ToString()); } catch { }
        if (!gotResult)
        {
            var useful = string.Join("\n", stderr.Split('\n').Where(l => !l.Contains("hook")));
            onEvent(new AgentEvent.Failure(Friendly(string.IsNullOrWhiteSpace(useful)
                ? $"Claude Code exited without an answer (code {p.ExitCode})." : useful)));
        }
    }

    private static IEnumerable<AgentEvent> Parse(string line)
    {
        JsonObject? o;
        try { o = JsonNode.Parse(line) as JsonObject; } catch { yield break; }
        if (o == null) yield break;
        if ((string?)o["session_id"] is { Length: > 0 } session) yield return new AgentEvent.Session(session);
        switch ((string?)o["type"])
        {
            case "stream_event":
                var ev = o["event"] as JsonObject;
                switch ((string?)ev?["type"])
                {
                    case "message_start": yield return new AgentEvent.Reset(); break;
                    case "content_block_delta":
                        if ((string?)ev?["delta"]?["type"] == "text_delta" && (string?)ev?["delta"]?["text"] is { } t)
                            yield return new AgentEvent.Text(t);
                        break;
                }
                break;
            case "assistant":
                if (o["message"]?["content"] is JsonArray content)
                    foreach (var block in content)
                        if ((string?)block?["type"] == "tool_use")
                            yield return new AgentEvent.Step(StepLabel((string?)block?["name"] ?? "", block?["input"] as JsonObject));
                break;
            case "result":
                var result = (string?)o["result"] ?? "";
                if ((bool?)o["is_error"] == true)
                    yield return new AgentEvent.Failure(Friendly(result.Length == 0 ? (string?)o["subtype"] ?? "" : result));
                else if (result.Length > 0)
                    yield return new AgentEvent.Final(result);
                break;
        }
    }

    public static string StepLabel(string tool, JsonObject? input)
    {
        string File(string key = "file_path") => ((string?)input?[key])?.Replace('/', '\\').Split('\\').LastOrDefault() ?? "a file";
        switch (tool)
        {
            case "Bash":
            case "PowerShell":
                var command = ((string?)input?["command"] ?? "").Trim();
                if (command.Contains("CopyFromScreen")) return "Looking at your screen";
                if ((string?)input?["description"] is { Length: > 0 } d) return d;
                if (command.Contains("Start-Process", StringComparison.OrdinalIgnoreCase)) return "Opening something";
                return "Running a command";
            case "Read":
                return ((string?)input?["file_path"] ?? "").Contains("blob-screen") ? "Looking at your screen" : $"Reading {File()}";
            case "Write": case "Edit": case "MultiEdit": return $"Editing {File()}";
            case "Glob": case "Grep": return "Searching files";
            case "WebSearch": return "Searching the web";
            case "WebFetch": return "Reading a web page";
            default: return tool;
        }
    }

    private static string Friendly(string message)
    {
        var lower = message.ToLowerInvariant();
        if (lower.Contains("login") || lower.Contains("api key") || lower.Contains("authenticat"))
            return "Claude Code isn’t signed in. Run claude in a terminal and type /login.";
        if (lower.Contains("git-bash") || lower.Contains("git bash"))
            return "Claude Code needs Git for Windows. Install it from git-scm.com, then try again.";
        if (lower.Contains("error_max_turns")) return "That took too many steps, so I stopped.";
        if (lower.Contains("limit")) return "You’ve hit your Claude usage limit for now.";
        var trimmed = message.Trim();
        return trimmed.Length == 0 ? "Claude Code stopped unexpectedly." : trimmed[..Math.Min(200, trimmed.Length)];
    }
}
