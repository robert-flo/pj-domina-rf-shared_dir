# Changelog

All notable changes to this project are documented in this file.

## Unreleased

## [0.2.0] - 2026-07-28

### Added

- Add multi-directory installer and watcher verifier ([#13](https://github.com/robert-flo/PJ-DOMINA-rf-shared_dir/pull/13)). <!-- changelog-pr:13 -->

- Add reusable product-adaptation agent prompt ([#6](https://github.com/robert-flo/PJ-DOMINA-rf-shared_dir/pull/6)). <!-- changelog-pr:6 -->


## [0.1.0] - 2026-07-21

### Added

- Adapt repository from git-setup to shared_dir ([#2](https://github.com/robert-flo/PJ-DOMINA-rf-shared_dir/pull/2)). <!-- changelog-pr:2 -->
- Initial `shared_dir` Arch Linux installer for group-shared directories with
  ACL, SGID, and systemd permission monitoring.
- Privileged Arch Docker sandbox with systemd as PID 1 for safe end-to-end
  trials.
- Host smoke tests for the installer contract without requiring real root.
