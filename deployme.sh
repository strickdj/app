#!/bin/bash

set -euo pipefail

DRY_RUN=0
BASE_DIR=""
RELEASES=""
NEW_RELEASE=""
PREVIOUS_RELEASE=""
SWITCHED=0
LOCK_HELD=0

readonly ARCHIVE_PATH="/tmp/release.tar.gz"
readonly RELEASE_KEEP=4

print_usage() {
  echo "Usage: $0 [base_dir] [--dry-run]"
}

parse_args() {
  local arg
  local base_arg="./"

  for arg in "$@"; do
    case "$arg" in
      --dry-run|-n)
        DRY_RUN=1
        ;;
      --help|-h)
        print_usage
        exit 0
        ;;
      *)
        if [[ "$base_arg" != "./" ]]; then
          echo "Only one base_dir argument is allowed." >&2
          exit 1
        fi
        base_arg="$arg"
        ;;
    esac
  done

  BASE_DIR="$(cd "$base_arg" && pwd)" # canonicalize path even when ssh starts in home dir
}

init_paths() {
  local timestamp

  RELEASES="$BASE_DIR/releases"
  timestamp="$(date +%Y%m%d%H%M%S)"
  NEW_RELEASE="$RELEASES/$timestamp"
}

resolve_current_release() {
  local current_link="$BASE_DIR/current"

  if [[ ! -e "$current_link" && ! -L "$current_link" ]]; then
    printf ''
    return 0
  fi

  if [[ ! -L "$current_link" ]]; then
    echo "Refusing to deploy: $current_link exists but is not a symlink" >&2
    return 1
  fi

  local resolved
  resolved="$(readlink -f "$current_link" 2>/dev/null || true)"

  if [[ -z "$resolved" || ! -d "$resolved" ]]; then
    echo "Refusing to deploy: $current_link does not point to a valid release directory" >&2
    return 1
  fi

  case "$resolved" in
    "$RELEASES"/*)
      printf '%s\n' "$resolved"
      ;;
    *)
      echo "Refusing to deploy: $current_link points outside of $RELEASES" >&2
      return 1
      ;;
  esac
}

atomic_switch_current() {
  local target_release="$1"
  local tmp_link="$BASE_DIR/.current.tmp.$$"

  if [[ ! -d "$target_release" ]]; then
    echo "Cannot switch current symlink: release directory not found: $target_release" >&2
    return 1
  fi

  ln -sfn "$target_release" "$tmp_link"
  mv -Tf "$tmp_link" "$BASE_DIR/current"
}

cleanup() {
  if [[ "$LOCK_HELD" -eq 1 ]]; then
    flock -u 200 || true
  fi
}

rollback() {
  if [[ "$SWITCHED" -eq 1 && -n "${PREVIOUS_RELEASE:-}" ]]; then
    atomic_switch_current "$PREVIOUS_RELEASE"
    echo "Rolled back to previous release: $PREVIOUS_RELEASE" >&2
  fi
}

on_error() {
  echo "Deploy failed." >&2
  rollback
  exit 1
}

ensure_deploy_lock() {
  local lock_file="$RELEASES/.deploy.lock"

  if ! command -v flock >/dev/null 2>&1; then
    echo "Required command not found: flock" >&2
    return 1
  fi

  mkdir -p "$RELEASES"
  exec 200>"$lock_file"

  if ! flock -n 200; then
    echo "Another deployment appears to be in progress: $lock_file" >&2
    return 1
  fi

  printf '%s\n' "$$" 1>&200
  LOCK_HELD=1

  return 0
}

ensure_structure() {
  local -a structure_entries=(
    "dir:releases" # release directories
    "dir:shared"
    "dir:shared/bootstrap"
    "dir:shared/bootstrap/cache"
    "dir:shared/storage"
    "dir:shared/storage/logs"
    "dir:shared/storage/framework"
    "dir:shared/storage/framework/views"
    "dir:shared/storage/framework/cache"
    "dir:shared/storage/framework/sessions"
    "file:shared/.env"
  )
  local entry
  local type
  local path
  local full_path

  for entry in "${structure_entries[@]}"; do
    [[ -z "${entry:-}" ]] && continue

    type="${entry%%:*}"
    path="${entry#*:}"

    if [[ -z "$type" || -z "$path" || "$type" == "$entry" ]]; then
      echo "Invalid structure entry: '$entry' (expected 'dir:path' or 'file:path')" >&2
      exit 1
    fi

    full_path="$BASE_DIR/$path"

    case "$type" in
      dir)
        if [[ "$DRY_RUN" -eq 1 ]]; then
          if [[ -d "$full_path" ]]; then
            echo "[dry-run] Directory exists: $full_path"
          else
            echo "[dry-run] Would create directory: $full_path"
          fi
        else
          mkdir -p "$full_path"
        fi
        ;;
      file)
        if [[ "$DRY_RUN" -eq 1 ]]; then
          if [[ ! -d "$(dirname "$full_path")" ]]; then
            echo "[dry-run] Would create parent directory: $(dirname "$full_path")"
          fi

          if [[ -f "$full_path" ]]; then
            echo "[dry-run] File exists: $full_path"
          else
            echo "[dry-run] Would create file: $full_path"
          fi
        else
          mkdir -p "$(dirname "$full_path")"
          [[ -f "$full_path" ]] || touch "$full_path"
        fi
        ;;
      *)
        echo "Unknown structure type '$type' in entry '$entry'" >&2
        exit 1
        ;;
    esac
  done
}

validate_archive() {
  if [[ ! -r "$ARCHIVE_PATH" ]]; then
    echo "Release archive not found or not readable: $ARCHIVE_PATH" >&2
    exit 1
  fi

  if tar -tzf "$ARCHIVE_PATH" | grep -Eq '(^/|(^|/)\.\.(/|$))'; then
    echo "Unsafe paths detected in release archive: $ARCHIVE_PATH" >&2
    exit 1
  fi
}

print_dry_run_plan() {
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
  echo "[dry-run] Would clean up old releases (keep last $RELEASE_KEEP)"
  echo "Dry run complete."
}

prepare_release_directory() {
  echo "Creating release directory..."
  mkdir -p "$NEW_RELEASE"

  echo "Extracting build..."
  tar -xzf "$ARCHIVE_PATH" -C "$NEW_RELEASE"
  rm "$ARCHIVE_PATH"
}

link_shared_files() {
  echo "Linking shared files..."
  ln -sfn "$BASE_DIR/shared/.env" "$NEW_RELEASE/.env"

  if [[ -e "$NEW_RELEASE/storage" && ! -L "$NEW_RELEASE/storage" ]]; then
    rm -rf "$NEW_RELEASE/storage"
  fi
  ln -sfn "$BASE_DIR/shared/storage" "$NEW_RELEASE/storage"

  if [[ -e "$NEW_RELEASE/bootstrap/cache" && ! -L "$NEW_RELEASE/bootstrap/cache" ]]; then
    rm -rf "$NEW_RELEASE/bootstrap/cache"
  fi
  ln -sfn "$BASE_DIR/shared/bootstrap/cache" "$NEW_RELEASE/bootstrap/cache"
}

install_and_migrate() {
  cd "$NEW_RELEASE"

  echo "Installing dependencies (safety net)..."
  composer install --no-dev --prefer-dist --no-interaction

  echo "Validating migrations (--pretend)..."
  php artisan migrate --force --pretend

  echo "Applying migrations..."
  php artisan migrate --force
}

optimize_and_restart_queue() {
  cd "$BASE_DIR/current"

  echo "Running optimizations..."
  php artisan config:cache
  php artisan route:cache
  php artisan view:clear
  php artisan view:cache

  echo "Restarting queue workers..."
  php artisan queue:restart
}

cleanup_old_releases() {
  local current_release="$1"
  echo "Cleanup old releases (keep last $RELEASE_KEEP)..."
  local entry
  local release_dir
  local -a release_entries=()
  local kept=0

  while IFS= read -r -d '' entry; do
    release_entries+=("${entry#* }")
  done < <(find "$RELEASES" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\0' | sort -zr)

  for release_dir in "${release_entries[@]}"; do
    if [[ "$release_dir" == "$current_release" || "$release_dir" == "$NEW_RELEASE" || "$release_dir" == "$PREVIOUS_RELEASE" ]]; then
      continue
    fi

    if [[ "$kept" -lt "$RELEASE_KEEP" ]]; then
      kept=$((kept + 1))
      continue
    fi

    rm -rf "$release_dir"
  done
}

main() {
  local current_release

  parse_args "$@"
  init_paths

  trap cleanup EXIT
  trap on_error ERR

  cd "$BASE_DIR"

  if [[ "$DRY_RUN" -eq 0 ]]; then
    if ! ensure_deploy_lock; then
      exit 1
    fi
  else
    echo "Dry run mode enabled. No filesystem or database changes will be made."
  fi

  PREVIOUS_RELEASE="$(resolve_current_release)"

  # /var/www/myapp
  #  ├── releases/
  #  ├── current -> releases/20260422120000
  #  ├── shared/
  #      ├── .env
  #      ├── storage/
  ensure_structure
  validate_archive

  if [[ "$DRY_RUN" -eq 1 ]]; then
    print_dry_run_plan
    exit 0
  fi

  prepare_release_directory
  link_shared_files
  install_and_migrate

  echo "Switching release (atomic)..."
  atomic_switch_current "$NEW_RELEASE"
  SWITCHED=1

  current_release="$(resolve_current_release)"

  optimize_and_restart_queue
  cleanup_old_releases "$current_release"

  echo "Deploy complete."
}

main "$@"
