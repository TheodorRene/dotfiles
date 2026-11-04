---
name: sway
description: Inspect the user's running sway desktop (windows, workspaces, outputs, keyboards), take a screenshot of a window or screen to look at it, or check a sway config change. Use when the user asks what's on screen or in a window, wants something checked visually, asks about displays/monitors, keyboard layouts or window placement, or when editing sway/kanshi config. Read-only by default; anything that changes the session is asked for first.
---

# Sway

The tool is `~/dotfiles/scripts/swayq` (not on `PATH`; use the full path). It only reads.
`~/dotfiles/scripts/swayq --help` lists everything.

| Need | Command |
|---|---|
| What windows exist, where, which is focused | `swayq tree` |
| Find a window by app or title (regex) | `swayq find firefox` |
| Displays: mode, scale, position | `swayq outputs` |
| Keyboards and their layouts | `swayq inputs` (`--all` for platform pseudo-devices) |
| This session's own window and herdr tab | `swayq whereami` |
| Look at something | `swayq shot` → prints a PNG path, then Read it |
| Check a sway config edit | `swayq validate` |

`tree` flags: `*` focused, `!` urgent, `~` floating, `F` fullscreen, `-` not visible.

## Screenshots

- `swayq shot` (focused window), `shot <id>`, `shot output <name>`, `shot all`. Add `-s 0.5` for
  a smaller image when detail doesn't matter.
- **Only visible windows can be captured.** `grim` grabs what is on screen, so `shot` refuses a
  window marked `-` in `tree` rather than return a picture of whatever covers it. Showing it means
  switching the user's workspace: ask first, note the current workspace, and switch back afterwards.
- Shots land in `$XDG_RUNTIME_DIR/swayq/` (private, gone at logout). **Never copy a screenshot or
  window titles into `~/dotfiles`**: the repo is public, and titles carry DM names, ticket ids and
  page titles.

## What needs asking first

Anything through `swaymsg` that changes state acts on the user's live session, possibly while
they are typing:

- **Never run `swaymsg reload` yourself.** It re-runs every `exec_always` (kanshi, swaybg,
  swayidle). Hand it to the user.
- Focus, workspace switches, moving/resizing/killing windows: ask, unless the user asked for that
  exact action.
- **Outputs belong to kanshi** (`~/dotfiles/kanshi/config`). A runtime `swaymsg output …` is
  overridden on the next hotplug; a lasting change goes in the kanshi config.
- There is deliberately **no keystroke/mouse injection** (wtype and ydotool were rejected as not
  worth the risk). To trigger a binding, run its command directly, after asking.

## Editing the config

- `~/.config/sway` is a symlink to `~/dotfiles/sway/`: edit the repo file.
- Run `swayq validate` after every edit. Silent success prints `ok:`; errors give the line number.
- Then tell the user to reload (`$mod+Shift+c` or `swaymsg reload`) at a moment that suits them.
- `swayq validate <file>` checks a scratch copy without touching the real one.
