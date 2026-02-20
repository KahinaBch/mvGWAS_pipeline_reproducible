#!/usr/bin/env bash
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

# If DRY_RUN=1, print the command; otherwise execute it.
run_cmd() {
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    echo "[dry-run] $*"
    return 0
  fi
  "$@"
}

# Print/execute a command string (useful for sbatch lines)
run_sh() {
  local cmd="$1"
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    echo "[dry-run] $cmd"
    return 0
  fi
  bash -lc "$cmd"
}
