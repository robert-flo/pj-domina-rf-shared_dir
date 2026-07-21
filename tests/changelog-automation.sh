#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/shared_dir-changelog-test.XXXXXX")"
CHANGELOG_FILE="$TEST_ROOT/CHANGELOG.md"

trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

cp "$ROOT_DIR/CHANGELOG.md" "$CHANGELOG_FILE"

generate_changelog() {
  PR_NUMBER=999 \
    PR_URL='https://example.test/pull/999' \
    PR_TITLE='999 - Keep generated changelog whitespace valid' \
    PR_LABELS='changelog:changed' \
    CHANGELOG_FILE="$CHANGELOG_FILE" \
    "$ROOT_DIR/.github/scripts/update-pr-changelog.sh"
}

generate_changelog
first_digest=$(sha256sum "$CHANGELOG_FILE")
generate_changelog
[[ $first_digest == "$(sha256sum "$CHANGELOG_FILE")" ]] || fail 'changelog generation is not idempotent'

awk '
  NF { last_nonblank_line = NR }
  END { exit NR != last_nonblank_line }
' "$CHANGELOG_FILE" || fail 'generated changelog has a blank line at EOF'

printf 'PASS: generated changelog is idempotent and whitespace-safe\n'
