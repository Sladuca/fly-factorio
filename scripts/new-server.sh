#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Create and optionally deploy a new Fly.io Factorio server from fly.template.toml.

Usage:
  scripts/new-server.sh --app APP_NAME --region REGION [options]

Required:
  --app NAME                 Fly app name, e.g. factorio-seb-space-age
  --region REGION            Fly region for the machine and volume, e.g. sjc, ord, iad

Options:
  --volume-name NAME         Fly volume name inside the app (default: factorio)
  --volume-size GB           Initial volume size in GB (default: 30)
  --factorio-tag TAG         factoriotools/factorio tag (default: stable)
  --memory SIZE              VM memory, e.g. 4gb, 8gb (default: 8gb)
  --cpus N                   VM shared CPU count (default: 4)
  --cpu-kind KIND            shared or performance (default: shared)
  --space-age true|false     Enable Space Age built-in mods (default: true)
  --update-mods true|false   Update mods on boot (default: true)
  --save-name NAME           Load /factorio/saves/NAME.zip instead of latest save
  --username USERNAME        Set Factorio USERNAME secret
  --token TOKEN              Set Factorio TOKEN secret
  --no-ip                    Do not allocate a dedicated IPv4 address
  --no-deploy                Generate config and create resources, but do not deploy
  --yes                      Pass --yes to Fly commands that may prompt, including IPv4 allocation
  -h, --help                 Show this help

Environment variable fallbacks use the uppercase option names where practical:
  APP_NAME, REGION, FACTORIO_USERNAME, FACTORIO_TOKEN, etc.

Notes:
  UDP on Fly.io requires a dedicated IPv4 address. Dedicated IPv4 addresses are
  a paid resource; omit --yes if you want flyctl to ask for confirmation.
USAGE
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "error: required command '$1' not found" >&2
    exit 1
  }
}

APP_NAME="${APP_NAME:-}"
REGION="${REGION:-}"
VOLUME_NAME="${VOLUME_NAME:-factorio}"
VOLUME_SIZE="${VOLUME_SIZE:-30}"
FACTORIO_TAG="${FACTORIO_TAG:-stable}"
VM_MEMORY="${VM_MEMORY:-8gb}"
CPUS="${CPUS:-4}"
CPU_KIND="${CPU_KIND:-shared}"
DLC_SPACE_AGE="${DLC_SPACE_AGE:-true}"
UPDATE_MODS_ON_START="${UPDATE_MODS_ON_START:-true}"
LOAD_LATEST_SAVE="${LOAD_LATEST_SAVE:-true}"
SAVE_NAME="${SAVE_NAME:-}"
FACTORIO_USERNAME="${FACTORIO_USERNAME:-${USERNAME:-}}"
FACTORIO_TOKEN="${FACTORIO_TOKEN:-${TOKEN:-}}"
SNAPSHOT_RETENTION="${SNAPSHOT_RETENTION:-14}"
AUTO_EXTEND_THRESHOLD="${AUTO_EXTEND_THRESHOLD:-80}"
AUTO_EXTEND_INCREMENT="${AUTO_EXTEND_INCREMENT:-5}"
AUTO_EXTEND_LIMIT="${AUTO_EXTEND_LIMIT:-100}"
ALLOCATE_IP=1
DEPLOY=1
YES=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app) APP_NAME="$2"; shift 2 ;;
    --region) REGION="$2"; shift 2 ;;
    --volume-name) VOLUME_NAME="$2"; shift 2 ;;
    --volume-size) VOLUME_SIZE="$2"; shift 2 ;;
    --factorio-tag) FACTORIO_TAG="$2"; shift 2 ;;
    --memory) VM_MEMORY="$2"; shift 2 ;;
    --cpus) CPUS="$2"; shift 2 ;;
    --cpu-kind) CPU_KIND="$2"; shift 2 ;;
    --space-age) DLC_SPACE_AGE="$2"; shift 2 ;;
    --update-mods) UPDATE_MODS_ON_START="$2"; shift 2 ;;
    --save-name) SAVE_NAME="$2"; LOAD_LATEST_SAVE="false"; shift 2 ;;
    --username) FACTORIO_USERNAME="$2"; shift 2 ;;
    --token) FACTORIO_TOKEN="$2"; shift 2 ;;
    --no-ip) ALLOCATE_IP=0; shift ;;
    --no-deploy) DEPLOY=0; shift ;;
    --yes|-y) YES=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

[[ -n "$APP_NAME" ]] || { echo "error: --app is required" >&2; usage >&2; exit 1; }
[[ -n "$REGION" ]] || { echo "error: --region is required" >&2; usage >&2; exit 1; }
[[ "$DLC_SPACE_AGE" == "true" || "$DLC_SPACE_AGE" == "false" ]] || { echo "error: --space-age must be true or false" >&2; exit 1; }
[[ "$UPDATE_MODS_ON_START" == "true" || "$UPDATE_MODS_ON_START" == "false" ]] || { echo "error: --update-mods must be true or false" >&2; exit 1; }
[[ "$LOAD_LATEST_SAVE" == "true" || "$LOAD_LATEST_SAVE" == "false" ]] || { echo "error: LOAD_LATEST_SAVE must be true or false" >&2; exit 1; }

require_cmd fly
require_cmd perl

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$ROOT_DIR/fly.template.toml"
GENERATED_DIR="$ROOT_DIR/generated"
CONFIG="$GENERATED_DIR/$APP_NAME.fly.toml"
mkdir -p "$GENERATED_DIR"

if [[ -n "$SAVE_NAME" ]]; then
  SAVE_NAME_LINE="  SAVE_NAME = \"$SAVE_NAME\""
else
  SAVE_NAME_LINE=""
fi
export APP_NAME REGION VOLUME_NAME VOLUME_SIZE FACTORIO_TAG VM_MEMORY CPUS CPU_KIND \
  DLC_SPACE_AGE UPDATE_MODS_ON_START LOAD_LATEST_SAVE SAVE_NAME_LINE SNAPSHOT_RETENTION \
  AUTO_EXTEND_THRESHOLD AUTO_EXTEND_INCREMENT AUTO_EXTEND_LIMIT

perl -pe 's/\$\{([A-Z0-9_]+)\}/exists $ENV{$1} ? $ENV{$1} : $&/ge' < "$TEMPLATE" > "$CONFIG"

echo "Generated $CONFIG"

fly_maybe_yes() {
  if [[ "$YES" -eq 1 ]]; then
    fly "$@" --yes
  else
    fly "$@"
  fi
}

if ! fly apps list | awk '{print $1}' | grep -Fxq "$APP_NAME"; then
  fly_maybe_yes apps create "$APP_NAME"
else
  echo "App $APP_NAME already exists"
fi

if ! fly volumes list --app "$APP_NAME" | awk -v name="$VOLUME_NAME" -v region="$REGION" '$2 == name && $3 == region { found = 1 } END { exit !found }'; then
  fly_maybe_yes volumes create "$VOLUME_NAME" --app "$APP_NAME" --region "$REGION" --size "$VOLUME_SIZE"
else
  echo "Volume $VOLUME_NAME already exists in $REGION for $APP_NAME"
fi

if [[ "$ALLOCATE_IP" -eq 1 ]]; then
  if fly ips list --app "$APP_NAME" | grep -Eiq 'v4|ipv4'; then
    echo "App $APP_NAME already has an IPv4 address"
  else
    echo "Allocating dedicated IPv4 for UDP. This is a paid Fly.io resource."
    fly_maybe_yes ips allocate-v4 --app "$APP_NAME"
  fi
else
  echo "Skipping IPv4 allocation (--no-ip). UDP will not work without a dedicated IPv4 address."
fi

if [[ -n "$FACTORIO_USERNAME" || -n "$FACTORIO_TOKEN" ]]; then
  [[ -n "$FACTORIO_USERNAME" && -n "$FACTORIO_TOKEN" ]] || {
    echo "error: provide both --username and --token, or neither" >&2
    exit 1
  }
  fly secrets set --app "$APP_NAME" USERNAME="$FACTORIO_USERNAME" TOKEN="$FACTORIO_TOKEN"
else
  echo "Skipping Factorio secrets. Set later with: fly secrets set --app $APP_NAME USERNAME=... TOKEN=..."
fi

if [[ "$DEPLOY" -eq 1 ]]; then
  fly deploy --app "$APP_NAME" --config "$CONFIG"
else
  echo "Skipping deploy (--no-deploy). Deploy later with: fly deploy --app $APP_NAME --config $CONFIG"
fi

echo
echo "Done. Connect to: $APP_NAME.fly.dev:34197"
