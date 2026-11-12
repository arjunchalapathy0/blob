using System;
using System.IO;
using System.Net.Sockets;
using System.Text;
using System.Threading.Tasks;
using Avalonia.Threading;
using Blob.Core;

namespace Blob.Services;

/// <summary>
/// One Blob per user. A second `blob` hands its command to the first over a Unix socket and exits,
/// which is also how a keyboard shortcut talks to Blob: `blob --toggle-talk`, `blob --ask "…"`.
/// </summary>
public static class Ipc
{
    /// <summary>Sends a command to a running Blob. False if there isn't one.</summary>
    public static bool TrySend(string command)
    {
        try
        {
            if (!File.Exists(Paths.Socket)) return false;
            using var socket = new Socket(AddressFamily.Unix, SocketType.Stream, ProtocolType.Unspecified);
            socket.Connect(new UnixDomainSocketEndPoint(Paths.Socket));
            socket.Send(Encoding.UTF8.GetBytes(command + "\n"));
            return true;
        }
        catch
        {
            return false;
        }
    }

    /// <summary>Listens for commands; each one is handed to `handle` on the UI thread.</summary>
    public static void Listen(Action<string> handle)
    {
        try
        {
            if (File.Exists(Paths.Socket)) File.Delete(Paths.Socket); // a stale one: nobody answered TrySend
            var server = new Socket(AddressFamily.Unix, SocketType.Stream, ProtocolType.Unspecified);
            server.Bind(new UnixDomainSocketEndPoint(Paths.Socket));
            server.Listen(4);
            _ = Task.Run(async () =>
            {
                while (true)
                {
                    try
                    {
                        using var client = await server.AcceptAsync();
                        using var reader = new StreamReader(new NetworkStream(client), Encoding.UTF8);
                        var line = await reader.ReadLineAsync();
                        if (!string.IsNullOrWhiteSpace(line)) Dispatcher.UIThread.Post(() => handle(line.Trim()));
                    }
                    catch { await Task.Delay(200); }
                }
            });
        }
        catch { /* no socket: Blob still works, just without commands from outside */ }
    }

    public static void Close()
    {
        try { if (File.Exists(Paths.Socket)) File.Delete(Paths.Socket); } catch { }
    }
}
