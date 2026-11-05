# A Bluetooth mouse shows as connected but the pointer doesn't move

**Status:** APPLIED 2026-10-30 (MX Master 4 paired over Bluetooth). Nothing in
this repo changed: the pairing key lives in `/var/lib/bluetooth/` (root-only,
not tracked).

## Symptom

A Logitech **MX Master 4** (Bluetooth name `MX Master 4 B`) showed as
**connected** in blueman and `bluetoothctl`, but the pointer didn't move.
There was no input device for it in the kernel (`/proc/bus/input/devices`) or
in sway (`swaymsg -t get_inputs`).

## Cause

The mouse was **connected but never paired**. `bluetoothctl info <addr>` at
13:50:

```
Paired: no
Bonded: no
Trusted: yes
Connected: yes
```

Each time it connected, bluetoothd failed to read the HID-over-GATT setup it
needs to create an input device:

```
13:50:06 bluetoothd: profiles/deviceinfo/dis.c:read_pnpid_cb() Error reading PNP_ID value: Request attribute has encountered an unlikely error
13:50:06 bluetoothd: profiles/input/hog-lib.c:info_read_cb() HID Information read failed: Request attribute has encountered an unlikely error
13:50:06 bluetoothd: profiles/input/hog-lib.c:report_reference_cb() Read Report Reference descriptor failed: Request attribute has encountered an unlikely error
13:50:06 bluetoothd: profiles/input/hog-lib.c:proto_mode_read_cb() Protocol Mode characteristic read failed: Request attribute has encountered an unlikely error
```

The same block came back at 13:51:07 and 13:51:38, so it reconnected while
still unpaired.

- **Verified:** with no pairing the reads fail and no input device appears.
  After pairing, the reads succeed and the device appears.
- **Theorised:** the mouse only serves these attributes over an encrypted link.
  It reports the refusal as the generic ATT "unlikely error" rather than an
  authentication error, which is why the log doesn't say "pair me". Pairing
  fixing it fits this; the ATT error code wasn't captured.
- **Unexplained:** how the device came to be `Trusted` without being paired.
  Probably blueman's *Connect*, or trusting it from the device list, without
  doing *Pair*. Not logged.

## Fix

1. Put the mouse in pairing mode: hold its Easy-Switch channel button about 3 s
   until the light blinks fast.
2. Pair it. Either right-click it in blueman-manager → **Pair** (and **Remove**
   it first if Pair fails), or from a terminal:

   ```sh
   addr=$(bluetoothctl devices | awk '/MX Master/ {print $2; exit}')
   bluetoothctl remove "$addr"
   bluetoothctl --timeout 20 scan on        # wait for "MX Master 4 B"
   addr=$(bluetoothctl devices | awk '/MX Master/ {print $2; exit}')   # may change after remove
   bluetoothctl pair "$addr"
   bluetoothctl trust "$addr"
   bluetoothctl connect "$addr"
   ```

No passkey prompt is expected for a mouse. **Clicking Connect again does not
help**: it reopens the same unencrypted link.

## Verified end state (2026-10-30)

```
$ bluetoothctl info <addr> | grep -E 'Paired|Bonded|Trusted|Connected|Battery'
	Paired: yes
	Bonded: yes
	Trusted: yes
	Connected: yes
	Battery Percentage: 0x46 (70)

$ journalctl -k | grep 'MX Master'
13:52:16 kernel: input: MX Master 4 B Mouse as /devices/virtual/misc/uhid/0005:046D:B048.001A/input/input51
13:52:16 kernel: hid-generic 0005:046D:B048.001A: input,hidraw1: BLUETOOTH HID v0.16 Mouse [MX Master 4 B] on <adapter>

$ swaymsg -t get_inputs -r | jq -r '.[] | select(.type=="pointer") | .identifier'
1133:45128:MX_Master_4_B_Mouse
```

After that, no more `unlikely error` lines.

The sway identifier `1133:45128:MX_Master_4_B_Mouse` (USB IDs `046d:b048`) is
what an `input "…" { … }` block in `sway/config` would match, for example to
change pointer speed or scroll settings.

## After a reboot or sleep

**Verified 2026-11-02:** it reconnected by itself after a reboot (boot
09:29:39, `input: MX Master 4 B Mouse` at 09:42:26, still `Paired`/`Bonded`).
Move or click it once to wake it.

- It won't work at the LUKS prompt or the gdm login screen until Bluetooth has
  started. Use the laptop keyboard or the Voyager there.
- **The pairing belongs to one Easy-Switch channel.** On another channel the
  mouse tries to reach that channel's host. Press the button to switch back.
- Pairing **replaced** whatever host that channel was paired with before.
  That other computer has to pair again.

If it doesn't come back:

```sh
bluetoothctl info "$(bluetoothctl devices | awk '/MX Master/ {print $2; exit}')" | grep -E 'Paired|Connected'
```

- `Paired: yes`, `Connected: no`: click the mouse, or switch it back to the
  right channel.
- `Paired: no`: the pairing was lost. Pair again as above.

## Not checked

- The kernel handles it with **`hid-generic`**, not `hid-logitech-hidpp`.
  Basic pointing, clicks and scrolling work. The thumbwheel, side buttons,
  gesture button and smooth (hi-res) scrolling were not tested.
- Reconnecting after suspend (a reboot is verified, see above).

## How to undo it

```sh
bluetoothctl remove "$(bluetoothctl devices | awk '/MX Master/ {print $2; exit}')"
```

This deletes the pairing key. The mouse's channel keeps its own half until it's
paired again.

## Dead ends

| Tried / theory | Why it's wrong |
|---|---|
| Connect again in blueman | Opens the same unpaired link, and the HID reads fail the same way |
| `Trusted: yes` means it's set up | Trusted only allows automatic connects. It is not paired or bonded |
| Radio blocked / adapter off | `rfkill`: not blocked. Adapter `Powered: yes` |
