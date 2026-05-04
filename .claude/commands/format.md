---
description: Format Swift code with SwiftFormat.
---

# /format

Run SwiftFormat against changed files (default) or a specific path.

## Usage

```
/format            # changed Swift files vs. HEAD
/format <path>     # specific file or directory
```

## Commands

### Format the whole project

```bash
swiftformat .
```

### Format a path

```bash
swiftformat Devvy/
swiftformat Shared/
swiftformat DevvyLiveActivity/
```

### Format only changed Swift files

```bash
git diff --name-only --diff-filter=d | grep '\.swift$' | xargs swiftformat
```

### Preview without writing

```bash
swiftformat . --dryrun
```

## Configuration (`.swiftformat`)

- `--stripunusedargs closure-only`
- `--trimwhitespace always`
- `--commas always`
- `--allman false` — K&R style braces

### Disabled rules

- `redundantSelf`
- `spaceInsideComments`
- `specifiers`
- `redundantReturn`
- `numberFormatting`

## Excluded

- `**Generated**`
- `**Config**`
- `**Scripts**`

## Workflow

1. Make code changes.
2. `/format` to auto-format.
3. `/lint` for remaining issues.
4. Commit.
