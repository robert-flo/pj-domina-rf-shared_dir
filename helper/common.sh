#!/usr/bin/env bash

# shellcheck disable=SC2034 # consumed by the root entry point after sourcing
DEFAULT_DIR="/z"
SHARE_GROUP="wheel"
# shellcheck disable=SC2034 # consumed by the configuration operation after sourcing
FIX_SCRIPT_NAME="fix_shared_dir_perms.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
step() { echo -e "${BLUE}[STEP]${NC} $1"; }
ok() { echo -e "${CYAN}[OK]${NC} $1"; }

usage() {
  cat <<'EOF'
Usage: shared_dir [OPTIONS] [DIRECTORY ...]

Create and monitor one or more shared directories for the wheel group.
With no DIRECTORY, the installer configures /z.

Options:
  -h, --help, -help  Show this help and exit.

DIRECTORY values must be absolute paths. Each directory receives mode 2770,
ACLs for wheel, a permission watcher, and a 30-second backup timer.

Examples:
  sudo ./shared_dir
  sudo ./shared_dir /z
  sudo ./shared_dir /z /team-share
EOF
}

normalize_shared_directory() {
  local input_dir=$1

  if [[ $input_dir != /* ]]; then
    error "The path must be absolute (start with /). Example: /z"
    return 1
  fi

  realpath -m -- "$input_dir"
}

report_failure() {
  local exit_code=$?

  if [[ $exit_code -ne 0 ]]; then
    error "The script failed with exit code $exit_code."
    error 'Check the error messages above.'
  fi
}

require_root() {
  step '1/9 - Checking root permissions...'
  if [[ $EUID -ne 0 ]]; then
    error 'This script must be run as root.'
    error 'Usage: sudo bash shared_dir [DIRECTORY ...]'
    exit 1
  fi
  ok 'Running as root.'
}

require_share_group() {
  step "2/9 - Checking that group '$SHARE_GROUP' exists..."
  if ! getent group "$SHARE_GROUP" &>/dev/null; then
    error "Group '$SHARE_GROUP' does not exist on this system."
    error "Create it first with: sudo groupadd $SHARE_GROUP"
    exit 1
  fi
  ok "Group '$SHARE_GROUP' found."
}

ensure_dependencies() {
  step '3/9 - Checking dependencies...'

  if ! command -v setfacl &>/dev/null; then
    info "Installing 'acl' package..."
    if ! pacman -S --noconfirm acl 2>/dev/null; then
      error "Could not install 'acl'. Check your connection and repositories."
      exit 1
    fi
    ok "'acl' package installed."
  else
    ok "'acl' package already installed."
  fi

  if ! command -v inotifywait &>/dev/null; then
    info "Installing 'inotify-tools' package..."
    if ! pacman -S --noconfirm inotify-tools 2>/dev/null; then
      error "Could not install 'inotify-tools'. Check your connection and repositories."
      exit 1
    fi
    ok "'inotify-tools' package installed."
  else
    ok "'inotify-tools' package already installed."
  fi
}
