# Dropped to the dracut emergency shell — "ubuntu-vg/ubuntu-lv does not exist"

**Status: nothing here is applied.** `/etc/default/grub` is untouched (and isn't
tracked in this repo). This is the diagnosis plus candidate fixes, written up so a
repeat can be recognised in seconds instead of re-derived. Written 2026-08-05.

**Cause is NOT established.** Several plausible theories were built and then killed
by further evidence (see *Dead ends*). Read the symptom record and the verified
mechanics; treat the leading explanation as a lead, not a conclusion.

**Revised 2026-09-04** with a 21-boot measurement that narrows it to one branch —
see *New evidence, 2026-09-04*. Nothing is applied as a result.

## The incident

2026-08-05, morning boot. Reported sequence, from the user who was sitting there:

1. Boot proceeded to the plymouth splash.
2. **A passphrase prompt appeared, and the passphrase was typed in.**
3. **The plymouth spinner then animated** — it kept drawing, for
   **roughly 90 seconds**.
4. Dropped to a shell with:

```
Warning: /dev/mapper/ubuntu--vg-ubuntu--lv does not exist
Warning: /dev/ubuntu-vg/ubuntu-lv does not exist
...
A rdsosreport was generated in /run/initramfs/rdsosreport.txt
```

**A plain reboot fixed it** and it hasn't recurred.

Those four details are the whole evidence base — the logs are gone (see *Why the
evidence was gone*). Each one kills at least one theory, so keep them exact.

## The one fact that decodes the message

Root lives *inside* LUKS:

```
nvme0n1p8 (crypto_LUKS) → dm_crypt-0 → ubuntu-vg/ubuntu-lv → /
```

So `ubuntu-vg/ubuntu-lv does not exist` is **not necessarily an LVM fault**. The VG
is physically unreadable until `dm_crypt-0` is unlocked — no unlock means no PV,
no VG, no LV. The message is emitted identically whether the failure was the
unlock *or* the activation. Don't jump to LVM metadata; establish which layer
stopped first.

## What the ~90 seconds proves

Two verified facts turn the timing into hard information:

- `systemd-cryptsetup@dm_crypt\x2d0.service` (generated from crypttab) has
  **`TimeoutSec=infinity`**. The passphrase step *never gives up on its own*.
- `DefaultDeviceTimeoutUSec=1min 30s` — systemd's default, with no override in
  `/etc/systemd/system.conf`.

`90s` matches `DefaultDeviceTimeoutUSec` **exactly**. So the thing that gave up was
the **`.device` job for `ubuntu--vg-ubuntu--lv`**, not the passphrase step. Which
means, stated precisely and with confidence:

> **`/dev/mapper/ubuntu--vg-ubuntu--lv` did not appear within 90 seconds of the
> device job starting.**

That's the one solid conclusion. Everything below is about *why* — and see
*New evidence, 2026-09-04* for the measurement that makes a 90s **passphrase**
delay look ordinary rather than exotic.

## Verified mechanics (so future-me doesn't re-derive or misread these)

### This machine uses dracut, not initramfs-tools

Most Ubuntu advice online assumes initramfs-tools, whose knobs don't exist here:

- `dracut` + `dracut-core` installed; `initramfs-tools` is `un` (not installed).
- `rdsosreport.txt` in `/run/initramfs/` is *dracut's* emergency dump — that
  filename is the tell.
- The initramfs is **systemd-based** (`/usr/lib/dracut/modules.d/10systemd` exists;
  `/run/initramfs/systemd/` shows systemd ran inside it). So the live plymouth path
  is `plymouth-start.service`, **not** dracut's
  `45plymouth/plymouth-pretrigger.sh` — that hook is only installed
  `if ! dracut_module_included "systemd"`. Easy to misread: it checks
  `plymouth.enable` but not `splash`, which is irrelevant here.
- `/etc/dracut.conf` and `/etc/dracut.conf.d/` are both empty. `hostonly="yes"`
  comes from `/usr/lib/dracut/dracut.conf.d/hostonly/10-hostonly.conf`.

### `rd.lvm.lv` IS set — via the image, not `/proc/cmdline`

This one is genuinely counter-intuitive and cost a wrong theory:

- `/usr/bin/dracut:1377-1380` — if `hostonly` is set and `hostonly_cmdline` is
  unset, dracut sets **`hostonly_cmdline="yes"`** ("Enable hostonly-cmdline by
  default in hostonly mode").
- `70lvm/module-setup.sh` then writes `rd.lvm.lv=ubuntu-vg/ubuntu-lv` into
  **`/etc/cmdline.d/20-lvm.conf` inside the initramfs**.
- dracut's `getargs` reads `/etc/cmdline.d/*.conf` as well as `/proc/cmdline`.

So **`rd.lvm.lv` is effectively set even though `/proc/cmdline` shows only
`quiet splash`.** Consequences:

- `70lvm/parse-lvm.sh` does *not* delete `/etc/udev/rules.d/64-lvm*.rules` (it only
  does that when `rd.lvm.vg`/`rd.lvm.lv` are both empty and `rd.auto` is off).
- It runs `wait_for_dev -n /dev/ubuntu-vg/ubuntu-lv`.
- dracut's `64-lvm.rules` is present, including its retry fallback:
  `RUN+="/sbin/initqueue --timeout --name 51-lvm_scan --onetime --unique /sbin/lvm_scan --activationmode degraded"`

### There are three activation paths, and one is a timeout retry

On the LUKS unlock, `dm-0` gets a `change` event and can be activated by:

1. dracut `64-lvm.rules` → `initqueue --settled --onetime /sbin/lvm_scan`
2. dracut `64-lvm.rules` → `initqueue --timeout … lvm_scan --activationmode degraded`
   (the fallback that fires if the device never showed up)
3. system `69-lvm.rules` → `lvm pvscan --cache --listvg --checkcomplete --vgonline
   --autoactivation event …`, then `systemd-run --no-block … vgchange -aay`

Note `64-lvm.rules` has `KERNEL=="dm-[0-9]*", ACTION=="add", GOTO="lvm_end"` — for
dm devices only `change` counts, which is normal. Also **no `lvm2-pvscan@.service`
exists** on this system (only `lvm2-lvmpolld`, `lvm2-monitor`); activation is
udev-rule-driven per path 3.

**Implication:** "LVM autoactivation simply never fired" is a *weak* theory here —
there's redundancy plus an explicit timeout retry. Don't reach for it without log
evidence.

### Which framebuffer the prompt lives on

From a *good* boot (2026-08-05 08:52):

| Time | Event |
|---|---|
| 08:52:15 | `Relocating firmware framebuffer`; `Initialized simpledrm 1.0.0`; `fb0: simpledrmdrmfb` |
| 08:52:37 | root ext4 mounted — i.e. **passphrase entered around here** |
| 08:52:39 | `xe 0000:00:02.0: vgaarb: deactivate vga console`, Panther Lake display takes over |

The prompt renders on **simpledrm / the firmware framebuffer**; the real `xe` driver
takes over only *after* root is mounted. Matches
`/usr/share/plymouth/plymouthd.defaults`: `UseSimpledrm=1`, `DeviceTimeout=8`,
`ShowDelay=0`.

So the `simpledrm → xe` handoff is **not** implicated on a normal boot — don't
chase `xe` unless a future log shows the ordering shifted.

### The two password agents are mutually exclusive

Kept because it's easy to misdiagnose, **not** because it's the current lead
(the prompt did appear, so display worked — see *Dead ends*):

| Agent | Gate |
|---|---|
| `systemd-ask-password-plymouth.{path,service}` | `ConditionPathExists=/run/plymouth/pid` **and** `ConditionKernelCommandLine=splash` |
| `systemd-ask-password-console.{path,service}` | `ConditionPathExists=!/run/plymouth/pid` |

`systemd-cryptsetup` never prompts directly — it drops a request in
`/run/systemd/ask-password` and waits for an agent. If `plymouthd` is alive but its
agent doesn't service the queue, the console agent is **already condition'd out by
the pidfile**, and nothing re-arms it (systemd evaluates `.path` conditions once at
start). The mutual exclusion is deliberate upstream design — two agents would both
consume the request and echo a passphrase in two places — so this is a fragility,
not a bug.

## Leading explanation (a lead, not a conclusion)

*Updated 2026-09-04 — see [New evidence](#new-evidence-2026-09-04-90s-prompt-gaps-happen-on-successful-boots-too) below, which shifts the odds sharply toward branch (a).*

Given that the prompt appeared, the passphrase was typed, the spinner kept
animating, and the **device** job — not the passphrase step — timed out, the
surviving shape is:

**The typed passphrase never resulted in an unlocked `dm_crypt-0` within 90s, and
nothing surfaced an error.** Two branches, not yet separable:

- **(a) The passphrase never satisfied `systemd-cryptsetup`.** It was submitted to
  plymouth but not delivered onward, or arrived after the request was abandoned.
  `TimeoutSec=infinity` means cryptsetup would then wait silently forever — which is
  exactly what an animating spinner with no error looks like. Plymouth is implicated
  in the **submit** direction here, not the display direction.
- **(b) `dm_crypt-0` unlocked, but the LV never appeared.** Requires all three
  activation paths above to have missed, including the timeout retry — so it needs
  evidence before being believed.

**Distinguishing them takes ten seconds at the emergency shell next time:**

```sh
ls /dev/mapper/          # is dm_crypt-0 there?
```

`dm_crypt-0` present ⇒ branch (b), an LVM activation failure. Absent ⇒ branch (a),
the unlock never happened. **Record this before anything else.**

## New evidence, 2026-09-04: 90s+ prompt gaps happen on *successful* boots too

Decomposing 21 consecutive boots from the journal (full table in
[boot-time-budget.md](boot-time-budget.md)) turned up something this document
did not have when it was written: the gap between **the prompt appearing** and
**`cryptsetup` having the passphrase in hand** is wildly variable on boots that
then completed perfectly normally.

| boot | prompt → passphrase in hand | outcome |
|---|---|---|
| 2026-08-28 16:31 | 27.7s | booted fine |
| 2026-08-31 16:57 | 41.0s | booted fine |
| 2026-09-01 16:45 | **90.4s** | booted fine |
| 2026-08-31 19:32 | **114.7s** | booted fine |

And on all 21 boots, once the passphrase arrived, argon2 took **2.0s** (±0.05) and
the LV appeared **0.3s** after that. Two consequences for the branches above:

- **Branch (b) is now much less likely.** LVM activation has not been slow or
  flaky even once in three weeks of boots — the unlock→LV step is one of the most
  consistent things in the whole boot.
- **Branch (a) gained a mechanism.** A **90.4s** gap on a *successful* boot lands
  exactly on top of the 90s `DefaultDeviceTimeoutUSec` that expired during the
  incident. If that same delay runs a second or two longer, the `.device` job gives
  up first and you get the emergency shell. Under that reading the incident is not
  a distinct failure at all — it is **the ordinary long gap, one second too long**,
  which also explains why a plain reboot "fixed" it and why it has not recurred.

**The discriminator is still missing, and it is not recoverable from the logs.**
Nothing in the journal separates "the human typed late" from "keystrokes were not
reaching plymouth". Asked directly on 2026-09-04; not recallable for those four
boots. So this remains a lead, not a conclusion — but it is now the *only* live
branch.

### How to capture the discriminator next time

**Free, no config change:** when the wait feels long, **type one character and
watch the screen.** Plymouth echoes each keystroke immediately (a dot/asterisk per
character).

- Dots appear ⇒ input *is* being delivered; the delay is human or downstream.
- No dots ⇒ input is not reaching plymouth ⇒ **branch (a) confirmed**, and this
  stops being a mystery.

**Config option, unverified:** `plymouth.debug` on the kernel cmdline makes
`plymouthd` log verbosely, input handling included. `/run` survives switch-root, so
on a boot that *succeeds* the log is still readable afterwards. Not tested here —
confirm where the log actually lands before relying on it. Note that candidate
change #1 below (dropping `quiet splash`) removes plymouth from the path entirely,
which answers the question a different way.

## Dead ends — theories that were built and then killed

Recorded so they don't get rebuilt from the same starting point:

| Theory | Killed by |
|---|---|
| **Blind plymouthd** — `plymouthd` alive but rendering nothing, stranding the request behind an invisible prompt | The prompt **was visible** and the **spinner animated**. Plymouth's display path worked. |
| **Wrong passphrase** (e.g. the USB Voyager not having enumerated, so characters landed wrong) | A wrong passphrase fails *fast and visibly* with retries (~1-2s per attempt); it cannot produce a 90s silent spin. **Note the narrow scope:** this kills *wrong* input, not *undelivered* input — "keystrokes never reached plymouth" is branch (a) and is now the live lead, not a dead end. |
| **dracut deleted the LVM activation rules** because `rd.lvm.vg`/`rd.lvm.lv` were absent from `/proc/cmdline` | `hostonly_cmdline` defaults to `yes` under `hostonly`, so `rd.lvm.lv=ubuntu-vg/ubuntu-lv` is baked into the image at `/etc/cmdline.d/20-lvm.conf`. The rules and their retry fallback are present. |
| **LVM autoactivation never fired** (branch (b)) | Weakened further 2026-09-04: across 21 boots, unlock→LV was 0.3s every single time. Redundant activation paths plus a timeout retry, and no observed flakiness. |
| **Failing NVMe / filesystem** | See *What was ruled out*. Also: hardware faults don't clear on a plain reboot. |

## Why the evidence was gone

`/run` is a tmpfs — the reboot that fixed the boot destroyed `rdsosreport.txt`. And
the failed boot never mounted root, so it left **no persistent journal entry**
(`journalctl --list-boots` shows nothing between 2026-08-04 22:28 and
2026-08-05 08:52).

**Next time, save the report before rebooting.** `/boot` is plain unencrypted ext4:

```sh
mount /dev/nvme0n1p7 /mnt && cp /run/initramfs/rdsosreport.txt /mnt/
```

## If it recurs — do these, in this order

0. **Before it drops to a shell, while the spinner is still going: type one
   character and look for a dot appearing.** As of 2026-09-04 this is the highest-value
   observation available and it is only available *then* — see *How to capture the
   discriminator next time*.
1. **`ls /dev/mapper/`** — the branch (a)/(b) discriminator above. Most valuable
   single command at the shell; everything else is recoverable, this datum isn't.
2. **Save the report**: `mount /dev/nvme0n1p7 /mnt && cp /run/initramfs/rdsosreport.txt /mnt/`
3. **Recover in place** rather than rebooting:

```sh
cryptsetup luksOpen /dev/nvme0n1p8 dm_crypt-0   # skip if dm_crypt-0 already exists
lvm vgchange -ay ubuntu-vg
exit          # boot continues normally
```

(LUKS UUID per `/etc/crypttab`: `a68cb466-3822-421d-a6f5-64e9d5b4976c`.)

Whether `luksOpen` accepts the passphrase here is itself informative: accepted ⇒
the passphrase and keyboard are fine, indicting the boot-time delivery path.

## What was ruled out — it is not the hardware

Checked 2026-08-05, all clean:

| Check | Result |
|---|---|
| NVMe errors (timeout/reset/abort/I/O) across the last 9 boots | **0 lines**, including the boots either side |
| Drive enumeration | Clean — `nvme0n1: p1 … p8` at +1s |
| Root filesystem | Mounted clean, orphan cleanup only, no forced fsck, no ext4 errors |
| initramfs regeneration | Unchanged since 2026-07-20 — no bad rebuild, many good boots since |
| apt activity before the bad boot | `history.log` empty since 2026-08-04 09:13 |

Treat a *recurring* failure as a different problem and re-check this table.

## Candidate changes (none applied)

### 1. Make the next failure legible — the only clearly worthwhile one

The real defect in this incident is that **90 seconds of failure produced zero
diagnostic output**. In `/etc/default/grub`:

```diff
-GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
+GRUB_CMDLINE_LINUX_DEFAULT=""
```

Then `sudo update-grub` (**needs root — hand the command over, see agents.md**).

Dropping **`quiet`** matters as much as `splash` here: it's what lets you actually
see the cryptsetup/LVM/device-timeout messages instead of a spinner. Dropping
`splash` fails `plymouth-start.service`'s `ConditionKernelCommandLine=splash`, so
plymouth doesn't run and `systemd-ask-password-console` handles the prompt
(`systemd-tty-ask-password-agent --watch --console`) on `/dev/console` — plain text,
no graphics stack, working before DRM is ready.

`plymouth.enable=0` is the sturdier way to disable just plymouth (survives `splash`
being re-added by Ubuntu tooling, and covers the legacy non-systemd dracut hook);
`nosplash` is a third equivalent.

**Cost:** no boot logo, and a wall of boot text. Given a silent 90s hang already
happened once, that's a reasonable trade until the cause is known.

### 2. Restore an escape hatch in GRUB

There is currently **no practical way to reach the GRUB menu** to edit the cmdline
when the system won't boot:

```
GRUB_TIMEOUT=0
GRUB_TIMEOUT_STYLE=hidden
```

`GRUB_TIMEOUT=2` + `GRUB_TIMEOUT_STYLE=menu` costs two seconds per boot and buys the
ability to fix a broken boot from the keyboard. Also needs `update-grub`.

### 3. Do NOT bother pinning `rd.lvm.*`

Superseded — `rd.lvm.lv=ubuntu-vg/ubuntu-lv` is **already** in the image via
`hostonly_cmdline` (see *Verified mechanics*). Adding it to the kernel cmdline is
redundant. `rd.luks.uuid=` is likewise unnecessary: crypttab is baked in under
`hostonly`, and the LUKS device was found fine — a prompt appeared.

## Checking drive health

`smartmontools` **is** installed (7.5-2). It needs root to open the device — as your
user it returns `Permission denied`:

```sh
sudo smartctl -a /dev/nvme0n1
```

Figures to watch: `Percentage Used`, `Media and Data Integrity Errors`,
`Available Spare`. Same for `sudo tune2fs -l /dev/mapper/ubuntu--vg-ubuntu--lv` to
read filesystem state / mount counts.
