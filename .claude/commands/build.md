---
description: Build the Devvy iOS app to verify it compiles.
---

# /build

Compile-only build. Does not install or launch — use `/run` for that.

## Usage

```
/build
```

## Instructions

### Step 1: Resolve the simulator UUID

1. Read `.claude/.simulator_id` if it exists.
2. Otherwise pick any available, non-booted iPhone simulator (prefer iPhone 17 Pro, iPhone 17 Pro Max, iPhone 17). Don't auto-create one — suggest `/setup` if none qualify.

### Step 2: Run xcodebuild

Run via Bash (single line, 5-minute timeout):

```bash
xcodebuild build \
  -project Devvy.xcodeproj \
  -scheme Devvy \
  -destination "platform=iOS Simulator,id=$SIM_UUID" \
  -derivedDataPath .derivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO 2>&1 | tail -100
```

Use `xcodebuild` directly, not `mcp__XcodeBuildMCP__build_sim` — the MCP tool can mis-sequence the widget extension's dependency on `Shared/` sources.

### Step 3: Report

- On success: one-line confirmation.
- On failure: surface the compile errors from the tail; if it's a "module not found" issue, `rm -rf .derivedData` and rebuild once before giving up.

Don't capture screenshots, tail logs, or interact with the simulator unless the user asks.
