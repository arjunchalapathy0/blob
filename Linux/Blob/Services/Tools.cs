using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Threading.Tasks;
using Blob.Core;

namespace Blob.Services;

/// <summary>Finding and running the command-line tools Blob leans on (claude, parecord, busctl…).</summary>
public static class Tools
{
    /// <summary>Folders searched for programs: PATH, plus the places per-user installs usually go.</summary>
    public static IEnumerable<string> SearchDirectories()
    {
        var seen = new HashSet<string>();
        var extra = new[]
        {
            Path.Combine(Paths.Home, ".local", "bin"),
            Path.Combine(Paths.Home, ".claude", "local"),
            Path.Combine(Paths.Home, ".npm-global", "bin"),
            Path.Combine(Paths.Home, "bin"),
            "/usr/local/bin", "/usr/bin", "/bin",
        };
        var path = (Environment.GetEnvironmentVariable("PATH") ?? "").Split(':', StringSplitOptions.RemoveEmptyEntries);
        foreach (var d in path)
            if (seen.Add(d)) yield return d;
        foreach (var d in extra)
            if (seen.Add(d)) yield return d;
    }

    public static string? Find(string name)
    {
        foreach (var dir in SearchDirectories())
        {
            var candidate = Path.Combine(dir, name);
            if (File.Exists(candidate)) return candidate;
        }
        return null;
    }

    /// <summary>Runs a program and returns what it printed, or null if it failed or took too long.</summary>
    public static async Task<string?> RunAsync(string file, IEnumerable<string> args, int timeoutMs = 3000)
    {
        try
        {
            var psi = new ProcessStartInfo(file) { UseShellExecute = false, RedirectStandardOutput = true, RedirectStandardError = true };
            foreach (var a in args) psi.ArgumentList.Add(a);
            using var p = Process.Start(psi);
            if (p == null) return null;
            var output = p.StandardOutput.ReadToEndAsync();
            var errors = p.StandardError.ReadToEndAsync();
            var exited = p.WaitForExitAsync();
            if (await Task.WhenAny(exited, Task.Delay(timeoutMs)) != exited)
            {
                try { p.Kill(true); } catch { }
                return null;
            }
            await errors;
            return p.ExitCode == 0 ? await output : null;
        }
        catch { return null; }
    }

    /// <summary>Opens a link, file or folder with the desktop's default app.</summary>
    public static void Open(string target)
    {
        try
        {
            var psi = new ProcessStartInfo(Find("xdg-open") ?? "xdg-open") { UseShellExecute = false, RedirectStandardError = true, RedirectStandardOutput = true };
            psi.ArgumentList.Add(target);
            Process.Start(psi);
        }
        catch { }
    }
}
