#!/bin/sh

set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$repo_root"

echo "Rendering top-level docker compose stacks"

for compose_file in */docker-compose.yml; do
	if [ ! -f "$compose_file" ]; then
		continue
	fi

	stack_dir=${compose_file%/docker-compose.yml}
	env_dist="$stack_dir/.env.dist"
	stack_env="$stack_dir/.env"

	echo "==> [$stack_dir] docker compose config"

	created_env=0
	if [ ! -f "$stack_env" ] && [ -f "$env_dist" ]; then
		cp "$env_dist" "$stack_env"
		created_env=1
	fi

	if ! docker compose -f "$compose_file" config >/dev/null; then
		if [ "$created_env" -eq 1 ]; then
			rm -f "$stack_env"
		fi
		echo "ERROR [$stack_dir]: docker compose config failed for $compose_file"
		exit 1
	fi

	if [ "$created_env" -eq 1 ]; then
		rm -f "$stack_env"
	fi
done

echo "Compose validation passed"
