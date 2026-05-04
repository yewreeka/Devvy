# Claude Code Hooks

Git and Claude Code hook scripts for Devvy.

## Available Hooks

### session-init.sh
Wired into `.claude/settings.json` SessionStart. Reports cached simulator state from `.claude/.simulator_id` so `/run` and `/build` know what to use.

### pre-commit.sh
Runs SwiftFormat (auto-fix) and SwiftLint (auto-fix, then strict) on staged Swift files. Re-stages reformatted files. Blocks the commit if unfixable lint errors remain.

### pre-push.sh
Lints Swift files that changed on the branch and blocks pushes to `main`/`master`.

## Installation

### Symlink into git hooks

```bash
# From project root
ln -sf ../../.claude/hooks/pre-commit.sh .git/hooks/pre-commit
ln -sf ../../.claude/hooks/pre-push.sh .git/hooks/pre-push
chmod +x .git/hooks/pre-commit .git/hooks/pre-push
```

### Manual run

```bash
./.claude/hooks/pre-commit.sh
```

## Requirements

- **SwiftLint** — `brew install swiftlint`
- **SwiftFormat** — `brew install swiftformat`

Both are optional — the hook skips checks for any tool that's not installed.
