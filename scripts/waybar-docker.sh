#!/usr/bin/env bash
# Emit running Docker containers as JSON for a waybar custom module.
# Prints an empty text (which hides the module) when the daemon is down or
# nothing is running, so the bar stays quiet outside dev sessions.
set -uo pipefail

hide() { echo '{"text":"","tooltip":"","class":""}'; exit 0; }

command -v docker >/dev/null 2>&1 || hide

# name \t status \t compose project ("" for standalone containers)
rows="$(docker ps --format '{{.Names}}\t{{.Status}}\t{{.Label "com.docker.compose.project"}}' 2>/dev/null)" || hide
[ -n "$rows" ] || hide

esc() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }

count=0
class=""
tooltip=""
project=$'\x01'  # sentinel: no group emitted yet (a real project may be "")

while IFS=$'\t' read -r name status proj; do
  [ -n "$name" ] || continue
  count=$((count + 1))

  case "$status" in
    *unhealthy*)             icon="✖" ; class="critical" ;;
    Restarting*)             icon="↻" ; [ "$class" = critical ] || class="warning" ;;
    *health:\ starting*)     icon="…" ; [ "$class" = critical ] || class="warning" ;;
    *)                       icon="✔" ;;
  esac

  if [ "$proj" != "$project" ]; then
    project="$proj"
    [ -n "$tooltip" ] && tooltip+=$'\n'
    tooltip+="<b>${project:-standalone}</b>"$'\n'
  fi
  tooltip+="  ${icon} ${name}  <i>${status}</i>"$'\n'
done < <(printf '%s\n' "$rows" | sort -t$'\t' -k3,3 -k1,1 | esc)

[ "$count" -gt 0 ] || hide

jq -cn \
  --arg text "🐳 $count" \
  --arg tooltip "${tooltip%$'\n'}" \
  --arg class "$class" \
  '{text: $text, tooltip: $tooltip, class: $class}'
