using System;
using System.Threading.Tasks;
using Blob.Core;
using Windows.Security.Credentials.UI;

namespace Blob.Services;

/// <summary>
/// Windows Hello in front of Clipboard and Ask: face (on PCs with an IR camera), fingerprint or PIN,
/// whichever this PC is set up for. Stays unlocked for five minutes.
/// </summary>
public sealed class LockService
{
    private DateTime _unlockedAt = DateTime.MinValue;
    public string Availability { get; private set; } = "Checking…";
    public bool IsAvailable { get; private set; }

    public bool IsLocked => Prefs.Current.LockWithHello && DateTime.Now - _unlockedAt > TimeSpan.FromMinutes(5);

    public async Task RefreshAsync()
    {
        try
        {
            var a = await UserConsentVerifier.CheckAvailabilityAsync();
            IsAvailable = a == UserConsentVerifierAvailability.Available;
            Availability = a switch
            {
                UserConsentVerifierAvailability.Available => "Windows Hello is ready",
                UserConsentVerifierAvailability.DeviceNotPresent => "No Windows Hello camera or reader",
                UserConsentVerifierAvailability.NotConfiguredForUser => "Set up Windows Hello in Settings → Accounts → Sign-in options",
                UserConsentVerifierAvailability.DisabledByPolicy => "Windows Hello is turned off by policy",
                _ => "Windows Hello is busy",
            };
        }
        catch
        {
            IsAvailable = false;
            Availability = "Windows Hello isn’t available";
        }
    }

    public async Task<bool> UnlockAsync(IntPtr window)
    {
        try
        {
            var result = window != IntPtr.Zero
                ? await UserConsentVerifierInterop.RequestVerificationForWindowAsync(window, "Unlock Blob")
                : await UserConsentVerifier.RequestVerificationAsync("Unlock Blob");
            if (result == UserConsentVerificationResult.Verified)
            {
                _unlockedAt = DateTime.Now;
                return true;
            }
        }
        catch { }
        return false;
    }

    public void Lock() => _unlockedAt = DateTime.MinValue;
}
