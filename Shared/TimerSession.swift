import Foundation

/// One concurrent development "tank" running a Recipe.
public struct TimerSession: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var recipeId: UUID
    public var recipeName: String
    public var tankLabel: String
    /// Snapshot of recipe steps captured at session start so the session is
    /// stable even if the recipe is later edited.
    public var steps: [Step]
    public var stepIndex: Int
    /// Wall-clock time at which the current step (re)started.
    public var stepStartedAt: Date
    /// If non-nil, the timer is paused with this many seconds remaining on the current step.
    public var pausedRemaining: TimeInterval?
    public var liveActivityId: String?
    public var createdAt: Date
    public var tintHex: String?

    public init(
        id: UUID = UUID(),
        recipeId: UUID,
        recipeName: String,
        tankLabel: String,
        steps: [Step],
        stepIndex: Int = 0,
        stepStartedAt: Date = .now,
        pausedRemaining: TimeInterval? = nil,
        liveActivityId: String? = nil,
        createdAt: Date = .now,
        tintHex: String? = nil
    ) {
        self.id = id
        self.recipeId = recipeId
        self.recipeName = recipeName
        self.tankLabel = tankLabel
        self.steps = steps
        self.stepIndex = stepIndex
        self.stepStartedAt = stepStartedAt
        self.pausedRemaining = pausedRemaining
        self.liveActivityId = liveActivityId
        self.createdAt = createdAt
        self.tintHex = tintHex
    }

    public var currentStep: Step? {
        guard stepIndex >= 0, stepIndex < steps.count else { return nil }
        return steps[stepIndex]
    }

    public var isPaused: Bool { pausedRemaining != nil }
    public var isFinished: Bool { stepIndex >= steps.count }

    /// Date at which the current step will fire its end. For paused sessions
    /// this is `.distantFuture` since the wall-clock end is undefined.
    public var stepEndsAt: Date {
        guard let step = currentStep else { return .distantPast }
        if let remaining = pausedRemaining {
            return Date.now.addingTimeInterval(remaining)
        }
        return stepStartedAt.addingTimeInterval(step.duration)
    }

    /// Remaining seconds on the current step right now.
    public func remainingNow(at moment: Date = .now) -> TimeInterval {
        guard let step = currentStep else { return 0 }
        if let remaining = pausedRemaining { return remaining }
        let elapsed = moment.timeIntervalSince(stepStartedAt)
        return max(0, step.duration - elapsed)
    }

    /// Has the current step's wall-clock window ended (only meaningful while running).
    public func stepHasElapsed(at moment: Date = .now) -> Bool {
        guard !isPaused, currentStep != nil else { return false }
        return remainingNow(at: moment) <= 0
    }

    public var nextStep: Step? {
        let i = stepIndex + 1
        return i < steps.count ? steps[i] : nil
    }

    /// Wall-clock anchor for "when did the current step start?" — accounts for
    /// pause state. While paused this is a synthetic anchor: the step's start
    /// projected forward as if we resumed right now.
    public var stepLogicalStart: Date {
        guard let step = currentStep else { return stepStartedAt }
        if let remaining = pausedRemaining {
            return Date.now.addingTimeInterval(remaining - step.duration)
        }
        return stepStartedAt
    }

    /// Agitation cycles for the current step in absolute time.
    public var agitationCycles: [AgitationCycle] {
        guard let step = currentStep else { return [] }
        return step.agitationCycles(stepStartedAt: stepLogicalStart)
    }

    /// The agitation cycle currently in progress, if any. Returns nil while
    /// paused (we don't show a live agitation countdown over a frozen timer).
    public func currentAgitation(at moment: Date = .now) -> AgitationCycle? {
        guard !isPaused, !isFinished else { return nil }
        return agitationCycles.first { moment >= $0.startsAt && moment < $0.endsAt }
    }
}
