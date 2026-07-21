#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/shared_dir-git-make-test.XXXXXX")"
TEST_BIN="$TEST_ROOT/bin"
GH_LOG="$TEST_ROOT/gh.log"
GH_PAYLOAD="$TEST_ROOT/payload.json"

trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

mkdir -p "$TEST_BIN"
cat > "$TEST_BIN/gh" <<'MOCK_GH'
#!/usr/bin/env bash
set -Eeuo pipefail

printf '%s\n' "$*" >> "$GH_LOG"

case "${1:-}" in
  auth)
    exit 0
    ;;
  repo)
    case "$*" in
      *nameWithOwner*) printf '%s\n' 'example-owner/example-repo' ;;
      *defaultBranchRef*) printf '%s\n' 'trunk' ;;
    esac
    ;;
  api)
    cat > "$GH_PAYLOAD"
    ;;
  *)
    printf 'unexpected gh invocation: %s\n' "$*" >&2
    exit 1
    ;;
esac
MOCK_GH
chmod +x "$TEST_BIN/gh"

PATH="$TEST_BIN:$PATH" GH_LOG="$GH_LOG" GH_PAYLOAD="$GH_PAYLOAD" \
  make --no-print-directory -C "$ROOT_DIR" git-protect-default-branch \
  > "$TEST_ROOT/protect-output"

grep -Fqx 'api --method PUT repos/example-owner/example-repo/branches/trunk/protection --input -' "$GH_LOG" || \
  fail 'protection target did not resolve the repository default branch'
for expected in \
  '"enforce_admins":true' \
  '"required_approving_review_count":0' \
  '"allow_force_pushes":false' \
  '"allow_deletions":false' \
  '"allow_fork_syncing":false'; do
  grep -Fq "$expected" "$GH_PAYLOAD" || fail "missing protection setting: $expected"
done
if grep -Fq 'dismissal_restrictions' "$GH_PAYLOAD"; then
  fail 'personal repositories must omit dismissal restrictions'
fi

: > "$GH_LOG"
rm -f "$GH_PAYLOAD"
PATH="$TEST_BIN:$PATH" GH_LOG="$GH_LOG" GH_PAYLOAD="$GH_PAYLOAD" \
  make --no-print-directory -C "$ROOT_DIR" git-protect-default-branch DRY_RUN=1 \
  > "$TEST_ROOT/dry-run-output"

grep -Fq 'would require pull requests' "$TEST_ROOT/dry-run-output" || \
  fail 'dry run did not describe the intended protection'
if grep -Fq 'api --method PUT' "$GH_LOG"; then
  fail 'dry run updated branch protection'
fi
[[ ! -e $GH_PAYLOAD ]] || fail 'dry run sent a branch-protection payload'

printf 'PASS: Make protects the resolved GitHub default branch\n'
