# Videos won't play in Firefox after the laptop wakes from low-battery sleep

**Status: Nothing applied.** This was a one-off recovery on 2026-10-06; no config
was changed. Restarting PipeWire fixed it. Kept because the symptom points at
Firefox, and Firefox isn't the cause. The speaker output is frozen and nothing
logs an error.

## Symptom

After the battery ran down to ~2% and the laptop woke up again, **no video
would play in Firefox**: it just sat there and never started. **Restarting Firefox
did not help.** The rest of the desktop worked normally. A similar episode before
this one felt "related to audio somehow".

## Cause

### The low-battery hybrid-sleep

At `PercentageAction=2.0` UPower runs its `CriticalPowerAction`, which is
`HybridSleep` here (writes a hibernate image, then suspends to RAM).
`/etc/UPower/UPower.conf` is the **stock package file** (`dpkg --verify upower`
is clean), so this is Ubuntu's default behaviour, not something set in this repo.

```
17:17:39 systemd-logind: The system will hybrid sleep now!
17:17:39 kernel: PM: hibernation: hibernation entry
17:18:04 kernel: PM: hibernation: Wrote 10364332 kbytes in 12.66 seconds (818.66 MB/s)
17:18:04 systemd-sleep: System returned from sleep operation 'hybrid-sleep'.
```

It woke up ~25s later. What woke it is not established.

### The speaker PCM came back "running" but frozen

ALSA reported the speaker stream (`card0/pcm2p`, id `Speaker`) as `RUNNING`, but
its hardware pointer **did not move**. It was the same value one second later:

```
$ grep -E 'state|hw_ptr|trigger_time' /proc/asound/card0/pcm2p/sub0/status
state: RUNNING
trigger_time: 26679.602026234
hw_ptr      : 768            # still 768 a second later
appl_ptr    : 6528
```

`trigger_time` is seconds of monotonic clock since boot (09:53:20), which
works out to **~17:18, the moment of resume**. The stream had been stuck from
the resume until it was noticed ~20 minutes later.

`pw-top` showed the same thing from PipeWire's side. The Speaker sink and
both Firefox streams were in state `R` (running) but with **QUANT 0, RATE 0**
and zero busy time, meaning the graph's driver never ticks:

```
S   ID  QUANT   RATE    WAIT    BUSY   ...  NAME
R   55      0      0   0.0us   0.0us   ...  alsa_output...sof_sdw.HiFi__Speaker__sink
R  134      0      0   0.0us   0.0us   ...  Firefox
R  135      0      0   0.0us   0.0us   ...  Firefox
```

**Gotcha:** `wpctl status` looked completely healthy. Firefox's streams were
linked to `Speaker:playback_FL/FR` and marked `[active]`. The routing was
right; the device at the end of it just never consumed anything.

### Why that stops *video*

When a video has an audio track, Firefox uses the audio output as its
playback clock. If the sink never consumes samples, the clock never advances,
so the video never gets past its first frame. That's known Firefox
behaviour and was **not traced in Firefox's code here**. The fix below
proves the link: restarting only the audio stack made video play again.

It also explains why restarting Firefox did nothing. The new Firefox opened new
streams into the same frozen sink. Spotify (paused at the time) would have hung
the same way.

## The fix

Run in your own terminal. Audio drops out for about a second:

```bash
systemctl --user restart pipewire pipewire-pulse wireplumber
```

Then reload the video tab. Restarting closes the stuck PCM; when PipeWire
reopens it, the driver sets it up from scratch. That the reopen is what clears
it is the natural explanation, not something traced.

If it is **still** frozen after the restart, the sound hardware itself is
wedged, and a reboot is the clean fix.

### Verified end state (2026-10-06, after the restart)

The user confirmed videos play again. With a few seconds of digital silence
playing (`pw-play` of a zero-filled WAV, so nothing audible):

```
$ grep hw_ptr /proc/asound/card0/pcm2p/sub0/status    # one second apart
hw_ptr      : 804720
hw_ptr      : 853056      # +48336 frames/s ≈ 48 kHz, advancing

$ pw-top -b -n 2 | grep Speaker
R   59   2048  48000  84.3us  22.1us  ...  alsa_output...sof_sdw.HiFi__Speaker__sink
```

QUANT 2048 / RATE 48000 with real busy time, versus 0 / 0 before.

## How to tell it's this again (10 seconds)

1. **Something must be playing.** With nothing playing, every PCM status file
   just says `closed` and the sink is `S` (suspended) in `pw-top`. That is
   normal and tells you nothing.
2. With a video or song "playing", run this twice, a second apart:
   ```bash
   grep -H -E 'state|hw_ptr' /proc/asound/card0/pcm*p/sub0/status | grep -v closed
   ```
   `RUNNING` with an **unchanging** `hw_ptr` = this problem.
3. Or: `pw-top -b -n 2`. A sink in state **`R` with QUANT 0 / RATE 0** = this
   problem. (`S` with 0 / 0 is just an idle, suspended sink.)

## Verified vs. not established

**Verified:**
- The low-battery hybrid-sleep at 17:17:39 and the resume at 17:18:04.
- The speaker PCM was `RUNNING` with a frozen `hw_ptr`, triggered at resume.
- PipeWire's graph was stalled (QUANT/RATE 0 on a running sink).
- Restarting PipeWire/WirePlumber/pipewire-pulse fixed video playback, and
  `hw_ptr` advances at 48 kHz afterwards.

**Not established:**
- **Whether the SOF DSP or PipeWire is at fault.** No kernel error was
  logged for the sound card on resume: no `sof`, `snd` or SoundWire lines at all
  after boot. It failed silently.
- **Whether an ordinary suspend (lid close) triggers it too**, or only the
  hybrid-sleep/hibernate path. Plain suspends are common (2026-09-26, -29, -30,
  10-01, 10-05 in the journal), and none is known to have broken audio, but
  nobody checked. Next time after a
  lid-close resume, run the check above while something is playing.
- **Whether 2026-09-30 was the same thing.** That morning had two critical-battery
  hybrid-sleeps (08:45:47 and 08:46:46), and the machine was rebooted at 08:48,
  ~17s after the second resume. Consistent with "something broke, so reboot",
  but nothing records whether audio was stuck.
- What woke the machine ~25s after it went to sleep.

## Dead ends, don't re-theorise

| Theory | Why it's wrong |
|---|---|
| Firefox itself is broken | Firefox had been restarted (process 4 minutes old) and still couldn't play. Fixed without touching Firefox. |
| Today's 17:01 apt upgrade (pushed by NinjaRMM) | It was `linux-oem` 7.0.0-1015 + generic HWE kernel (not running until reboot), `libfreerdp3`, `libfreetype6`. Firefox is a **snap** and bundles its own libs. A pending Firefox snap refresh (156 → 157) is unrelated too. |
| PipeWire routing / wrong default sink | `wpctl status` showed Firefox linked to the default `Speaker` sink and `[active]`. The routing was fine; the sink wasn't consuming. |
| Bluetooth | `hci0` logged `Controller in error state` / `Intel Soft Reset failed (-62)` on resume, but it recovered on its own (`Powered: yes`), and audio was going to the built-in speaker anyway. |

## Prevention: open/optional, nothing applied

Only worth doing if it turns out to recur, especially on ordinary suspends:

- A resume hook that restarts the user's PipeWire stack. User units can't order
  themselves after the system's `sleep.target`, so this would be a root
  `/usr/lib/systemd/system-sleep/` hook calling `systemctl --user -M trc@ restart
  pipewire pipewire-pulse wireplumber` on `post`. Untested.
- Plugging in before 5% avoids the hybrid-sleep entirely. Changing
  `CriticalPowerAction` to `PowerOff` would also avoid it, at the cost of losing
  the session at 2%. Not recommended.

## Reversing it

Nothing was changed, so there's nothing to reverse.

## Versions at the time

Kernel `7.0.0-1014-oem`; SOF firmware `2.14.1.1` (IPC4, Panther Lake,
`sof-soundwire` card); PipeWire `1.6.2`; WirePlumber `0.5.13`; UPower `1.91.1-1`;
Firefox snap `156.0.1-1` (rev 8969).
