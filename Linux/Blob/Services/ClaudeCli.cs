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
    /// <summary>How to start Claude Code.</summary>
    public sealed record Launcher(string File, string[] Prefix);

    public static Launcher? Locate()
    {
        // For testing, and for installs in unusual places.
        if (Environment.GetEnvironmentVariable("BLOB_CLAUDE") is { Length: > 0 } custom && File.Exists(custom))
            return new Launcher(custom, Array.Empty<string>());
        return Tools.Find("claude") is { } path ? new Launcher(path, Array.Empty<string>()) : null;
    }

    private const string AgentPrompt =
        "You are Blob, the user's assistant living at the top of their Linux computer's screen. They speak or type short " +
        "requests (often transcribed speech, so expect small transcription errors) and you carry them out on this computer.\n\n" +
        "How to act on the computer:\n" +
        "- Shell commands with Bash. `xdg-open <url|file|folder>` opens things with the default app; `gtk-launch <name>` or " +
        "`gio launch` starts an app from its .desktop file.\n" +
        "- Music and video players: `playerctl` if it is installed, otherwise MPRIS over D-Bus with `busctl --user`.\n" +
        "- Desktop settings: `gsettings` on GNOME, `kwriteconfig6`/`qdbus` on KDE. Check $XDG_CURRENT_DESKTOP first.\n" +
        "- Typing and clicking in apps: `xdotool` on X11, `ydotool` or `wtype` on Wayland, if installed. Check " +
        "$XDG_SESSION_TYPE. If the tool you need is missing, say which one to install instead of guessing.\n" +
        "- To see the screen, save a screenshot to /tmp/blob-screen.png with whichever of these exists " +
        "(`gnome-screenshot -f`, `spectacle -b -n -o`, `grim`, `scrot`, `import -window root`), then Read that file.\n\n" +
        "Rules:\n" +
        "- Act directly and quickly; don't ask clarifying questions unless the request is truly ambiguous.\n" +
        "- Before anything destructive or hard to undo (deleting or overwriting files, emptying the trash, " +
        "closing apps with unsaved work), anything sent to other people (messages, emails, posts), purchases, or " +
        "changing security/privacy settings: do NOT do it. Say exactly what you would do and ask the user to " +
        "confirm; their next request continues this conversation.\n" +
        "- Never use sudo, and never touch passwords or credentials.\n" +
        "- When finished, reply in one or two short plain sentences saying what you did or found. The reply is " +
        "shown in a tiny notch: no Markdown headings, no lists unless asked.";

    /// <summary>What's different on a Chromebook, added to the instructions there.</summary>
    private const string ChromeOSNote =
        "\n\nThis computer is a Chromebook, and you are inside ChromeOS's Linux container. `xdg-open` opens links and files " +
        "in Chrome on the ChromeOS side. You can't control Chrome, ChromeOS settings, Android apps or ChromeOS's own files " +
        "outside the shared Linux folders, and screenshots only show Linux windows. If a request needs any of those, say so " +
        "plainly and suggest how the user can do it themselves.";

    public static Task Agent(Launcher cli, string request, string? resume, Action<AgentEvent> onEvent, CancellationToken ct)
    {
        var args = new List<string>
        {
            "-p", request,
            "--allowedTools", "Bash,Read,Write,Edit,Glob,Grep,WebFetch,WebSearch",
            "--disallowedTools", "Bash(sudo:*),Bash(rm -rf:*),Bash(rm -fr:*),Bash(mkfs:*),Bash(dd:*)",
            "--permission-mode", "acceptEdits",
            "--max-turns", "40",
            "--append-system-prompt", Platform.IsChromeOS ? AgentPrompt + ChromeOSNote : AgentPrompt,
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
        try { File.WriteAllText(Path.Combine(Paths.Cache, "ask.log"), log.ToString()); } catch { }
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
        string File(string key = "file_path") => ((string?)input?[key])?.Split('/').LastOrDefault() ?? "a file";
        switch (tool)
        {
            case "Bash":
                var command = ((string?)input?["command"] ?? "").Trim();
                if (command.Contains("blob-screen")) return "Looking at your screen";
                if ((string?)input?["description"] is { Length: > 0 } d) return d;
                if (command.StartsWith("xdg-open") || command.StartsWith("gtk-launch") || command.StartsWith("gio ")) return "Opening something";
                if (command.StartsWith("playerctl") || command.StartsWith("busctl")) return "Controlling an app";
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
        if (lower.Contains("error_max_turns")) return "That took too many steps, so I stopped.";
        if (lower.Contains("limit")) return "You’ve hit your Claude usage limit for now.";
        var trimmed = message.Trim();
        return trimmed.Length == 0 ? "Claude Code stopped unexpectedly." : trimmed[..Math.Min(200, trimmed.Length)];
    }
}
