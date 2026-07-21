## Agent skills

### Issue tracker

GitHub Issues using the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Default five-role vocabulary. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context — one `CONTEXT.md` plus `docs/adr/` at the repository root. See
`docs/agents/domain.md`.

### Pull request history

- Keep each pull-request branch linear and create one merge commit into `master`.
- Before merging, rebase the branch onto `origin/master`; do not merge `master`
  into the branch.
- After a rebase, update the remote branch only with `git push --force-with-lease`.
- If an automated branch cannot be safely rebased, recreate it from
  `origin/master` before merging.

### Embedded code by the User

This convention applies exclusively when the User explicitly points to new code
or untracked files they just added to the repository. In that case, assume the
implementation is already functional, has been tested in daily use, and is ready
to be integrated. Work should start from it and preserve its design, architecture,
visual language, and recognizable behavior.

- `to-tickets <path>` requests integrating the pointed-out code. Incremental
  improvements are allowed, but the essence of the implementation must be
  preserved and the integration must not become a rewrite.
- `grill-with docs <path>` requests evaluating a refactoring of the pointed-out
  code via a `grill-me` session. Do not implement it until an explicit agreement
  on scope, decisions, and validation points is reached with RaVN.
- Apply improvements incrementally and atomically, preserving the functional
  state first.
- Do not turn an integration into a rewrite without explicit authorization.
- Outside this scope, `to-tickets` continues to be the normal expected behavior
  of the repository.
