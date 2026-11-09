using System.Windows.Threading;

namespace Blob.Services;

/// <summary>Every long-lived piece of Blob, created once at startup.</summary>
public sealed class Services
{
    public NoticeCenter Notices { get; }
    public NowPlayingService Music { get; }
    public TimerService Timers { get; }
    public ClipboardService Clipboard { get; }
    public ClaudeStatusService Claude { get; }
    public AgentService Agent { get; }
    public LockService Lock { get; }
    public UpdateService Updates { get; }

    public Services(Dispatcher ui)
    {
        Notices = new NoticeCenter();
        Music = new NowPlayingService(ui);
        Timers = new TimerService();
        Clipboard = new ClipboardService();
        Claude = new ClaudeStatusService(ui);
        Agent = new AgentService(ui, Notices);
        Lock = new LockService();
        Updates = new UpdateService(Notices);
    }
}
