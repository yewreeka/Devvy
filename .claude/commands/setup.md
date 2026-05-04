---
description: Initialize a Claude Code session — pick or clone a dedicated simulator and cache its UUID.
---

# /setup

Set up the simulator that `/run` and `/build` will use for this session, and cache its UUID at `.claude/.simulator_id`.

## When to run

- First session in a fresh checkout
- After deleting the cached simulator
- Any time you want to switch this session to a different simulator

## Instructions

### Step 1: Choose a simulator name

Derive from the current git branch:
- `git branch --show-current`
- Sanitize: replace `/` and special characters with `-`, lowercase
- Prefix with `devvy-`
- Example: `jarod/timer-fix` → `devvy-jarod-timer-fix`
- Special case: `main` or `master` → `devvy-main`

### Step 2: Find or clone the simulator

```bash
SIMULATOR_NAME="<resolved name>"
SIM_UUID=$(xcrun simctl list devices -j | python3 -c "import json,sys; d=json.load(sys.stdin); print(next((dev['udid'] for rt in d['devices'].values() for dev in rt if dev['name']=='$SIMULATOR_NAME'), ''))")

if [ -z "$SIM_UUID" ]; then
  # Clone from the latest available iPhone (prefer iPhone 17 Pro / iPhone 17).
  BASE=$(xcrun simctl list devices available -j | python3 -c "import json,sys; d=json.load(sys.stdin); print(next((dev['name'] for rt in d['devices'].values() for dev in rt if 'iPhone' in dev['name'] and dev['isAvailable']), ''))")
  xcrun simctl clone "$BASE" "$SIMULATOR_NAME"
  SIM_UUID=$(xcrun simctl list devices -j | python3 -c "import json,sys; d=json.load(sys.stdin); print(next((dev['udid'] for rt in d['devices'].values() for dev in rt if dev['name']=='$SIMULATOR_NAME'), ''))")
fi

echo -n "$SIM_UUID" > .claude/.simulator_id
```

### Step 3: Regenerate the Xcode project if missing

`Devvy.xcodeproj` is generated from `project.yml` via xcodegen. If the project is missing, run:

```bash
xcodegen generate
```

### Step 4: Report

```
✅ Session setup complete
📱 Simulator: <SIMULATOR_NAME> (<UUID>)
📁 Project: Devvy.xcodeproj
🎯 Scheme: Devvy
```

## Error handling

- If simulator clone fails: surface the error and suggest `xcrun simctl list devices` to inspect available bases.
- If no iPhone simulator exists at all: ask the user to install an iOS Simulator runtime in Xcode.
- If `xcodegen` is missing: `brew install xcodegen`.
