# shared_dir

Arch Linux root helper that creates a group-shared directory with unrestricted
in-group access. It sets SGID permissions and default ACLs, installs a fix-up
script, and keeps permissions correct in real time with a systemd service
(`inotify`) plus a backup timer.

Default target directory: `/wt`. Default group: `wheel`.

---

<br>

<a id="installation"></a>
<img src="https://readme-typing-svg.herokuapp.com?font=Lexend+Giga&size=25&pause=1000&color=CCA9DD&vCenter=true&width=435&height=25&lines=INSTALLATION" width="450"/>

### Arch Linux Dependencies

`shared_dir` runs only on Arch Linux and must be executed as root. It expects
`pacman` and will install missing runtime packages when needed:

```shell
sudo pacman -S --needed acl inotify-tools
```

Also required (normally present on a full Arch system):

- `bash`, `coreutils`, `findutils`, `util-linux`
- `systemd` (for the watcher service and backup timer)

### From Source

Clone the repository and run the installer:

```shell
git clone https://github.com/robert-flo/pj-domina-rf-shared_dir.git
cd pj-domina-rf-shared_dir
sudo ./shared_dir
```

The script then:

1. Verifies root and that group `wheel` exists
2. Ensures `acl` and `inotify-tools` are installed
3. Creates the directory as `root:wheel` with mode `2770` (SGID, no sticky bit)
4. Applies recursive and default ACLs (`g:wheel:rwx`)
5. Installs `/usr/local/bin/fix_shared_dir_perms.sh`
6. Installs and starts a per-directory systemd service and 30s backup timer

Service names are derived from the directory basename
(for `/wt` → `wt-perms.service` / `wt-perms.timer`).

### Usage

```shell
sudo ./shared_dir [DIRECTORY ...]
sudo ./shared_dir --help
```

`DIRECTORY` values must be absolute paths. With no directory arguments, the
installer configures `/wt`. Each requested directory is configured in order
with the same `wheel` permissions, ACLs, fix script, permission watcher, and
backup timer.

```shell
# Configure the default shared directory: /wt
sudo ./shared_dir

# Configure one explicit shared directory
sudo ./shared_dir /team-share

# Configure several shared directories in one pass
sudo ./shared_dir /wt /team-share /projects

# See supported arguments and examples without changing the system
./shared_dir --help
# `-h` and `-help` are accepted aliases
```

The installer rejects relative paths and unknown options before it performs
privileged configuration. If any requested directory cannot be configured, the
command exits non-zero.

### Verify permission watchers

Use the included verifier to confirm that each permission watcher repairs a
controlled temporary file. It changes only its own marker files and removes
them before returning a per-directory result and summary:

```shell
sudo ./scripts/verify_shared_dir_monitoring.sh /wt /team-share /projects
```

---

<br>

<a id="docker"></a>
<img src="https://readme-typing-svg.herokuapp.com?font=Lexend+Giga&size=25&pause=1000&color=CCA9DD&vCenter=true&width=435&height=25&lines=TRY%20IT%20IN%20DOCKER" width="450"/>

Try the full root + systemd flow in an isolated privileged Arch container
before touching the host:

```shell
make docker-run
```

That builds `shared_dir:local` when needed, starts an ephemeral container
with systemd as PID 1 (`--privileged`, host cgroup namespace), waits until
systemd is ready, and launches `shared_dir` automatically. When the installer
exits you get a root shell to inspect the result (`systemctl`, `getfacl`,
`ls`). Exit the shell to destroy the container.

Useful image lifecycle commands:

```shell
make docker-build
make docker-clean
make docker-clean-all
```

Nothing from the container persists on the host after exit.

---

<br>

<a id="behavior"></a>
<img src="https://readme-typing-svg.herokuapp.com?font=Lexend+Giga&size=25&pause=1000&color=CCA9DD&vCenter=true&width=435&height=25&lines=BEHAVIOR" width="450"/>

| Item | Value |
| --- | --- |
| Directory owner | `root:wheel` |
| Mode | `2770` (SGID; group rwx; others none) |
| ACLs | `g:wheel:rwx` on the tree + default ACL for new entries |
| Fix script | `/usr/local/bin/fix_shared_dir_perms.sh` |
| Watcher | `inotifywait` loop via `${name}-perms.service` |
| Backup | `${name}-perms.timer` every 30 seconds |

Any member of `wheel` can create, read, modify, delete, and execute files under
the shared directory. New files inherit the group and are corrected in real
time when permissions drift.

Add users to the group:

```shell
sudo usermod -aG wheel <username>
```

Group membership is cached until a new login session (or `newgrp wheel` in the
current terminal).

Useful service commands (example for `/wt`):

```shell
sudo systemctl status wt-perms.service
sudo systemctl restart wt-perms.service
sudo journalctl -u wt-perms.service -f
```

---

<br>

<a id="security"></a>
<img src="https://readme-typing-svg.herokuapp.com?font=Lexend+Giga&size=25&pause=1000&color=CCA9DD&vCenter=true&width=435&height=25&lines=SECURITY" width="450"/>

- Requires root; do not run untrusted copies with `sudo`.
- Grants full mutual access inside `wheel` (including delete). There is no
  sticky bit.
- Others have no access to the shared directory.
- Existing ACLs are backed up under `/tmp` when reconfiguring a directory that
  already exists.
- The Docker sandbox is privileged by design so systemd and ACL behavior match
  a real host; treat it as a throwaway environment.

---

<br>

<a id="contributing"></a>
<img src="https://readme-typing-svg.herokuapp.com?font=Lexend+Giga&size=25&pause=1000&color=CCA9DD&vCenter=true&width=435&height=25&lines=CONTRIBUTING" width="450"/>

- Prefer a clear issue describing a bug or feature over an unfocused pull
  request.
- Every change is reviewed line by line.
- Read [CONTRIBUTING.md](CONTRIBUTING.md) for local checks and the pull-request
  workflow.

---

<br>

## License

This project is released under the [MIT License](LICENSE).
