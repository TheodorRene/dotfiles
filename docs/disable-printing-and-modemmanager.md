# Turning off printing and ModemManager

**Status: APPLIED 2026-09-03.** Both printing and ModemManager are disabled and
the `cups` snap is removed. Verified state at the bottom. Findings measured the
same day. Kept as a record of what was turned off and how to reverse it.

Both are daemons servicing hardware this machine doesn't use. Neither is a big
win on its own (~112 MB of RSS plus some boot-time device probing); the reason to
do it is that both are *also* doing background network/device discovery you never
asked for.

## Printing

### What's actually running

**Two complete CUPS stacks**, deb and snap, simultaneously:

| unit | RSS |
|---|---|
| `snap.cups.cupsd.service` | 60.6 MB |
| `cups-browsed.service` | 18.1 MB |
| `cups.service` | 14.7 MB |
| `snap.cups.cups-browsed.service` | 7.9 MB |
| **total** | **~101 MB** |

`lpstat -p` reports two printers — a Brother DCP-L8410CDW and an Epson ET-5170.
**Neither was deliberately added.** `/etc/cups/cups-browsed.conf` has:

```
BrowseRemoteProtocols dnssd
```

so `cups-browsed` auto-creates a queue for every printer it hears advertised over
mDNS on whatever network you're attached to. That's where they came from, and it's
why they'll come back if you only delete the queues.

### Disabling it — what was run

The socket and path units matter — disabling `cups.service` alone leaves it
**socket-activated**, so it restarts the moment anything touches the CUPS socket:

```bash
sudo systemctl disable --now cups.service cups.socket cups.path cups-browsed.service
sudo snap remove cups
```

`snap remove cups` took care of both `snap.cups.*` units — they no longer appear
in `systemctl list-unit-files` at all. The four deb units remain listed but are
`disabled`, which is the expected end state (the package is still installed).

If you ever want it back: `sudo systemctl enable --now cups.socket cups-browsed`
(the socket is enough — it'll pull in the service on demand).

### Optional: avahi

`avahi-daemon` (2.4 MB) is what feeds `cups-browsed` its mDNS discovery. With
printing gone it has little left to do on this machine, but it's *not* printer-only
— it also backs `.local` hostname resolution and some device/network discovery.
Leave it unless you have a reason; the 2.4 MB isn't the point.

## ModemManager

### What it is

A daemon that discovers and drives **cellular/WWAN modems** — built-in 4G/5G
laptop cards, USB broadband dongles, some serial modems. It's part of the
NetworkManager stack: NM delegates anything cellular to it, so a machine with a
SIM slot gets mobile-broadband connections in the normal network UI.

To find hardware, it **probes serial, USB and PCI devices at startup**, speaking
AT commands at anything that might answer. That probing is the reason it has a
long-standing reputation for interfering with USB-serial devices — Arduinos,
ESP32s, debug UARTs — which it can grab and confuse while deciding whether they're
modems.

### Why it's pointless here

There is no WWAN hardware at all:

```
$ mmcli -L
No modems were found

$ lspci | grep -iE 'modem|wwan|cellular'   # nothing
$ lsusb | grep -iE 'modem|wwan|cellular'   # nothing
$ ls /sys/class/net/
docker0  enx9405bb11cf26  lo  wlp0s20f3     # wifi + a USB ethernet dongle only
```

It costs 10.8 MB and probes devices at every boot to rediscover that there's
nothing to manage.

### Disabling it — what was run

```bash
sudo systemctl disable --now ModemManager.service
```

Nothing depends on it except `multi-user.target` — NetworkManager works fine
without it and simply stops offering mobile-broadband. Re-enable with
`sudo systemctl enable --now ModemManager` if a USB WWAN dongle ever shows up.

## Combined effect

~112 MB of RSS, a handful of boot-time device probes, and no more printer queues
silently appearing from whatever network you join. This is tidying, not a speed
fix — see [boot-time-budget.md](boot-time-budget.md) for the changes that actually
move the needle.

## Verified end state (2026-09-03)

```
$ systemctl is-active ModemManager   -> inactive
$ systemctl is-enabled ModemManager  -> disabled

$ systemctl is-active/is-enabled cups.service cups.socket cups.path cups-browsed.service
   all -> inactive / disabled

$ snap list cups
error: no matching snaps installed

$ lpstat -p
lpstat: Scheduler is not running.
```

`lpstat` reporting "Scheduler is not running" is the confirmation that the
auto-discovered Brother and Epson queues are gone with it.

**If printing is ever needed again**, `cups.socket` alone is enough — it pulls in
the service on demand:

```bash
sudo systemctl enable --now cups.socket cups-browsed.service
```

Expect the mDNS-discovered queues to reappear on their own; that is
`cups-browsed` doing what it is configured to do, not a leftover.
