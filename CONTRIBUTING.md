# Contributing to shared_dir

Thank you for helping improve `shared_dir`. Bug fixes, features, documentation,
and test improvements are all welcome.

## Getting started

1. Fork [the repository](https://github.com/robert-flo/shared_dir)
   and clone your fork:

   ```bash
   git clone https://github.com/<your-user>/shared_dir.git
   cd shared_dir
   ```

2. Create a focused branch from `master`:

   ```bash
   git switch -c type/short-description
   ```

3. Run the checks before opening a pull request:

   ```bash
   pre-commit run --all-files
   bash tests/shared_dir.sh
   bash tests/docker-make.sh
   bash tests/git-make.sh
   bash tests/changelog-automation.sh
   shellcheck -S warning shared_dir tests/*.sh .vscode/shellcheck.sh
   ```

4. Commit atomically using the
   [commit message guidelines](COMMIT_MESSAGE_GUIDELINES.md), then push your
   branch and open a pull request targeting `master`.

## Guidelines

- Keep changes focused. The installer at `./shared_dir` is the product; preserve
  its behavior unless a change explicitly updates that contract.
- Add or update smoke coverage under `tests/` for behavior changes.
- Do not commit tokens, private keys, personal credentials, or host-specific
  paths from a live machine.
- Describe the validation you ran in the pull request.
- Follow the [branching and pull-request policy](RELEASE_POLICY.md): direct
  commits and pushes to `master` are not allowed.

## References

- [Pull request template](.github/PULL_REQUEST_TEMPLATE.md)
- [Commit message guidelines](COMMIT_MESSAGE_GUIDELINES.md)
- [Release policy](RELEASE_POLICY.md)
- [Project README](README.md)
