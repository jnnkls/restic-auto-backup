#!/usr/bin/env bash
set -o errexit
set -o pipefail

# Optional dry-run mode
RESTIC_ADDITIONALS=""
for arg in "$@"; do
  if [ "$arg" == "--dry-run" ]; then
    RESTIC_ADDITIONALS="--dry-run"
    echo "[INFO] Running in dry-run mode: no data will be written."
  fi
done

# Utility functions
log_error() {
  local msg="$1"
  printf "[ERROR] %s\n" "$msg" >&2
}

log_info() {
  local msg="$1"
  printf "[INFO] %s\n" "$msg"
}

# Check for missing .env file
if [ ! -f .env ]; then
  log_error "Can't find .env file in '$(pwd)'"
  exit 1
fi

# Required environment variables
REQUIRED_VARS=(
  WORKING_DIR
  BACKUP_PASSWORD_FILE
  BACKUP_BACKEND
  BACKUP_REPO
  BACKUP_PATHS
  BACKUP_EXCLUDES_FILE
)

set -o allexport
source .env
set +o allexport

# Check required variables
missing_vars=()
for var in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var+x}" ] || [ -z "${!var}" ]; then
    missing_vars+=("$var")
  fi
done

if [ ${#missing_vars[@]} -ne 0 ]; then
  log_error "The following required variables are missing or empty:"
  for var in "${missing_vars[@]}"; do
    echo " - $var"
  done
  exit 1
fi

IFS=' ' read -r -a BACKUP_PATHS_ARRAY <<< "$BACKUP_PATHS"
if [[ ${#BACKUP_PATHS_ARRAY[@]} -eq 0 ]]; then
  log_error "No paths found in BACKUP_PATHS"
  exit 1
fi

# Check for required files
if [ ! -f "$BACKUP_PASSWORD_FILE" ]; then
  log_error "Can't find password file at '$BACKUP_PASSWORD_FILE'"
  exit 1
fi

if [ ! -f "$BACKUP_EXCLUDES_FILE" ]; then
  log_error "Can't find excludes file at '$BACKUP_EXCLUDES_FILE'"
  exit 1
fi

# Check required commands
for cmd in uuidgen restic curl; do
  if ! command -v "$cmd" &> /dev/null; then
    log_error "Required command '$cmd' not found"
    exit 1
  fi
done

# Check if already running
LOCKFILE="$WORKING_DIR/backup.lock"
if [ -f "$LOCKFILE" ]; then
  log_error "The script is already running (lock file exists)"
  exit 1
fi

# Create lock and temp log file
uuid=$(uuidgen)
LOGFILE=$(mktemp retic-backup.XXXXXX.log)
touch "$LOGFILE"
touch "$LOCKFILE"

hc_log() {
  if [ -z "${!BACKUP_HEALTHCHECK_ID+x}" ] || [ -z "${!BACKUP_HEALTHCHECK_ID}" ]; then
    return 1
  fi

  local mode="$1"
  shift

  local url="https://hc-ping.com/$BACKUP_HEALTHCHECK_ID"
  local curl_args=(-fsS -m 10 --retry 5 -o /dev/null)

  case "$mode" in
    start)
      url+="/start?rid=$uuid"
      ;;
    log)
      url+="/log?rid=$uuid"
      curl_args+=(--data-raw "$1")
      ;;
    log_withFile)
      url+="/log?rid=$uuid"
      curl_args+=(--data-binary "@$LOGFILE")
      ;;
    fail)
      url+="/fail?rid=$uuid"
      curl_args+=(--data-binary "@$LOGFILE")
      ;;
    finish)
      url+="?rid=$uuid"
      ;;
    *)
      log_error "You need to specify one of [start/log/log_withFile/fail/finish] for hc_log() - given $mode"
      return 1
      ;;
  esac

  curl "${curl_args[@]}" "$url"
}

# Cleanup trap (runs on all exits)
trap 'rm -f "$LOGFILE" "$LOCKFILE"' EXIT

# Failure-specific trap
error_handler() {
  hc_log "fail"
  exit 1
}
trap 'error_handler' ERR

# Healthcheck start
hc_log "start"

# Backup each path
for rawpath in "${BACKUP_PATHS_ARRAY[@]}"; do
  bpath=$(echo "$rawpath" | xargs)  # trim whitespace
  if [[ -z "$bpath" ]]; then
    log_info "'$bpath' doesn't exist, skipping"
    continue  # skip empty paths
  fi

  log_info "Starting backup for path: $bpath"
  hc_log "log" "Start backup on path $bpath"

  restic -p "$BACKUP_PASSWORD_FILE" -v -r "$BACKUP_BACKEND:$BACKUP_REPO" backup \
  "$bpath" $RESTIC_ADDITIONALS --exclude-file="$BACKUP_EXCLUDES_FILE" \
  2>&1 | tee -a "$LOGFILE"

  RESTIC_EXIT=${PIPESTATUS[0]}
  if [[ $RESTIC_EXIT -ne 0 ]]; then
    hc_log "log" "Restic failed for path $bpath"
  fi

  hc_log "log_withFile"
done

# Healthcheck complete
hc_log "finish"
log_info "Backup finished successfully"