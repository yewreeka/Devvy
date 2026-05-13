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
    /// Bath temperature (°F) the user picked at tank start. Step durations in
    /// `steps` have already been compensated for this temperature; the value
    /// is kept around for display only.
    public var temperatureF: Double?

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
        tintHex: String? = nil,
        temperatureF: Double? = nil
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
        self.temperatureF = temperatureF
    }

    private enum CodingKeys: String, CodingKey {
        case id, recipeId, recipeName, tankLabel, steps, stepIndex, stepStartedAt
        case pausedRemaining, liveActivityId, createdAt, tintHex, temperatureF
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.recipeId = try c.decode(UUID.self, forKey: .recipeId)
        self.recipeName = try c.decode(String.self, forKey: .recipeName)
        self.tankLabel = try c.decode(String.self, forKey: .tankLabel)
        self.steps = try c.decode([Step].self, forKey: .steps)
        self.stepIndex = try c.decode(Int.self, forKey: .stepIndex)
        self.stepStartedAt = try c.decode(Date.self, forKey: .stepStartedAt)
        self.pausedRemaining = try c.decodeIfPresent(TimeInterval.self, forKey: .pausedRemaining)
        self.liveActivityId = try c.decodeIfPresent(String.self, forKey: .liveActivityId)
        self.createdAt = try c.decode(Date.self, forKey: .createdAt)
        self.tintHex = try c.decodeIfPresent(String.self, forKey: .tintHex)
        self.temperatureF = try c.decodeIfPresent(Double.self, forKey: .temperatureF)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(recipeId, forKey: .recipeId)
        try c.encode(recipeName, forKey: .recipeName)
        try c.encode(tankLabel, forKey: .tankLabel)
        try c.encode(steps, forKey: .steps)
        try c.encode(stepIndex, forKey: .stepIndex)
        try c.encode(stepStartedAt, forKey: .stepStartedAt)
        try c.encodeIfPresent(pausedRemaining, forKey: .pausedRemaining)
        try c.encodeIfPresent(liveActivityId, forKey: .liveActivityId)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encodeIfPresent(tintHex, forKey: .tintHex)
        try c.encodeIfPresent(temperatureF, forKey: .temperatureF)
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

    /// The next agitation cycle whose start is within `leadSeconds`. Used to
    /// drive an "Agitate in 0:15" heads-up before each cycle. Returns nil
    /// while currently agitating, paused, or finished.
    public func upcomingAgitation(
        within leadSeconds: TimeInterval,
        at moment: Date = .now
    ) -> AgitationCycle? {
        guard !isPaused, !isFinished else { return nil }
        guard currentAgitation(at: moment) == nil else { return nil }
        return agitationCycles.first { cycle in
            let lead = cycle.startsAt.timeIntervalSince(moment)
            return lead > 0 && lead <= leadSeconds
        }
    }
}
