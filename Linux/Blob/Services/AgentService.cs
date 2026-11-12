using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Avalonia.Threading;
using Blob.Core;

namespace Blob.Services;

/// <summary>
/// Blob's hands: hold the talk key, speak, let go. Whisper transcribes on this computer and
/// Claude Code (the user's own subscription) carries the request out. Typed requests take the same path.
/// </summary>
public sealed class AgentService
{
    public enum Phase { Idle, Listening, Transcribing, Working, Done, Failed }

    private readonly NoticeCenter _notices;
    private readonly VoiceKey _key = new();
    private readonly VoiceRecorder _recorder = new();
    private readonly DispatcherTimer _levelTimer;
    private CancellationTokenSource? _run;
    private string? _sessionId;
    private DateTime? _lastFinished;

    public Transcriber Transcriber { get; } = new();
    public Phase State { get; private set; } = Phase.Idle;
    public float Level { get; private set; }
    public string Request { get; private set; } = "";
    public string Reply { get; private set; } = "";
    public List<string> Steps { get; } = new();
    public string? Error { get; private set; }
    public string WhisperStatus { get; private set; } = "Downloads on first use (about 150 MB)";

    public event Action? Changed;

    public AgentService(NoticeCenter notices)
    {
        _notices = notices;
        _key.Began += BeginListening;
        _key.Ended += EndListening;
        _key.Cancelled += CancelListening;
        _levelTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(50) };
        _levelTimer.Tick += (_, _) => { Level = _recorder.Level; Changed?.Invoke(); };
    }

    public bool IsBusy => State is Phase.Listening or Phase.Transcribing or Phase.Working;
    public string CurrentStep => Steps.Count > 0 ? Steps[^1] : State == Phase.Working ? "Thinking" : "";
    public bool ClaudeInstalled => ClaudeCli.Locate() != null;

    public void Start()
    {
        ApplyPrefs();
        Prefs.Changed += ApplyPrefs;
        // Get Whisper ready in the background so the first request is quick (only once it's been downloaded).
        _ = Task.Run(async () =>
        {
            await Task.Delay(6000);
            if (System.IO.File.Exists(Transcriber.ModelPath)) await WarmUpAsync();
        });
    }

    private void ApplyPrefs()
    {
        if (Prefs.Current.VoiceKey) _key.Start(); else _key.Stop();
    }

    public async Task WarmUpAsync()
    {
        if (Transcriber.IsReady) { SetWhisper("Ready"); return; }
        SetWhisper(System.IO.File.Exists(Transcriber.ModelPath) ? "Loading Whisper…" : "Downloading Whisper…");
        try
        {
            await Transcriber.PrepareAsync();
            SetWhisper("Ready");
        }
        catch (Exception e)
        {
            SetWhisper($"Couldn’t load Whisper: {e.Message}");
        }
    }

    private void SetWhisper(string s) => Dispatcher.UIThread.Post(() => { WhisperStatus = s; Changed?.Invoke(); });

    // Voice

    /// <summary>One press starts listening, the next one stops (for a keyboard shortcut bound to `blob --toggle-talk`).</summary>
    public void ToggleListening()
    {
        if (State == Phase.Listening) EndListening();
        else BeginListening();
    }

    public void BeginListening()
    {
        if (IsBusy) return;
        if (!VoiceRecorder.HasRecorder)
        {
            _notices.Show("mic", "No recorder found", 2.5);
            return;
        }
        if (!ClaudeInstalled)
        {
            _notices.Show("warn", "Install Claude Code", 2.5);
            return;
        }
        try { _recorder.Start(); }
        catch (Exception e) { Fail($"Microphone: {e.Message}"); return; }
        State = Phase.Listening;
        _levelTimer.Start();
        Changed?.Invoke();
    }

    public async void EndListening()
    {
        _levelTimer.Stop();
        Level = 0;
        if (State != Phase.Listening) return;
        State = Phase.Transcribing;
        Changed?.Invoke();
        var recording = await _recorder.StopAsync();
        if (recording is not { } r || r.Duration < TimeSpan.FromSeconds(0.4) || r.Wav.Length < 44 + 3200)
        {
            State = Phase.Idle;
            Changed?.Invoke();
            return;
        }
        _ = Task.Run(async () =>
        {
            try
            {
                if (!Transcriber.IsReady) SetWhisper(System.IO.File.Exists(Transcriber.ModelPath) ? "Loading Whisper…" : "Downloading Whisper…");
                var text = await Transcriber.TranscribeAsync(r.Wav);
                SetWhisper("Ready");
                Dispatcher.UIThread.Post(() =>
                {
                    if (string.IsNullOrWhiteSpace(text))
                    {
                        State = Phase.Idle;
                        Changed?.Invoke();
                        _notices.Show("ear", "Didn’t catch that", 1.8);
                    }
                    else Run(text);
                });
            }
            catch (Exception e)
            {
                Dispatcher.UIThread.Post(() => Fail($"Couldn’t transcribe: {e.Message}"));
            }
        });
    }

    public void CancelListening()
    {
        _levelTimer.Stop();
        Level = 0;
        _recorder.Cancel();
        if (State == Phase.Listening) { State = Phase.Idle; Changed?.Invoke(); }
    }

    // Agent

    public void Run(string text)
    {
        var cli = ClaudeCli.Locate();
        if (cli == null)
        {
            Request = text;
            Fail("Install Claude Code and sign in to let Blob do things.");
            return;
        }
        _run?.Cancel();
        var cts = _run = new CancellationTokenSource();
        // Follow-ups within 10 minutes continue the same conversation ("yes, do it").
        var resume = _lastFinished is { } f && DateTime.Now - f < TimeSpan.FromMinutes(10) ? _sessionId : null;
        Request = text;
        Reply = "";
        Steps.Clear();
        Error = null;
        State = Phase.Working;
        Changed?.Invoke();

        _ = Task.Run(async () =>
        {
            string? failure = null;
            try
            {
                await ClaudeCli.Agent(cli, text, resume, ev => Dispatcher.UIThread.Post(() =>
                {
                    if (cts.IsCancellationRequested) return;
                    switch (ev)
                    {
                        case AgentEvent.Reset: Reply = ""; break;
                        case AgentEvent.Text t: Reply += t.Value; break;
                        case AgentEvent.Final fin: Reply = fin.Value; break;
                        case AgentEvent.Failure fail: failure = fail.Message; break;
                        case AgentEvent.Step s: if (Steps.Count == 0 || Steps[^1] != s.Label) Steps.Add(s.Label); break;
                        case AgentEvent.Session sid: _sessionId = sid.Id; break;
                    }
                    Changed?.Invoke();
                }), cts.Token);
            }
            catch (OperationCanceledException)
            {
                Dispatcher.UIThread.Post(() => { State = Phase.Idle; Changed?.Invoke(); });
                return;
            }
            catch (Exception e)
            {
                failure = e.Message;
            }
            // Posted after the stream's own posts, so it runs once they have all been applied.
            Dispatcher.UIThread.Post(() =>
            {
                if (cts.IsCancellationRequested) return;
                _lastFinished = DateTime.Now;
                if (failure != null && Reply.Length == 0) Fail(failure);
                else
                {
                    State = Phase.Done;
                    Changed?.Invoke();
                    _notices.Show("check", Headline(Reply), 4);
                }
            });
        });
    }

    public void Cancel()
    {
        _run?.Cancel();
        _run = null;
        if (State == Phase.Working) { State = Phase.Idle; Changed?.Invoke(); }
    }

    public void NewConversation()
    {
        _sessionId = null;
        _lastFinished = null;
        Request = Reply = "";
        Steps.Clear();
        Error = null;
        if (!IsBusy) State = Phase.Idle;
        Changed?.Invoke();
    }

    private void Fail(string message)
    {
        Error = message;
        State = Phase.Failed;
        Changed?.Invoke();
        _notices.Show("warn", "Couldn’t do that", 2.5);
    }

    /// <summary>First sentence, short enough for the notch.</summary>
    private static string Headline(string text)
    {
        var flat = text.Replace('\n', ' ').Trim();
        var dot = flat.IndexOf('.');
        var sentence = dot > 0 ? flat[..dot] : flat;
        if (sentence.Length == 0) return "Done";
        return sentence.Length > 28 ? sentence[..27] + "…" : sentence;
    }
}
