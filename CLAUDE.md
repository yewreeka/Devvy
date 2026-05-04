# Devvy — Codebase Conventions

iPhone/iPad darkroom timer for film development. iOS 26 only. Pure SwiftUI with Liquid Glass APIs and a Live Activity.

## Project layout

The Xcode project (`Devvy.xcodeproj`) is generated from `project.yml` via [xcodegen](https://github.com/yonaskolb/XcodeGen). Regenerate after editing `project.yml`:

```bash
xcodegen generate
```

Three source roots:

| Path | Target | Purpose |
|------|--------|---------|
| `Shared/` | both | Models, App-Group store, App Intents, ActivityAttributes, NotificationScheduler |
| `Devvy/` | app | `@main DevvyApp`, `AppState`, `LiveActivityManager`, SwiftUI views |
| `DevvyLiveActivity/` | widget extension | WidgetBundle + Live Activity UI |

A type that's needed in both targets *must* live in `Shared/`. Otherwise prefer the smaller target.

Sample data: `Devvy/Resources/XTOL_1_1_250.rcp` is bundled and seeded into `SharedStore` on first launch via `SeedRecipes`.

## Build, run, lint

| Action | Command / slash |
|--------|-----------------|
| Compile | `/build` |
| Build + launch | `/run` |
| Setup simulator | `/setup` |
| Format | `/format` |
| Lint | `/lint` |
| Manual build | `xcodebuild build -project Devvy.xcodeproj -scheme Devvy -destination "platform=iOS Simulator,id=<UUID>" -derivedDataPath .derivedData CODE_SIGNING_ALLOWED=NO` |

`.derivedData/` is gitignored and per-worktree. Safe to `rm -rf .derivedData` to force a clean rebuild.

`xcodebuild` directly (not `mcp__XcodeBuildMCP__build_sim`) — the MCP tool can mis-sequence the widget extension's build order.

## Cross-process state

Source of truth: App Group `group.com.jarod.devvy`, accessed only through `SharedStore` (UserDefaults-backed Codable).

```
SharedStore
  ├── recipes  ([Recipe])
  └── sessions ([TimerSession])
```

The Live Activity intents (`PauseTimerIntent`, `ResumeTimerIntent`, `NextStepIntent`, `StopTimerIntent`) run in the app's process and mutate state through `DevvyIntentRunner`, which:

1. Loads + mutates the session via `SessionMutation`
2. Persists via `SharedStore`
3. Updates the `Activity` content state via `Activity.update`
4. Reschedules notifications via `NotificationScheduler.reschedule`

When adding new state mutations, route them through `SessionMutation` so the app-side `AppState` and the widget-side intents stay aligned.

## SwiftUI conventions

### State

```swift
@Observable
@MainActor
final class MyViewModel { var foo = "" }

// in views
@State private var vm = MyViewModel()
```

App-wide state is read via `@Environment(AppState.self)`.

### Buttons

Always use the `label:` form to avoid closure-overload compile errors:

```swift
Button {
    Haptics.tap()
    doThing()
} label: {
    Label("Do Thing", systemImage: "hand.tap")
}
```

### Liquid Glass

iOS 26-only project — prefer Liquid Glass over hand-rolled materials:

- `.glassEffect(in: .rect(cornerRadius: 22))` for floating containers
- `.buttonStyle(.glass)` and `.buttonStyle(.glassProminent)` for actions
- `.tabViewStyle(.sidebarAdaptable)` for the root TabView (auto-expands on iPad)
- `.matchedTransitionSource` + `.navigationTransition(.zoom(...))` for hero transitions

### Animation

Project presets in `Devvy/Views/Helpers.swift`:

- `Animation.devvy` — default spring
- `Animation.devvyFast` — snappy
- `Animation.devvyBounce` — playful

`HeartbeatClock` ticks at 4 Hz for progress rings; inject via `.environment(heartbeat)`.

## Models

`Recipe` is a Codable struct (`Shared/Recipe.swift`) with custom `decodeRCP(from:)` / `encodeRCP()` that round-trips the legacy 2-element JSON array format used by the original "Develop" app:

```json
[
  { "name": "...", "description": "..." },
  [ { "order": 0, "name": "...", "duration": 600,
      "notification": 30, "notificationThereafter": 60 }, ... ]
]
```

`TimerSession` snapshots `Recipe.steps` at start time so editing a recipe never mutates a running tank.

## Notifications

Three kinds per running step (`NotificationScheduler.reschedule`):

1. End-of-step (always)
2. Heads-up at `step.leadInNotice` seconds before end (if non-zero)
3. Recurring agitation reminders every `step.recurringNotice` seconds (if non-zero)

Notification IDs are prefixed `devvy.session.<UUID>.` so a session's pending alerts can be cancelled in bulk. Always call `reschedule` after a state mutation — the runner does this automatically; if you bypass it, you must too.

## Capabilities & entitlements

- `com.apple.security.application-groups` → `group.com.jarod.devvy` on **both** targets
- `NSSupportsLiveActivities = true` in the app's Info.plist
- Custom UTI `com.jarod.devvy.recipe` for `.rcp` files
- Notifications use `.active` interruption level — flip to `.timeSensitive` only after adding `com.apple.developer.usernotifications.time-sensitive` to entitlements

## Don'ts

- Don't introduce a second source of truth for sessions — everything routes through `SharedStore`.
- Don't import `UIKit` from `Shared/` (it must build for the widget extension).
- Don't add `print` / `os_log` calls in shipping code paths without a reason.
- Don't reach into `Devvy/` from `DevvyLiveActivity/` — pull the type into `Shared/` instead.
- Don't write `static var` on App Intent metadata fields — Swift 6 strict concurrency requires `static let`.
