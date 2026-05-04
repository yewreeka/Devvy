import ActivityKit
import Foundation

enum LiveActivityManager {
    /// Returns the started activity's id, or nil if Live Activities are unavailable.
    @discardableResult
    static func start(for session: TimerSession) async -> String? {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return nil }
        let attributes = DevvyActivityAttributes(
            sessionId: session.id.uuidString,
            recipeName: session.recipeName
        )
        let state = contentState(for: session)
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
            return activity.id
        } catch {
            return nil
        }
    }

    static func update(_ session: TimerSession) async {
        guard let id = session.liveActivityId,
              let activity = Activity<DevvyActivityAttributes>.activities.first(where: { $0.id == id })
        else { return }
        await activity.update(ActivityContent(state: contentState(for: session), staleDate: nil))
    }

    static func end(_ session: TimerSession) async {
        guard let id = session.liveActivityId,
              let activity = Activity<DevvyActivityAttributes>.activities.first(where: { $0.id == id })
        else { return }
        await activity.end(
            ActivityContent(state: contentState(for: session), staleDate: nil),
            dismissalPolicy: .immediate
        )
    }

    /// After a cold launch some sessions may have lost their Live Activity
    /// (iOS occasionally ends them when the host process is killed, especially
    /// in the simulator). For each persisted session ensure exactly one live
    /// `Activity` exists for it; sweep up orphans and duplicates along the way.
    /// - Returns: any sessions whose `liveActivityId` we updated, so the caller
    ///   can persist them.
    static func reconcile(sessions: [TimerSession]) async -> [TimerSession] {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return [] }

        let liveActivities = Activity<DevvyActivityAttributes>.activities
        let validSessionIds = Set(sessions.filter { !$0.isFinished }.map(\.id.uuidString))

        // 1. End orphans — activities whose sessionId doesn't match any active
        //    session. These leak when an end() got dropped, the session was
        //    deleted while the app was suspended, etc.
        for activity in liveActivities where !validSessionIds.contains(activity.attributes.sessionId) {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        // 2. Index remaining activities by sessionId — there may be more than
        //    one if a previous reconcile started a duplicate.
        var bySessionId: [String: [Activity<DevvyActivityAttributes>]] = [:]
        for activity in liveActivities where validSessionIds.contains(activity.attributes.sessionId) {
            bySessionId[activity.attributes.sessionId, default: []].append(activity)
        }

        var changed: [TimerSession] = []

        for session in sessions where !session.isFinished {
            let key = session.id.uuidString
            let matches = bySessionId[key] ?? []

            // Prefer the activity whose id matches the session's recorded id;
            // otherwise just pick the first.
            if let canonical = matches.first(where: { $0.id == session.liveActivityId }) ?? matches.first {
                // End every duplicate.
                for activity in matches where activity.id != canonical.id {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
                // Push current state.
                await canonical.update(ActivityContent(state: contentState(for: session), staleDate: nil))
                // Re-link the session if its recorded id is stale.
                if canonical.id != session.liveActivityId {
                    var updated = session
                    updated.liveActivityId = canonical.id
                    changed.append(updated)
                }
            } else {
                // No live activity for this session — start a fresh one.
                if let newId = await start(for: session) {
                    var updated = session
                    updated.liveActivityId = newId
                    changed.append(updated)
                }
            }
        }
        return changed
    }

    static func contentState(for session: TimerSession) -> DevvyActivityAttributes.ContentState {
        DevvyActivityAttributes.ContentState(
            stepIndex: session.stepIndex,
            stepCount: session.steps.count,
            stepName: session.currentStep?.name ?? "Done",
            stepDuration: session.currentStep?.duration ?? 0,
            stepEndsAt: session.stepEndsAt,
            pausedRemaining: session.pausedRemaining,
            nextStepName: session.nextStep?.name,
            tankLabel: session.tankLabel,
            agitationCycles: session.agitationCycles
        )
    }
}
