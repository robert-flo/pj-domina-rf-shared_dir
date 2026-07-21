# The `.github` Directory

[`RELEASE_POLICY.md`](RELEASE_POLICY.md) defines the repository's canonical
branching and pull-request policy. This guide explains how `.github` supports
that policy.

## Applied Policy

This repository uses `master` as its only permanent integration branch. It does
not use `dev` or `rc` branches.

The expected flow is:

```text
issue → temporary branch and worktree → pull request → master
```

Direct commits to `master` are prohibited. GitHub branch protection enforces
that rule. GitHub Actions validates changes but cannot prevent a direct push by
itself.

## Relevant Structure

```text
.github/
├── ISSUE_TEMPLATE/
│   ├── bug_report.yml
│   ├── custom.yml
│   ├── documentation_update.yml
│   └── feature_request.yml
├── PULL_REQUEST_TEMPLATE.md
├── scripts/
│   ├── update-pr-changelog.sh
│   └── validate-pr-changelog.sh
└── workflows/
    ├── ci.yml
    ├── lock.yml
    └── update-pr-changelog.yml
```

## Issue Templates

`ISSUE_TEMPLATE` provides forms for bugs, feature requests, documentation, and
general requests. GitHub displays them automatically when someone opens an
issue.

## Pull Request Template

`PULL_REQUEST_TEMPLATE.md` provides the initial pull-request body. Pull
requests must target `master`, reference their issue, and describe the
validations performed.

The template helps review quality; it does not enforce branch protection.

## Validation Workflow

`workflows/ci.yml` runs for pull requests to `master`, pushes to `master`, and
manual `workflow_dispatch` runs. It has two jobs:

- **Run Pre-Commit Hooks** checks formatting, file hygiene, and Markdown.
- **Validate repository changes** checks whitespace in the changed range,
  validates changed shell scripts with `bash -n`, runs ShellCheck, and runs
  `tests/shared_dir.sh` plus the Make and changelog automation suites.

### Why CI Runs Before and After a Merge

The pull-request run validates the proposed change before it reaches `master`.
This is the run branch protection should require.

Merging a pull request creates a push to `master`, so CI runs again against the
resulting commit. That post-merge run verifies the result but cannot undo a
change that already landed.

## Maintenance Workflow

`workflows/lock.yml` runs daily and marks inactive issues and pull requests. It
does not participate in the branch model or create commits.

## Pull Request Changelog

`workflows/update-pr-changelog.yml` validates that every pull request has an
entry under `Unreleased` in `CHANGELOG.md`. Generate that entry locally with
`.github/scripts/update-pr-changelog.sh` before requesting review; the workflow
only validates it and never modifies the branch.

## Required GitHub Protection

The `master` branch should require:

- a pull request before merging;
- the rule to apply to administrators;
- no force pushes; and
- the CI checks before merge.

With these rules, the intended flow remains: issue, temporary branch or
worktree, atomic commits, pull request to `master`, CI, merge, and cleanup.
