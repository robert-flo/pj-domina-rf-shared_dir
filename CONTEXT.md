# shared_dir

This context defines the terms used by the shared directory installer and its
source repository.

## Language

**Shared directory**:
The absolute filesystem path configured for unrestricted in-group collaboration
(default `/wt`).
_Avoid_: worktree root (unless that path is intentionally the shared directory)

**Share group**:
The Unix group granted full access to the shared directory (fixed as `wheel` in
the current installer).
_Avoid_: owner, others

**Installer**:
The root executable `shared_dir` in the source repository that creates the
shared directory, applies permissions, and installs monitoring.
_Avoid_: fix script, watcher

**Fix script**:
The generated helper installed at `/usr/local/bin/fix_shared_dir_perms.sh` that
repairs group ownership and mode bits under the shared directory.
_Avoid_: installer, systemd unit

**Permission watcher**:
The systemd service that runs an `inotifywait` loop and invokes the fix script
when the tree changes.
_Avoid_: backup timer

**Backup timer**:
The systemd timer that periodically runs the same repair path as a safety net
when inotify misses an event.
_Avoid_: permission watcher

**Source repository**:
This GitHub repository (`robert-flo/pj-domina-rf-shared_dir`), which owns the installer,
tests, Docker sandbox, and release history.
_Avoid_: package repository (not used yet)
