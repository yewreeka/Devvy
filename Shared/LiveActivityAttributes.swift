import ActivityKit
import Foundation

public struct DevvyActivityAttributes: ActivityAttributes {
    public typealias ContentState = State

    public struct State: Codable, Hashable, Sendable {
        public var stepIndex: Int
        public var stepCount: Int
        public var stepName: String
        public var stepDuration: TimeInterval
        /// Wall-clock end of the current step. Used by Live Activity countdown text.
        public var stepEndsAt: Date
        /// When non-nil the timer is paused; this is the static remaining seconds to display.
        public var pausedRemaining: TimeInterval?
        public var nextStepName: String?
        public var tankLabel: String
        /// Agitation cycles for the current step. The widget uses these to
        /// overlay "Agitate {countdown}" at the right moments without push
        /// updates — it drives a TimelineView off these dates.
        public var agitationCycles: [AgitationCycle]

        public init(
            stepIndex: Int,
            stepCount: Int,
            stepName: String,
            stepDuration: TimeInterval,
            stepEndsAt: Date,
            pausedRemaining: TimeInterval?,
            nextStepName: String?,
            tankLabel: String,
            agitationCycles: [AgitationCycle] = []
        ) {
            self.stepIndex = stepIndex
            self.stepCount = stepCount
            self.stepName = stepName
            self.stepDuration = stepDuration
            self.stepEndsAt = stepEndsAt
            self.pausedRemaining = pausedRemaining
            self.nextStepName = nextStepName
            self.tankLabel = tankLabel
            self.agitationCycles = agitationCycles
        }

        public var isPaused: Bool { pausedRemaining != nil }
        public var isFinished: Bool { stepIndex >= stepCount }

        /// True when the current step's wall-clock window has ended but the
        /// session hasn't advanced yet. While elapsed, the pause control is
        /// hidden everywhere — there's nothing meaningful left to pause.
        public func stepHasElapsed(at moment: Date) -> Bool {
            guard !isPaused, !isFinished else { return false }
            return moment >= stepEndsAt
        }

        /// Cycle currently in progress at `moment`, if any.
        public func currentAgitation(at moment: Date) -> AgitationCycle? {
            guard !isPaused, !isFinished else { return nil }
            return agitationCycles.first { moment >= $0.startsAt && moment < $0.endsAt }
        }

        /// Next cycle whose start is within `leadSeconds` of `moment`. Drives
        /// the "Agitate in 0:15" heads-up shown in the lock-screen card.
        public func upcomingAgitation(
            within leadSeconds: TimeInterval,
            at moment: Date
        ) -> AgitationCycle? {
            guard !isPaused, !isFinished else { return nil }
            guard currentAgitation(at: moment) == nil else { return nil }
            return agitationCycles.first { cycle in
                let lead = cycle.startsAt.timeIntervalSince(moment)
                return lead > 0 && lead <= leadSeconds
            }
        }
    }

    public var sessionId: String
    public var recipeName: String

    public init(sessionId: String, recipeName: String) {
        self.sessionId = sessionId
        self.recipeName = recipeName
    }
}
