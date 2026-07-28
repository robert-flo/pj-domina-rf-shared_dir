#!/usr/bin/env bash
#
# Verify that each shared directory's permission watcher repairs a controlled
# permission drift on a temporary marker created by this script.
#
# Examples:
#   sudo ./scripts/verify_shared_dir_monitoring.sh /wt
#   sudo ./scripts/verify_shared_dir_monitoring.sh /wt /team-share /projects

set -Eeuo pipefail

SHARE_GROUP='wheel'
TIMEOUT_SECONDS=10
declare -a MARKERS=()

usage() {
  cat <<'EOF'
Usage: verify_shared_dir_monitoring.sh [--timeout SECONDS] DIRECTORY...

For every DIRECTORY, create a temporary marker, force it to root:root with
mode 0600, then wait for the permission watcher to restore group wheel and
group rwx access. Markers are removed before exit.

Examples:
  sudo ./scripts/verify_shared_dir_monitoring.sh /wt
  sudo ./scripts/verify_shared_dir_monitoring.sh /wt /team-share /projects
  sudo ./scripts/verify_shared_dir_monitoring.sh --timeout 15 /projects
EOF
}

error() {
  printf 'ERROR: %s\n' "$1" >&2
}

cleanup() {
  local marker

  for marker in "${MARKERS[@]}"; do
    [[ -e $marker ]] && rm -f -- "$marker"
  done
}

has_group_rwx() {
  local mode=$1
  local mode_value

  mode_value=$((8#$mode))
  (( (mode_value & 0070) == 0070 ))
}

verify_directory() {
  local directory=$1
  local marker
  local started_at
  local elapsed
  local group
  local mode
  local owner

  if [[ ! -d $directory ]]; then
    printf 'FAIL  %s: directory does not exist\n' "$directory"
    return 1
  fi

  marker=$(mktemp --tmpdir="$directory" '.shared-dir-monitor.XXXXXX')
  MARKERS+=("$marker")
  chown root:root "$marker"
  chmod 0600 "$marker"
  started_at=$(date +%s)

  while true; do
    group=$(stat -c '%G' -- "$marker")
    mode=$(stat -c '%a' -- "$marker")

    if [[ $group == "$SHARE_GROUP" ]] && has_group_rwx "$mode"; then
      elapsed=$(( $(date +%s) - started_at ))
      owner=$(stat -c '%U' -- "$marker")
      printf 'PASS  %s: restored %s:%s mode %s in %ss\n' \
        "$directory" "$owner" "$group" "$mode" "$elapsed"
      rm -f -- "$marker"
      return 0
    fi

    elapsed=$(( $(date +%s) - started_at ))
    if (( elapsed >= TIMEOUT_SECONDS )); then
      owner=$(stat -c '%U' -- "$marker")
      printf 'FAIL  %s: after %ss marker is %s:%s mode %s\n' \
        "$directory" "$elapsed" "$owner" "$group" "$mode"
      rm -f -- "$marker"
      return 1
    fi

    sleep 0.1
  done
}

main() {
  local -a directories=()
  local directory
  local passed=0
  local failed=0

  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help|-help)
        usage
        exit 0
        ;;
      --timeout)
        [[ $# -ge 2 ]] || { error '--timeout requires a value'; exit 2; }
        TIMEOUT_SECONDS=$2
        shift
        ;;
      --)
        shift
        directories+=("$@")
        break
        ;;
      -*)
        error "Invalid option: $1"
        usage >&2
        exit 2
        ;;
      *)
        directories+=("$1")
        ;;
    esac
    shift
  done

  [[ ${TIMEOUT_SECONDS} =~ ^[1-9][0-9]*$ ]] || {
    error '--timeout must be a positive number of seconds'
    exit 2
  }
  [[ ${#directories[@]} -gt 0 ]] || {
    error 'Provide at least one shared directory.'
    usage >&2
    exit 2
  }
  [[ $EUID -eq 0 ]] || {
    error 'This verification must be run as root.'
    exit 2
  }

  trap cleanup EXIT
  printf 'Verifying permission watchers for group %s (timeout: %ss)\n' \
    "$SHARE_GROUP" "$TIMEOUT_SECONDS"

  for directory in "${directories[@]}"; do
    if verify_directory "$directory"; then
      ((passed += 1))
    else
      ((failed += 1))
    fi
  done

  printf 'Summary: %d passed, %d failed\n' "$passed" "$failed"
  (( failed == 0 ))
}

main "$@"
