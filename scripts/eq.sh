#!/usr/bin/env bash
# EQ for the 3.5mm headphone jack, for trying out presets side by side.
#
# Nothing here outlives the session: the EQ runs as a *transient* user unit
# (jack-eq) whose config is generated into $XDG_RUNTIME_DIR, so `off`, a crash
# or a reboot all leave the plain jack exactly as it was. Restore steps and the
# reasoning: docs/headphone-eq-presets.md.
#
#   eq.sh [show [preset]] what's boosted and cut: curve + bands (the default)
#   eq.sh on [preset]    start it and make it the default output
#   eq.sh use <preset>   switch preset live; "flat" = no EQ, level-matched
#   eq.sh ab             toggle between the current preset and flat
#   eq.sh pick           choose a preset with wofi
#   eq.sh list           presets; * marks the active one
#   eq.sh status
#   eq.sh check          validate the preset files without touching audio
#   eq.sh reload         re-read the preset files after editing them
#   eq.sh off            back to the plain jack, stop the EQ
#
# Presets are audio/eq-presets/*.txt in AutoEQ / EqualizerAPO ParametricEQ.txt
# format. Only PK, LSC and HSC bands: that is all PipeWire's param_eq reads.
set -euo pipefail
export LC_ALL=C            # awk must print "-6.10", not "-6,10"

DOTFILES="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
PRESETS="$DOTFILES/audio/eq-presets"
RUN="${XDG_RUNTIME_DIR:?}/jack-eq"
UNIT=jack-eq
EQ_NODE=jack_eq
JACK_SUFFIX=HiFi__Headphones__sink
MAX_PRESETS=7              # the builtin mixer has 8 inputs; the 8th is flat
FLAT=8

die() { echo "eq: $*" >&2; exit 1; }

node_id() {                # exact node.name -> id
  pw-dump | jq -r --arg n "$1" 'first(.[] | select(.type == "PipeWire:Interface:Node"
    and .info.props["node.name"] == $n) | .id) // empty'
}
jack_name() {
  pw-dump | jq -r --arg s "$JACK_SUFFIX" 'first(.[] | select(.type == "PipeWire:Interface:Node")
    | .info.props["node.name"] // "" | select(endswith($s))) // empty'
}
default_name() {
  wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | sed -n 's/^[ *]*node\.name = "\(.*\)"$/\1/p'
}
running() { systemctl --user is-active --quiet "$UNIT"; }
# Redraw waybar's custom/eq now rather than at its next 5 s poll.
bar_refresh() { pkill -RTMIN+10 -x waybar 2> /dev/null || true; }

# Write a clean copy of one preset to $2 and print its preamp. The copy puts
# "Preamp:" on line 1 because param_eq reads line 1 as the preamp no matter
# what it says, and reformats numbers to fit param_eq's fixed-width sscanf.
normalise() {
  awk -v dst="$2" '
    { sub(/\r$/, "") }
    /^[[:space:]]*(#.*)?$/ { next }
    /^Preamp:/ { if (!seen++) pre = $2 + 0; next }
    $1 == "Filter" && $3 == "OFF" { next }
    $1 == "Filter" && $3 == "ON" && ($4 == "PK" || $4 == "LSC" || $4 == "HSC") &&
      $5 == "Fc" && $7 == "Hz" && $8 == "Gain" && $10 == "dB" && $11 == "Q" && NF == 12 {
      out[++n] = sprintf("Filter %d: ON %s Fc %g Hz Gain %.2f dB Q %.3f", n, $4, $6, $9, $12)
      if ($9 + 0 > boost) boost = $9 + 0
      next
    }
    { printf "eq: %s:%d: not a PK/LSC/HSC band: %s\n", FILENAME, FNR, $0 > "/dev/stderr"; bad = 1 }
    END {
      if (!bad && n == 0) printf "eq: %s: no bands found\n", FILENAME > "/dev/stderr"
      if (bad || n == 0) exit 1
      if (!seen && boost > 0)
        printf "eq: %s: boosts up to %.1f dB but has no Preamp line; loud tracks will clip\n",
          FILENAME, boost > "/dev/stderr"
      printf "Preamp: %.2f dB\n", pre > dst
      for (i = 1; i <= n; i++) print out[i] > dst
      printf "%.2f\n", pre
    }' "$1"
}

# Validate all presets into dir $1 and write $1/index: idx, name, preamp, gain.
# Every option is level-matched to the most-attenuated preset, so switching
# never gets louder and "louder sounds better" doesn't decide the A/B.
build() {
  local dir="$1" i=0 f pre
  mkdir -p "$dir"
  : > "$dir/raw"
  while IFS= read -r f; do
    i=$((i + 1))
    if (( i > MAX_PRESETS )); then
      echo "eq: only $MAX_PRESETS presets fit; skipping ${f##*/}" >&2
      continue
    fi
    pre="$(normalise "$f" "$dir/p$i.txt")" || die "fix or remove $f"
    printf '%d\t%s\t%s\n' "$i" "$(basename "$f" .txt)" "$pre" >> "$dir/raw"
  done < <(find "$PRESETS" -maxdepth 1 -name '*.txt' | sort)
  [[ -s "$dir/raw" ]] || die "no presets in $PRESETS"
  awk -F'\t' -v flat="$FLAT" '
    { idx[NR] = $1; name[NR] = $2; pre[NR] = $3; if ($3 < min) min = $3 }
    END {
      for (i = 1; i <= NR; i++)
        printf "%d\t%s\t%.2f\t%.6f\n", idx[i], name[i], pre[i], 10 ^ ((min - pre[i]) / 20)
      printf "%d\tflat\t0.00\t%.6f\n", flat, 10 ^ (min / 20)
    }' "$dir/raw" > "$dir/index"
}

index_of() { awk -F'\t' -v n="$1" '$2 == n { print $1; f = 1 } END { exit !f }' "$RUN/index"; }

# Mixer gains selecting option $1: its level-matched gain, every other input 0.
gains() {
  awk -F'\t' -v sel="$1" -v ch="$2" '
    { g[$1] = ($1 == sel) ? $4 : 0 }
    END { for (i = 1; i <= 8; i++) printf "\"mix%s:Gain %d\" %s ", ch, i, (i in g) ? g[i] : 0 }
  ' "$RUN/index"
}

conf() {
  local jack="$1" sel="$2" i n
  n="$(awk -F'\t' -v flat="$FLAT" '$1 != flat' "$RUN/index" | wc -l)"
  cat <<EOF
# Generated by scripts/eq.sh; lives in \$XDG_RUNTIME_DIR, gone at reboot.
context.properties = { log.level = 2 }
context.spa-libs = {
  audio.convert.* = audioconvert/libspa-audioconvert
  support.*       = support/libspa-support
}
context.modules = [
  { name = libpipewire-module-rt args = { } flags = [ ifexists nofail ] }
  { name = libpipewire-module-protocol-native }
  { name = libpipewire-module-client-node }
  { name = libpipewire-module-adapter }
  { name = libpipewire-module-filter-chain
    args = {
      node.description = "Headphone jack EQ"
      media.name       = "Headphone jack EQ"
      audio.channels   = 2
      audio.position   = [ FL FR ]
      filter.graph = {
        # copy -> one param_eq per preset, in parallel -> mixer picks one.
        # Mixer input 8 is the dry signal (flat).
        nodes = [
          { type = builtin name = splitL label = copy }
          { type = builtin name = splitR label = copy }
EOF
  for ((i = 1; i <= n; i++)); do
    echo "          { type = builtin name = eq$i label = param_eq config = { filename = \"$RUN/p$i.txt\" } }"
  done
  cat <<EOF
          { type = builtin name = mixL label = mixer control = { $(gains "$sel" L | sed 's/"mixL:\(Gain [0-9]\)"/"\1" =/g') } }
          { type = builtin name = mixR label = mixer control = { $(gains "$sel" R | sed 's/"mixR:\(Gain [0-9]\)"/"\1" =/g') } }
        ]
        links = [
EOF
  for ((i = 1; i <= n; i++)); do
    cat <<EOF
          { output = "splitL:Out" input = "eq$i:In 1" }
          { output = "splitR:Out" input = "eq$i:In 2" }
          { output = "eq$i:Out 1" input = "mixL:In $i" }
          { output = "eq$i:Out 2" input = "mixR:In $i" }
EOF
  done
  cat <<EOF
          { output = "splitL:Out" input = "mixL:In $FLAT" }
          { output = "splitR:Out" input = "mixR:In $FLAT" }
        ]
        inputs  = [ "splitL:In" "splitR:In" ]
        outputs = [ "mixL:Out" "mixR:Out" ]
      }
      capture.props = {
        node.name   = "$EQ_NODE"
        media.class = Audio/Sink
      }
      playback.props = {
        node.name    = "$EQ_NODE.out"
        node.passive = true
        # Only ever the jack. If it's missing, wait for it rather than fall
        # back to the speakers (a headphone bass boost on laptop speakers).
        target.object      = "$jack"
        node.dont-fallback = true
        node.linger        = true
      }
    }
  }
]
EOF
}

apply() {                  # select option $1 (index) on the running EQ
  local id
  id="$(node_id "$EQ_NODE")"
  [[ -n $id ]] || die "EQ node not found; try: eq.sh off && eq.sh on"
  pw-cli set-param "$id" Props "{ params = [ $(gains "$1" L)$(gains "$1" R)] }" > /dev/null
}

cmd_use() {
  running || die "EQ is off; start it with: eq.sh on [preset]"
  local idx
  idx="$(index_of "$1")" || die "no preset '$1' (eq.sh list)"
  apply "$idx"
  echo "$1" > "$RUN/active"
  [[ $1 == flat ]] || echo "$1" > "$RUN/last"
  bar_refresh
  echo "eq: $1"
}

cmd_on() {
  if running; then
    [[ -n ${1:-} ]] && cmd_use "$1"
    cmd_status
    return
  fi
  local jack want idx prev eq_id="" t
  jack="$(jack_name)"
  [[ -n $jack ]] || die "no headphone-jack sink (*$JACK_SUFFIX) found"
  rm -rf "$RUN"
  build "$RUN"
  want="${1:-$(head -n1 "$RUN/index" | cut -f2)}"
  idx="$(index_of "$want")" || { rm -rf "$RUN"; die "no preset '$want' (eq.sh list)"; }
  conf "$jack" "$idx" > "$RUN/jack-eq.conf"

  prev="$(default_name)"
  [[ -z $prev || $prev == "$EQ_NODE" ]] && prev="$jack"
  echo "$prev" > "$RUN/previous-default"
  node_id "$jack" > "$RUN/jack-id"           # scripts/volume.sh reads this

  systemctl --user reset-failed "$UNIT" 2> /dev/null || true
  systemd-run --user --quiet --collect --unit="$UNIT" \
    --description="Headphone jack EQ (scripts/eq.sh)" \
    /usr/bin/pipewire -c "$RUN/jack-eq.conf"

  for t in $(seq 30); do
    eq_id="$(node_id "$EQ_NODE")"
    [[ -n $eq_id ]] && break
    sleep 0.1
  done
  if [[ -z $eq_id ]]; then
    systemctl --user stop "$UNIT" 2> /dev/null || true
    die "EQ didn't come up; nothing was changed. Log: journalctl --user -u $UNIT"
  fi
  wpctl set-volume "$eq_id" 1.0             # volume stays on the jack itself
  wpctl set-default "$eq_id"
  echo "$want" > "$RUN/active"
  [[ $want == flat ]] || echo "$want" > "$RUN/last"
  bar_refresh
  cmd_status
}

cmd_off() {               # must work even when half of the above is broken
  local prev="" id=""
  if [[ -r $RUN/previous-default ]]; then prev="$(< "$RUN/previous-default")"; fi
  if [[ -n $prev ]]; then id="$(node_id "$prev")"; fi
  # Previous default gone (e.g. Bluetooth since switched off): use the jack.
  if [[ -z $id ]]; then
    prev="$(jack_name)"
    if [[ -n $prev ]]; then id="$(node_id "$prev")"; fi
  fi
  # Move the default first, so streams go straight to it, then stop the EQ.
  if [[ -n $id ]]; then wpctl set-default "$id"; fi
  systemctl --user stop "$UNIT" 2> /dev/null || true
  systemctl --user reset-failed "$UNIT" 2> /dev/null || true
  rm -rf "$RUN"
  bar_refresh
  cmd_status
}

cmd_status() {
  echo "default output: $(default_name)"
  if running; then
    echo "EQ: on, preset: $(cat "$RUN/active" 2> /dev/null)"
  else
    echo "EQ: off"
  fi
}

# Bar chart of a (normalised) preset's net response, preamp excluded, plus its
# bands. RBJ-cookbook biquads: measured through the jack they matched PipeWire's
# param_eq within 0.03 dB (docs/headphone-eq-presets.md).
plot() {
  python3 -I - "$1" <<'PY'
import cmath, math, os, sys

FS = 48000
bands, pre = [], 0.0
for line in open(sys.argv[1]):
    t = line.split()
    if t[:1] == ["Preamp:"]:
        pre = float(t[1])
    elif t[:1] == ["Filter"]:
        bands.append((t[3], float(t[5]), float(t[8]), float(t[11])))

def response(f):
    z = cmath.exp(-2j * math.pi * f / FS)
    h = 1
    for kind, f0, gain, q in bands:
        A = 10 ** (gain / 40)
        w0 = 2 * math.pi * f0 / FS
        c, al = math.cos(w0), math.sin(w0) / (2 * q)
        s = 2 * math.sqrt(A) * al
        if kind == "PK":
            b = (1 + al * A, -2 * c, 1 - al * A)
            a = (1 + al / A, -2 * c, 1 - al / A)
        elif kind == "LSC":
            b = (A * ((A + 1) - (A - 1) * c + s), 2 * A * ((A - 1) - (A + 1) * c),
                 A * ((A + 1) - (A - 1) * c - s))
            a = ((A + 1) + (A - 1) * c + s, -2 * ((A - 1) + (A + 1) * c),
                 (A + 1) + (A - 1) * c - s)
        else:  # HSC
            b = (A * ((A + 1) + (A - 1) * c + s), -2 * A * ((A - 1) + (A + 1) * c),
                 A * ((A + 1) + (A - 1) * c - s))
            a = ((A + 1) - (A - 1) * c + s, 2 * ((A - 1) - (A + 1) * c),
                 (A + 1) - (A - 1) * c - s)
        h *= (b[0] + b[1] * z + b[2] * z * z) / (a[0] + a[1] * z + a[2] * z * z)
    return 20 * math.log10(abs(h))

color = sys.stdout.isatty() and "NO_COLOR" not in os.environ
UP, DOWN, DIM, OFF = ("\033[32m", "\033[31m", "\033[2m", "\033[0m") if color else ("",) * 4
def tint(v):
    return UP if v >= 0.05 else DOWN if v <= -0.05 else ""

W, LO, HI = 64, 20, 20000
def x_of(f):
    return round(math.log(f / LO) / math.log(HI / LO) * (W - 1))
db = [response(LO * (HI / LO) ** (i / (W - 1))) for i in range(W)]

top = max(1, min(12, round(max(db))))
bottom = min(-1, max(-12, round(min(db))))
for r in range(top, bottom - 1, -1):
    if r == 0:
        row = DIM + "─" * W + OFF
    else:
        hit = (lambda d: d >= r - 0.5) if r > 0 else (lambda d: d <= r + 0.5)
        row = (UP if r > 0 else DOWN) + "".join("█" if hit(d) else " " for d in db).rstrip() + OFF
    print(f"{r:+3d} dB │{row}")

def at_ticks(cells):       # place each (f, text, colour) under its frequency
    out, used = "", 0
    for f, text, col in cells:
        x = x_of(f)
        out += " " * max(1 if used else 0, x - used) + (col + text + OFF if col else text)
        used = max(used + 1, x) + len(text) if used else x + len(text)
    return "        " + out

ticks = [(20, "20"), (50, "50"), (100, "100"), (200, "200"), (500, "500"), (1000, "1k"),
         (2000, "2k"), (5000, "5k"), (10000, "10k"), (20000, "20k")]
print("       └" + "─" * W)
print(at_ticks([(f, t, "") for f, t in ticks]) + "  Hz")
print(at_ticks([(f, f"{response(f):+.1f}", tint(response(f))) for f, _ in ticks]) + "  dB")

names = {"PK": "peak", "LSC": "low shelf", "HSC": "high shelf"}
print(f"\n  {'band':<11} {'at':>9} {'gain':>9} {'Q':>6}")
for kind, f0, g, q in sorted(bands, key=lambda b: b[1]):
    at = f"{f0 / 1000:g} kHz" if f0 >= 1000 else f"{f0:g} Hz"
    print(f"  {names[kind]:<11} {at:>9} {tint(g)}{g:>+6.1f} dB{OFF} {q:>6.2f}")
print(f"\n  preamp {pre:+.1f} dB: everything goes down by this first, so the boosts can't clip")
PY
}

cmd_show() {
  local name="${1:-}" active="" head tmp idx
  if running; then active="$(cat "$RUN/active" 2> /dev/null || true)"; fi
  if [[ -n $name ]]; then
    head="preset $name"
  elif [[ -n $active && $active != flat ]]; then
    name="$active"
    head="EQ on: $name"
  elif [[ $active == flat ]]; then
    name="$(cat "$RUN/last" 2> /dev/null || true)"
    head="EQ on, set to flat: nothing is boosted or cut (just the level match)."
    [[ -n $name ]] && head+=$'\n'"\`eq.sh ab\` switches to $name:"
  else
    head="EQ off."
  fi
  if [[ -z $name ]]; then
    name="$(find "$PRESETS" -maxdepth 1 -name '*.txt' -printf '%f\n' | sort | head -n1)"
    name="${name%.txt}"
    head+=$'\n'"\`eq.sh on\` would use $name:"
  fi
  [[ -r $PRESETS/$name.txt ]] || die "no preset '$name' (eq.sh list)"
  tmp="$(mktemp)"
  normalise "$PRESETS/$name.txt" "$tmp" > /dev/null || { rm -f "$tmp"; die "fix $PRESETS/$name.txt"; }
  echo "$head"
  # The file may have been edited since `on` loaded it.
  if running && idx="$(index_of "$name" 2> /dev/null)" && ! cmp -s "$tmp" "$RUN/p$idx.txt"; then
    echo "(the file changed since it was loaded; \`eq.sh reload\` to hear this version)"
  fi
  echo
  plot "$tmp"
  rm -f "$tmp"
}

# JSON for waybar's custom/eq module. Empty text hides the module, so it only
# shows while the EQ is on. Cheap on purpose (no pw-dump): it runs every 5 s.
cmd_waybar() {
  local active="" text="" tip="" class=""
  if running; then
    active="$(cat "$RUN/active" 2> /dev/null || echo '?')"
    text="🎚️"
    if [[ $active == flat ]]; then
      tip="EQ on: flat (bypassed, level-matched)"
      class=flat
    else
      tip="EQ on: $active"
      class=on
    fi
  fi
  jq -cn --arg text "$text" --arg tooltip "$tip" --arg class "$class" \
    '{text: $text, tooltip: $tooltip, class: $class}'
}

cmd_list() {
  local active=""
  if running && [[ -r $RUN/index ]]; then
    active="$(cat "$RUN/active" 2> /dev/null)"
    awk -F'\t' -v a="$active" '{ printf "%s %-28s preamp %6s dB\n", ($2 == a ? "*" : " "), $2, $3 }' "$RUN/index"
  else
    find "$PRESETS" -maxdepth 1 -name '*.txt' -printf '  %f\n' | sort | sed 's/\.txt$//'
    echo "  flat"
  fi
}

cmd_check() {
  CHECK_DIR="$(mktemp -d)"
  trap 'rm -rf "$CHECK_DIR"' EXIT
  build "$CHECK_DIR"
  awk -F'\t' '{ printf "%-28s preamp %6s dB  level-match gain %s\n", $2, $3, $4 }' "$CHECK_DIR/index"
  echo "all presets OK"
}

cmd_ab() {
  running || die "EQ is off"
  local active last
  active="$(cat "$RUN/active")"
  last="$(cat "$RUN/last" 2> /dev/null || true)"
  if [[ $active == flat ]]; then
    [[ -n $last ]] || die "no preset to go back to"
    cmd_use "$last"
  else
    cmd_use flat
  fi
}

cmd_pick() {
  local choice
  choice="$( { running && cut -f2 "$RUN/index" || cmd_list | sed 's/^  //'; } | wofi --dmenu --prompt EQ)" || exit 0
  [[ -n $choice ]] || exit 0
  if running; then cmd_use "$choice"; else cmd_on "$choice"; fi
}

cmd_reload() {
  local active="flat"
  running || die "EQ is off"
  active="$(cat "$RUN/active" 2> /dev/null || echo flat)"
  cmd_off > /dev/null
  cmd_on "$active"
}

case "${1:-show}" in
  show)   cmd_show "${2:-}" ;;
  on)     cmd_on "${2:-}" ;;
  off)    cmd_off ;;
  use)    [[ -n ${2:-} ]] || die "usage: eq.sh use <preset>"; cmd_use "$2" ;;
  ab)     cmd_ab ;;
  pick)   cmd_pick ;;
  list)   cmd_list ;;
  check)  cmd_check ;;
  reload) cmd_reload ;;
  status) cmd_status ;;
  waybar) cmd_waybar ;;
  *)      awk 'NR > 1 && !/^#/ { exit } NR > 1 { sub(/^# ?/, ""); print }' "$0"; exit 1 ;;
esac
