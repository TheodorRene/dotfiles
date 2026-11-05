# Trying EQ presets on the headphone jack, without being able to break it

**Status:** APPLIED 2026-10-15, **repo-only**. `scripts/eq.sh`,
`audio/eq-presets/`, a guarded branch in `scripts/volume.sh` and a waybar
indicator (`custom/eq`). **Nothing is installed and nothing persists**: the EQ
exists only while `eq.sh on` is in effect, as a transient user unit with its
config in `$XDG_RUNTIME_DIR`.

This is the second attempt. The first (2026-10-14) broke the user's audio; see
[Last time](#last-time-2026-10-14-and-why-this-one-is-shaped-differently).

## Use

```
scripts/eq.sh                       # what's boosted/cut right now: curve, dB per frequency, bands
scripts/eq.sh show <preset>         # the same for any preset, before switching to it
scripts/eq.sh on                    # EQ on with the first preset; becomes the default output
scripts/eq.sh use oratory1990-hd6xx # switch preset, instant, no gap
scripts/eq.sh use flat              # no EQ (level-matched, see below)
scripts/eq.sh ab                    # toggle current preset <-> flat
scripts/eq.sh pick                  # same, from a wofi menu
scripts/eq.sh list                  # * = active
scripts/eq.sh off                   # back to the plain jack
```

**Getting back to normal is always `scripts/eq.sh off`.** If that doesn't work,
see [Restore](#restore).

- **Volume keys keep working the same**: while the EQ is on they still move the
  jack's own (hardware) volume, and the EQ sink sits at 100%.
- **waybar shows 🎚️ just before the audio module while the EQ is on** (dimmed
  on `flat`; hover for the preset name), and nothing when it's off. That's
  `custom/eq`, which runs `eq.sh waybar`: `eq.sh` signals `RTMIN+10` on every
  change, and a 5 s poll catches the EQ dying on its own.
- **waybar's audio module shows `🔊 100%` while the EQ is on**: it displays the
  default sink, which is now the EQ (always at 100%, and it has no headphone
  icon). The popup from the volume keys shows the real (jack) value. Scrolling
  on that module moves the EQ sink's own (software) volume, not the jack's.
  Harmless, and the next `on` resets it.
- **The EQ is quieter than no EQ** by the preset's preamp (−6.1 dB for the
  oratory1990 one). It has to be, so the boosts don't clip. Turn up to taste;
  `off` then jumps back up by that amount.
- **Unplugging the headphones while the EQ is on gives silence, not the
  speakers.** That's deliberate (a headphone bass boost on laptop speakers). `off`
  restores normal behaviour.

## Presets

`audio/eq-presets/*.txt`, one file per preset, in the **AutoEQ / EqualizerAPO
`ParametricEQ.txt` format**. The file name (without `.txt`) is the preset name.

```
Preamp: -6.1 dB
Filter 1: ON LSC Fc 105 Hz Gain 6.4 dB Q 0.70
Filter 2: ON PK Fc 8800 Hz Gain 5.1 dB Q 1.42
...
```

- Shipped: `oratory1990-hd6xx.txt`, **byte-for-byte** from AutoEQ:
  `results/oratory1990/over-ear/Sennheiser HD 6XX/Sennheiser HD 6XX ParametricEQ.txt`
  (github.com/jaakkopasanen/AutoEq, fetched 2026-10-15).
- **Up to 7 presets** load at once (the builtin mixer has 8 inputs; the 8th is
  flat). Extras are skipped with a message.
- **Only `PK`, `LSC` and `HSC` bands.** That's all PipeWire's `param_eq` reads.
  Anything else (`LS`, `HS`, `LP`, `HP`, `LSQ`…) is **refused** with the line
  number, never silently dropped (a missing shelf changes the sound a lot).
  `OFF` bands, comments and blank lines are skipped. CRLF is fine.
- A preset that **boosts without a `Preamp:` line** loads, with a clipping
  warning.

**To tune**: edit the file, then `scripts/eq.sh check` (validates every preset
without touching audio) and `scripts/eq.sh reload` (restarts the EQ with the
new files and keeps the selected preset; about a second of audio on the plain
jack while it restarts).

### A/B fairly

Every option, `flat` included, is **level-matched to the most-attenuated
preset**: `flat` is the dry signal at −6.1 dB rather than at 0 dB. Otherwise the
louder option wins every comparison, whatever it sounds like. Switching between
options inside the EQ therefore never jumps in level; `off` does.

## How it works

`eq.sh on` does this, in order:

1. Validates the presets and writes normalised copies (`p1.txt`…) plus an index
   into `$XDG_RUNTIME_DIR/jack-eq/`.
2. Generates `jack-eq.conf` there: a stand-alone PipeWire client (same base
   modules as the stock `/usr/share/pipewire/filter-chain.conf`) with one
   `libpipewire-module-filter-chain`:

   ```
   input L/R -> copy -> param_eq (preset 1) -\
                    -> param_eq (preset 2) --+-> mixer (per channel) -> output
                    -> ...                   |   one input at its gain,
                    -> dry (flat) ----------/    all others at 0
   ```

   Switching preset is a `pw-cli set-param` on the mixer gains, which is why
   it's instant.
3. Starts it as a **transient** unit:
   `systemd-run --user --collect --unit=jack-eq /usr/bin/pipewire -c …/jack-eq.conf`.
4. Saves the current default output, then `wpctl set-volume <eq> 1.0` and
   `wpctl set-default <eq>`. Streams that follow the default move onto it.

The EQ's output stream is pinned:

```
target.object      = "alsa_output.…HiFi__Headphones__sink"
node.dont-fallback = true
node.linger        = true
```

In WirePlumber 0.5.13 (`scripts/linking/find-defined-target.lua`),
`dont-fallback` without `linger` makes WirePlumber **destroy** a stream whose
target is missing. With `linger` it waits for the jack instead. Either way it
never falls back to another output.

`eq.sh off` sets the default back to what it was (or the jack, if that output
has gone), *then* stops the unit, then deletes `$XDG_RUNTIME_DIR/jack-eq`.

`scripts/volume.sh`: if `$XDG_RUNTIME_DIR/jack-eq/jack-id` exists **and** the
default sink is `jack_eq`, the keys act on the jack's node id instead of
`@DEFAULT_AUDIO_SINK@`. Otherwise it does exactly what it did before.

**Gotcha, learned the hard way on 2026-10-14:** `cs42l45 Headphone` (amixer)
**is** the Headphones sink's volume. UCM binds it as the `PlaybackMixerElem`, so
PipeWire's volume *is* the codec gain (`softVolumes: [1.0, 1.0]`); 0.64 in
`wpctl` reads −11.63 dB in `amixer`. It is not a second gain stage to max out.

### Why the preset files get normalised

`param_eq` (`plugin_builtin.c`, PipeWire 1.6.2) reads **line 1 as the preamp
unconditionally**: `sscanf(line, "%*s %6s %*s", gain)`. A preset starting with a
comment or `Filter 1:` would silently lose that line and get a junk preamp. Band
lines are read with fixed widths (`%8s` frequency, `%6s` gain and Q). So the
copy always puts `Preamp:` first and reformats numbers to fit.

## What it changes on the system

| What | Where | Lifetime |
|---|---|---|
| EQ process | user unit `jack-eq` (transient) | until `off`, crash or reboot |
| Generated config, normalised presets, saved default, jack id | `$XDG_RUNTIME_DIR/jack-eq/` (tmpfs) | deleted by `off`; gone at reboot |
| Default output | WirePlumber metadata, saved to `~/.local/state/wireplumber/default-nodes` | `off` puts it back |
| **Leftover after `off`:** `default.configured.audio.sink.0=jack_eq` | `default-nodes` | permanent, harmless (below) |
| **Leftover after `off`:** two `Headphone\sjack\sEQ` volume lines (both 1.0) | `stream-properties` | permanent, harmless |

**Not touched:** `~/.config/pipewire` (doesn't exist), `~/.config/wireplumber`,
`filter-chain.service` (Ubuntu's stock one, enabled, runs empty), `/etc`,
packages.

**Why the `default-nodes` leftover is harmless:** WirePlumber keeps a *history*
of chosen defaults (`state-default-nodes.lua`). After `off` it reads
`sink=<jack>`, `sink.0=jack_eq`, and it ranks the available nodes by that order
(`20001 - position`). The jack always outranks `jack_eq`, and `jack_eq` only
exists while the EQ is on anyway.

## Restore

1. **Normal:** `scripts/eq.sh off`.
2. **If the script itself is broken**, do by hand what it does:
   ```
   wpctl status                     # note the id of "sof-soundwire Headphones"
   wpctl set-default <that id>
   systemctl --user stop jack-eq
   rm -rf "$XDG_RUNTIME_DIR/jack-eq"
   ```
3. **Reboot.** Nothing about the EQ survives one. See below for what's verified.
4. **Scrub WirePlumber's memory of it** (optional, cosmetic). This restarts the
   audio daemon, so it causes a short gap; run it yourself:
   ```
   systemctl --user stop wireplumber
   sed -i '/jack_eq/d' ~/.local/state/wireplumber/default-nodes
   sed -i '/Headphone\\sjack\\sEQ/d' ~/.local/state/wireplumber/stream-properties
   systemctl --user start wireplumber
   ```
   WirePlumber rewrites these files from memory, so editing them while it runs
   gets undone.
5. **Remove it entirely:** `scripts/eq.sh off`, then delete `scripts/eq.sh` and
   `audio/eq-presets/`. Revert the `jack-eq` block in `scripts/volume.sh` and
   the `custom/eq` module in `waybar/config` + `waybar/style.css` (or revert the
   commit), then `pkill -SIGUSR2 -x waybar`.

## Verified 2026-10-15

Run with everything paused. The jack was **hardware-muted** for the tone test
(`[off]` on `cs42l45 Headphone`), so nothing was audible, then unmuted.

**`eq.sh on`**: unit `active`, default `jack_eq`, all 7 streams (Spotify,
Firefox ×5, `viz`) moved onto it, EQ volume `1.000000`, and its output linked
only to the jack:
```
jack_eq.out:output_FL
  |-> alsa_output.pci-0000_00_1f.3-platform-sof_sdw.HiFi__Headphones__sink:playback_FL
jack_eq.out:output_FR
  |-> alsa_output.pci-0000_00_1f.3-platform-sof_sdw.HiFi__Headphones__sink:playback_FR
```

**The EQ really is applied, and correctly.** Tones (−20 dBFS, 1 s each) were
played through each path and the jack's feed recorded
(`pw-record --target <jack> -P '{ stream.capture.sink = true }'`). The level at
each frequency was measured and compared with the preset's bands computed from
the RBJ biquad formulas:

```
    Hz  flat vs no-EQ  preset vs flat  expected   (L / R, dB)
    50  -6.10/ -6.10   +4.57/ +4.57     +4.54
   105  -6.10/ -6.10   +0.16/ +0.16     +0.16
  1000  -6.10/ -6.10   -0.54/ -0.54     -0.54
  3169  -6.10/ -6.10   -1.33/ -1.33     -1.33
  8800  -6.10/ -6.10   +4.35/ +4.35     +4.35
 16000  -6.10/ -6.10   -1.56/ -1.56     -1.56
```

That's within 0.03 dB of expected, identical on both channels, and `flat` sits
exactly at the −6.10 dB level match.

**Volume keys** with the EQ on: `volume.sh up` moved the jack 0.54 → 0.59 with
the EQ sink at 1.00; `down` took it back to 0.54.

**Crash**: `systemctl --user kill -s KILL jack-eq`. WirePlumber made the jack
the default by itself, and all 7 streams went back to `Headphones`. The volume
keys hit the jack. `eq.sh off` afterwards cleaned up.

**`reload`** kept the selected preset (`flat`: mixer gain 8 = `0.495450`, the
rest 0).

**End state after `off`**: unit `inactive`, 0 `jack-eq` units listed, 0 nodes
named `jack_eq*`, default = `sof-soundwire Headphones`, every stream on
`Headphones`, runtime dir gone. WirePlumber state against a snapshot taken just
before: the two leftovers in the table above, plus two changes made by the
test's own volume/mute presses (the profile's saved route list now names
`[Out] Headphones`; Spotify's `Music` volume entry now stores channel map
`FL, FR` instead of `UNK, UNK`, same volume).

### Not verified

- **A reboot with the EQ still on.** Expected to come up on the jack, because the
  boot-time choice runs through the same history-ranking hook the crash test
  exercised. **Inferred, not rebooted.**
- **Unplugging the jack with the EQ on.** Expected: silence, from the
  `dont-fallback` + `linger` logic quoted above. **Read from the code, not tested.**
- **`eq.sh pick`** (wofi): not exercised, since it opens a window on the
  user's screen.
- **How it sounds.** The measurements prove the filter is the one in the file;
  whether you like it is up to your ears.

## Last time (2026-10-14), and why this one is shaped differently

What happened, from that session's transcript:

1. A 10-band EQ was put in `~/.config/pipewire/filter-chain.conf.d/` (with
   `pipewire` added to the `symlinkifier.pl` `.config` loop). Ubuntu's
   `filter-chain.service` is enabled and loads that directory **at every boot**,
   and the EQ was made the default output.
2. A curses TUI to drive it didn't work: `getch()` returned the raw `27 91 65`
   for arrow keys, so the first arrow hit the ESC=quit binding. After a fix, the
   user still couldn't hear changes.
3. EasyEffects was installed as a Flatpak **on top of that** (it creates its own
   `easyeffects_sink` and takes over the default output).
4. User: "you messed up my system, headphones connect but the eq is in the way".
   Everything was reverted, including a stale `default.configured.audio.sink.0`
   pointing at the deleted EQ.

| Dead end | Instead, here |
|---|---|
| Persistent drop-in loaded at boot by `filter-chain.service` | Transient unit + tmpfs config; a reboot is a full reset |
| EQ as a permanent default output | Default switched only by `on`, put back by `off`, and WirePlumber falls back by itself on a crash (verified) |
| Custom TUI | Plain commands + a wofi picker; presets are text files |
| Two EQs stacked (filter-chain + EasyEffects) | One EQ. **Don't run EasyEffects alongside this** |
| "Max out `cs42l45 Headphone`" | That *is* the volume (gotcha above) |

**Still left over from 2026-10-14, not touched here:**
- The **EasyEffects Flatpak is still installed**
  (`com.github.wwmm.easyeffects` 8.2.9, `--user`). It's not running and has no
  autostart entry. Remove it with
  `flatpak uninstall --user com.github.wwmm.easyeffects`.
- **4 lines in `stream-properties` mention EasyEffects**, including Slack's output
  and a "Headphones EQ" stream saved with `"target":"easyeffects_sink"`.
  Harmless while that sink doesn't exist. If EasyEffects ever runs again, Slack
  would route into it. Scrub them the same way as restore step 4, with
  `/easyeffects\|Headphones\\sEQ/d`.
