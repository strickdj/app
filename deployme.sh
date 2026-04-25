#!/bin/bash

set -euo pipefail

DRY_RUN=0
BASE_ARG="./"

for arg in "$@"; do
  case "$arg" in
    --dry-run|-n)
      DRY_RUN=1
      ;;
    --help|-h)
      echo "Usage: $0 [base_dir] [--dry-run]"
      exit 0
      ;;
    *)
      if [[ "$BASE_ARG" != "./" ]]; then
        echo "Only one base_dir argument is allowed." >&2
        exit 1
      fi
      BASE_ARG="$arg"
      ;;
  esac
done

BASE_DIR="$(cd "$BASE_ARG" && pwd)"   # canonicalize path even when ssh starts in home dir
APP_DIR="$BASE_DIR"
RELEASES="$APP_DIR/releases"
TIMESTAMP=$(date +%Y%m%d%H%M%S)
NEW_RELEASE=$RELEASES/$TIMESTAMP
LOCK_DIR="$APP_DIR/.deploy.lock"
ARCHIVE_PATH="/tmp/release.tar.gz"
PREVIOUS_RELEASE="$(readlink -f "$APP_DIR/current" 2>/dev/null || true)"
SWITCHED=0
LOCK_HELD=0

cleanup() {
  if [[ "$LOCK_HELD" -eq 1 ]]; then
    rm -rf "$LOCK_DIR"
  fi
}

rollback() {
  if [[ "$SWITCHED" -eq 1 && -n "${PREVIOUS_RELEASE:-}" ]]; then
    ln -sfn "$PREVIOUS_RELEASE" "$APP_DIR/current"
    echo "Rolled back to previous release: $PREVIOUS_RELEASE" >&2
  fi
}

on_error() {
  echo "Deploy failed." >&2
  rollback
  exit 1
}

trap cleanup EXIT
trap on_error ERR

cd "$BASE_DIR"

if [[ "$DRY_RUN" -eq 0 ]]; then
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "Another deployment appears to be in progress: $LOCK_DIR" >&2
    exit 1
  fi
  LOCK_HELD=1
else
  echo "Dry run mode enabled. No filesystem or database changes will be made."
fi

# /var/www/myapp
#  ├── releases/
#  ├── current -> releases/20260422120000
#  ├── shared/
#      ├── .env
#      ├── storage/

# ensure releases directory structure
# format: "<type>:<relative-path>"
# type must be "dir" or "file"
STRUCTURE_ENTRIES=(
  "dir:releases"       # release directories
  "dir:shared"         # shared root
  "dir:shared/storage" # persistent Laravel storage
  "file:shared/.env"   # shared environment file
)

for entry in "${STRUCTURE_ENTRIES[@]}"; do
  # skip empty lines defensively
  [[ -z "${entry:-}" ]] && continue

  # strict split: everything before first ":" is type, remainder is path
  type="${entry%%:*}"
  path="${entry#*:}"

  if [[ -z "$type" || -z "$path" || "$type" == "$entry" ]]; then
    echo "Invalid structure entry: '$entry' (expected 'dir:path' or 'file:path')" >&2
    exit 1
  fi

  FULL_PATH="$BASE_DIR/$path"

  case "$type" in
    dir)
      if [[ "$DRY_RUN" -eq 1 ]]; then
        if [[ -d "$FULL_PATH" ]]; then
          echo "[dry-run] Directory exists: $FULL_PATH"
        else
          echo "[dry-run] Would create directory: $FULL_PATH"
        fi
      else
        mkdir -p "$FULL_PATH"
      fi
      ;;
    file)
      if [[ "$DRY_RUN" -eq 1 ]]; then
        if [[ ! -d "$(dirname "$FULL_PATH")" ]]; then
          echo "[dry-run] Would create parent directory: $(dirname "$FULL_PATH")"
        fi

        if [[ -f "$FULL_PATH" ]]; then
          echo "[dry-run] File exists: $FULL_PATH"
        else
          echo "[dry-run] Would create file: $FULL_PATH"
        fi
      else
        mkdir -p "$(dirname "$FULL_PATH")"
        [[ -f "$FULL_PATH" ]] || touch "$FULL_PATH"
      fi
      ;;
    *)
      echo "Unknown structure type '$type' in entry '$entry'" >&2
      exit 1
      ;;
  esac
done

if [[ ! -r "$ARCHIVE_PATH" ]]; then
  echo "Release archive not found or not readable: $ARCHIVE_PATH" >&2
  exit 1
fi

if tar -tzf "$ARCHIVE_PATH" | grep -Eq '(^/|(^|/)\.\.(/|$))'; then
  echo "Unsafe paths detected in release archive: $ARCHIVE_PATH" >&2
  exit 1
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "[dry-run] Release archive validated: $ARCHIVE_PATH"
  echo "[dry-run] Would create release directory: $NEW_RELEASE"
  echo "[dry-run] Would extract archive into release directory"
  echo "[dry-run] Would link shared files (.env, storage)"
  echo "[dry-run] Would run composer install --no-dev --prefer-dist --no-interaction"
  echo "[dry-run] Would run php artisan migrate --force --pretend"
  echo "[dry-run] Would run php artisan migrate --force"
  echo "[dry-run] Would run config/route/view cache commands"
  echo "[dry-run] Would atomically switch current symlink"
  echo "[dry-run] Would run php artisan queue:restart"
  echo "[dry-run] Would clean up old releases (keep last 4)"
  echo "Dry run complete."
  exit 0
fi

echo "Creating release directory..."
mkdir -p "$NEW_RELEASE"

echo "Extracting build..."
tar -xzf "$ARCHIVE_PATH" -C "$NEW_RELEASE"
rm "$ARCHIVE_PATH"

echo "Linking shared files..."
ln -sfn "$APP_DIR/shared/.env" "$NEW_RELEASE/.env"
if [[ -e "$NEW_RELEASE/storage" && ! -L "$NEW_RELEASE/storage" ]]; then
  rm -rf "$NEW_RELEASE/storage"
fi
ln -sfn "$APP_DIR/shared/storage" "$NEW_RELEASE/storage"

cd "$NEW_RELEASE"

echo "Installing dependencies (safety net)..."
composer install --no-dev --prefer-dist --no-interaction

echo "Validating migrations (--pretend)..."
php artisan migrate --force --pretend

echo "Applying migrations..."
php artisan migrate --force

echo "Running optimizations..."
php artisan config:cache
php artisan route:cache
php artisan view:cache

echo "Switching release (atomic)..."
ln -sfn "$NEW_RELEASE" "$APP_DIR/current"
SWITCHED=1

echo "Restarting queue workers..."
php artisan queue:restart

echo "Cleanup old releases (keep last 4)..."
find "$RELEASES" -mindepth 1 -maxdepth 1 -printf '%T@ %p\0' \
  | sort -zr \
  | tail -zn +5 \
  | cut -z -d' ' -f2- \
  | xargs -0 rm -rf || true

echo "Deploy complete."
