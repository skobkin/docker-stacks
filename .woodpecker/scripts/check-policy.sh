#!/bin/sh

set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$repo_root"

pipeline_files="${CI_PIPELINE_FILES:-}"
prev_commit_sha="${CI_PREV_COMMIT_SHA:-}"

env_file_pattern='^[[:space:]]*env_file:([[:space:]]*(["'\'']?\.env["'\'']?)|[[:space:]]*$)'

echo "Checking stack policy constraints"

for compose_file in */docker-compose.yml; do
	if [ ! -f "$compose_file" ]; then
		continue
	fi

	stack_dir=${compose_file%/docker-compose.yml}

	if grep -Eq "$env_file_pattern" "$compose_file" && [ ! -f "$stack_dir/.env.dist" ]; then
		echo "ERROR [$stack_dir]: uses env_file=.env but $stack_dir/.env.dist is missing"
		exit 1
	fi
done

if [ -z "$pipeline_files" ]; then
	echo "Skipping PORTS.md check: CI_PIPELINE_FILES is not set"
	exit 0
fi

if printf '%s\n' "$pipeline_files" | tr ',' '\n' | grep -Fxq 'PORTS.md'; then
	echo "PORTS.md changed in this pipeline, skipping port diff enforcement"
	exit 0
fi

if [ -z "$prev_commit_sha" ]; then
	echo "Skipping PORTS.md check: CI_PREV_COMMIT_SHA is not set"
	exit 0
fi

echo "Checking published port changes against PORTS.md"

changed_compose_files=$(
	printf '%s\n' "$pipeline_files" \
	| tr ',' '\n' \
	| grep -E '^[^/]+/docker-compose\.yml$' || true
)

if [ -z "$changed_compose_files" ]; then
	echo "No stack compose files changed"
	exit 0
fi

for compose_file in $changed_compose_files; do
	if [ ! -f "$compose_file" ]; then
		continue
	fi

	stack_dir=${compose_file%/docker-compose.yml}

	if ! grep -Eq '^[[:space:]]*ports:[[:space:]]*$' "$compose_file"; then
		continue
	fi

	if ! git cat-file -e "$prev_commit_sha:$compose_file" 2>/dev/null; then
		echo "ERROR [$stack_dir]: $compose_file is new or missing in $prev_commit_sha; update PORTS.md if published ports were added"
		exit 1
	fi

	if git diff --unified=0 "$prev_commit_sha" -- "$compose_file" \
		| awk '
			BEGIN { in_ports = 0; changed = 0 }
			/^@@/ { next }
			/^[+-][[:space:]]*ports:[[:space:]]*$/ { in_ports = 1; changed = 1; next }
			/^[ +-][[:space:]]*-[[:space:]]/ {
				if (in_ports) {
					changed = 1
				}
				next
			}
			/^[ +-][[:space:]]*[A-Za-z0-9_.-]+:[[:space:]]*$/ {
				in_ports = 0
				next
			}
			/^[ +-][[:space:]]*$/ { next }
			{ in_ports = 0 }
			END { exit changed ? 0 : 1 }
		'
	then
		echo "ERROR [$stack_dir]: published ports changed in $compose_file but PORTS.md was not updated"
		exit 1
	fi
done

echo "Policy checks passed"
