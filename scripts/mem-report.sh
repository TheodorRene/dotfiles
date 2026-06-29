#!/usr/bin/env bash
# mem-report.sh — human-readable memory assessment.
# Shows: RAM overview, swap/zram (with compression ratio), PSI memory pressure,
# today's systemd-oomd kills, and the biggest process groups by RAM.
#
# Usage: mem-report.sh [N]      # N = how many process groups to show (default 15)
set -uo pipefail

TOPN="${1:-15}"

# ── colors (only if stdout is a terminal) ───────────────────────────────────
if [ -t 1 ]; then
  B=$'\e[1m'; DIM=$'\e[2m'; R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; C=$'\e[36m'; X=$'\e[0m'
else
  B=''; DIM=''; R=''; G=''; Y=''; C=''; X=''
fi
hdr() { printf '\n%s%s%s\n' "$B$C" "$1" "$X"; }

# ── 1. RAM overview ─────────────────────────────────────────────────────────
# Pull exact KiB from /proc/meminfo for accurate percentages.
read -r mem_total   < <(awk '/^MemTotal:/{print $2}'     /proc/meminfo)
read -r mem_avail   < <(awk '/^MemAvailable:/{print $2}' /proc/meminfo)
read -r mem_free    < <(awk '/^MemFree:/{print $2}'      /proc/meminfo)
used=$(( mem_total - mem_avail ))
used_pct=$(( used * 100 / mem_total ))
avail_pct=$(( mem_avail * 100 / mem_total ))
gib() { awk -v k="$1" 'BEGIN{printf "%.1f", k/1048576}'; }

# usage bar (30 cells)
bar_w=30; filled=$(( used_pct * bar_w / 100 )); [ "$filled" -gt "$bar_w" ] && filled=$bar_w
bar_color=$G; [ "$avail_pct" -lt 25 ] && bar_color=$Y; [ "$avail_pct" -lt 10 ] && bar_color=$R
bar=""; i=0
while [ "$i" -lt "$bar_w" ]; do
  if [ "$i" -lt "$filled" ]; then bar="$bar█"; else bar="$bar${DIM}·${X}${bar_color}"; fi
  i=$((i+1))
done

hdr "RAM"
printf '  %s[%s%s]%s  %s%%%s used\n' "$bar_color" "$bar" "$bar_color" "$X" "$used_pct" ""
printf '  total %s%s GiB%s   used %s%s GiB%s   available %s%s GiB (%s%%)%s   free %s GiB\n' \
  "$B" "$(gib "$mem_total")" "$X" "$B" "$(gib "$used")" "$X" \
  "$B" "$(gib "$mem_avail")" "$avail_pct" "$X" "$(gib "$mem_free")"

# ── 2. Swap + zram ──────────────────────────────────────────────────────────
hdr "SWAP"
if [ -n "$(swapon --noheadings 2>/dev/null)" ]; then
  swapon --show=NAME,TYPE,SIZE,USED,PRIO 2>/dev/null | sed 's/^/  /'
  if command -v zramctl >/dev/null 2>&1 && zramctl --noheadings 2>/dev/null | grep -q .; then
    # compression ratio = uncompressed DATA / actual COMPR(essed) bytes
    zramctl --output NAME,DISKSIZE,DATA,COMPR --bytes 2>/dev/null \
      | awk 'NR>1 && $3+0>0 {printf "  %s: %.2f GB data -> %.2f GB in RAM  (%.1fx compression)\n", $1, $3/1073741824, $4/1073741824, $3/$4}'
  fi
else
  printf '  %s(no swap configured)%s\n' "$DIM" "$X"
fi

# ── 3. PSI memory pressure ──────────────────────────────────────────────────
hdr "PRESSURE (PSI — % of time tasks stalled waiting on memory)"
if [ -r /proc/pressure/memory ]; then
  some10=$(awk '/^some/{for(i=1;i<=NF;i++) if($i ~ /^avg10=/){sub("avg10=","",$i); print $i}}' /proc/pressure/memory)
  awk '/^some/{print "  some "$2" "$3" "$4} /^full/{print "  full "$2" "$3" "$4}' /proc/pressure/memory
  verdict=$(awk -v v="$some10" 'BEGIN{ if(v+0<1) print "calm — no thrashing"; else if(v+0<10) print "mild"; else print "HIGH — system is thrashing/reclaiming hard" }')
  printf '  %s-> %s%s\n' "$DIM" "$verdict" "$X"
else
  printf '  %s(PSI not available)%s\n' "$DIM" "$X"
fi

# ── 4. oomd kills today ─────────────────────────────────────────────────────
hdr "OOMD KILLS (today)"
kills=$(journalctl --since today --no-pager 2>/dev/null | grep -c "systemd-oomd killed" || true)
if [ "${kills:-0}" -gt 0 ]; then
  printf '  %s%s kill(s) today%s\n' "$R" "$kills" "$X"
  journalctl --since today --no-pager 2>/dev/null | grep "Killed" | grep -i oomd | tail -3 | sed 's/^/  /'
else
  printf '  %s0 — healthy%s\n' "$G" "$X"
fi

# ── 5. Top workloads by RAM (RSS summed, classified by command line) ────────
# Grouping by `comm` lumps .NET under the cryptic "MainThread" and splits it
# across thread names. Instead we classify each process by its full cmdline so
# known dev workloads (rust-analyzer, .NET, rust builds…) roll up into one
# labelled bucket; anything unmatched falls back to its process name.
# To add a workload: insert another `else if (index(la,"NEEDLE"))` line below
# (needles are lowercased substrings, first match wins, so order = priority).
hdr "TOP $TOPN BY RAM (grouped by workload; rust-analyzer & .NET called out)"
ps -eo rss=,comm=,args= 2>/dev/null \
  | awk '
      {
        rss=$1; comm=$2;
        args=""; for (i=3; i<=NF; i++) args = args " " $i;
        la=tolower(args);
        # NB: Node names its main thread "MainThread", so node tooling shows up
        # under comm="MainThread" — classify by cmdline to label it properly.
        if      (index(la,"rust-analyzer"))                                  label="rust-analyzer";
        else if (index(la,"rustc") || index(la,"cargo"))                     label="rust build (cargo/rustc)";
        else if (index(la,"eslint"))                                         label="eslint LSP";
        else if (index(la,"tsserver") || index(la,"typescript-language"))    label="TypeScript LSP";
        else if (index(la,"vite"))                                           label="vite (frontend)";
        else if (index(la,"webpack"))                                        label="webpack (frontend)";
        else if (index(la,"imperocloud") || index(la,"dotnet"))              label=".NET (ImperoCloud)";
        else if (index(la,"firefox"))                                        label="Firefox";
        else if (index(la,"slack"))                                          label="Slack";
        else if (index(la,"/node ") || index(la,"node "))                    label="node (other)";
        else                                                                 label=comm;
        sum[label]+=rss; cnt[label]++;
      }
      END { for (l in sum) printf "%d\t%d\t%s\n", sum[l], cnt[l], l }' \
  | sort -rn | head -n "$TOPN" \
  | awk -F'\t' -v X="$X" -v RED="$R" -v YEL="$Y" '{
      gb=$1/1048576;
      col = (gb>=3 ? RED : (gb>=1 ? YEL : ""));
      proc = ($2>1 ? sprintf("%s (x%d)", $3, $2) : $3);
      printf "  %s%6.2f GB%s  %s\n", col, gb, (col=="" ? "" : X), proc }'

printf '\n'
