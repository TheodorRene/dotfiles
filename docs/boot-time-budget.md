# Where the boot time actually goes

**Status: nothing here is applied.** This is the measurement plus ranked candidate
changes.

First measured 2026-09-03 from a **single** `systemd-analyze` run (kernel
7.0.0-30-generic). **Revised 2026-09-04 after decomposing 21 consecutive boots
from the journal** — the single-sample numbers turned out to be badly
unrepresentative, and two of the conclusions drawn from them were wrong. The
corrections are marked below.

## The headline: there is no "the boot time"

Across 21 boots the total ranges **19.1s to 2min 29s**. Every phase except the
unlock itself swings by 5-10x. Three facts survive that variance:

- **The actual decryption is the one rock-solid number in the whole boot.** argon2
  key derivation took **2.0s on all 21 boots** (1.98-2.05s). If a boot feels slow,
  it is *not* the crypto — stop looking there.
- **`systemd-analyze` counts the human typing the passphrase.** That gap ran
  **3.4s to 114.7s**. So a "fast" boot may just be one where the passphrase was
  typed quickly. ~~"~13s is the human typing"~~ — 13s was a coincidence of the
  2026-09-03 sample, not a typical value.
- **Plymouth holds the screen for ~10.5s after the desktop is already up**, on 17
  of the 21 boots. This is the thing that feels like "I typed my password and got a
  spinner for ages", and it is *after* the unlock, not during it.

## The 21-boot distribution (measured 2026-09-04)

`gap` = plymouth prompt appearing → `cryptsetup` having the passphrase in hand
(mostly human). `argon2` = the actual unlock. `pquit` = `plymouth-quit-wait.service`.

| boot | firmware | loader | gap | argon2 | initrd | pquit | userspace | total |
|---|---|---|---|---|---|---|---|---|
| 2026-08-27 08:49 | 5.730s | 5.185s | 13.9 | 2.01 | 17.479s | **0.3** | 3.902s | 32.878s |
| 2026-08-27 17:35 | 5.686s | 2.659s | 32.4 | 2.02 | 35.603s | 10.7 | 13.894s | 58.435s |
| 2026-08-27 20:07 | 5.697s | 2.658s | 5.4 | 2.03 | 8.919s | 10.5 | 13.637s | 31.431s |
| 2026-08-28 09:01 | 5.495s | 4.389s | 11.0 | 2.01 | 14.286s | 10.5 | 14.251s | 38.977s |
| 2026-08-28 16:31 | 5.524s | 11.247s | 27.7 | 1.98 | 30.971s | 10.5 | 13.621s | 1min 1.876s |
| 2026-08-29 12:14 | 5.534s | 9.668s | 5.3 | 2.01 | 8.727s | 10.3 | 13.755s | 38.291s |
| 2026-08-30 00:08 | 5.535s | 2.260s | 15.4 | 2.03 | 18.902s | 10.9 | 14.607s | 41.881s |
| 2026-08-30 12:14 | 5.583s | 2.643s | 3.4 | 1.98 | 6.710s | **0.5** | 3.642s | **19.141s** |
| 2026-08-31 10:18 | 5.398s | 5.208s | 24.9 | 2.00 | 28.046s | 10.5 | 13.555s | 52.696s |
| 2026-08-31 16:57 | 5.420s | 11.238s | 41.0 | 2.05 | 44.524s | 10.6 | 13.870s | 1min 15.671s |
| 2026-08-31 19:32 | 5.375s | 11.223s | **114.7** | 2.02 | 1min 58.228s | 10.5 | 13.731s | **2min 29.018s** |
| 2026-09-01 08:44 | **28.726s** | 3.129s | 9.3 | 2.01 | 12.618s | 10.7 | 13.871s | 58.945s |
| 2026-09-01 16:45 | 5.382s | 11.219s | **90.4** | 2.03 | 1min 33.988s | 10.5 | 13.501s | 2min 4.610s |
| 2026-09-01 19:00 | 5.414s | 2.425s | 7.3 | 2.01 | 10.617s | 10.9 | 13.983s | 32.916s |
| 2026-09-02 08:33 | 5.580s | 2.663s | 6.7 | 1.99 | 9.770s | 10.5 | 13.835s | 32.332s |
| 2026-09-02 16:57 | 5.432s | 7.966s | 8.7 | 2.01 | 12.054s | 10.3 | 13.537s | 39.462s |
| 2026-09-03 08:44 | 11.715s | 3.001s | 27.6 | 2.00 | 30.997s | 11.1 | 14.567s | 1min 803ms |
| 2026-09-03 11:22 | 6.742s | 6.831s | 13.2 | 2.03 | 16.449s | **0.9** | 4.392s | 34.933s |
| 2026-09-03 19:40 | 6.391s | 5.863s | 7.0 | 2.05 | 10.514s | 10.8 | 13.992s | 37.340s |
| 2026-09-04 08:28 | 12.673s | 2.066s | 7.8 | 1.99 | 11.568s | 11.8 | 14.893s | 41.828s |
| 2026-09-04 17:57 | 5.352s | **14.077s** | 6.6 | 2.01 | 9.839s | **0.5** | 3.703s | 33.604s |

The 2026-09-03 11:22 row is the one the original version of this document was
written from. It is a fast-plymouth outlier with a middling typing gap — i.e. the
least representative row in the table on both of the axes it drew conclusions from.

Reproduce the table with the loop in *Re-measuring* below.

## Plymouth costs ~10.5s, after the desktop is already painted

`plymouth-quit-wait.service` took **10.3-11.8s on 17 of 21 boots**, and 0.3-0.9s on
the other four. That single term accounts for the entire bimodality of the
`userspace` column (13.5-14.9s vs 3.6-4.4s) — nothing else differs.

It is genuinely visible time. On 2026-09-04 08:28, sway and waybar were up at
**18.7s** and plymouth held the display until **26.98s** — 8s of spinner over a
running desktop, with `multi-user.target` and `graphical.target` blocked behind it.

Verified mechanics:

- `plymouth-quit-wait.service` is `ExecStart=-/usr/bin/plymouth --wait` with
  **`TimeoutSec=0`** — so the ~10.5s is *not* a systemd timeout. `plymouthd` itself
  stays alive that long.
- Nothing in the journal marks the moment it exits; `multi-user.target` follows
  ~2ms later and that is the first entry after it.
- `plymouth-quit.service` (the unit that would tell it to quit) is only ever seen
  in the journal as `gdm.service: Failed to enqueue OnFailure=plymouth-quit.service`
  **at shutdown**, never during boot.
- **Dead end:** it is not the external monitor. The four fast boots split 2/2 on
  whether `DP-1` (the Lenovo T25d) was connected, and so do the slow ones. Ruled
  out 2026-09-04 by counting `output DP-1` references per boot.

**What separates the four fast boots is not established.** Don't theorise; the fix
below sidesteps it entirely.

## Why the loader varies 2.1s → 14.1s

~~"6.8s ≈ 58 MiB at 8.5 MiB/s over UEFI block I/O"~~ — **wrong**, or at least not
the whole story. The same read takes **2.066s** on one boot and **14.077s** on
another, i.e. 28 MiB/s to 4 MiB/s for identical bytes. There is a variable factor,
unidentified. Note the suspiciously tight cluster at **11.219 / 11.223 / 11.238 /
11.247s** on four boots, which looks more like a fixed wait than like throughput.

What is still solid:

- It is not the GRUB menu — `/etc/default/grub` has `GRUB_TIMEOUT=0` and
  `GRUB_TIMEOUT_STYLE=hidden`.
- The bytes are real and reducible: `vmlinuz` 16.5 MiB + **a 41.6 MiB *generic*
  dracut initrd** = 58.1 MiB. `hostonly` is unset (`/usr/bin/dracut:1398` is
  `hostonly=${hostonly-}`; the `hostonly/`, `generic/` and `rescue/` directories
  under `/usr/lib/dracut/dracut.conf.d/` are *inactive profiles* — dracut reads
  `*.conf` files directly in `conf.d`, not subdirectories — so grepping them yields
  three contradictory `hostonly=` values that all mean nothing. There is no
  `/etc/dracut.conf.d/` at all).
- So reading **fewer bytes** helps regardless of what the variance is.

### Where these firmware/loader numbers come from

There are **no `Loader*` EFI variables** on this machine (checked: 266 vars in
`/sys/firmware/efi/efivars/`, zero matching `loader` — Ubuntu's shim/GRUB do not
implement systemd's boot-loader interface). systemd is reading **ACPI FPDT**
instead, so `firmware` = firmware init → bootloader launch and `loader` =
bootloader launch → `ExitBootServices`. Worth knowing before trying to reconcile
them against anything else.

### `/boot` is NOT inside LUKS

Worth writing down because it is the opposite of what the LUKS layout suggests:

```
nvme0n1p1  384M  vfat  ESP    /boot/efi
nvme0n1p7    2G  ext4         /boot        <- plain, unencrypted
nvme0n1p8  452G  LUKS  -> dm_crypt-0 -> ubuntu-vg/ubuntu-lv -> /
```

So GRUB is **not** doing `cryptomount` (confirmed: no `cryptomount`/`insmod luks`
in `/boot/grub/grub.cfg`), and the loader time is not GRUB doing software AES. See
[luks-boot-emergency-shell.md](luks-boot-emergency-shell.md) for the rest of the
boot chain.

## How to read a single slow boot

The four markers that decompose any boot, in order:

```
[    1.233405] Started systemd-ask-password-plymouth.service     <- prompt is up
[    7.853904] systemd-cryptsetup[518]: Set cipher aes, mode …   <- passphrase in hand
[    9.864378] Finished systemd-cryptsetup@dm_crypt\x2d0.service <- unlocked (always +2.0s)
[   13.927225] Finished plymouth-quit-wait.service               <- splash finally goes away
```

`Set cipher …` is the reliable split: everything before it is the human (or
whatever is delaying passphrase delivery), everything after it is machine work.

`systemd-analyze blame` is actively misleading here: its top ~30 entries are all
`*.device` units that merely inherit the initrd duration (rfkill, tpm0, ttyS0-3,
zram0…). Always filter:

```bash
systemd-analyze blame | grep -vE '\.device$'
```

## Candidate changes (none applied)

### 1. TPM2 auto-unlock — removes the typing *and* the prompt

Hardware is there: `/dev/tpm0`, `/sys/class/tpm/tpm0/tpm_version_major` = `2`
(STM0925), and `/usr/bin/systemd-cryptenroll` exists. Current `/etc/crypttab`:

```
dm_crypt-0 UUID=a68cb466-3822-421d-a6f5-64e9d5b4976c none luks
```

This is the biggest lever precisely *because* the typing gap is unbounded — it
removes a term that has been measured as high as 114.7s, not a fixed 13s.

**The catch, and it is a real one: Secure Boot is disabled** (`mokutil --sb-state`
→ `SecureBoot disabled`). PCR 7 measures Secure Boot state and keys, so sealing to
PCR 7 with SB off is a weak seal — someone with the laptop can boot a modified
kernel and have the TPM hand the key over unprompted. That downgrades FDE from
"protects a stolen laptop" to "protects a stolen drive". Two honest ways forward:

```bash
# A: turn Secure Boot on in the BIOS first, then seal to PCR 7
sudo systemd-cryptenroll /dev/nvme0n1p8 --tpm2-device=auto --tpm2-pcrs=7

# B: leave SB off, require a PIN (still typing, but 4 digits, not a passphrase)
sudo systemd-cryptenroll /dev/nvme0n1p8 --tpm2-device=auto --tpm2-pcrs=7 \
     --tpm2-with-pin=yes
```

Then add `tpm2-device=auto` to the options column in `/etc/crypttab` and
regenerate the initrd. **Keep the existing passphrase keyslot** as fallback — a
firmware update changes PCR values and can lock you out otherwise.

### 2. Drop `quiet splash` — removes ~10.5s on 17 of 21 boots

Same change as
[luks-boot-emergency-shell.md](luks-boot-emergency-shell.md) §"Make the next
failure legible", and it pays twice: it deletes the plymouth stall measured above
*and* it means the next silent 90s hang prints what it is waiting on.

```diff
-GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
+GRUB_CMDLINE_LINUX_DEFAULT=""
```

Then `sudo update-grub` (**needs root — hand the command over, see agents.md**).
`plymouth.enable=0` is the sturdier variant if `splash` may get re-added by Ubuntu
tooling. **Cost:** no boot logo, a wall of boot text, and the passphrase prompt
moves to `systemd-ask-password-console` on `/dev/console` — plain text, no
graphics stack. Given that plymouth is both ~10.5s of dead time and the component
implicated in the 2026-08-05 hang, this is the best value/risk ratio in the list.

### 3. Host-only initrd — attacks the loader

41.6 MiB → typically 10-15 MiB. The loader time is not a clean function of bytes
(see above), but fewer bytes cannot hurt, and on a bad boot the loader is 14s.

```bash
printf 'hostonly="yes"\nhostonly_cmdline="yes"\n' | sudo tee /etc/dracut.conf.d/10-hostonly.conf
sudo dracut -f --regenerate-all
```

**Risk, given this machine's history:** a host-only initrd carries drivers for
*this* hardware only, and `GRUB_TIMEOUT=0` + `hidden` means recovering to the
previous initrd requires holding Shift/Esc during POST. `initrd.img.old` →
`initrd.img-7.0.0-29-generic` is the fallback. Read
[luks-boot-emergency-shell.md](luks-boot-emergency-shell.md) §"Restore an escape
hatch in GRUB" before doing this — that doc already proposes raising the timeout,
and the two changes should land together, timeout first.

### 4. Firmware — BIOS only, and it spikes

Usually 5.4s, but measured at 6.7s, 11.7s, 12.7s and once **28.7s**. F2 → POST
Behavior → **Fast Boot: Minimal** (from Thorough); disable the UEFI Network Stack /
PXE if unused. Cannot be scripted from the OS. The spikes are unexplained; if they
persist after Fast Boot: Minimal, that is a separate investigation.

### 5. LUKS PBKDF, 2.0s — leave it alone

`sudo cryptsetup luksDump /dev/nvme0n1p8` shows the argon2 memory/iteration
parameters (needs root). They can be lowered, but this is the one knob that
directly trades away brute-force resistance, it is the *most consistent* 2 seconds
in the boot, and it is moot if #1 lands.

### 6. kdump / `crashkernel` — not a boot-time change

Worth ~230ms, which is nothing, but it reserves 512 MB of RAM for a facility that
**cannot work on this machine**. Separate finding, separate doc:
[kdump-cannot-capture-on-luks.md](kdump-cannot-capture-on-luks.md).

## Realistic outcome

#1 + #2 + #3 together: a **~10s** boot, and — more valuable than the mean — one
without the 1-2 minute tail seen four times in three weeks. #1 and #2 are most of
it; #2 is the cheapest and also buys diagnosability.

## Re-measuring

Single boot:

```bash
systemd-analyze                                    # the budget
systemd-analyze blame | grep -vE '\.device$'       # real slow units
journalctl -b -o short-monotonic | grep -E 'cryptsetup|ask-password|plymouth-quit'
```

The whole journal, which is what actually matters here — one row per boot:

```bash
for b in $(seq -20 0); do
  L=$(journalctl -b $b --no-pager 2>/dev/null | grep -m1 -E 'Startup finished in .*\(loader\)')
  [ -z "$L" ] && continue
  m() { journalctl -b $b -o short-monotonic --no-pager 2>/dev/null \
        | grep -m1 "$1" | sed -E 's/^\[[[:space:]]*([0-9.]+)\].*/\1/'; }
  ask=$(m 'Started systemd-ask-password-plymouth.service')
  cip=$(m 'Set cipher aes'); fin=$(m 'Finished systemd-cryptsetup')
  pqs=$(m 'Starting plymouth-quit-wait'); pqe=$(m 'Finished plymouth-quit-wait')
  printf '%s  gap=%s argon2=%s pquit=%s | %s\n' \
    "$(journalctl -b $b -o short-iso --no-pager 2>/dev/null | head -1 | cut -c1-16)" \
    "$(awk -v a=$ask -v c=$cip 'BEGIN{printf "%.1f",c-a}')" \
    "$(awk -v c=$cip -v f=$fin 'BEGIN{printf "%.2f",f-c}')" \
    "$(awk -v a=$pqs -v c=$pqe 'BEGIN{printf "%.1f",c-a}')" \
    "$(echo "$L" | sed -E 's/.*Startup finished in //')"
done
```
