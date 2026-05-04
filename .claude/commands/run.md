---
description: Build and launch Devvy on the session's dedicated simulator.
---

# /run

Build, install, and launch Devvy. Idempotent — re-running rebuilds and relaunches.

## Usage

```
/run
```

Bundle id: `com.jarod.devvy`

## Instructions

### Step 1: Resolve the simulator

1. `.claude/.simulator_id` if it exists.
2. Otherwise derive the simulator name from the current git branch:
   - `git branch --show-current`, sanitize (`/` and special chars → `-`, lowercased)
   - Prefix with `devvy-`
   - `main`/`master` → `devvy-main`

   ```bash
   SIM_UUID=$(xcrun simctl list devices -j | python3 -c "import json,sys; d=json.load(sys.stdin); print(next((dev['udid'] for rt in d['devices'].values() for dev in rt if dev['name']=='$SIMULATOR_NAME'), ''))")
   ```

3. If a simulator with that name doesn't exist, clone from an available iPhone:

   ```bash
   BASE=$(xcrun simctl list devices available -j | python3 -c "import json,sys; d=json.load(sys.stdin); print(next((dev['name'] for rt in d['devices'].values() for dev in rt if 'iPhone' in dev['name'] and dev['isAvailable']), ''))")
   xcrun simctl clone "$BASE" "$SIMULATOR_NAME"
   SIM_UUID=$(xcrun simctl list devices -j | python3 -c "import json,sys; d=json.load(sys.stdin); print(next((dev['udid'] for rt in d['devices'].values() for dev in rt if dev['name']=='$SIMULATOR_NAME'), ''))")
   echo -n "$SIM_UUID" > .claude/.simulator_id
   ```

4. Boot it (no-op if already booted):

   ```bash
   xcrun simctl boot "$SIM_UUID" 2>/dev/null || true
   ```

### Step 2: Build

```bash
xcodebuild build \
  -project Devvy.xcodeproj \
  -scheme Devvy \
  -destination "platform=iOS Simulator,id=$SIM_UUID" \
  -derivedDataPath .derivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO 2>&1 | tail -100
```

300-second timeout. Use `xcodebuild` directly, not `mcp__XcodeBuildMCP__build_sim`.

If the build fails:
- Surface compile errors from the tail.
- For `module not found`: `rm -rf .derivedData` and rebuild once.
- Stop if it still fails.

### Step 3: Install and launch

```bash
APP_PATH=$(find .derivedData/Build/Products -name 'Devvy.app' -type d -not -path '*/PlugIns/*' | head -1)
xcrun simctl install "$SIM_UUID" "$APP_PATH"
xcrun simctl launch "$SIM_UUID" com.jarod.devvy
open -a Simulator
```

### Step 4: Report

```
✅ App running on <SIMULATOR_NAME>
```

Don't capture screenshots, probe the UI, or tail logs unless the user explicitly asks.

## DerivedData isolation

`.derivedData/` is gitignored and local. Safe to `rm -rf .derivedData` any time to force a clean build.
