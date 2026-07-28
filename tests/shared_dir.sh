#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHARED_DIR_SRC="$ROOT_DIR/shared_dir"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/shared_dir-test.XXXXXX")"

trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

require_output() {
  grep -Fq "$2" "$1" || fail "missing output in ${1##*/}: $2"
}

require_file() {
  [[ -f $1 ]] || fail "missing file: $1"
}

# Fixture copy of the installer and its modules plus PATH stubs for privileged
# side effects. The product files on disk are never modified.
build_fixture() {
  local fixture=$1
  local log=$2

  mkdir -p \
    "$fixture/bin" \
    "$fixture/usr/local/bin" \
    "$fixture/etc/systemd/system" \
    "$fixture/tmp" \
    "$fixture/var"

  cp "$SHARED_DIR_SRC" "$fixture/shared_dir"
  cp -R "$ROOT_DIR/helper" "$fixture/helper"
  cp -R "$ROOT_DIR/scripts" "$fixture/scripts"
  # Host smoke tests are not root. Open the EUID guard and redirect only the
  # absolute install destinations the product writes, without rewriting paths
  # that already point inside the fixture.
  python3 - "$fixture/shared_dir" "$fixture" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
fixture = sys.argv[2]
replacements = {
    'if [[ $EUID -ne 0 ]]; then': 'if [[ 1 -eq 0 ]]; then',
    'DEFAULT_DIR="/wt"': f'DEFAULT_DIR="{fixture}/var/default"',
    '"/usr/local/bin/': f'"{fixture}/usr/local/bin/',
    '"/etc/systemd/system/': f'"{fixture}/etc/systemd/system/',
    '"/tmp/shared_dir_acl_backup_': f'"{fixture}/tmp/shared_dir_acl_backup_',
}
for candidate in [path, *sorted((path.parent / 'helper').glob('*.sh')), *sorted((path.parent / 'scripts').glob('*.sh'))]:
    text = candidate.read_text()
    for old, new in replacements.items():
        text = text.replace(old, new)
    candidate.write_text(text)
PY

  cat > "$fixture/bin/getent" <<'EOF'
#!/usr/bin/env bash
if [[ ${1:-} == group && ${2:-} == wheel ]]; then
  printf 'wheel:x:10:root,testuser\n'
  exit 0
fi
exit 2
EOF

  cat > "$fixture/bin/setfacl" <<EOF
#!/usr/bin/env bash
printf 'setfacl %s\n' "\$*" >> "$log"
exit 0
EOF

  cat > "$fixture/bin/getfacl" <<'EOF'
#!/usr/bin/env bash
printf '# file: %s\n' "${1:-}"
printf 'user::rwx\ngroup::rwx\nother::---\n'
exit 0
EOF

  cat > "$fixture/bin/systemctl" <<EOF
#!/usr/bin/env bash
printf 'systemctl %s\n' "\$*" >> "$log"
exit 0
EOF

  cat > "$fixture/bin/chown" <<EOF
#!/usr/bin/env bash
printf 'chown %s\n' "\$*" >> "$log"
exit 0
EOF

  cat > "$fixture/bin/chmod" <<EOF
#!/usr/bin/env bash
printf 'chmod %s\n' "\$*" >> "$log"
/usr/bin/chmod "\$@" 2>/dev/null || true
exit 0
EOF

  cat > "$fixture/bin/inotifywait" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

  # pacman must not run during smoke tests. If the installer reaches it, fail.
  cat > "$fixture/bin/pacman" <<EOF
#!/usr/bin/env bash
printf 'pacman %s\n' "\$*" >> "$log"
exit 1
EOF

  chmod +x "$fixture/bin"/*

  # Prefer fixture stubs, then the real host tools for mkdir/find/etc.
  export PATH="$fixture/bin:/usr/bin:/bin"
}

run_with_path() {
  local fixture=$1
  local out=$2
  shift 2

  env PATH="$fixture/bin:/usr/bin:/bin" \
    bash "$fixture/shared_dir" "$@" > "$out" 2>&1
}

# ── Syntax and executable bit ──────────────────────────────────
bash -n "$SHARED_DIR_SRC" || fail 'shared_dir failed bash -n'
bash -n "$ROOT_DIR"/helper/*.sh "$ROOT_DIR"/scripts/*.sh || \
  fail 'shared_dir modules failed bash -n'
[[ -x $SHARED_DIR_SRC ]] || fail 'shared_dir is not executable'

# ── Help is side-effect free ───────────────────────────────────
help_fixture="$TEST_ROOT/help"
help_log="$TEST_ROOT/help.log"
: > "$help_log"
build_fixture "$help_fixture" "$help_log"
run_with_path "$help_fixture" "$TEST_ROOT/help.out" --help || fail 'help failed'
require_output "$TEST_ROOT/help.out" 'Usage: shared_dir [OPTIONS] [DIRECTORY ...]'
require_output "$TEST_ROOT/help.out" 'sudo ./shared_dir /wt /team-share'
[[ ! -s $help_log ]] || fail 'help triggered privileged commands'
run_with_path "$help_fixture" "$TEST_ROOT/help-short.out" -help || fail '-help failed'
require_output "$TEST_ROOT/help-short.out" 'Usage: shared_dir [OPTIONS] [DIRECTORY ...]'

# ── Non-root must refuse ───────────────────────────────────────
non_root_status=0
"$SHARED_DIR_SRC" /wt > "$TEST_ROOT/non-root.out" 2>&1 || non_root_status=$?
((non_root_status != 0)) || fail 'non-root invocation did not fail'
require_output "$TEST_ROOT/non-root.out" 'This script must be run as root.'

# ── Relative path rejected (before privileged work) ────────────
relative_status=0
"$SHARED_DIR_SRC" relative/path > "$TEST_ROOT/relative.out" 2>&1 || relative_status=$?
((relative_status != 0)) || fail 'relative path did not fail'
require_output "$TEST_ROOT/relative.out" 'The path must be absolute'

# ── Invalid option fails before privileged work ────────────────
invalid_status=0
"$SHARED_DIR_SRC" --unknown > "$TEST_ROOT/invalid.out" 2>&1 || invalid_status=$?
((invalid_status != 0)) || fail 'invalid option did not fail'
require_output "$TEST_ROOT/invalid.out" 'Invalid option: --unknown'

# ── Missing wheel group stops before mutation ──────────────────
missing_group="$TEST_ROOT/missing-group"
missing_log="$TEST_ROOT/missing-group.log"
: > "$missing_log"
build_fixture "$missing_group" "$missing_log"
cat > "$missing_group/bin/getent" <<'EOF'
#!/usr/bin/env bash
exit 2
EOF
chmod +x "$missing_group/bin/getent"

missing_group_status=0
run_with_path "$missing_group" "$TEST_ROOT/missing-group.out" \
  "$missing_group/var/share" || missing_group_status=$?
((missing_group_status != 0)) || fail 'missing wheel group did not fail'
require_output "$TEST_ROOT/missing-group.out" "Group 'wheel' does not exist"
[[ ! -e $missing_group/var/share ]] || fail 'missing group still created the directory'

# ── Happy path: units, fix script, watcher ─────────────────────
happy="$TEST_ROOT/happy"
happy_log="$TEST_ROOT/happy.log"
: > "$happy_log"
build_fixture "$happy" "$happy_log"
target_dir="$happy/var/wt"

run_with_path "$happy" "$TEST_ROOT/happy.out" "$target_dir" || \
  fail "happy path failed: $(cat "$TEST_ROOT/happy.out")"

require_output "$TEST_ROOT/happy.out" 'Configuration completed successfully.'
require_output "$TEST_ROOT/happy.out" "Directory:            $target_dir"
require_output "$TEST_ROOT/happy.out" 'Group:                wheel'
require_output "$TEST_ROOT/happy.out" 'Base permissions:     2770 (SGID, no sticky bit)'
require_output "$TEST_ROOT/happy.out" 'wt-perms.service'
require_output "$TEST_ROOT/happy.out" 'wt-perms.timer'

require_file "$happy/usr/local/bin/fix_shared_dir_perms.sh"
require_file "$happy/usr/local/bin/wt-perms_watcher.sh"
require_file "$happy/etc/systemd/system/wt-perms.service"
require_file "$happy/etc/systemd/system/wt-perms.timer"
[[ -d $target_dir ]] || fail 'shared directory was not created'

grep -Fq 'fix_shared_dir_perms.sh' "$happy/usr/local/bin/wt-perms_watcher.sh" || \
  fail 'watcher does not invoke the fix script'
grep -Fq "Description=Monitors $target_dir" "$happy/etc/systemd/system/wt-perms.service" || \
  fail 'service unit missing directory description'
grep -Fq 'OnUnitActiveSec=30s' "$happy/etc/systemd/system/wt-perms.timer" || \
  fail 'timer unit missing 30s interval'
grep -Fq 'systemctl daemon-reload' "$happy_log" || \
  fail 'systemctl daemon-reload was not invoked'
grep -Fq 'systemctl enable --now wt-perms.service' "$happy_log" || \
  fail 'service was not enabled'
grep -Fq 'systemctl enable --now wt-perms.timer' "$happy_log" || \
  fail 'timer was not enabled'
grep -Fq 'pacman' "$happy_log" && fail 'smoke test invoked pacman' || true

# ── No operand configures the default directory ────────────────
default="$TEST_ROOT/default"
default_log="$TEST_ROOT/default.log"
: > "$default_log"
build_fixture "$default" "$default_log"
default_dir="$default/var/default"

run_with_path "$default" "$TEST_ROOT/default.out" || \
  fail "default path failed: $(cat "$TEST_ROOT/default.out")"
[[ -d $default_dir ]] || fail 'default shared directory was not created'
require_output "$TEST_ROOT/default.out" "Directory:            $default_dir"

# ── Custom basename drives service name ────────────────────────
custom="$TEST_ROOT/custom"
custom_log="$TEST_ROOT/custom.log"
: > "$custom_log"
build_fixture "$custom" "$custom_log"
custom_dir="$custom/var/team-share"

run_with_path "$custom" "$TEST_ROOT/custom.out" "$custom_dir" || \
  fail "custom path failed: $(cat "$TEST_ROOT/custom.out")"

require_file "$custom/etc/systemd/system/team-share-perms.service"
require_file "$custom/etc/systemd/system/team-share-perms.timer"
require_file "$custom/usr/local/bin/team-share-perms_watcher.sh"
require_output "$TEST_ROOT/custom.out" 'team-share-perms.service'

# ── Multiple targets are configured independently ──────────────
multi="$TEST_ROOT/multi"
multi_log="$TEST_ROOT/multi.log"
: > "$multi_log"
build_fixture "$multi" "$multi_log"
first_dir="$multi/var/first-share"
second_dir="$multi/var/second-share"

run_with_path "$multi" "$TEST_ROOT/multi.out" "$first_dir" "$second_dir" || \
  fail "multiple targets failed: $(cat "$TEST_ROOT/multi.out")"

require_file "$multi/etc/systemd/system/first-share-perms.service"
require_file "$multi/etc/systemd/system/second-share-perms.service"
require_file "$multi/usr/local/bin/first-share-perms_watcher.sh"
require_file "$multi/usr/local/bin/second-share-perms_watcher.sh"
require_output "$TEST_ROOT/multi.out" "Directory:            $first_dir"
require_output "$TEST_ROOT/multi.out" "Directory:            $second_dir"
grep -Fq "SHARED_DIR=\"$first_dir\"" "$multi/usr/local/bin/first-share-perms_watcher.sh" || \
  fail 'first watcher does not retain its target directory'
grep -Fq "SHARED_DIR=\"$second_dir\"" "$multi/usr/local/bin/second-share-perms_watcher.sh" || \
  fail 'second watcher does not retain its target directory'

printf 'PASS: shared_dir smoke contract\n'
