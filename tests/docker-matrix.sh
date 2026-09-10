#!/usr/bin/env bash
# Run install.sh in a throwaway container per distro and assert the environment
# actually comes up. Needs docker and network access.
#
#   tests/docker-matrix.sh                 # every image
#   tests/docker-matrix.sh debian alt      # only matching labels
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOGS="${TMPDIR:-/tmp}/dotfiles-matrix-$(date +%H%M%S)"
mkdir -p "$LOGS"

# label image
IMAGES=(
  "arch    archlinux:latest"
  "debian  debian:13"
  "fedora  fedora:42"
  "alt     alt:latest"
)

wanted=("$@")
matches() {
  (( ${#wanted[@]} == 0 )) && return 0
  local w
  for w in "${wanted[@]}"; do [[ $1 == *"$w"* ]] && return 0; done
  return 1
}

# Runs inside the container: copy the repo somewhere writable (symlinks must not
# point at a read-only mount), install, then assert. Re-runs install.sh to prove
# it is idempotent -- a second pass must create no new .bak paths.
runner='
set -uo pipefail
export HOME=/root TERM=xterm-256color DOTFILES=/root/dotfiles
cp -a /src /root/dotfiles
cd /root/dotfiles

echo "=================== install.sh (first run) ==================="
./install.sh -y --no-chsh
first=$?
echo "install.sh exit: $first"

echo
echo "=================== install.sh (second run, idempotency) ==================="
before=$(find "$HOME/.config" -name "*.bak.*" 2>/dev/null | wc -l)
./install.sh -y --no-chsh --no-packages --no-plugins >/tmp/second.log 2>&1
second=$?
after=$(find "$HOME/.config" -name "*.bak.*" 2>/dev/null | wc -l)
echo "install.sh exit: $second ; backups before=$before after=$after"
if [ "$before" = "$after" ]; then echo "  PASS  re-run moved nothing aside"; else echo "  FAIL  re-run created backups"; tail -30 /tmp/second.log; fi

echo
echo "=================== assertions ==================="
bash tests/assert-env.sh
assert=$?
echo
echo "RESULT install=$first rerun=$second assert=$assert"
[ "$first" -eq 0 ] && [ "$second" -eq 0 ] && [ "$assert" -eq 0 ] && [ "$before" = "$after" ]
'

declare -a results=()
for entry in "${IMAGES[@]}"; do
  read -r label image <<<"$entry"
  matches "$label" || continue

  printf '\n################ %s (%s) ################\n' "$label" "$image"
  log="$LOGS/$label.log"
  if timeout 2400 docker run --rm \
       -v "$REPO:/src:ro" \
       -e DEBIAN_FRONTEND=noninteractive \
       "$image" bash -c "$runner" >"$log" 2>&1; then
    status="PASS"
  else
    status="FAIL"
  fi
  results+=("$status $label")
  tail -40 "$log"
  printf '  -- full log: %s\n' "$log"
done

printf '\n################ matrix summary ################\n'
for r in "${results[@]}"; do printf '  %s\n' "$r"; done
printf '  logs in %s\n' "$LOGS"
[[ ! " ${results[*]} " =~ FAIL ]]
