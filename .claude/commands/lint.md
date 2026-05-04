---
description: Run SwiftLint against the project.
---

# /lint

Lint Swift sources with SwiftLint.

## Usage

```
/lint            # whole project
/lint <path>     # specific file or directory
```

## Commands

### Check for issues

```bash
swiftlint
```

### Lint a path

```bash
swiftlint lint --path Devvy/
swiftlint lint --path Shared/
```

### Auto-fix

```bash
swiftlint --fix
```

### Lint only changed files

```bash
git diff --name-only --diff-filter=d | grep '\.swift$' | xargs swiftlint lint --path
```

## Key rules

From `.swiftlint.yml`:

- Prefer `first(where:)` over filter
- Sorted imports
- `private` over `fileprivate`
- No implicitly unwrapped optionals
- Line length: 200 chars max
- Function body: 125 lines max

## Excluded paths

- `.build/`
- `.derivedData/`
- `Devvy.xcodeproj/`

## On issues found

1. Try auto-fix first: `swiftlint --fix`
2. Review remaining issues manually.
3. To silence a specific line: `// swiftlint:disable:next rule_name`
4. To silence project-wide, add to `disabled_rules` in `.swiftlint.yml`.
