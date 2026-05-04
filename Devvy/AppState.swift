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
    }

    func refresh() {
        let store = SharedStore.shared
        let loadedRecipes = store.loadRecipes().sorted { $0.updatedAt > $1.updatedAt }
        let loadedSessions = store.loadSessions().sorted { $0.createdAt > $1.createdAt }
        // Avoid spurious view updates when nothing changed.
        if loadedRecipes != recipes { recipes = loadedRecipes }
        if loadedSessions != sessions { sessions = loadedSessions }
        applyIdleTimerPolicy()
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

    // MARK: - Recipes

    func saveRecipe(_ recipe: Recipe) {
        SharedStore.shared.upsertRecipe(recipe)
        refresh()
    }

    func deleteRecipe(_ recipe: Recipe) {
        SharedStore.shared.deleteRecipe(id: recipe.id)
        refresh()
    }

    func importRecipe(from data: Data) throws -> Recipe {
        let recipe = try Recipe.decodeRCP(from: data)
        SharedStore.shared.upsertRecipe(recipe)
        refresh()
        return recipe
    }

    // MARK: - Sessions

    @discardableResult
    func startSession(for recipe: Recipe, tankLabel: String? = nil, tintHex: String? = nil) async -> TimerSession? {
        guard !recipe.steps.isEmpty else { return nil }
        let label = tankLabel ?? Self.suggestedTankLabel(existing: sessions)
        var session = TimerSession(
            recipeId: recipe.id,
            recipeName: recipe.name,
            tankLabel: label,
            steps: recipe.steps,
            stepStartedAt: .now,
            tintHex: tintHex ?? Self.randomTint()
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
            // Final step done -> stop session entirely.
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
