import ActivityKit
import Observation
import SwiftUI

@Observable
@MainActor
final class AppState {
    private(set) var recipes: [Recipe] = []
    private(set) var sessions: [TimerSession] = []

    init() {
        refresh()
        // Seed the agitation baseline so we don't fire a "start" chime for a
        // tank that was already mid-agitation at app launch.
        let now = Date()
        lastAgitatingSessionIds = Set(
            sessions.filter { $0.currentAgitation(at: now) != nil }.map(\.id)
        )
    }

    private var liveActivityRefreshTask: Task<Void, Never>?
    /// Tracks the last-known step index per session so we can detect a step
    /// transition between two `refresh()` calls and chime accordingly. nil
    /// (untracked) on first observation — we don't chime for the initial sync.
    private var lastStepIndex: [UUID: Int] = [:]
    /// Sessions that were inside an agitation period the last time we observed
    /// boundaries. Lets us chime once on each start / end transition.
    private var lastAgitatingSessionIds: Set<UUID> = []
    /// "<sessionId>:<stepIndex>" keys for which we've already fired the
    /// "10 seconds left" chime. Reset when the step advances or session ends.
    private var stepEndingSoonFired: Set<String> = []

    func refresh() {
        let store = SharedStore.shared
        let loadedRecipes = store.loadRecipes().sorted { $0.updatedAt > $1.updatedAt }
        let loadedSessions = store.loadSessions().sorted { $0.createdAt < $1.createdAt }
        // Avoid spurious view updates when nothing changed.
        if loadedRecipes != recipes { recipes = loadedRecipes }
        if loadedSessions != sessions { sessions = loadedSessions }
        chimeForStepTransitions()
        chimeForStepEndingSoon()
        applyIdleTimerPolicy()
        scheduleNextLiveActivityRefresh()
    }

    /// Fires `Chime.stepEntered()` for every session that just advanced to a
    /// new step, and `Chime.stepFinished()` for every session whose final
    /// step just completed (stepIndex moved past the end). Skips first-sight
    /// sessions (no chime when an existing tank's state is loaded fresh).
    private func chimeForStepTransitions() {
        var didAdvance = false
        var didFinish = false
        for session in sessions {
            if let prev = lastStepIndex[session.id], prev != session.stepIndex {
                if session.stepIndex < session.steps.count {
                    didAdvance = true
                } else {
                    didFinish = true
                }
            }
            lastStepIndex[session.id] = session.stepIndex
        }
        // Drop entries for sessions that no longer exist.
        let live = Set(sessions.map(\.id))
        lastStepIndex = lastStepIndex.filter { live.contains($0.key) }
        if didAdvance { Chime.stepEntered() }
        if didFinish { Chime.stepFinished() }
    }

    /// Fires `Chime.stepEndingSoon()` once per (session, step) when the
    /// current step is within 10 seconds of ending. Backgrounded coverage is
    /// handled by the matching local notification scheduled in
    /// `NotificationScheduler`.
    private func chimeForStepEndingSoon() {
        let now = Date()
        for session in sessions {
            guard !session.isPaused, !session.isFinished, session.currentStep != nil else { continue }
            let key = "\(session.id.uuidString):\(session.stepIndex)"
            let secondsLeft = session.stepEndsAt.timeIntervalSince(now)
            if secondsLeft > 0, secondsLeft <= 10, !stepEndingSoonFired.contains(key) {
                Chime.stepEndingSoon()
                stepEndingSoonFired.insert(key)
            }
        }
        let liveKeys = Set(sessions.map { "\($0.id.uuidString):\($0.stepIndex)" })
        stepEndingSoonFired = stepEndingSoonFired.intersection(liveKeys)
    }

    /// True if any session is actively counting down (not paused, not finished).
    /// While true we keep the screen awake so the user can glance at the timer
    /// without unlocking the phone every few seconds.
    var hasRunningSession: Bool {
        sessions.contains { !$0.isPaused && !$0.isFinished }
    }

    private func applyIdleTimerPolicy() {
        let shouldStayAwake = hasRunningSession
        if UIApplication.shared.isIdleTimerDisabled != shouldStayAwake {
            UIApplication.shared.isIdleTimerDisabled = shouldStayAwake
        }
    }

    /// Live Activities don't reliably re-render their views from a TimelineView
    /// schedule — only `Text(timerInterval:)` self-updates between pushes. So
    /// at every agitation cycle boundary we push an `Activity.update(...)` to
    /// flip the "Agitate" label / countdown overlay on or off.
    ///
    /// This is best-effort: while the app is foregrounded the Task fires on
    /// time; once backgrounded iOS may suspend it, in which case the lock
    /// screen card can lag until the next foreground or `Activity.update`. The
    /// chime notifications still fire on schedule regardless.
    private func scheduleNextLiveActivityRefresh() {
        liveActivityRefreshTask?.cancel()
        let now = Date()
        let boundaries = sessions.flatMap { session -> [Date] in
            guard !session.isPaused, !session.isFinished else { return [] }
            var dates = session.agitationCycles
                .flatMap { [$0.startsAt.addingTimeInterval(-15), $0.startsAt, $0.endsAt] }
            // Also wake at the "10s remaining" heads-up boundary and at step
            // end so the corresponding chimes fire while foregrounded.
            dates.append(session.stepEndsAt.addingTimeInterval(-10))
            dates.append(session.stepEndsAt)
            return dates.filter { $0 > now }
        }.sorted()
        guard let next = boundaries.first else { return }

        let delay = max(0.05, next.timeIntervalSince(Date()))
        liveActivityRefreshTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self else { return }
            await self.pushLiveActivityRefresh()
        }
    }

    private func pushLiveActivityRefresh() async {
        let now = Date()
        let agitating = Set(
            sessions.filter { $0.currentAgitation(at: now) != nil }.map(\.id)
        )
        let starting = agitating.subtracting(lastAgitatingSessionIds)
        let ending = lastAgitatingSessionIds.subtracting(agitating)
        if !starting.isEmpty { Chime.agitationStart() }
        if !ending.isEmpty { Chime.agitationEnd() }
        lastAgitatingSessionIds = agitating

        chimeForStepEndingSoon()

        for session in sessions {
            await LiveActivityManager.update(session)
        }
        scheduleNextLiveActivityRefresh()
    }

    // MARK: - Recipes

    func saveRecipe(_ recipe: Recipe) {
        SharedStore.shared.upsertRecipe(recipe)
        refresh()
    }

    func deleteRecipe(_ recipe: Recipe) {
        SharedStore.shared.deleteRecipe(id: recipe.id)
        refresh()
    }

    @discardableResult
    func duplicateRecipe(_ recipe: Recipe) -> Recipe {
        let now = Date()
        var copy = recipe
        copy.id = UUID()
        copy.name = recipe.name + " Copy"
        copy.steps = recipe.steps.map { step in
            var s = step
            s.id = UUID()
            return s
        }
        copy.createdAt = now
        copy.updatedAt = now
        SharedStore.shared.upsertRecipe(copy)
        refresh()
        return copy
    }

    func importRecipe(from data: Data) throws -> Recipe {
        let recipe = try Recipe.decodeRCP(from: data)
        SharedStore.shared.upsertRecipe(recipe)
        refresh()
        return recipe
    }

    // MARK: - Sessions

    @discardableResult
    func startSession(
        for recipe: Recipe,
        tankLabel: String? = nil,
        tintHex: String? = nil,
        temperatureF: Double? = nil
    ) async -> TimerSession? {
        guard !recipe.steps.isEmpty else { return nil }
        let label = tankLabel ?? Self.suggestedTankLabel(existing: sessions)

        // Bake temperature compensation into the developer step (index 0).
        // The rest of the recipe (stop, fix, wash, …) stays untouched.
        var steps = recipe.steps
        if let tempF = temperatureF, !steps.isEmpty {
            steps[0].duration = TempCompensation.adjustedDuration(
                steps[0].duration,
                baseF: recipe.baseTemperatureF,
                actualF: tempF
            )
        }

        var session = TimerSession(
            recipeId: recipe.id,
            recipeName: recipe.name,
            tankLabel: label,
            steps: steps,
            stepStartedAt: .now,
            tintHex: tintHex ?? Self.randomTint(),
            temperatureF: temperatureF
        )
        let activityId = await LiveActivityManager.start(for: session)
        session.liveActivityId = activityId
        SharedStore.shared.upsertSession(session)
        NotificationScheduler.reschedule(for: session)
        refresh()
        return session
    }

    func pause(_ session: TimerSession) async {
        await DevvyIntentRunner.pause(sessionId: session.id.uuidString)
        refresh()
    }

    func resume(_ session: TimerSession) async {
        await DevvyIntentRunner.resume(sessionId: session.id.uuidString)
        refresh()
    }

    func advance(_ session: TimerSession) async {
        if session.stepIndex + 1 >= session.steps.count {
            // Final step done -> chime then stop the session entirely. We
            // chime before `stop` because stop deletes the session and the
            // refresh-side transition detector would have nothing to compare
            // against.
            Chime.stepFinished()
            await stop(session)
        } else {
            await DevvyIntentRunner.advance(sessionId: session.id.uuidString)
            refresh()
        }
    }

    func stop(_ session: TimerSession) async {
        await DevvyIntentRunner.stop(sessionId: session.id.uuidString)
        refresh()
    }

    func restartCurrentStep(_ session: TimerSession) async {
        guard var s = SharedStore.shared.session(id: session.id) else { return }
        SessionMutation.restartStep(&s)
        SharedStore.shared.upsertSession(s)
        await LiveActivityManager.update(s)
        NotificationScheduler.reschedule(for: s)
        refresh()
    }

    /// Called when the app comes to foreground (or cold launches): any session
    /// whose step has elapsed while we were inactive should be auto-advanced
    /// (or finished).
    func tickAndAdvanceFinishedSteps() async {
        let now = Date()
        let toAdvance = sessions.filter { !$0.isPaused && $0.stepHasElapsed(at: now) }
        for s in toAdvance {
            await advance(s)
        }
    }

    /// On launch / foreground, make sure every persisted session has a live
    /// `Activity` attached. Live Activities don't always survive an app cold
    /// kill — iOS may have ended them. Restart them silently here so users
    /// don't have to.
    func reconcileLiveActivities() async {
        let updated = await LiveActivityManager.reconcile(sessions: sessions)
        for session in updated {
            SharedStore.shared.upsertSession(session)
        }
        if !updated.isEmpty { refresh() }
    }

    // MARK: - Helpers

    static func suggestedTankLabel(existing: [TimerSession]) -> String {
        let used = Set(existing.map(\.tankLabel))
        for letter in "ABCDEFGHIJKL" {
            let label = "Tank \(letter)"
            if !used.contains(label) { return label }
        }
        return "Tank \(existing.count + 1)"
    }

    static let palette: [String] = [
        "F46453", // coral
        "EFC04E", // amber
        "5DB9E6", // sky
        "9B7EE8", // lavender
        "62C088", // sage
        "E97AAE"  // rose
    ]

    static func randomTint() -> String {
        palette.randomElement() ?? "F46453"
    }
}
