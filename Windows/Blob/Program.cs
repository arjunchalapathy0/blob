using System;
using System.Linq;
using Blob.Services;

namespace Blob;

public static class Program
{
    [STAThread]
    public static int Main(string[] args)
    {
        // Claude Code runs `Blob.exe --claude-hook` on every tool call: record the status and
        // leave before any window code loads, so it adds almost no time to Claude's work.
        if (args.Contains(ClaudeHook.Marker))
        {
            ClaudeHook.Run();
            return 0;
        }
        var app = new App();
        app.InitializeComponent();
        return app.Run();
    }
}
