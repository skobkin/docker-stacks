#!/usr/bin/env bash
# rebuild-created.sh
#
# Walk stack directories (./<stack>/docker-compose.yml or ./<stack>/compose.yml)
# and restart ONLY stacks that:
#   1) have a .env file in the stack directory
#   2) already have at least one container created for that compose project
#
# Usage:
#   ./restart-stacks.sh --dry-run
#   ./restart-stacks.sh
#
# Optional:
#   STACKS_ROOT=/path/to/stacks ./restart-stacks.sh --dry-run

set -euo pipefail

DRY_RUN=0
VERBOSE=0

usage() {
  cat <<'EOF'
Usage: restart-stacks.sh [--dry-run] [--verbose] [--help]

Options:
  --dry-run   Print what would be restarted, do not change anything
  --verbose   Print extra diagnostics
  --help      Show this help

Env:
  STACKS_ROOT Root directory containing stack subdirectories (default: current directory)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --verbose) VERBOSE=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

ROOT="${STACKS_ROOT:-.}"

log() {
  # Always print
  printf '%s\n' "$*"
}

vlog() {
  [[ "$VERBOSE" -eq 1 ]] && printf '%s\n' "$*"
}

# Returns 0 if the stack has any created containers, else 1.
has_created_containers() {
  local dir="$1"
  (
    cd "$dir"
    # If no containers exist for this project, output is empty -> grep fails -> return 1
    docker compose ps -aq 2>/dev/null | grep -q .
  )
}

# Find compose files one level below ROOT: ROOT/<stack>/(docker-compose.yml|compose.yml)
# The -print0 / read -d '' combo is safe for spaces/newlines.
find "$ROOT" -mindepth 2 -maxdepth 2 -type f \( -name docker-compose.yml -o -name compose.yml \) -print0 \
| while IFS= read -r -d '' compose_file; do
    dir="$(dirname "$compose_file")"
    stack_rel="${dir#"$ROOT"/}"

    # Check 1: .env must exist
    if [[ ! -f "$dir/.env" ]]; then
      vlog "skip (no .env): $stack_rel"
      continue
    fi

    # Check 2: must have created containers already
    if ! has_created_containers "$dir"; then
      vlog "skip (no created containers): $stack_rel"
      continue
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
      log "would restart: $stack_rel"
      continue
    fi

    log "restarting: $stack_rel"
    (
      cd "$dir"
      docker compose down
      docker compose up -d
    )
  done
