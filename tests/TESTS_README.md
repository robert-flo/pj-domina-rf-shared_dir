# Tests

Regression checks for `shared_dir` and the Make/CI helpers that ship with this
repository. Every script is a plain Bash file: no framework, no network, and no
changes to your real system configuration.

## Layout

| File | What it guards |
| --- | --- |
| `shared_dir.sh` | Installer contract (product smoke tests) |
| `docker-make.sh` | `make docker-*` targets (argv and cleanup) |
| `git-make.sh` | Default-branch protection in `make` Git targets |
| `changelog-automation.sh` | PR changelog generator idempotency |

## How to run them

From the repository root:

```bash
# One suite
bash tests/shared_dir.sh
bash tests/docker-make.sh
bash tests/git-make.sh
bash tests/changelog-automation.sh

# Everything local contributors are expected to run before a PR
bash tests/shared_dir.sh \
  && bash tests/docker-make.sh \
  && bash tests/git-make.sh \
  && bash tests/changelog-automation.sh
```

Optional companion checks (also used in CI / CONTRIBUTING):

```bash
shellcheck -S warning shared_dir tests/*.sh .vscode/shellcheck.sh .git-hooks/pre-commit
pre-commit run --all-files
```

### Expected output

Each suite prints a single success line and exits `0` on pass, or `FAIL: …` and
a non-zero status on failure:

```text
PASS: shared_dir smoke contract
PASS: Make builds and cleans the shared_dir Docker sandbox
PASS: Make protects the resolved GitHub default branch
PASS: generated changelog is idempotent and whitespace-safe
```

---

## `shared_dir.sh` — product smoke contract

Exercises the installer **without real root**. It copies `./shared_dir` into a
temporary fixture, opens the EUID guard only in that copy, redirects install
paths into the fixture tree, and stubs privileged tools (`chown`, `chmod`,
`setfacl`, `getfacl`, `systemctl`, `getent`, `pacman`, `inotifywait`).

| Case | Assertion |
| --- | --- |
| Syntax | `bash -n` on the product file; executable bit set |
| Non-root | Real binary refuses with “must be run as root” |
| Relative path | Absolute path required; relative input fails early |
| Missing `wheel` | Stops before creating the directory |
| Happy path | Creates the directory, fix script, watcher, `*-perms.service` / `*-perms.timer`, and records `systemctl enable --now` |
| Custom basename | e.g. `…/team-share` → `team-share-perms.*` unit names |

**Does not** start real systemd, install packages, or modify the host.

```bash
bash tests/shared_dir.sh
# PASS: shared_dir smoke contract
```

---

## `docker-make.sh` — Make Docker targets

Drives `make docker-build`, `make docker-run`, and `make docker-clean-all` with a
**stub `docker` on `PATH`** that only records argv. No Docker daemon is required.

Checks that Make:

- builds `Dockerfile` as `shared_dir:local`
- starts a detached privileged sandbox (`--cgroupns=host`, cgroup mount)
- auto-launches `/usr/local/bin/shared_dir`, then an inspection shell
- removes the sandbox container on exit
- prints the ephemeral-trial banner (host stays untouched / cleanup confirmed)
- refuses `docker-clean` of unmanaged image names

This validates the **Make wiring**, not a live systemd container. For a real
trial use `make docker-run` manually (see README).

```bash
bash tests/docker-make.sh
# PASS: Make builds and cleans the shared_dir Docker sandbox
```

---

## `git-make.sh` — default-branch protection

Uses a stub `gh` binary to verify that the Make Git helpers refuse a direct push
workflow against the resolved GitHub default branch. This enforces the repo
branching policy (`RELEASE_POLICY.md`); it is unrelated to the installer itself.

```bash
bash tests/git-make.sh
# PASS: Make protects the resolved GitHub default branch
```

---

## `changelog-automation.sh` — PR changelog generator

Runs `.github/scripts/update-pr-changelog.sh` twice against a **copy** of
`CHANGELOG.md` (never the working tree file):

1. First run inserts a labeled Unreleased entry.
2. Second run must be byte-identical (idempotent).
3. The file must not end with a trailing blank line.

```bash
bash tests/changelog-automation.sh
# PASS: generated changelog is idempotent and whitespace-safe
```

---

## When to run them manually

| Situation | What to run |
| --- | --- |
| Before opening a pull request | All four suites + `shellcheck` (and `pre-commit` if installed) |
| Changed `./shared_dir` | `bash tests/shared_dir.sh` |
| Changed `make/docker.mk` or `Dockerfile` | `bash tests/docker-make.sh` (plus a real `make docker-run` if you care about systemd behavior) |
| Changed `make/git.mk` branch protection | `bash tests/git-make.sh` |
| Changed changelog scripts or `CHANGELOG.md` format | `bash tests/changelog-automation.sh` |
| After pulling `master` | Full suite if you are about to commit on top |

You do **not** need root, Docker, or network access for any script under
`tests/`.

---

## Where they run in CI

`.github/workflows/ci.yml` job **Validate repository changes** runs, in order:

1. whitespace check on the changed range  
2. `bash -n` on changed shell scripts  
3. `shellcheck -S warning shared_dir tests/*.sh …`  
4. `bash tests/shared_dir.sh`  
5. `bash tests/docker-make.sh`  
6. `bash tests/git-make.sh`  
7. `bash tests/changelog-automation.sh`  

Triggers: pull requests to `master`, pushes to `master`, and manual
`workflow_dispatch`. A separate job runs `pre-commit` on the whole tree.

---

## What these tests deliberately skip

- Live privileged Docker + systemd end-to-end install (`make docker-run`)
- Real `pacman` package installs
- Host ACL / inotify / systemd unit persistence after the process exits

Those paths are for interactive trials or a future integration suite, not for
this fast offline gate.
