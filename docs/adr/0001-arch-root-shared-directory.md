# Arch root installer for group-shared directories

`shared_dir` is a single root executable for Arch Linux. It configures one
absolute shared directory for the `wheel` group using mode `2770` (SGID, no
sticky bit), POSIX ACLs, a generated fix script under `/usr/local/bin`, and a
systemd permission watcher backed by `inotify-tools` plus a short interval
timer.

The source repository ships that installer directly. There is no multi-command
dispatcher, no non-Arch package manager path, and no separate package payload
layout yet. Local Docker support is an Arch image that runs systemd as PID 1 in
a privileged container so the full installer can be exercised without changing
the host.
