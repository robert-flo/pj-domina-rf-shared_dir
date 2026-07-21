#!/usr/bin/env bash

set -euo pipefail

mode=${1:-}

is_shell_file() {
  local file=$1
  local shebang

  [[ $file == *.sh ]] && return 0
  IFS= read -r shebang < "$file" || true
  [[ $shebang =~ ^\#![[:space:]]*/([^[:space:]]*/)?(env[[:space:]]+)?(bash|sh)([[:space:]]|$) ]]
}

check_file() {
  local file=$1

  [[ -f $file ]] || return 0
  is_shell_file "$file" || return 0
  shellcheck -f gcc -- "$file" || true
}

case $mode in
  changed)
    while IFS= read -r -d '' file; do
      check_file "$file"
    done < <(
      {
        git diff --name-only -z --diff-filter=ACMRT HEAD
        git ls-files --others --exclude-standard -z
      } | sort -zu
    )
    ;;
  full)
    while IFS= read -r -d '' file; do
      check_file "${file#./}"
    done < <(find . -type f -not -path './.git/*' -print0 | sort -z)
    ;;
  *)
    printf 'Usage: %s {changed|full}\n' "$0" >&2
    exit 2
    ;;
esac
