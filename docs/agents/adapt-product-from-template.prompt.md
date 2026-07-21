# Agent prompt: adapt this repository to a new product

Copy everything below the line into a new agent session. Fill the
`{{PLACEHOLDERS}}` first. Do not skip phases. Do not invent scope beyond the
filled placeholders and the answers you collect in Phase 0.

---

## ROLE

You are a senior repository-adaptation agent working in the RaVN / Oh My Pi
harness on a **template repository** that currently ships one root product and
must be cut over to a **different finished product** already present (or about
to be placed) at the repo root.

You optimize for correctness, linear git history, and a clean first release.
You follow `AGENTS.md`, `RELEASE_POLICY.md`, `COMMIT_MESSAGE_GUIDELINES.md`,
`docs/agents/issue-tracker.md`, and `docs/agents/triage-labels.md` without
being asked.

You do **not** rewrite the new product’s core behavior unless Phase 0
explicitly allows product edits. Preserve design, architecture, visual
language, and recognizable behavior of any user-supplied finished tool
(`AGENTS.md` → “Embedded code by the User”).

---

## FILL THESE BEFORE STARTING

```text
{{OLD_PRODUCT}}          = current product/command name (e.g. shared_dir)
{{NEW_PRODUCT}}          = new product/command name (e.g. my_new_tool)
{{NEW_PRODUCT_PATH}}     = path to the finished executable at repo root
                           (usually ./{{NEW_PRODUCT}})
{{GITHUB_OWNER}}         = GitHub owner (e.g. robert-flo)
{{GITHUB_REPO}}          = desired GitHub repo name after cutover
                           (often equals {{NEW_PRODUCT}})
{{GITHUB_REPO_URL}}      = https://github.com/{{GITHUB_OWNER}}/{{GITHUB_REPO}}
{{CLONE_DIR_NAME}}       = directory name used in clone examples
                           (usually {{GITHUB_REPO}})
{{DEFAULT_BRANCH}}       = master
{{FIRST_VERSION}}        = 0.1.0
{{TAG}}                  = v{{FIRST_VERSION}}
{{DISTRO_POLICY}}        = arch-only | multi-distro-docs-only | full-multi-distro
{{DOCKER_POLICY}}        = none | deps-only | privileged-systemd-autolaunch
{{TEST_POLICY}}          = delete-old-only | smoke-no-root | full-suite
{{DOCS_LANGUAGE}}        = en | es | bilingual
{{PRODUCT_TOUCH}}        = none | rename-only | minimal-integration | allowed-improvements
{{OLD_SCAFFOLD_DIRS}}    = helper scripts templates lib  (space-separated; delete if empty/unused)
{{ISSUE_TITLE_ADAPT}}    = Adapt repository from {{OLD_PRODUCT}} to {{NEW_PRODUCT}}
{{ISSUE_TITLE_RELEASE}}  = Release {{FIRST_VERSION}}
```

Optional product-domain facts (fill from reading `{{NEW_PRODUCT_PATH}}`):

```text
{{PRODUCT_ONE_LINER}}    = one sentence what it does
{{PRODUCT_RUNTIME}}      = e.g. root Arch bash installer / user CLI / daemon
{{PRODUCT_DEPS}}         = packages/commands it needs
{{PRODUCT_DEFAULTS}}     = default paths, groups, ports, etc.
{{PRODUCT_SIDE_EFFECTS}} = files/units it writes (systemd, /usr/local/bin, …)
{{DOCKER_IMAGE}}         = {{NEW_PRODUCT}}:local
{{DOCKER_CONTAINER}}     = {{NEW_PRODUCT}}-sandbox
{{OPT_INSTALL_PATH}}     = /opt/{{NEW_PRODUCT}}
```

---

## HARD RULES

1. **Issue → branch → PR → merge commit → master.** No direct commits to
   `{{DEFAULT_BRANCH}}` even if branch protection is off.
2. **Linear PR branches.** Rebase onto `origin/{{DEFAULT_BRANCH}}` before
   merge. Never merge master into the topic branch. Push rebased branches with
   `--force-with-lease` only.
3. **One merge commit** into `{{DEFAULT_BRANCH}}` per PR (`gh pr merge --merge`).
4. **Issue titles** after creation: `<number> - <title>`
   (`docs/agents/issue-tracker.md`).
5. **Commits** use Conventional Commits + Gitmoji after the colon, e.g.
   `feat: ✨ …`, `chore(changelog): 📝 Update PR #<n>`,
   `merge: 🔀 Merge branch '…'`.
6. **Changelog gate:** every PR needs exactly one of
   `changelog:added|changed|fixed|removed|security|deprecated|skip`.
   Generate the Unreleased entry **locally** with
   `.github/scripts/update-pr-changelog.sh` and commit it before review.
7. **Do not rewrite** `{{NEW_PRODUCT_PATH}}` beyond `{{PRODUCT_TOUCH}}`.
8. **Do not leave** `{{OLD_PRODUCT}}` product references in docs/CI/Docker/tests
   (except intentional historical notes, which this template avoids).
9. **Do not confuse** Make target names like `git-setup` (bare clone helper in
   `make/git.mk`) with the old product name. Only rename product references.
10. **Verify before yield:** run the full offline test gate and shellcheck.
11. **Resolve the real GitHub repo** with `gh repo view` / API. Locals remotes
    may lag renames (`setup_X` → `X`). Update `git remote set-url origin` and
    all clone URLs to `{{GITHUB_REPO_URL}}`.
12. **Never print Make recipe comments.** In recipes, every recipe line that
    would run or would be a comment inside the recipe body must start with
    `TAB` + `@` if it would otherwise echo. Prefer comments **above** the
    target, not inside the recipe.
13. **Ignore interactive TTY exit codes** (130/SIGINT) from `docker exec -it`
    when cleaning up sandboxes; trial end must exit Make with 0.
14. **No trailing whitespace** (CI runs `git diff --check`). No blank line at
    EOF beyond a single final newline in generated changelog files.

---

## PHASE 0 — Scope interview (mandatory)

Before editing, map the repo and the new product, then ask the user concise
multiple-choice questions. Do not assume. Cover at least:

1. Public product/command name and root filename  
2. Depth: rename-only vs rebrand+prune dead scaffold vs surface-only  
3. Distro support vs what the product actually supports  
4. Docker purpose (none / smoke image / privileged systemd autolaunch)  
5. Legacy artifact policy (delete vs stub)  
6. Hooks/CI policy (generic shell gate vs product-specific)  
7. Tests policy (delete old / smoke without privileges / full suite)  
8. Changelog history (reset to `{{FIRST_VERSION}}` vs keep)  
9. Docs language  
10. Whether `{{NEW_PRODUCT_PATH}}` may be edited  

Also discover by tools (do not ask what tools can answer):

- Root listing, `git remote -v`, `gh repo view`
- Read `{{NEW_PRODUCT_PATH}}` fully (shebang, privileges, deps, side effects)
- Grep for `{{OLD_PRODUCT}}`, old image names, old test paths, old `/opt/…`
- Inventory empty scaffold dirs: `{{OLD_SCAFFOLD_DIRS}}`
- Read current `README.md`, `Dockerfile`, `make/docker.mk`, `.git-hooks/pre-commit`,
  `.github/workflows/ci.yml`, `tests/*`, `CONTEXT.md`, `CHANGELOG.md`

Record answers as session decisions. Proceed only after Phase 0 is settled.

---

## PHASE 1 — Prune old product surface

Delete or rewrite anything that only exists for `{{OLD_PRODUCT}}` and cannot
serve `{{NEW_PRODUCT}}`.

Typical deletions when cutting over from a previous tool:

- `tests/{{OLD_PRODUCT}}.sh` or equivalent product tests for the old tool
- Old libraries only used by the old tool (`lib/…` presentation helpers, etc.)
- Empty `helper/`, `scripts/`, `templates/` if the new product is a single root
  executable and does not use them
- Old docs that describe foreign workflows (tokens, multi-command dispatchers,
  ADRs for the previous distribution model)
- Multi-distro Dockerfiles if `{{DISTRO_POLICY}}` is `arch-only`

Keep:

- Repo process docs that are product-agnostic (`RELEASE_POLICY.md`,
  `COMMIT_MESSAGE_GUIDELINES.md`, issue templates structure, changelog scripts)
- `make/git.mk` and its targets (including any target whose **name** collides
  with an old product string but means something else)

Update `.gitignore` for local noise (e.g. `.directory`, `.agents/`).

---

## PHASE 2 — Product documentation cutover

Rewrite in `{{DOCS_LANGUAGE}}` (default English for this template):

### `README.md`

Must include:

- Title `{{NEW_PRODUCT}}` and `{{PRODUCT_ONE_LINER}}`
- Dependencies for the supported distro(s)
- Clone + run from source using `{{GITHUB_REPO_URL}}` and `./{{NEW_PRODUCT}}`
- Behavior table / commands actually supported
- Security notes grounded in real side effects
- Docker section matching `{{DOCKER_POLICY}}`
- Contributing pointer + MIT license blurb

Visual style: keep the existing RaVN README patterns if present
(typing-svg headers, `---` separators) unless the user asks otherwise.

### `CONTEXT.md`

Replace glossary terms for the **new** domain. No leftover old-product
distribution vocabulary unless still true.

### `CONTRIBUTING.md`

- Fork/clone URLs → `{{GITHUB_REPO_URL}}`
- Local check commands must match real paths:

```bash
pre-commit run --all-files
bash tests/{{NEW_PRODUCT}}.sh
bash tests/docker-make.sh
bash tests/git-make.sh
bash tests/changelog-automation.sh
shellcheck -S warning {{NEW_PRODUCT}} tests/*.sh .vscode/shellcheck.sh
```

### `CHANGELOG.md`

If resetting history for a new product:

```markdown
# Changelog

All notable changes to this project are documented in this file.

## Unreleased

## [{{FIRST_VERSION}}] - {{YYYY-MM-DD}}

### Added

- Initial {{NEW_PRODUCT}} …
- … Docker / tests bullets matching reality …
```

### ADR

Replace obsolete ADRs under `docs/adr/` with one that states the real
architecture of `{{NEW_PRODUCT}}` (single executable vs dispatcher, distro,
privileges, Docker model).

### Other docs

- `GITHUB_FOLDER_EXPLAINED.md`: CI must mention `tests/{{NEW_PRODUCT}}.sh`
- Remove docs that only served the old product
- Fix every clone URL and repo slug to `{{GITHUB_OWNER}}/{{GITHUB_REPO}}`

---

## PHASE 3 — Docker + Make (`{{DOCKER_POLICY}}`)

### If `none`

Remove Docker targets/docs/tests or leave stubs that error clearly.

### If `privileged-systemd-autolaunch` (recommended when product needs root+systemd)

**`Dockerfile`**

- Base image matches `{{DISTRO_POLICY}}` (Arch: `archlinux:latest`)
- Install only deps required to run the product and systemd
- `WORKDIR {{OPT_INSTALL_PATH}}`
- `COPY {{NEW_PRODUCT}} {{OPT_INSTALL_PATH}}/{{NEW_PRODUCT}}`
- Symlink into `/usr/local/bin/{{NEW_PRODUCT}}`
- Mask noisy/useless units (`getty`, `udev`, `logind`, `firstboot`, …)
- `STOPSIGNAL SIGRTMIN+3`
- `CMD` = systemd as PID 1 (`/usr/lib/systemd/systemd --system`)
- Do **not** set the installer as PID 1

**`make/docker.mk`**

Variables:

- `DOCKER_IMAGE ?= {{DOCKER_IMAGE}}`
- `DOCKER_CONTAINER ?= {{DOCKER_CONTAINER}}`
- `DOCKER_RUN_FLAGS := --privileged --cgroupns=host --volume /sys/fs/cgroup:/sys/fs/cgroup:rw`
- `DOCKER_READY_TIMEOUT ?= 30`

`docker-run` algorithm (mandatory):

1. Ensure image exists (`docker-build` if missing)
2. Remove leftover container with the same name
3. Print a **visual ephemeral-trial banner** (see copy deck below)
4. `docker run -d --name …` with `DOCKER_RUN_FLAGS`
5. Poll `docker exec … systemctl is-system-running` until `running` or
   `degraded` (accept `degraded` only if still usable; prefer masking units
   that cause degrade)
6. Print handoff lines clarifying host is untouched
7. `docker exec -it … /usr/local/bin/{{NEW_PRODUCT}} || true`
8. Print inspection-shell banner
9. `docker exec -it … /bin/bash || true`
10. Always `docker rm -f` container
11. Print success cleanup line
12. `exit 0` (never fail Make on TTY/SIGINT 130)

Banner copy deck (adapt names, keep meaning):

```text
󰡨  {{NEW_PRODUCT}} · ephemeral Docker trial
────────────────────────────────────────────────────────────────────────────────
  Isolated throwaway container — your host stays untouched.
  Nothing created inside survives when this session ends.

  ▸ Booting systemd sandbox...
  ✓ Sandbox is live
  ▸ Interactive terminal open inside the container: running {{NEW_PRODUCT}} for testing.

  All installer changes stay in this throwaway environment.
  They never reach your local machine.

… product runs …

󰡨  {{NEW_PRODUCT}} finished inside the sandbox
────────────────────────────────────────────────────────────────────────────────
  Root shell for inspection (systemctl, getfacl, ls).
  Type exit — the container is destroyed and the host is unchanged.

  ✓ Ephemeral sandbox removed. Host unchanged.
```

**Pitfalls already learned (do not regress):**

- `docker run -it` with systemd PID 1 and getty masked looks “frozen” — always
  detached systemd + `docker exec` for the product/shell
- Make echoes recipe lines that are comments without `@` — never put bare
  `# comment` lines inside a recipe
- `[[ false ]]` is true in bash — use `[[ 1 -eq 0 ]]` if rewriting guards in
  fixtures
- `EUID` is readonly — tests must rewrite a **copy** of the installer, not
  export EUID
- Path rewrites in fixtures must not naively `sed s|/tmp/|…|` or they corrupt
  paths already rewritten to the fixture

Update `tests/docker-make.sh` with a stub `docker` on `PATH` that records argv
and fakes: build, detached run, inspect, `systemctl is-system-running` →
`running`, exec product, exec bash, rm. Assert exact flags and banner
substrings.

---

## PHASE 4 — Hooks, VS Code, CI

### `.git-hooks/pre-commit`

- Generic shell quality gate: staged shell files → `shfmt` then
  `shellcheck -S warning`
- Remove legacy path exclusions from other products/dotfiles trees
- Escape hatch: `SKIP_HOOKS=1`
- AI report text should name `{{NEW_PRODUCT}}`, not the old tool

### `.vscode/shellcheck.sh` / `settings.json`

- Drop foreign ignore globs
- Keep format-on-save / shellcheck enablement

### `.github/workflows/ci.yml`

Validate job must:

1. whitespace `git diff --check`
2. `bash -n` on changed shell scripts
3. `shellcheck -S warning {{NEW_PRODUCT}} tests/*.sh .vscode/shellcheck.sh .git-hooks/pre-commit`
4. `bash tests/{{NEW_PRODUCT}}.sh`
5. `bash tests/docker-make.sh`
6. `bash tests/git-make.sh`
7. `bash tests/changelog-automation.sh`

Ensure changelog labels exist on the GitHub repo (`changelog:added`, etc.).
Create them if missing.

---

## PHASE 5 — Tests

### `tests/{{NEW_PRODUCT}}.sh` (`{{TEST_POLICY}}=smoke-no-root`)

Offline smoke contract:

- `bash -n` + executable bit
- Refusal paths that do not need privileges (bad args, non-root if applicable)
- Happy path via **fixture copy** + stubs for privileged commands
- Assert side effects that define the product contract (units written, files
  created under redirected prefixes, key log lines)
- Never invoke real package managers or host systemd

### Keep/adjust

- `tests/git-make.sh` — default-branch protection (product-agnostic)
- `tests/changelog-automation.sh` — rename temp prefixes to `{{NEW_PRODUCT}}-…`
- `tests/docker-make.sh` — as in Phase 3

### `tests/TESTS_README.md`

Document for humans:

- table of suites
- how to run each / all
- expected `PASS: …` lines
- when to run manually
- where CI runs them
- what is intentionally not covered (live privileged Docker, etc.)

**No trailing double spaces** for Markdown hard breaks if CI whitespace check
is strict — use normal paragraphs or code blocks.

---

## PHASE 6 — Full local verification gate

From repo root, all must pass before the adaptation PR:

```bash
bash tests/{{NEW_PRODUCT}}.sh
bash tests/docker-make.sh
bash tests/git-make.sh
bash tests/changelog-automation.sh
shellcheck -S warning {{NEW_PRODUCT}} tests/*.sh .vscode/shellcheck.sh .git-hooks/pre-commit
```

If Docker policy is systemd autolaunch and Docker is available, also smoke:

1. `make docker-build`
2. Detached run + wait for systemd + non-interactive product invocation
3. Confirm critical side effect
4. Remove container

Do not claim Docker works without observing it.

---

## PHASE 7 — GitHub flow (adaptation PR)

### 7.1 Ensure origin is the real repo

```bash
gh repo view --json nameWithOwner,url
git remote -v
# if renamed on GitHub:
git remote set-url origin git@github.com:{{GITHUB_OWNER}}/{{GITHUB_REPO}}.git
```

Fix docs if the slug changed.

### 7.2 Create changelog labels if absent

`changelog:added`, `changed`, `fixed`, `removed`, `security`, `deprecated`, `skip`.

### 7.3 Issue

```bash
gh issue create --title "{{ISSUE_TITLE_ADAPT}}" --body "…"
gh issue edit <n> --title "<n> - {{ISSUE_TITLE_ADAPT}}"
```

### 7.4 Branch

```bash
git fetch origin
git switch {{DEFAULT_BRANCH}}
git pull --ff-only origin {{DEFAULT_BRANCH}}
git switch -c feat/<n>-adapt-{{NEW_PRODUCT}}-repo
```

### 7.5 Commit product cutover

Stage all intended files (not local junk). Commit:

```text
feat: ✨ Adapt repository for {{NEW_PRODUCT}} product

Replace the inherited {{OLD_PRODUCT}} packaging surface with {{NEW_PRODUCT}}:
docs, Docker/Make/CI/hooks, tests, and first-release changelog for {{FIRST_VERSION}}.

Closes #<n>
```

### 7.6 Push + PR

```bash
git push -u origin HEAD
gh pr create --base {{DEFAULT_BRANCH}} \
  --title "<n> - {{ISSUE_TITLE_ADAPT}}" \
  --label changelog:added \
  --body "Fixes #<n> … validation checklist …"
```

### 7.7 Changelog entry for the PR

```bash
PR_NUMBER=<pr> PR_URL=<url> PR_TITLE=<title> PR_LABELS=changelog:added \
  bash .github/scripts/update-pr-changelog.sh
# run twice; second must be idempotent
git add CHANGELOG.md
git commit -m "chore(changelog): 📝 Update PR #<pr>"
git push
```

### 7.8 CI

```bash
gh pr checks <pr> --watch
```

Fix failures (whitespace, shellcheck paths, tests) with small follow-up commits.
Rebase onto latest `origin/{{DEFAULT_BRANCH}}` if needed; push
`--force-with-lease`.

### 7.9 Merge

```bash
gh pr merge <pr> --merge --delete-branch \
  --subject "merge: 🔀 Merge branch 'feat/<n>-adapt-{{NEW_PRODUCT}}-repo'" \
  --body "Merge pull request #<pr>. Closes #<issue>."
git fetch origin
git switch {{DEFAULT_BRANCH}}
git pull --ff-only origin {{DEFAULT_BRANCH}}
```

---

## PHASE 8 — First release tag

### 8.1 Release prep issue + branch

```bash
gh issue create --title "{{ISSUE_TITLE_RELEASE}}" --body "Promote Unreleased → [{{FIRST_VERSION}}], tag {{TAG}}"
gh issue edit <n> --title "<n> - {{ISSUE_TITLE_RELEASE}}"
git switch -c release/{{FIRST_VERSION}}
```

### 8.2 Promote changelog

Move Unreleased PR entries under:

```markdown
## [{{FIRST_VERSION}}] - {{YYYY-MM-DD}}
```

Leave:

```markdown
## Unreleased

```

(empty body). Keep a single trailing newline. Commit:

```text
chore(release): 📝 Promote changelog for {{FIRST_VERSION}}
```

### 8.3 PR with `changelog:skip`

Because this PR only rearranges changelog for tagging:

```bash
git push -u origin HEAD
gh pr create --base {{DEFAULT_BRANCH}} \
  --title "<n> - {{ISSUE_TITLE_RELEASE}}" \
  --label changelog:skip \
  --body "Fixes #<n>"
# run update-pr-changelog.sh with PR_LABELS=changelog:skip (no Unreleased bullet)
gh pr checks <pr> --watch
gh pr merge <pr> --merge --delete-branch \
  --subject "merge: 🔀 Merge branch 'release/{{FIRST_VERSION}}'"
git switch {{DEFAULT_BRANCH}} && git pull --ff-only origin {{DEFAULT_BRANCH}}
```

### 8.4 Annotated tag + GitHub Release

```bash
git tag -a {{TAG}} -m "{{NEW_PRODUCT}} {{FIRST_VERSION}}

First release. …"
git push origin {{TAG}}

gh release create {{TAG}} --title "{{TAG}}" --notes "## {{NEW_PRODUCT}} {{FIRST_VERSION}}
…"
```

Confirm:

```bash
gh release view {{TAG}}
git status   # clean, on {{DEFAULT_BRANCH}}
```

---

## PHASE 9 — Final report to the user

Return a compact summary with links:

- Issues closed
- PRs merged (merge commit SHAs)
- Tag + release URL
- What was pruned / rewritten
- Validation commands run and results
- Known follow-ups (branch protection, CLI flags, AUR, etc.) **only as a
  short list**, not as unfinished work from this prompt

---

## ACCEPTANCE CHECKLIST (all required)

- [ ] Phase 0 answers recorded; no silent scope assumptions
- [ ] `{{NEW_PRODUCT_PATH}}` is the only product entrypoint documented
- [ ] No stale `{{OLD_PRODUCT}}` product references in README/CI/Docker/tests/docs
      (except `make/git.mk` unrelated target names if applicable)
- [ ] Clone URLs use `{{GITHUB_REPO_URL}}` and match `gh repo view`
- [ ] Docker behavior matches `{{DOCKER_POLICY}}` and does not freeze on systemd
- [ ] `make docker-run` auto-launches the product when policy says so
- [ ] Ephemeral/host-untouched messaging is visible and accurate
- [ ] Offline tests all PASS; shellcheck -S warning clean for gated paths
- [ ] Adaptation issue + PR + merge commit done
- [ ] Changelog Unreleased entry committed before adaptation PR merge
- [ ] Release prep promoted changelog; tag `{{TAG}}` pushed; GitHub Release exists
- [ ] Working tree clean on `{{DEFAULT_BRANCH}}`

---

## REFERENCE: session-proven failure modes

Fix these proactively; they already burned real time on the template cutover:

| Symptom | Cause | Fix |
| --- | --- | --- |
| `make docker-run` hangs | systemd is PID 1, no getty | detached run + `docker exec` |
| Make prints `# shell or docker…` | comment lines inside recipe without `@` | comments above target only |
| `Error 130` after `exit` in container shell | docker exec TTY SIGINT | `\|\| true` + always `exit 0` after cleanup |
| CI `trailing whitespace` | Markdown hard-break spaces | strip trailing WS |
| CI changelog validation fails | entry not committed / wrong section | local `update-pr-changelog.sh` + commit |
| Tests can’t fake root | `EUID` readonly | rewrite guard only in fixture copy |
| Fixture paths become `/tmp/…/tmp/…` | blind sed on `/tmp/` | precise literal replacements |
| `gh issue` lands on wrong repo | GitHub rename vs old remote URL | `gh repo view` + fix origin/docs |
| shellcheck fails on intentional `echo '$var'` generators | SC2016 info | `shellcheck -S warning` in CI/hook |
| `[[ false ]]` doesn’t skip block | bash treats non-empty string as true | use `[[ 1 -eq 0 ]]` |

---

## REFERENCE: minimum file touch map

| Path | Action |
| --- | --- |
| `{{NEW_PRODUCT}}` | keep / rename-only per `{{PRODUCT_TOUCH}}` |
| `README.md` | full rewrite |
| `CONTEXT.md` | full rewrite |
| `CONTRIBUTING.md` | URLs + check commands |
| `CHANGELOG.md` | reset or promote to `{{FIRST_VERSION}}` |
| `Dockerfile` | rewrite for new product + policy |
| `make/docker.mk` | rewrite run flow + image names |
| `tests/{{NEW_PRODUCT}}.sh` | create |
| `tests/docker-make.sh` | rewrite assertions |
| `tests/git-make.sh` | temp name prefixes |
| `tests/changelog-automation.sh` | temp name prefixes |
| `tests/TESTS_README.md` | create/update |
| `.github/workflows/ci.yml` | paths + test commands |
| `.git-hooks/pre-commit` | generic gate; no old exclusions |
| `.vscode/*` | drop foreign ignores |
| `docs/adr/*` | replace with new product ADR |
| `GITHUB_FOLDER_EXPLAINED.md` | CI suite names |
| old product-only trees | delete |

---

## START COMMAND (once placeholders are filled)

1. Read `AGENTS.md`, `RELEASE_POLICY.md`, this prompt’s Phase 0 requirements  
2. Map repo + read `{{NEW_PRODUCT_PATH}}`  
3. Run the Phase 0 interview  
4. Execute Phases 1–9 in order without yielding a partial cutover as “done”  
5. Stop only when the Acceptance Checklist is fully satisfied  

End of prompt.
