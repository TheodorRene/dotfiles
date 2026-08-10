# æ ø å on a US layout (Voyager + sway) — plan, not yet applied

**Status: nothing here is applied.** `sway/config` is untouched and the Voyager
firmware is unchanged. This is the write-up so it can be done in one sitting
later. Written 2026-08-03.

## The problem

Goal: stay on a **US layout** (so `'`, `` ` ``, `;` stay where vim, the shell and
every muscle memory expect them) while typing Norwegian often — there's even a
bokmål spell dictionary in `nvim_v2/spell/nb.utf-8.add`.

Today's state, and why the current keymap can't deliver that:

- `sway/config` sets
  `xkb_layout "us,no"` / `xkb_variant ",nodeadkeys"` /
  `xkb_options "ctrl:nocaps,grp:alt_shift_toggle,compose:ralt"`.
- Right Alt is therefore **Compose (`Multi_key`)**, not AltGr.
- But the Voyager's layer-1 keys send `RALT(LSFT(KC_A))`, `RALT(KC_QUOTE)`,
  `RALT(KC_O)` (`keymap.c:299-322` in the Oryx source export) — i.e. they assume AltGr. With
  `compose:ralt` those chords open a compose sequence instead of emitting a
  letter, so the three dedicated Nordic keys don't work.
- Which leaves the `us,no` group toggle as the only real path — and
  `grp:alt_shift_toggle` is the part to get rid of (see below).

## The fix, in two halves

### 1. Host: switch to `us(altgr-intl)`, single group

```diff
 input type:keyboard {
-    xkb_layout "us,no"
-    xkb_variant ",nodeadkeys"
-    xkb_options "ctrl:nocaps,grp:alt_shift_toggle,compose:ralt"
+    xkb_layout "us"
+    xkb_variant "altgr-intl"
+    xkb_options "ctrl:nocaps,compose:menu"
 }
```

Then `swaymsg reload` (safe — no session restart needed). `sway --validate -c
sway/config` passed on this diff when it was tried.

Why this variant, from `/usr/share/X11/xkb/symbols/us`: `altgr-intl` is
`include "us(intl)"` plus overrides that move the dead keys up to level 3 —
crucially `key <TLDE> { [grave, asciitilde, dead_grave, dead_tilde] }` and
`key <AC11> { [apostrophe, quotedbl, dead_acute, dead_diaeresis] }`. So the
base and shift levels are **plain US** (`'` and `` ` `` are ordinary
characters, unlike plain `us(intl)` where they're dead keys), and it inherits
the AltGr level from `us(intl)`:

| Chord | Letter | xkb key |
|---|---|---|
| AltGr+`z` / AltGr+Shift+`z` | æ / Æ | `AB01` |
| AltGr+`w` / AltGr+Shift+`w` | å / Å | `AD02` |
| AltGr+`l` / AltGr+Shift+`l` | ø / Ø | `AC09` |

This is resolved in the compositor, so it works in Wayland apps, XWayland,
terminals and Electron alike — no per-app input-method support needed.

Two consequences of the diff:

- `altgr-intl` ends with `include "level3(ralt_switch)"`, so **Right Alt must be
  AltGr** and `compose:ralt` has to go. `compose:menu` is inert until some key
  sends `KC_APP` — either bind one on Voyager layer 2, or pick
  `compose:prsc` / `compose:rwin` instead (note `prsc` is currently the
  `5`-hold screenshot key).
- Dropping the second group also drops `grp:alt_shift_toggle`. That's the
  point: `$mod` is `Mod4`, so sway bindings were never triggering it — the
  likely culprit is the Voyager's home-row mods, where `S` is Alt and `D`/`K`
  are Shift, so a fast roll can register Alt+Shift and silently flip the layout
  to Norwegian mid-word.

### 2. Oryx: remap three keys (+ one unrelated fix)

Layout: <https://configure.zsa.io/voyager/layouts/ZRY0e/orDvzZ/0>

On **layer 1**, each Nordic key becomes a plain letter with the **Right Alt**
modifier ticked:

| Key (current) | New | Gives |
|---|---|---|
| Å — row 2, right pinky | `W` + Right Alt | å (Å with Shift) |
| æ — row 3, right pinky | `Z` + Right Alt | æ (Æ with Shift) |
| ø — row 3, far right | `L` + Right Alt | ø (Ø with Shift) |

The æ and ø keys are currently **dual-function** keys (`DUAL_FUNC_10/11`), so
clear the dual-function setting before assigning the plain key. Tap/hold for
case is no longer needed — `us(altgr-intl)` puts the capitals on level 4, so
AltGr+Shift gives the uppercase letter, with Shift coming from the left
home-row `D`. If the one-tap-per-case feel is preferred, keep them as
dual-function with `RALT(KC_W)` on tap and `RALT(LSFT(KC_W))` on hold.

While in Oryx, also fix **layer 0**: the top-row key right of `9` sends `KC_S`
(`keymap.c:30` in that export), so `0` doesn't exist on the base layer and `S` is
duplicated. Set it to `0`.

Then Compile → flash from Oryx or Keymapp. The repo doesn't track the firmware
source, but Oryx's **Download source** zip is the readable form of a layout if
it needs inspecting or diffing later:

```sh
unzip -j ~/Downloads/zsa_voyager_*_source.zip '*_source/keymap.c' -d /tmp/voyager
```

## Order of operations

1. Apply the sway diff, `swaymsg reload`.
2. Test `AltGr+z` → æ on the **laptop's internal keyboard**. The Voyager can't
   test it until step 3, because nothing on it currently sends a bare Right Alt.
3. Do the Oryx remap, compile, flash.

Between 1 and 3 the three layer-1 Nordic keys are dead (they were already
broken, just differently), and the `us,no` group toggle is gone — so no
Norwegian at all in that window. Don't start this right before writing Norwegian.

## Fallback if the host config should stay as-is

`compose:ralt` already works today; the system table has the sequences
(`/usr/share/X11/locale/en_US.UTF-8/Compose`):

| Sequence | Letter | Line |
|---|---|---|
| `Compose` `a` `e` | æ | 106 |
| `Compose` `/` `o` | ø | 507 |
| `Compose` `a` `a` | å | 430 |

An Oryx **macro** that taps `RAlt`, then `a`, then `e` collapses that into one
keypress, so layer 1 ends up feeling the same with zero sway changes. Weaker
only in that compose is client-side: GTK/Qt/kitty/Firefox honour it, some
Electron and Java apps don't. `us(altgr-intl)` is the more robust of the two.

QMK's Unicode keycodes are a third option, but Oryx doesn't expose them and the
Linux mode wants ibus — not worth it.

## Checked: no fallout in nvim

All 18 `<A-…>` maps (`nvim_v2/lua/config/keymaps.lua:71-204`,
`lua/config/lsp.lua:42,98`) fire on **Left** Alt, which the diff doesn't touch.
Right Alt was `Multi_key` before and becomes AltGr after — it never produced
Meta either way, so nothing loses a way of being pressed. The Voyager's
right-hand home-row Alt is `MT(MOD_LALT, KC_L)` (`keymap.c:32`) —
deliberately *Left* Alt — so Alt from either hand still reaches nvim as Meta.

`'` and `` ` `` stay ordinary characters under `altgr-intl`, so marks and
backtick jumps are safe (plain `us(intl)` would have broken them). The only new
behaviour is that RAlt+letter emits a character in insert mode; no mapping in
the config has a non-ASCII left-hand side. Spell files are layout-independent.

## Appendix: the layout as of 2026-08-03

From the Oryx source export (`zsa_voyager_ZRY0e_orDvzZ_bonvoyage_source`); the
repo doesn't keep a copy, so re-download from Oryx if the details matter.
Tunables: `TAPPING_TERM 170` · `RGB_MATRIX_TIMEOUT 300 s` ·
`MOUSEKEY_TIME_TO_MAX 30` · dynamic tapping term enabled (adjustable from
layer 2).

**Layer 0 — base**

```
Esc     1       2       3ᵃ      4ᵇ      5ᶜ     │  6       7       8       9       S⁉     /
Tab     Q       W       E       R       T      │  Y       U       I       O       P      /ᵈ
Play    A⌘      S⌥      D⇧      F⌃      G      │  H       J⌃      K⇧      L⌥      ;⌘     '
Nextᵉ   Z       X       Cᶠ      Vᵍ      B      │  N       M       ,       .       -      TT(2)
                            Enter   MO(1)      │  Bspc    Space
```

Home-row mods (hold): `A`=Super `S`=Alt `D`=Shift `F`=Ctrl │ `J`=Ctrl `K`=Shift
`L`=Alt `;`=Super — the right-hand Alt is deliberately **left** Alt, so it never
collides with AltGr. Tap/hold keys: `ᵃ 3 / Ctrl+Shift+C` · `ᵇ 4 / Ctrl+Shift+V` ·
`ᶜ 5 / PrintScreen` · `ᵈ / (slash) / \` · `ᵉ Next track / Prev track` ·
`ᶠ C / Ctrl+C` · `ᵍ V / Ctrl+V`. `⁉` is the missing-`0` slip described above.

**Layer 1 — symbols + numpad** (hold right thumb `MO(1)`)

```
Esc     !       "       #       ~       %      │  ▽       7       8       9       ?      `
`       |       @       :       $       %      │  ~       4       5       6       Å      '
#       ^       &       *       (ⁱ      )      │  ▽       1       2       3       æ      ø
<       >       [ˡ      ]       {ᵐ      }      │  ▽       -       0       +       =      Enter
                            ▽       ▽          │  ▽       ▽
```

`ⁱ ( / )` · `ˡ [ / ]` · `ᵐ { / }` — tap opens, hold closes. Å/æ/ø are the three
broken keys this document is about.

**Layer 2 — nav / mouse / media** (`TT(2)`, `Esc` returns via `TO(0)`)

```
TO(0)   F1      F2      ▽       ▽       ▽      │  MacLock Prev    Play    Next    Vol+   TT↑
Zoom+   ▽       LMB     MS↑     RMB     Wh↑    │  Home    PgUp    PgDn    End     Vol-   TT↓
Zoom−   ▽       MS←     MS↓     MS→     Wh↓    │  ←       ↓       ↑       →       Mute   TT?
▽       ▽       ▽       ▽       ▽       ▽      │  ▽       ⇧⌃Tab   ⌃Tab    ▽       ▽      ▽
                            LMB     ▽          │  ▽       ▽
```

`Zoom±` = `Super +` / `Super −`; `TT↑ / TT↓ / TT?` are the dynamic tapping-term
controls (print types the current value out).

**Why the `LT(n, …)` layer numbers look wrong.** The `DUAL_FUNC_*` macros are
`LT(3, …)`, `LT(14, …)` and so on, referring to layers that don't exist. That's
an Oryx idiom: `LT` is used only to get tap/hold detection, and
`process_record_user` intercepts each keycode and returns `false` before any
layer switch happens. The layer numbers are inert.
