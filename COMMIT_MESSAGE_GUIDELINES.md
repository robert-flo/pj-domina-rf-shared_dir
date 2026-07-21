# Commit Message Guidelines

A good commit message should be descriptive and provide context about the changes made. This makes it easier to understand and review the changes in the future.

To keep our commit history clear and visually scannable, we use a hybrid style of **Conventional Commits** paired with **Gitmoji**.

---

## General Guidelines

- **Start with a short summary** of the changes made in the commit.
- **Use the imperative mood** for the summary, as if you're giving a command. For example, `"Add feature"` instead of `"Added feature"`.
- **Provide additional details** in the commit message body, if necessary. This could include the reason for the change, the impact of the change, or any dependencies that were introduced or removed.
- **Keep the message within 72 characters** per line to ensure that it's easy to read in `git log` output.

---

## Format Structure

We recommend placing the emoji **after the colon** of the conventional commit type:

```markdown
<type>(<optional-scope>): <emoji> <description>
```

*Example:* `feat(auth): ✨ Add authentication feature for user login`

This approach remains compatible with tools that parse Conventional Commit types at the start of the subject line.

---

## Changelog Commits

When committing a generated `CHANGELOG.md` entry for a pull request, the
subject must include the documentation emoji:

```markdown
chore(changelog): 📝 Update PR #<number>
```

For example: `chore(changelog): 📝 Update PR #21`.

---

## Commit Message Types

Here is the comprehensive list of commit types matched with their respective Gitmojis:

### `feat` — ✨ (Sparkles)

Adding a new feature to the project.

```markdown
feat: ✨ Add multi-image upload support
```

### `fix` — 🐛 (Bug)

Fixing a bug or issue.

```markdown
fix: 🐛 Fix bug causing application to crash on startup
```

### `docs` — 📝 (Memo)

Updating or adding documentation.

```markdown
docs: 📝 Update documentation for API endpoints
```

### `style` — 🎨 (Art)

Making cosmetic, styling, or formatting changes that do not affect code behavior (colors, layouts, spacing).

```markdown
style: 🎨 Update colors and formatting
```

### `refactor` — ♻️ (Recycle)

Making code changes that don't affect behavior, but improve code quality, readability, or design.

```markdown
refactor: ♻️ Remove unused code
```

### `test` — 🧪 (Test Tube)

Adding or modifying tests.

```markdown
test: 🧪 Add tests for new authentication module
```

### `chore` — 🧹 (Broom) or 🔧 (Wrench)

General maintenance changes that do not fit into other categories (updating dependencies, config files).

```markdown
chore: 🧹 Update dependencies
```

### `perf` — ⚡ (Zap)

Improving execution performance or resource usage.

```markdown
perf: ⚡ Improve performance of image processing
```

### `security` — 🔒 (Lock)

Addressing or fixing security vulnerabilities.

```markdown
security: 🔒 Update dependencies to address security issues
```

### `merge` — 🔀 (Shuffle)

Merging branches.

```markdown
merge: 🔀 Merge branch 'feature/login' into develop
```

### `revert` — ⏪ (Rewind)

Reverting a previous commit.

```markdown
revert: ⏪ Revert "Add feature"
```

### `build` — 📦 (Package)

Making changes to the build system, packing scripts, or external dependencies.

```markdown
build: 📦 Update dependencies
```

### `ci` — 👷 (Construction Worker)

Making changes to CI configurations or workflow scripts (GitHub Actions, GitLab CI).

```markdown
ci: 👷 Update CI workflow configuration
```

### `config` — ⚙️ (Gear)

Making changes to configuration files (linter settings, git configs).

```markdown
config: ⚙️ Update markdownlint rules configuration
```

### `deploy` — 🚀 (Rocket)

Making changes to the deployment scripts, staging, or production environments.

```markdown
deploy: 🚀 Update deployment scripts
```

### `init` — 🎉 (Party Popper)

Creating or initializing a new repository, module, or project.

```markdown
init: 🎉 Initialize project boilerplate
```

### `move` — 🚚 (Delivery Truck)

Moving files or directories within the project.

```markdown
move: 🚚 Move source files to new folder
```

### `rename` — 🏷️ (Label)

Renaming files, folders, or directories.

```markdown
rename: 🏷️ Rename files
```

### `remove` — 🔥 (Fire)

Removing files, dead code, or directories.

```markdown
remove: 🔥 Remove legacy config files
```

### `update` — 🔄 (Circular Arrows)

Updating code, components, or minor dependencies.

```markdown
update: 🔄 Update code structure
```

---

## Guidelines for Custom Types

If you are planning to use a custom commit message type other than the ones listed above, make sure to add it to this list so that others can understand it as well. Create a pull request to add it to this file.
