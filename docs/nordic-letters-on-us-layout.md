# Typing æ ø å on the Voyager without leaving the US layout

**Status:** Nothing applied. Plan written 2026-08-03, revised 2026-10-16: the
laptop keyboard now keeps its Norwegian layout, and the "will Alt break?"
question is checked against compiled keymaps. `sway/config`, waybar and the
Voyager firmware are all unchanged.

## The problem

Goal: the Voyager on a **US layout** (so `'`, `` ` ``, `;` stay where vim, the
shell and muscle memory expect them) while typing Norwegian often. There's even
a bokmål spell dictionary in `nvim_v2/spell/nb.utf-8.add`. **The laptop's
built-in keyboard stays Norwegian**: the user still types `no` on it (stated
2026-10-16), so the change has to be per-device, not global.

Today's state, and why the current keymap can't deliver that:

- `sway/config:39-43` sets, for **every** keyboard (`input type:keyboard`),
  `xkb_layout "us,no"` / `xkb_variant ",nodeadkeys"` /
  `xkb_options "ctrl:nocaps,grp:alt_shift_toggle,compose:ralt"`.
- Right Alt is therefore **Compose (`Multi_key`)**, not AltGr.
- But the Voyager's layer-1 keys send `RALT(LSFT(KC_A))`, `RALT(KC_QUOTE)`,
  `RALT(KC_O)` (`keymap.c:299-322` in the Oryx source export), which assumes
  AltGr. With `compose:ralt` those chords open a compose sequence instead of
  emitting a letter, so the three dedicated Nordic keys don't work.
- **The layout switch is shared between the two keyboards.** sway's default
  `keyboard_grouping smart` groups keyboards "by their keymap and repeat info"
  and "the effective layout is synced between the keyboards in the group"
  (sway-input(5), 1.11). Both keyboards have the same keymap today, so switching
  the laptop to `no` switches the Voyager too. `swaymsg -t get_inputs` on
  2026-10-16: all 14 keyboard-type devices list
  `['English (US)', 'Norwegian (no dead keys)']`.
- **`grp:alt_shift_toggle` is on three keys, not one.** In the compiled keymap
  `ISO_Next_Group` sits on level 2 of `LALT`, `LFSH` *and* `RTSH`, so Alt then
  Shift, or Shift then Alt, switches layout. *Theorised, never observed:* the
  Voyager's home-row mods (`S` = Alt, `D`/`K` = Shift) firing this on a fast
  roll and flipping to Norwegian mid-word.

## The fix, in two halves

### 1. Host: the Voyager on `us(altgr-intl)`, the laptop unchanged

```diff
 input type:keyboard {
-    xkb_layout "us,no"
-    xkb_variant ",nodeadkeys"
-    xkb_options "ctrl:nocaps,grp:alt_shift_toggle,compose:ralt"
+    xkb_layout "us"
+    xkb_variant "altgr-intl"
+    xkb_options "ctrl:nocaps,compose:menu"
+}
+
+# Laptop keyboard keeps US/Norwegian with the Alt+Shift toggle (more specific, so it wins)
+input "1:1:AT_Translated_Set_2_keyboard" {
+    xkb_layout "us,no"
+    xkb_variant ",nodeadkeys"
+    xkb_options "ctrl:nocaps,grp:alt_shift_toggle,compose:ralt"
 }
```

Then `swaymsg reload` (safe; no session restart, and it restarts waybar through
the `exec_always` line). **`sway --validate` passed on this exact diff on
2026-10-16.**

**Why the Voyager gets the `type:` block and the laptop gets its own, not the
other way round:** the laptop is one device with a stable identifier. The
Voyager shows up as **four** keyboard devices (`12951:6519:ZSA_Technology_Labs_Voyager`,
`…_Voyager_Keyboard`, `…_Consumer_Control`, `…_System_Control`), and which one
carries the letter keys isn't established. Side effect: any other external
keyboard also gets `us(altgr-intl)`, which is plain US for normal and Shift
typing.

**Precedence.** sway-input(5), 1.11: "In the configuration file, settings with
a more specific selector take precedence over more general ones:
*<identifier>* > *type:<input_type>* > *\**." So the order of the two blocks in
the file doesn't matter. **Gotcha:** that holds for the file only. "When
executing input commands, however, the settings are applied to all matching
input devices! This means that *type:<input_type>* can override previously set
*<identifier>* settings." That matters for the live trial below.

Once the keymaps differ, the two keyboards fall into different groups, so **the
laptop's toggle no longer touches the Voyager**.

*Not decided:* if the laptop is only ever used as `no`, never `us`, its block
can be just `xkb_layout "no"` / `xkb_variant "nodeadkeys"`, dropping
`grp:alt_shift_toggle` there too.

Why this variant, from `/usr/share/X11/xkb/symbols/us`: `altgr-intl` is
`include "us(intl)"` plus overrides that move the dead keys up to level 3,
crucially `key <TLDE> { [grave, asciitilde, dead_grave, dead_tilde] }` and
`key <AC11> { [apostrophe, quotedbl, dead_acute, dead_diaeresis] }`. So normal
and Shift typing are **plain US** (`'` and `` ` `` are ordinary characters,
unlike plain `us(intl)` where they're dead keys), and it inherits the AltGr
level from `us(intl)` (re-checked in the file 2026-10-16):

| Chord | Letter | xkb key |
|---|---|---|
| AltGr+`z` / AltGr+Shift+`z` | æ / Æ | `AB01` |
| AltGr+`w` / AltGr+Shift+`w` | å / Å | `AD02` |
| AltGr+`l` / AltGr+Shift+`l` | ø / Ø | `AC09` |

This is resolved in the compositor, so it works in Wayland apps, XWayland,
terminals and Electron alike. No per-app input-method support is needed.

Two consequences for the Voyager:

- `altgr-intl` ends with `include "level3(ralt_switch)"`, so **Right Alt must be
  AltGr** and `compose:ralt` has to go there. `compose:menu` is inert until some
  key sends `KC_APP`: either bind one on Voyager layer 2, or pick
  `compose:prsc` / `compose:rwin` instead (`prsc` is currently the `5`-hold
  screenshot key).
- The Voyager loses the `us,no` toggle. That's the point; it keeps the
  home-row-roll theory above from mattering.

### 1b. Waybar's layout indicator has to follow the laptop

`custom/language` (`waybar/config:178-183`) runs `scripts/waybar-layout.sh`,
which reports `first(.[] | select(.type=="keyboard"))`. Today that is a Voyager
device: `12951:6519:ZSA_Technology_Labs_Voyager_Consumer_Control` is first in
`get_inputs`. After the split it would always say `US`. Point it at the laptop:

- `scripts/waybar-layout.sh`: `select(.identifier=="1:1:AT_Translated_Set_2_keyboard")`
  instead of `select(.type=="keyboard")`.
- `on-click`: `swaymsg input 1:1:AT_Translated_Set_2_keyboard xkb_switch_layout next`.
  What the current `type:keyboard` form does after the split is untested.

`waybar/config` usually has unrelated pending edits; change only that line.

### 2. Oryx: remap three keys (+ one unrelated fix)

Layout: <https://configure.zsa.io/voyager/layouts/ZRY0e/orDvzZ/0>

On **layer 1**, each Nordic key becomes a plain letter with the **Right Alt**
modifier ticked:

| Key (current) | New | Gives |
|---|---|---|
| Å, row 2, right pinky | `W` + Right Alt | å (Å with Shift) |
| æ, row 3, right pinky | `Z` + Right Alt | æ (Æ with Shift) |
| ø, row 3, far right | `L` + Right Alt | ø (Ø with Shift) |

The æ and ø keys are currently **dual-function** keys (`DUAL_FUNC_10/11`), so
clear the dual-function setting before assigning the plain key. Capitals then
come from Shift on the left home-row `D` (layer thumb + `D` + the key), since
`us(altgr-intl)` puts them on level 4. If that three-key chord is awkward with
home-row mods, keep them as dual-function instead: `RALT(KC_W)` on tap,
`RALT(LSFT(KC_W))` on hold, and no Shift needed.

The positions come from the 2026-08-03 export. If the layout has changed since,
find the keys by their labels.

While in Oryx, also fix **layer 0**: the top-row key right of `9` sends `KC_S`
(`keymap.c:30` in that export), so `0` doesn't exist on the base layer and `S`
is duplicated. Set it to `0`.

Then Compile and flash from Oryx or Keymapp. The repo doesn't track the
firmware source, but Oryx's **Download source** zip is the readable form of a
layout if it needs inspecting or diffing later:

```sh
unzip -j ~/Downloads/zsa_voyager_*_source.zip '*_source/keymap.c' -d /tmp/voyager
```

## Will it break Alt in nvim or the terminal? Checked 2026-10-16: no

Both keymaps were compiled from the same rules sway uses and every key was
diffed. (`xkbcli` isn't installed. `xkbcomp` and `setxkbmap` are, from
`x11-xkb-utils`; `-print` only prints, it doesn't apply anything to XWayland.)

```sh
gen(){ setxkbmap -rules evdev -model pc105 -layout "$1" -variant "$2" \
         -option "" -option "$3" -print | xkbcomp -w0 -xkb - "$4"; }
gen us,no ,nodeadkeys ctrl:nocaps,grp:alt_shift_toggle,compose:ralt now.xkb
gen us altgr-intl     ctrl:nocaps,compose:menu                      new.xkb
grep -E 'key <(LALT|RALT)>' -A3 now.xkb new.xkb
```

Levels 1-2 of Group 1 (today's US group vs what the Voyager would get):

| Key | Today | After |
|---|---|---|
| `LALT` | `Alt_L`, `ISO_Next_Group` | `Alt_L` |
| `LFSH` / `RTSH` | `Shift_L`/`Shift_R`, `ISO_Next_Group` | `Shift_L`/`Shift_R` |
| `RALT` | `Multi_key`, `ISO_Next_Group` | `ISO_Level3_Shift` |
| `COMP` (Menu) | `Menu` | `Multi_key` |
| `LSGT` (the ISO `<>` key) | `less`, `greater` | `backslash`, `bar` |
| every other key | | identical |

`modifier_map Mod1 { <LALT> }` in both. What that means:

- **Left Alt is the same `Alt_L` on Mod1.** nvim's `<A-…>` maps, zsh's Alt
  bindings and Alacritty's ESC-prefix for Alt are untouched.
- **Every Alt that works today is already Left Alt**, because today Right Alt is
  `Multi_key` and isn't on Mod1. So nothing that works as Alt now can lose it.
  That includes the right-hand home-row Alt, which is `MT(MOD_LALT, KC_L)`
  (`keymap.c:32`). If it had ever been switched to Right Alt in Oryx, it would
  already not work as Alt in nvim today.
- No nvim mapping uses Alt+Shift (`grep -rnoE "<[AM]-(S-|[A-Z]>)" nvim_v2/lua`
  finds nothing), and `alacritty/`, `zsh/`, `.zshrc` and `sway/config` have no
  Alt or Mod1 references.
- `'` and `` ` `` stay ordinary characters, so marks and backtick jumps are
  safe (plain `us(intl)` would have broken them). The only new behaviour is
  that RAlt+letter types a character in insert mode, and no mapping in the
  config has a non-ASCII left-hand side. Spell files are layout-independent.
- **Home-row mods:** the three new keys send RAlt and the letter as one press,
  with no tap/hold timing once the dual-function setting is cleared. Nothing
  else on the Voyager sends Right Alt, so AltGr can't be hit by accident.
- *Not verified:* whether the Voyager's layer-1 `<` / `>` are `KC_LABK`/`KC_RABK`
  (Shift+comma/dot, unaffected) or `KC_NUBS` (the ISO key, which would become
  `\` / `|`). Check in Oryx, or just press them after the change.

## Try it live before editing anything

None of this touches files; **`swaymsg reload` puts everything back.** Type the
`type:` lines first and the laptop lines last, because typed `type:` commands
override per-device ones (see *Precedence*). *Not yet run.*

```sh
swaymsg input type:keyboard xkb_variant altgr-intl
swaymsg input type:keyboard xkb_layout us
swaymsg 'input type:keyboard xkb_options "ctrl:nocaps,compose:menu"'
swaymsg input 1:1:AT_Translated_Set_2_keyboard xkb_layout us,no
swaymsg input 1:1:AT_Translated_Set_2_keyboard xkb_variant ,nodeadkeys
swaymsg 'input 1:1:AT_Translated_Set_2_keyboard xkb_options "ctrl:nocaps,grp:alt_shift_toggle,compose:ralt"'
```

Then check:

1. On the Voyager, the usual Alt mappings in nvim inside Alacritty.
2. On the laptop, Alt+Shift still switches to Norwegian and the `ø` key types ø.
3. With the laptop on Norwegian, the Voyager still types US. That proves the
   groups are separate.

The waybar indicator will be wrong during the trial (it reads the Voyager). The
Voyager's æ/ø/å keys can't be tested until the flash.

## Order of operations

1. Waybar change (1b). It's harmless before the split, since the laptop's state
   is the shared state.
2. The sway diff, then `swaymsg reload`.
3. The Oryx remap, compile, flash.
4. Test on the Voyager: the three layer-1 keys give æ ø å, and with Shift Æ Ø Å.

Between 2 and 3 the Voyager has no Norwegian at all. **The laptop keyboard
still does**, which is the improvement over the 2026-08-03 plan.

## How to reverse it

- Host: revert the `sway/config` hunk and the two waybar edits, then
  `swaymsg reload`. Don't `git checkout` `waybar/config` wholesale; it usually
  has unrelated pending edits.
- Firmware: flash the previous revision of the layout from Oryx.

## Open questions

- Does the laptop keyboard need `us` at all, or only `no`? If only `no`, drop
  the toggle from its block.
- Which of the four Voyager devices carries the letter keys. Irrelevant to this
  plan; it would only matter if the Voyager ever needed its own identifier block.
- The layer-1 `<` / `>` keycodes (see above).
- The home-row roll triggering the toggle: theorised, never observed.

## Fallback if the host config should stay as-is

`compose:ralt` already works today; the system table has the sequences
(`/usr/share/X11/locale/en_US.UTF-8/Compose`):

| Sequence | Letter | Line |
|---|---|---|
| `Compose` `a` `e` | æ | 106 |
| `Compose` `/` `o` | ø | 507 |
| `Compose` `a` `a` | å | 430 |

An Oryx **macro** that taps `RAlt`, then `a`, then `e` collapses that into one
keypress, so layer 1 ends up feeling the same with zero sway changes. It's
weaker only because compose is handled per app: GTK, Qt, kitty and Firefox honour
it, some Electron and Java apps don't. `us(altgr-intl)` is the more robust of
the two. This fallback doesn't help the shared-toggle problem.

QMK's Unicode keycodes are a third option, but Oryx doesn't expose them and the
Linux mode wants ibus. Not worth it.

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
