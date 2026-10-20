#!/usr/bin/env bash
#
# Install or update a Luanti game (VoxeLibre or Mineclonia) into the games
# directory configured in .env (HOST_GAMES_DIR, default ./games).
#
# The script clones the chosen game at a specific release tag. Re-running it
# for an already installed game fetches and checks out another tag, which is
# how updates and rollbacks are done.
#
# Usage: ./install-game.sh

set -eu

# game-id|repository-url pairs (game ID equals the directory name Luanti sees)
GAME_REPOS=(
  "voxelibre|https://git.minetest.land/VoxeLibre/VoxeLibre.git"
  "mineclonia|https://codeberg.org/mineclonia/mineclonia.git"
)

err() {
  echo "ERROR: $*" >&2
}

# User the server runs as inside the container (official image default).
CONTAINER_UID=30000
# Read a simple KEY=VALUE from .env without sourcing it.
env_value() {
  grep -E "^$1=" .env 2>/dev/null | tail -n1 | cut -d= -f2- | tr -d '"' | tr -d "'" || true
}

# Can the given numeric UID reach <path> through the standard owner, group
# and other permission bits?
access_by_uid() {
  local mode="$1" uid="$2" path="$3" perms owner group class bit
  [ -e "$path" ] || return 1
  read -r perms owner group _ < <(stat -c '%a %u %g' "$path") || return 1
  # Normalize to four octal digits (stat omits leading zeros).
  perms="$(printf '%04o' "$((8#$perms))")"
  if [ "$owner" = "$uid" ]; then
    class=1
  elif [ "$group" = "$uid" ]; then
    class=2
  else
    class=3
  fi
  bit="${perms:$class:1}"
  case "$mode" in
    r) [ $((8#$bit & 4)) -ne 0 ] ;;
    w) [ $((8#$bit & 2)) -ne 0 ] ;;
    x) [ $((8#$bit & 1)) -ne 0 ] ;;
    *) return 1 ;;
  esac
}

# Find expression matching paths that the container user cannot read (files)
# or traverse (directories), judged by owner/group/other permission bits.
UNREADABLE_EXPR=(
  \( -type d ! \( -user "$CONTAINER_UID" -perm -u+x \) ! \( -group "$CONTAINER_UID" -perm -g+x \) ! -perm -o+x \) -o
  \( -type f ! \( -user "$CONTAINER_UID" -perm -u+r \) ! \( -group "$CONTAINER_UID" -perm -g+r \) ! -perm -o+r \)
)

# Make sure the installed game is readable by the container user. Takes no
# permissions away and only touches paths the server cannot read.
ensure_game_readable() {
  local target="$1" broken count
  broken="$(find "$target" "${UNREADABLE_EXPR[@]}" -print)"
  if [ -z "$broken" ]; then
    echo "All game files are readable by the server (UID $CONTAINER_UID), no permission changes needed."
    return 0
  fi
  count="$(echo "$broken" | wc -l)"
  echo "$count path(s) are not readable by the server (UID $CONTAINER_UID), for example:"
  echo "$broken" | head -n 3 | sed 's/^/  /'
  if [ "$count" -gt 3 ]; then
    echo "  ..."
  fi
  echo "Applying 'chmod o+rX' to the affected paths ..."
  # The whole expression is grouped so chmod applies to files and directories.
  find "$target" \( "${UNREADABLE_EXPR[@]}" \) -exec chmod o+rX {} +
  if [ -n "$(find "$target" "${UNREADABLE_EXPR[@]}" -print)" ]; then
    err "Some game files are still not readable by the server. Fix manually with:"
    echo "  sudo chmod -R o+rX '$target'" >&2
    return 1
  fi
  echo "Permissions fixed."
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

command -v git >/dev/null 2>&1 || {
  err "git is required but not installed."
  exit 1
}

if [ ! -f .env ]; then
  err "No .env file found in $(pwd)."
  echo "Create and configure it first:  cp .env.dist .env" >&2
  exit 1
fi

# Resolve the games directory the same way Compose does.
games_dir="$(env_value HOST_GAMES_DIR)"
[ -n "$games_dir" ] || games_dir="./games"
case "$games_dir" in
  /*) ;; # already absolute
  *) games_dir="${script_dir%/}/${games_dir#./}" ;;
esac

# Pre-flight: the server writes all runtime data (worlds, players,
# authentication) as UID/GID 30000, so the data directory must be writable
# by that user. Games and mods are only read, they need no special ownership.
data_dir="$(env_value HOST_DATA_DIR)"
[ -n "$data_dir" ] || data_dir="./data"
case "$data_dir" in
  /*) ;; # already absolute
  *) data_dir="${script_dir%/}/${data_dir#./}" ;;
esac

data_problems=()
if [ ! -d "$data_dir" ]; then
  data_problems+=("data directory $data_dir does not exist")
elif ! access_by_uid w "$CONTAINER_UID" "$data_dir"; then
  data_problems+=("$data_dir is not writable by the container user (UID/GID $CONTAINER_UID)")
fi

# The server opens .minetest/debug.txt at startup and gives up when it
# cannot; create the directory if it is missing.
if [ -d "$data_dir" ] && [ ! -e "$data_dir/.minetest" ]; then
  mkdir -p "$data_dir/.minetest" 2>/dev/null || true
fi
if [ -d "$data_dir" ] && ! access_by_uid w "$CONTAINER_UID" "$data_dir/.minetest"; then
  data_problems+=("$data_dir/.minetest does not exist or is not writable by the container user (UID/GID $CONTAINER_UID)")
fi

if [ "${#data_problems[@]}" -gt 0 ]; then
  echo "WARNING: the server will not be able to store its data:" >&2
  for problem in "${data_problems[@]}"; do
    echo "  - $problem" >&2
  done
  fix_cmd="sudo mkdir -p '$data_dir/.minetest' && sudo chown -R $CONTAINER_UID:$CONTAINER_UID '$data_dir'"
  read -r -p "Attempt to fix with sudo now? [y/N]: " fix_reply
  case "$fix_reply" in
    y | Y | yes | Yes)
      if sudo mkdir -p "$data_dir/.minetest" && sudo chown -R "$CONTAINER_UID:$CONTAINER_UID" "$data_dir"; then
        echo "Data directory is now writable by the container user."
      else
        err "Automatic fix failed. Run it manually before starting the server:"
        echo "  $fix_cmd" >&2
      fi
      ;;
    *)
      echo "Fix it manually before starting the server:" >&2
      echo "  $fix_cmd" >&2
      ;;
  esac
else
  echo "Data directory $data_dir is writable by the container user (UID/GID $CONTAINER_UID)."
fi

selected_game="$(env_value GAME_ID)"

echo "Luanti game installer"
echo
echo "Available games:"
default_choice=""
i=1
for entry in "${GAME_REPOS[@]}"; do
  game="${entry%%|*}"
  hint=""
  if [ "$game" = "$selected_game" ]; then
    hint="   <- currently selected in .env (GAME_ID)"
    default_choice="$i"
  fi
  echo "  $i) $game$hint"
  i=$((i + 1))
done
echo

entry=""
while :; do
  prompt="Choose game to install"
  [ -n "$default_choice" ] && prompt="$prompt [${default_choice}]"
  read -r -p "$prompt: " choice
  [ -z "$choice" ] && choice="$default_choice"
  case "$choice" in
    '' | *[!0-9]*) echo "Invalid choice, try again." ; continue ;;
  esac
  if [ "$choice" -ge 1 ] && [ "$choice" -le "${#GAME_REPOS[@]}" ]; then
    entry="${GAME_REPOS[$((choice - 1))]}"
    break
  fi
  echo "Invalid choice, try again."
done
game="${entry%%|*}"
repo="${entry#*|}"

echo
echo "Fetching available releases from $repo ..."
tags="$(git ls-remote --tags "$repo" | sed -n 's|.*refs/tags/||p' | grep -v '\^{}' | grep -E '^[0-9]+(\.[0-9]+)*$' | sort -V)"
if [ -z "$tags" ]; then
  err "No release tags found at $repo"
  exit 1
fi
latest="$(echo "$tags" | tail -n1)"

while :; do
  read -r -p "Version to install [$latest]: " tag
  [ -z "$tag" ] && tag="$latest"
  if echo "$tags" | grep -Fxq "$tag"; then
    break
  fi
  echo "Tag '$tag' not found at $repo. Try again (empty = $latest)."
done

target="$games_dir/$game"

echo
echo "About to install:"
echo "  Game:       $game"
echo "  Version:    $tag"
echo "  Repository: $repo"
echo "  Target:     $target"
echo
read -r -p "Proceed? [y/N]: " reply
case "$reply" in
  y | Y | yes | Yes) ;;
  *)
    echo "Aborted."
    exit 0
    ;;
esac

if [ -e "$target" ]; then
  if ! git -C "$target" rev-parse --git-dir >/dev/null 2>&1; then
    err "$target already exists and is not a git clone."
    echo "Remove or move it away, then re-run this script." >&2
    exit 1
  fi
  remote_url="$(git -C "$target" remote get-url origin 2>/dev/null || true)"
  if [ "$remote_url" != "$repo" ]; then
    err "$target is a clone of '$remote_url', not of '$repo'."
    exit 1
  fi
  echo "Updating existing clone at $target ..."
  git -C "$target" fetch --force --depth 1 origin tag "$tag"
  git -C "$target" checkout "$tag"
else
  mkdir -p "$games_dir"
  echo "Cloning into $target ..."
  git clone --branch "$tag" --depth 1 "$repo" "$target"
fi

# Games are mounted read-only: the server only needs to read them.
ensure_game_readable "$target"

echo
echo "Done. Game '$game' ($tag) is installed in $target"
echo
echo "Next steps:"
echo "  - Make sure GAME_ID=$game in .env (WORLD_NAME selects the world, see README.md)"
echo "  - Restart the server: docker compose up -d"
