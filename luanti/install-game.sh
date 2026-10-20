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

# Read a simple KEY=VALUE from .env without sourcing it.
env_value() {
  grep -E "^$1=" .env 2>/dev/null | tail -n1 | cut -d= -f2- | tr -d '"' | tr -d "'" || true
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

echo
echo "Done. Game '$game' ($tag) is installed in $target"
echo
echo "Next steps:"
echo "  - Make sure GAME_ID=$game in .env (WORLD_NAME selects the world, see README.md)"
echo "  - Restart the server: docker compose up -d"
