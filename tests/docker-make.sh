#!/usr/bin/env bash

set -Eeuo pipefail

TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/shared_dir-docker-make-test.XXXXXX")"
TEST_BIN="$TEST_ROOT/bin"
DOCKER_LOG="$TEST_ROOT/docker.log"
STATE_DIR="$TEST_ROOT/state"

trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

mkdir -p "$TEST_BIN" "$STATE_DIR"

# Record docker argv and emulate the small subset docker-run needs so Make can
# drive the full start → ready → exec → cleanup path without a real daemon.
cat > "$TEST_BIN/docker" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "\$*" >> "\$DOCKER_LOG"

cmd=\${1:-}
shift || true

case \$cmd in
  build | image)
    exit 0
    ;;
  run)
    # docker run -d --name NAME ...
    while [[ \$# -gt 0 ]]; do
      case \$1 in
        --name)
          printf '%s\n' "\$2" > "$STATE_DIR/container"
          shift 2
          ;;
        -d | --privileged | --cgroupns=host | --volume | -v)
          if [[ \$1 == --volume || \$1 == -v ]]; then
            shift 2
          else
            shift
          fi
          ;;
        *)
          shift
          ;;
      esac
    done
    : > "$STATE_DIR/running"
    exit 0
    ;;
  container)
    sub=\${1:-}
    name=\${2:-}
    case \$sub in
      inspect)
        if [[ -f $STATE_DIR/running && -f $STATE_DIR/container && \$(cat "$STATE_DIR/container") == "\$name" ]]; then
          exit 0
        fi
        # Before run, leftover inspect should miss; after rm, miss again.
        if [[ -f $STATE_DIR/removed && \$(cat "$STATE_DIR/removed" 2>/dev/null) == "\$name" ]]; then
          exit 1
        fi
        exit 1
        ;;
      *)
        exit 0
        ;;
    esac
    ;;
  exec)
    # docker exec [-it] NAME CMD...
    # Drop flags until the container name, then run the remaining command when
    # it is our readiness probe or interactive shell stand-in.
    while [[ \$# -gt 0 && \$1 == -* ]]; do
      shift
    done
    name=\${1:-}
    shift || true
    if [[ \$* == "systemctl is-system-running" ]]; then
      printf 'running\n'
      exit 0
    fi
    # Interactive shell: do nothing successfully.
    exit 0
    ;;
  rm)
    while [[ \$# -gt 0 ]]; do
      case \$1 in
        -f)
          shift
          ;;
        *)
          printf '%s\n' "\$1" > "$STATE_DIR/removed"
          rm -f "$STATE_DIR/running"
          shift
          ;;
      esac
    done
    exit 0
    ;;
  logs)
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
EOF
chmod +x "$TEST_BIN/docker"

: > "$DOCKER_LOG"
PATH="$TEST_BIN:$PATH" DOCKER_LOG="$DOCKER_LOG" \
  make --no-print-directory docker-build > "$TEST_ROOT/build-output"

grep -Fqx 'build --file Dockerfile --tag shared_dir:local .' "$DOCKER_LOG" || \
  fail 'default build did not use the Arch Dockerfile and shared_dir image'

: > "$DOCKER_LOG"
rm -f "$STATE_DIR"/*
PATH="$TEST_BIN:$PATH" DOCKER_LOG="$DOCKER_LOG" \
  make --no-print-directory docker-run > "$TEST_ROOT/run-output"

grep -Fqx 'build --file Dockerfile --tag shared_dir:local .' "$DOCKER_LOG" || \
  fail 'docker-run did not rebuild the local systemd image'

grep -Eq '^run -d --name shared_dir-sandbox --privileged --cgroupns=host --volume /sys/fs/cgroup:/sys/fs/cgroup:rw shared_dir:local$' "$DOCKER_LOG" || \
  fail 'docker-run did not start a detached privileged systemd sandbox'

grep -Eq '^exec -it shared_dir-sandbox /usr/local/bin/shared_dir$' "$DOCKER_LOG" || \
  fail 'docker-run did not launch shared_dir automatically'

grep -Eq '^exec -it shared_dir-sandbox /bin/bash$' "$DOCKER_LOG" || \
  fail 'docker-run did not open an inspection shell after shared_dir'

grep -Eq '^rm -f shared_dir-sandbox$' "$DOCKER_LOG" || \
  fail 'docker-run did not remove the sandbox container on exit'

grep -Fq 'ephemeral Docker trial' "$TEST_ROOT/run-output" || \
  fail 'docker-run did not show the ephemeral trial banner'
grep -Fq 'Interactive terminal open inside the container' "$TEST_ROOT/run-output" || \
  fail 'docker-run did not announce the interactive shared_dir session'
grep -Fq 'host stays untouched' "$TEST_ROOT/run-output" || \
  fail 'docker-run did not state that the host stays untouched'
grep -Fq 'Ephemeral sandbox removed' "$TEST_ROOT/run-output" || \
  fail 'docker-run did not confirm sandbox cleanup'

: > "$DOCKER_LOG"
rm -f "$STATE_DIR"/*
# Pretend a leftover container exists so clean-all removes it first.
printf 'shared_dir-sandbox\n' > "$STATE_DIR/container"
: > "$STATE_DIR/running"
PATH="$TEST_BIN:$PATH" DOCKER_LOG="$DOCKER_LOG" \
  make --no-print-directory docker-clean-all > "$TEST_ROOT/clean-all-output"

grep -Fqx 'rm -f shared_dir-sandbox' "$DOCKER_LOG" || \
  fail 'docker-clean-all did not remove the sandbox container'
grep -Fqx 'image rm shared_dir:local' "$DOCKER_LOG" || \
  fail 'docker-clean-all did not remove shared_dir:local'

unmanaged_cleanup_status=0
: > "$DOCKER_LOG"
PATH="$TEST_BIN:$PATH" DOCKER_LOG="$DOCKER_LOG" \
  make --no-print-directory docker-clean DOCKER_IMAGE=unrelated:local > "$TEST_ROOT/unmanaged-cleanup-output" 2>&1 || \
  unmanaged_cleanup_status=$?

((unmanaged_cleanup_status != 0)) || fail 'cleanup accepted an unmanaged Docker image'
grep -Fq 'Refusing to remove unmanaged Docker image: unrelated:local' "$TEST_ROOT/unmanaged-cleanup-output" || \
  fail 'cleanup did not explain why the image was rejected'
[[ ! -s $DOCKER_LOG ]] || fail 'cleanup invoked Docker for an unmanaged image'

printf 'PASS: Make builds and cleans the shared_dir Docker sandbox\n'
