import ActivityKit
import AppIntents
import Foundation

// MARK: - Pure mutations on a TimerSession
//
// Lives in Shared so the Live Activity intents (running outside the app's main
// process) can mutate the App-Group-stored state without depending on app code.

public enum SessionMutation {
    /// Pauses the current step at its current remaining time.
    public static func pause(_ session: inout TimerSession, at moment: Date = .now) {
        guard !session.isPaused, !session.isFinished else { return }
        let remaining = session.remainingNow(at: moment)
        session.pausedRemaining = max(0, remaining)
    }

    /// Resumes a paused session by re-anchoring stepStartedAt so that the
    /// remaining time still elapses correctly from now.
    public static func resume(_ session: inout TimerSession, at moment: Date = .now) {
        guard let remaining = session.pausedRemaining,
              let step = session.currentStep else { return }
        session.stepStartedAt = moment.addingTimeInterval(remaining - step.duration)
        session.pausedRemaining = nil
    }

    /// Advances to the next step. Idempotent past the end.
    public static func advance(_ session: inout TimerSession, at moment: Date = .now) {
        guard !session.isFinished else { return }
        session.stepIndex += 1
        session.stepStartedAt = moment
        session.pausedRemaining = nil
    }

    /// Restarts the current step from full duration.
    public static func restartStep(_ session: inout TimerSession, at moment: Date = .now) {
        session.stepStartedAt = moment
        session.pausedRemaining = nil
    }
}

// MARK: - App Intents

@available(iOS 17.0, *)
public struct PauseTimerIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Pause Timer"
    public static let description: IntentDescription = IntentDescription("Pauses a Devvy timer.")

    @Parameter(title: "Session ID")
    public var sessionId: String

    public init() {}
    public init(sessionId: String) { self.sessionId = sessionId }

    public func perform() async throws -> some IntentResult {
        await DevvyIntentRunner.pause(sessionId: sessionId)
        return .result()
    }
}

@available(iOS 17.0, *)
public struct ResumeTimerIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Resume Timer"
    public static let description: IntentDescription = IntentDescription("Resumes a paused Devvy timer.")

    @Parameter(title: "Session ID")
    public var sessionId: String

    public init() {}
    public init(sessionId: String) { self.sessionId = sessionId }

    public func perform() async throws -> some IntentResult {
        await DevvyIntentRunner.resume(sessionId: sessionId)
        return .result()
    }
}

@available(iOS 17.0, *)
public struct NextStepIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Next Step"
    public static let description: IntentDescription = IntentDescription("Advances the Devvy timer to the next step.")

    @Parameter(title: "Session ID")
    public var sessionId: String

    public init() {}
    public init(sessionId: String) { self.sessionId = sessionId }

    public func perform() async throws -> some IntentResult {
        await DevvyIntentRunner.advance(sessionId: sessionId)
        return .result()
    }
}

@available(iOS 17.0, *)
public struct StopTimerIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Stop Timer"
    public static let description: IntentDescription = IntentDescription("Stops a Devvy timer and ends its Live Activity.")

    @Parameter(title: "Session ID")
    public var sessionId: String

    public init() {}
    public init(sessionId: String) { self.sessionId = sessionId }

    public func perform() async throws -> some IntentResult {
        await DevvyIntentRunner.stop(sessionId: sessionId)
        return .result()
    }
}

// MARK: - Runner shared by intents (no UI dependencies)

public enum DevvyIntentRunner {
    public static func pause(sessionId: String) async {
        await mutate(sessionId: sessionId) { SessionMutation.pause(&$0) }
    }

    public static func resume(sessionId: String) async {
        await mutate(sessionId: sessionId) { SessionMutation.resume(&$0) }
    }

    public static func advance(sessionId: String) async {
        await mutate(sessionId: sessionId) { SessionMutation.advance(&$0) }
    }

    public static func stop(sessionId: String) async {
        guard let uuid = UUID(uuidString: sessionId) else { return }
        let store = SharedStore.shared
        if let session = store.session(id: uuid) {
            await endLiveActivity(for: session, finalState: contentState(for: session))
        }
        store.deleteSession(id: uuid)
        NotificationScheduler.cancelAll(for: uuid)
    }

    private static func mutate(sessionId: String, _ mutation: (inout TimerSession) -> Void) async {
        guard let uuid = UUID(uuidString: sessionId) else { return }
        let store = SharedStore.shared
        guard var session = store.session(id: uuid) else { return }
        mutation(&session)
        store.upsertSession(session)
        await updateLiveActivity(for: session)
        NotificationScheduler.reschedule(for: session)
    }

    private static func contentState(for session: TimerSession) -> DevvyActivityAttributes.ContentState {
        DevvyActivityAttributes.ContentState(
            stepIndex: session.stepIndex,
            stepCount: session.steps.count,
            stepName: session.currentStep?.name ?? "Done",
            stepDuration: session.currentStep?.duration ?? 0,
            stepEndsAt: session.stepEndsAt,
            pausedRemaining: session.pausedRemaining,
            nextStepName: session.nextStep?.name,
            tankLabel: session.tankLabel
        )
    }

    private static func updateLiveActivity(for session: TimerSession) async {
        // Match by either the recorded activity id OR the session id encoded
        // in the activity's static attributes. The latter catches the case
        // where the session's `liveActivityId` is stale after a reconcile.
        let sessionIdString = session.id.uuidString
        let matches = Activity<DevvyActivityAttributes>.activities.filter {
            $0.id == session.liveActivityId || $0.attributes.sessionId == sessionIdString
        }
        let state = contentState(for: session)
        for activity in matches {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    private static func endLiveActivity(
        for session: TimerSession,
        finalState: DevvyActivityAttributes.ContentState
    ) async {
        // End every activity that belongs to this session — match by id and
        // by attributes.sessionId so a stale recorded id can't strand a card
        // on the lock screen.
        let sessionIdString = session.id.uuidString
        let matches = Activity<DevvyActivityAttributes>.activities.filter {
            $0.id == session.liveActivityId || $0.attributes.sessionId == sessionIdString
        }
        for activity in matches {
            await activity.end(ActivityContent(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
        }
    }
}
