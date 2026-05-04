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

        /// Cycle currently in progress at `moment`, if any.
        public func currentAgitation(at moment: Date) -> AgitationCycle? {
            guard !isPaused, !isFinished else { return nil }
            return agitationCycles.first { moment >= $0.startsAt && moment < $0.endsAt }
        }
    }

    public var sessionId: String
    public var recipeName: String

    public init(sessionId: String, recipeName: String) {
        self.sessionId = sessionId
        self.recipeName = recipeName
    }
}
