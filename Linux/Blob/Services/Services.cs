namespace Blob.Services;

/// <summary>Every long-lived piece of Blob, created once at startup.</summary>
public sealed class Services
{
    public NoticeCenter Notices { get; } = new();
    public NowPlayingService Music { get; } = new();
    public TimerService Timers { get; } = new();
    public ClipboardService Clipboard { get; } = new();
    public ClaudeStatusService Claude { get; } = new();
    public AgentService Agent { get; }
    public UpdateService Updates { get; }

    public Services()
    {
        Agent = new AgentService(Notices);
        Updates = new UpdateService(Notices);
    }
}
