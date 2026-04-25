#!/bin/bash

set -euo pipefail

APP_DIR=/var/www/myapp
RELEASES=$APP_DIR/releases
TIMESTAMP=$(date +%Y%m%d%H%M%S)
NEW_RELEASE=$RELEASES/$TIMESTAMP

 # /var/www/myapp
 #  ├── releases/
 #  ├── current -> releases/20260422120000
 #  ├── shared/
 #      ├── .env
 #      ├── storage/

# ensure releases directory structure
FILE="server-structure.txt"
BASE_DIR="${1:-./}"   # default: ./ if not provided

while read -r type path; do
  [[ -z "${type:-}" || -z "${path:-}" ]] && continue

  # normalize full path relative to base
  FULL_PATH="$BASE_DIR/$path"

  case "$type" in
    dir)
      mkdir -p "$FULL_PATH"
      ;;
    file)
      mkdir -p "$(dirname "$FULL_PATH")"
      [ -f "$FULL_PATH" ] || touch "$FULL_PATH"
      ;;
  esac
done < "$FILE"

echo "Creating release directory..."
mkdir -p "$NEW_RELEASE"

echo "Extracting build..."
tar -xzf /tmp/release.tar.gz -C "$NEW_RELEASE"
rm /tmp/release.tar.gz

echo "Linking shared files..."
ln -sfn $APP_DIR/shared/.env "$NEW_RELEASE/.env"
rm -rf "$NEW_RELEASE/storage"
ln -sfn $APP_DIR/shared/storage "$NEW_RELEASE/storage"

cd "$NEW_RELEASE"

echo "Installing dependencies (safety net)..."
composer install --no-dev --prefer-dist --no-interaction

echo "Running migrations safely..."
# should do this first and check for errors before switching release, to avoid downtime if there are issues
#php artisan migrate --force --pretend
php artisan migrate --force

echo "Running optimizations..."
php artisan config:cache
php artisan route:cache
php artisan view:cache

echo "Switching release (atomic)..."
ln -sfn "$NEW_RELEASE" "$APP_DIR/current"

echo "Restarting queue workers..."
php artisan queue:restart

echo "Cleanup old releases (keep last 4)..."
find "$RELEASES" -mindepth 1 -maxdepth 1 -printf '%T@ %p\0' \
  | sort -zr \
  | tail -zn +5 \
  | cut -z -d' ' -f2- \
  | xargs -0 rm -rf || true

echo "Deploy complete."
