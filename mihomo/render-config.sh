#!/bin/sh
set -eu

CONFIG_DIR=/root/.config/mihomo
TEMPLATE_PATH="${CONFIG_DIR}/config.yaml.tmpl"
CONFIG_PATH="${CONFIG_DIR}/config.yaml"

: "${SOCKS_CONTAINER_PORT:=1050}"
: "${HTTP_CONTAINER_PORT:=1080}"
: "${TPROXY_CONTAINER_PORT:=12345}"
: "${CONTROLLER_CONTAINER_PORT:=9090}"
: "${CONTROLLER_SECRET:=change-me}"

if [ ! -f "${TEMPLATE_PATH}" ]; then
  echo >&2 "Missing ${TEMPLATE_PATH}. Copy config/config.yaml.dist to config/config.yaml.tmpl first."
  exit 1
fi

case "${CONTROLLER_SECRET}" in
  "" | "change-me" | "changeme" | "CHANGE_ME" | "CHANGE_ME_TO_A_LONG_RANDOM_TOKEN")
    echo >&2 "Set CONTROLLER_SECRET in .env before starting Mihomo."
    exit 1
    ;;
esac

escape_replacement() {
  printf "%s" "$1" | sed 's/[&|\\]/\\&/g'
}

cp "${TEMPLATE_PATH}" "${CONFIG_PATH}"

sed -i \
  -e "s|__SOCKS_CONTAINER_PORT__|$(escape_replacement "${SOCKS_CONTAINER_PORT}")|g" \
  -e "s|__HTTP_CONTAINER_PORT__|$(escape_replacement "${HTTP_CONTAINER_PORT}")|g" \
  -e "s|__TPROXY_CONTAINER_PORT__|$(escape_replacement "${TPROXY_CONTAINER_PORT}")|g" \
  -e "s|__CONTROLLER_CONTAINER_PORT__|$(escape_replacement "${CONTROLLER_CONTAINER_PORT}")|g" \
  -e "s|__CONTROLLER_SECRET__|$(escape_replacement "${CONTROLLER_SECRET}")|g" \
  "${CONFIG_PATH}"

exec /mihomo -d "${CONFIG_DIR}" "$@"
