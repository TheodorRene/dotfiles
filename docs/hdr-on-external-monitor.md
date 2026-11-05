# HDR on the external LG monitor needs sway 1.12 (Ubuntu 26.04 ships 1.11)

**Status: Nothing applied.** Investigated 2026-11-02 on kernel `7.0.0-1017-oem`,
sway 1.11-3, wlroots 0.19.2, Mesa 26.0.8. Everything was read-only; the upgrade
path below is written down but deliberately not taken.

**Summary:** the LG monitor advertises HDR10, and the GPU, driver and cable
can all carry it. **The only blocker is sway**: 1.11 can't signal HDR.
HDR10 output arrived in sway 1.12 (with wlroots 0.20) and needs the Vulkan
renderer. The laptop panel is SDR-only, so this is about the LG alone. Also
expect a modest result: the LG is a ~400-nit panel with no sign of local dimming
(DisplayHDR 400 class).

## The chain, link by link

| Link | Verdict | Evidence |
|---|---|---|
| LG monitor (`DP-1`) | **HDR10 capable** | EDID: ST 2084 (PQ) EOTF, BT.2020, 10 bpc input |
| Laptop panel (`eDP-1`) | **No HDR** | DisplayID: sRGB-only colour space/EOTF |
| GPU / driver (`xe`) | **Ready** | `HDR_OUTPUT_METADATA` and `Colorspace` (incl. `BT2020_RGB`) on the DP connector |
| Cable / link | **Ready, with little headroom** | HBR2 × 4 lanes = 17.28 Gbit/s; 4K60 10-bit needs 16.0 |
| Vulkan | **Available, not in use** | Mesa Intel driver sees the GPU; sway runs GLES2 |
| sway 1.11 | **Blocker** | no `hdr` output option, no colour-management protocol |

### The LG monitor's EDID

`swaymsg -t get_outputs` reports `DP-1` as `LG Electronics` / `LG ULTRAFINE`,
3840×2160 @ 59.997 Hz, scale 1.5. `edid-decode /sys/class/drm/card1-DP-1/edid`:

```
    Manufacturer: GSM
    Model: 23740
    Made in: week 5 of 2026
    Bits per primary color channel: 10
    Display Product Name: 'LG ULTRAFINE'
  Colorimetry Data Block:
    BT2020YCC
    BT2020RGB
  HDR Static Metadata Data Block:
    Electro optical transfer functions:
      Traditional gamma - SDR luminance range
      SMPTE ST2084
    Supported static metadata descriptors:
      Static metadata type 1
    Desired content max luminance: 96 (400.000 cd/m^2)
    Desired content max frame-average luminance: 96 (400.000 cd/m^2)
    Desired content min luminance: 80 (0.394 cd/m^2)
```

So it accepts HDR10 (PQ + BT.2020, static metadata type 1). It does not list HLG.
Max and frame-average are both 400 nits, so the whole screen can reach peak at
once, which suggests no local dimming (theorised from the numbers, not
confirmed against LG's spec sheet). Expect HDR10 compatibility rather than
bright highlights or deeper blacks; desktop content mapped into HDR on a panel
like this often looks no better than SDR.

**Not verified:** that this EDID identity is the monitor `agents.md` calls the
**LG 27U730A**. The EDID gives only the name `LG ULTRAFINE` and the product
code 23740.

### The laptop panel's EDID

Sharp `LQ140N1`, 1920×1200 @ 120 Hz. It uses a DisplayID 2.0 extension instead
of a CTA block. `edid-decode /sys/class/drm/card1-eDP-1/edid`:

```
    Red  : 0.6396, 0.3300
    Green: 0.2998, 0.5996
    Blue : 0.1503, 0.0595
    White: 0.3134, 0.3291
    Native Maximum Luminance (Full Coverage): 500.000000 cd/m^2
    Native Minimum Luminance: 0.250000 cd/m^2
    Native Color Depth: 10 bpc
    Native Gamma EOTF: 2.20
    Supported color space and EOTF standard combination 1: sRGB
```

The primaries are sRGB and the only colour space/EOTF combination is sRGB, so
this panel can't do HDR. Its connector exposes the same HDR properties as DP-1,
but that's the driver adding them to every port, not the panel. `edid-decode`
also reports `EDID conformity: FAIL`. The base block claims sRGB with
chromaticities that don't quite match, and a text field has a non-printable
byte. That's cosmetic.

### GPU and driver

`drm_info` (`xe` driver, "Intel Xe2 Graphics"; `vulkaninfo` names the device
"Intel(R) Graphics (PTL)"). On the DisplayPort connector:

```
"max bpc": range [6, 12] = 8
"Colorspace": enum {Default, …, BT2020_CYCC, BT2020_RGB, BT2020_YCC, DCI-P3_RGB_D65, …} = Default
"HDR_OUTPUT_METADATA": blob = 0
```

The properties exist and are at their defaults, so no HDR signal is going out
now. `max bpc = 8` means the link currently runs 8-bit. HDR would need
`render_bit_depth 10`.

### Cable and link

Connected over DisplayPort (USB-C → DP cable). The configured link rate and lane
count come from the link sink's DPCD registers `0x100`–`0x101` (root-only; the
DP AUX device is `0600 root`, and the Type-C sysfs exposes no usable pin
assignment here):

```
$ sudo dd if=/dev/drm_dp_aux1 bs=1 skip=256 count=2 status=none | xxd
00000000: 1484
```

`14` = HBR2 (5.4 Gbit/s per lane), `84` = 4 lanes (plus the `0x80`
enhanced-framing bit). That's 4 × 5.4 × 0.8 = **17.28 Gbit/s** of payload. 4K60
at 10-bit is 533.25 MHz × 30 bits = **16.0 Gbit/s**, about 93% of the link. It
fits without DSC, which the EDID doesn't seem to advertise anyway.

**Gotcha:** 4K60 working is *not* proof of 4 lanes. 8-bit 4K60 (12.8 Gbit/s)
squeezes onto 2 lanes of HBR3 (12.96). Only 10-bit needs the 4 lanes. The
2-lane USB-C hubs and the HDMI adapter (see
`usb-c-displays-disconnect-and-kernel-options.md`) can't carry it. `aux1`
is the one under `/sys/class/drm/card1-DP-1/`; re-check that mapping if the
connector changes.

### Renderer

sway runs the default **GLES2** renderer. `WLR_RENDERER` is unset in its
environment, and its process has `libEGL_mesa`, `libGLESv2` and `libgallium`
mapped, but not the Intel Vulkan driver. Vulkan itself is fine:
`mesa-vulkan-drivers` 26.0.8 is installed, `vulkaninfo --summary` lists the GPU
with Vulkan 1.4, and `libwlroots-0.19` contains the Vulkan renderer
(`render/vulkan/renderer.c`).

What Vulkan gives: on 1.11, ICC profiles via `output … color_profile icc …`
(believed Vulkan-only; not checked in the man page). On 1.12, HDR10 output and
the colour-management protocol, so apps such as mpv can say what colour space
their content is in instead of everything being treated as sRGB. On its own it
doesn't change appearance or speed. GLES2 is the more tested renderer, so
Vulkan is where odd bugs (screen sharing, screenshots, suspend) are more likely.

### sway

`sway --version` is 1.11. The binary has the strings `render_bit_depth` and
`color_profile` but no `hdr` and no colour-management symbols, and
`get_outputs` reports no `hdr` field. wlroots 0.19.2 does contain
`wp_color_management_v1`, but sway 1.11 doesn't use it.

Upstream: sway 1.12-rc1 came out 2026-03-26, and the final 1.12 in late May 2026,
built on wlroots 0.20. Its headline feature is HDR10 output, Vulkan renderer only.
Debian took 1.12-1 into unstable on 2026-05-25 and testing on 2026-06-08.
**Ubuntu 26.04 (resolute) stays on 1.11-3**, and as a universe package on an LTS
it's unlikely to be bumped. **26.10 (stonking) has sway 1.12-1 and
libwlroots-0.20 0.20.2-1.**

## Testing HDR without upgrading sway

Not possible inside sway 1.11, because nothing it runs can make the monitor
switch into HDR. Two things already installed can test it:

1. **The GNOME session.** `ubuntu-session` and GNOME Shell 50.1 are
   installed, and GNOME has had an HDR switch since 48. Log out of sway, pick
   **Ubuntu** at the login screen, then Settings → Displays → LG → HDR. The sway
   config isn't touched.
2. **mpv straight to the display from a text console.** Ctrl+Alt+F3, log in,
   then:
   ```
   mpv --vo=gpu-next --gpu-context=drm --target-colorspace-hint=yes hdr10-sample.mkv
   ```
   mpv 0.41 is installed. **Not verified** on `xe`. Needs an HDR10 (PQ/BT.2020)
   sample file.

**Proof that it worked:** LG monitors usually show an HDR badge, or grey out
some picture settings in the on-screen menu, when they receive HDR. Trust that
over how the picture looks.

## The fix: sway 1.12 from 26.10, pinned (not applied)

Every dependency of 26.10's `sway` 1.12-1 and `libwlroots-0.20` 0.20.2-1 is
already met by 26.04, so only those two packages would come from 26.10. Checked
2026-11-02 against packages.ubuntu.com's Depends lists. Examples:

| Dependency | 26.10 needs | Installed |
|---|---|---|
| libc6 | ≥ 2.38 (wlroots), ≥ 2.34 (sway) | 2.43-2ubuntu2.4 |
| libdisplay-info3 | ≥ 0.3.0 | 0.3.0-1 |
| libdrm2 | ≥ 2.4.129 | 2.4.131-1 |
| libwayland-server0 | ≥ 1.24.0 | 1.24.0-2 |
| libinput10 | ≥ 1.26.0 | 1.31.1-1ubuntu1.2 |
| libxkbcommon0 | ≥ 1.8.0 | 1.13.1-1 |
| libpixman-1-0 | ≥ 0.44.0 | 0.46.4-1 |
| libliftoff0 | ≥ 0.4.1 | 0.5.0-1.1build1 |
| libseat1 | ≥ 0.5.0 | 0.9.2-2 |

Add the 26.10 suite at low priority so nothing upgrades from it on its own,
then pull just sway:

```
sudo tee /etc/apt/sources.list.d/stonking.sources <<'EOF'
Types: deb
URIs: http://dk.archive.ubuntu.com/ubuntu/
Suites: stonking
Components: main universe
EOF

sudo tee /etc/apt/preferences.d/stonking-pin <<'EOF'
Package: *
Pin: release n=stonking
Pin-Priority: 100
EOF

sudo apt update
apt policy sway libwlroots-0.20               # 1.12-1 / 0.20.2-1 listed from stonking; installed sway still 1.11-3
sudo apt install --simulate sway/stonking     # must pull only sway + libwlroots-0.20; if more, stop
sudo apt install sway/stonking
sway --validate                               # before logging out — 1.12 may reject parts of the config
```

Then, in the sway session:
- start sway with `WLR_RENDERER=vulkan` in its environment (takes effect at the
  next login);
- `output DP-1 render_bit_depth 10` and `output DP-1 hdr on`. **The exact syntax
  is unverified**; check `man 5 sway-output` on 1.12.

Optionally, try `WLR_RENDERER=vulkan` on 1.11 first for a few days. It already
works there. If screen sharing and suspend still behave, the upgrade is the only
change left for HDR.

Costs:
- **Security updates** for these two packages come only from 26.10, which is
  supported until about July 2027. After that they're frozen. Mixing releases
  is officially unsupported.
- **Not tracked by this repo**: the two files under `/etc/apt/` are in-place
  edits. Re-create them after a reinstall, or move them under `etc/` with an
  installer script.

Other routes, not chosen:
- **Building from source**, with wlroots 0.20 as a meson subproject and installed
  to a separate prefix. It keeps Ubuntu's packages untouched, but it's more work
  and gets no updates.
- **Upgrading the whole OS to 26.10.** It's non-LTS, with nine months of support.
- **Nix.** A Nix-built compositor on non-NixOS struggles to find the system
  GPU/Vulkan drivers (it needs nixGL or similar).

## How to reverse it

```
sudo apt install sway/resolute
sudo rm /etc/apt/sources.list.d/stonking.sources /etc/apt/preferences.d/stonking-pin
sudo apt update
sudo apt autoremove        # drops libwlroots-0.20
```

`libwlroots-0.19` and `-0.20` can be installed side by side, so the downgrade
doesn't fight over files. Remove `hdr`/`render_bit_depth` and `WLR_RENDERER` from
the config and environment if they were added.

## Verified vs theorised

- **Verified:** the LG's HDR10 EDID; the panel's sRGB-only EDID; the `xe` HDR
  connector properties; the HBR2 × 4 link; sway 1.11 has no HDR option; sway runs
  GLES2; the Vulkan driver works; 26.10's packages depend on nothing newer than
  26.04 has.
- **Theorised / not checked:** no local dimming on the LG; that the `xe` driver
  actually sends the HDR metadata once a compositor sets it (no HDR session has
  been run); the mpv text-console test; the exact 1.12 config syntax; that the
  `--simulate` install really pulls only two packages (needs the suite added
  first); that ICC profiles are Vulkan-only on 1.11.
