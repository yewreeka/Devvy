import Foundation

public struct Recipe: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var notes: String
    public var steps: [Step]
    public var createdAt: Date
    public var updatedAt: Date
    /// Temperature (°F) for which `steps[0].duration` was calibrated. Used to
    /// adjust the developer step when a tank is started at a different
    /// temperature. Defaults to 68°F (20°C), the canonical darkroom baseline.
    public var baseTemperatureF: Double

    public init(
        id: UUID = UUID(),
        name: String,
        notes: String = "",
        steps: [Step] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now,
        baseTemperatureF: Double = 68
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.steps = steps
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.baseTemperatureF = baseTemperatureF
    }

    public var totalDuration: TimeInterval {
        steps.reduce(0) { $0 + $1.duration }
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, notes, steps, createdAt, updatedAt, baseTemperatureF
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.notes = try c.decode(String.self, forKey: .notes)
        self.steps = try c.decode([Step].self, forKey: .steps)
        self.createdAt = try c.decode(Date.self, forKey: .createdAt)
        self.updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        self.baseTemperatureF = try c.decodeIfPresent(Double.self, forKey: .baseTemperatureF) ?? 68
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(notes, forKey: .notes)
        try c.encode(steps, forKey: .steps)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(baseTemperatureF, forKey: .baseTemperatureF)
    }
}

public struct Step: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var order: Int
    public var name: String
    public var notes: String
    public var duration: TimeInterval
    /// Seconds to agitate at the very start of the step (0 = disabled).
    /// During this period, in-app + Live Activity show "Agitate {countdown}"
    /// instead of the step name.
    public var initialAgitation: Int
    /// Interval between recurring agitation cycle starts, anchored to step
    /// start. So with `agitationInterval = 60`, cycles start at t=60, 120,
    /// 180, … (skipping any that overlap the initial agitation). 0 = disabled.
    public var agitationInterval: Int
    /// Duration of each recurring agitation cycle in seconds. 0 = no recurring
    /// agitation. UI shows the "Agitate {countdown}" overlay for this many
    /// seconds at each cycle start.
    public var agitationDuration: Int

    public init(
        id: UUID = UUID(),
        order: Int,
        name: String,
        notes: String = "",
        duration: TimeInterval,
        initialAgitation: Int = 0,
        agitationInterval: Int = 0,
        agitationDuration: Int = 0
    ) {
        self.id = id
        self.order = order
        self.name = name
        self.notes = notes
        self.duration = duration
        self.initialAgitation = initialAgitation
        self.agitationInterval = agitationInterval
        self.agitationDuration = agitationDuration
    }

    // Custom decoder migrates legacy persisted data:
    //   leadInNotice / startNotice → initialAgitation
    //   recurringNotice            → agitationInterval
    //   (agitationDuration is new; defaults to 0)
    private enum CodingKeys: String, CodingKey {
        case id, order, name, notes, duration
        case initialAgitation, agitationInterval, agitationDuration
        case startNotice    // legacy v2
        case leadInNotice   // legacy v1
        case recurringNotice  // legacy
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.order = try c.decode(Int.self, forKey: .order)
        self.name = try c.decode(String.self, forKey: .name)
        self.notes = try c.decode(String.self, forKey: .notes)
        self.duration = try c.decode(TimeInterval.self, forKey: .duration)

        if let v = try c.decodeIfPresent(Int.self, forKey: .initialAgitation) {
            self.initialAgitation = v
        } else if let v = try c.decodeIfPresent(Int.self, forKey: .startNotice) {
            self.initialAgitation = v
        } else if let v = try c.decodeIfPresent(Int.self, forKey: .leadInNotice) {
            self.initialAgitation = v
        } else {
            self.initialAgitation = 0
        }

        if let v = try c.decodeIfPresent(Int.self, forKey: .agitationInterval) {
            self.agitationInterval = v
        } else if let v = try c.decodeIfPresent(Int.self, forKey: .recurringNotice) {
            self.agitationInterval = v
        } else {
            self.agitationInterval = 0
        }

        self.agitationDuration = try c.decodeIfPresent(Int.self, forKey: .agitationDuration) ?? 0
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(order, forKey: .order)
        try c.encode(name, forKey: .name)
        try c.encode(notes, forKey: .notes)
        try c.encode(duration, forKey: .duration)
        try c.encode(initialAgitation, forKey: .initialAgitation)
        try c.encode(agitationInterval, forKey: .agitationInterval)
        try c.encode(agitationDuration, forKey: .agitationDuration)
    }
}

/// One agitation period in absolute time. Returned by `TimerSession.agitationCycles`.
public struct AgitationCycle: Codable, Hashable, Sendable {
    public var startsAt: Date
    public var endsAt: Date
    /// True for the t=0 initial-agitation period; false for recurring cycles.
    public var isInitial: Bool

    public init(startsAt: Date, endsAt: Date, isInitial: Bool) {
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.isInitial = isInitial
    }
}

extension Step {
    /// Returns the agitation cycles for this step, given a wall-clock anchor
    /// for when the step started (or "would have started" if paused).
    /// - Initial agitation produces one cycle from anchor to anchor+initial.
    /// - Recurring cycles are at anchor+interval, anchor+2*interval, ...,
    ///   each lasting agitationDuration seconds. Any cycle whose start lies
    ///   inside the initial-agitation window is skipped (no overlapping
    ///   schedules); the first recurring cycle in that case is the next
    ///   interval boundary after the initial ends.
    public func agitationCycles(stepStartedAt: Date) -> [AgitationCycle] {
        var cycles: [AgitationCycle] = []

        if initialAgitation > 0 {
            cycles.append(AgitationCycle(
                startsAt: stepStartedAt,
                endsAt: stepStartedAt.addingTimeInterval(TimeInterval(initialAgitation)),
                isInitial: true
            ))
        }

        if agitationInterval > 0, agitationDuration > 0 {
            let interval = TimeInterval(agitationInterval)
            let dur = TimeInterval(agitationDuration)
            let initial = TimeInterval(initialAgitation)
            var t = interval
            while t + dur <= duration + 0.5 {
                if t >= initial {
                    cycles.append(AgitationCycle(
                        startsAt: stepStartedAt.addingTimeInterval(t),
                        endsAt: stepStartedAt.addingTimeInterval(t + dur),
                        isInitial: false
                    ))
                }
                t += interval
            }
        }

        return cycles
    }
}

// MARK: - .rcp file format
//
// The legacy "Develop" .rcp file is a JSON array of two elements:
//   [ { "name": "...", "description": "..." },
//     [ { "order": 0, "name": "...", "description": "...",
//         "duration": 600, "notification": 30, "notificationThereafter": 60 }, ... ] ]

public enum RecipeFormatError: Error, LocalizedError {
    case malformed
    public var errorDescription: String? {
        switch self {
        case .malformed: "This .rcp file isn't in a recognized format."
        }
    }
}

extension Recipe {
    public static func decodeRCP(from data: Data) throws -> Recipe {
        let raw = try JSONSerialization.jsonObject(with: data, options: [])
        guard let outer = raw as? [Any], outer.count == 2,
              let meta = outer[0] as? [String: Any],
              let rawSteps = outer[1] as? [[String: Any]] else {
            throw RecipeFormatError.malformed
        }
        let name = (meta["name"] as? String) ?? "Untitled"
        let notes = (meta["description"] as? String) ?? ""
        let baseF: Double = {
            if let v = meta["baseTemperatureF"] as? Double { return v }
            if let v = meta["baseTemperatureF"] as? Int { return Double(v) }
            return 68
        }()

        let steps: [Step] = rawSteps.map { dict in
            Step(
                order: (dict["order"] as? Int) ?? 0,
                name: (dict["name"] as? String) ?? "Step",
                notes: (dict["description"] as? String) ?? "",
                duration: TimeInterval((dict["duration"] as? Double) ?? Double((dict["duration"] as? Int) ?? 0)),
                initialAgitation: (dict["notification"] as? Int) ?? 0,
                agitationInterval: (dict["notificationThereafter"] as? Int) ?? 0,
                agitationDuration: (dict["agitationDuration"] as? Int) ?? 0
            )
        }.sorted { $0.order < $1.order }

        return Recipe(name: name, notes: notes, steps: steps, baseTemperatureF: baseF)
    }

    public func encodeRCP() throws -> Data {
        let meta: [String: Any] = [
            "name": name,
            "description": notes,
            "baseTemperatureF": baseTemperatureF,
        ]
        let stepDicts: [[String: Any]] = steps.enumerated().map { idx, step in
            var dict: [String: Any] = [
                "order": idx,
                "name": step.name,
                "description": step.notes,
                "duration": step.duration,
                "notification": step.initialAgitation,
                "notificationThereafter": step.agitationInterval,
            ]
            if step.agitationDuration > 0 {
                dict["agitationDuration"] = step.agitationDuration
            }
            return dict
        }
        let outer: [Any] = [meta, stepDicts]
        return try JSONSerialization.data(withJSONObject: outer, options: [.prettyPrinted])
    }
}

// MARK: - Temperature compensation

/// Time/temperature compensation matching Ilford's *Film Development
/// Time/Temperature Compensation Chart* (April 2002), which is a Q10 = 2.5
/// rate model:
///   t_new = t_old * 2.5 ^ (-ΔT_C / 10)
/// where ΔT_C is the temperature *increase* in Celsius. Warmer bath →
/// shorter time; cooler bath → longer. Verified against the chart's worked
/// example (8:00 @ 20°C → 5:30 @ 24°C ≈ 5:33 calculated) and several other
/// rows; matches within the chart's 15-second rounding.
public enum TempCompensation {
    /// Q10 coefficient — rate ratio for a 10°C temperature change.
    public static let q10: Double = 2.5

    /// Below this many seconds, Ilford warns about uneven development.
    public static let minimumRecommendedDeveloperSeconds: TimeInterval = 5 * 60

    public static func celsius(fromFahrenheit f: Double) -> Double {
        (f - 32) * 5.0 / 9.0
    }

    public static func fahrenheit(fromCelsius c: Double) -> Double {
        c * 9.0 / 5.0 + 32
    }

    /// Scale factor to apply to a baseline duration when developing at
    /// `actualF` instead of `baseF` (both in °F).
    public static func factor(baseF: Double, actualF: Double) -> Double {
        let deltaC = celsius(fromFahrenheit: actualF) - celsius(fromFahrenheit: baseF)
        return pow(q10, -deltaC / 10.0)
    }

    /// Adjusted duration (seconds) for `baseSeconds` when developing at
    /// `actualF` instead of `baseF`.
    public static func adjustedDuration(_ baseSeconds: TimeInterval, baseF: Double, actualF: Double) -> TimeInterval {
        baseSeconds * factor(baseF: baseF, actualF: actualF)
    }
}

// MARK: - Time formatting helpers

public enum TimeFormat {
    /// "M:SS" or "H:MM:SS" depending on duration. Matches the format produced
    /// by `Text(timerInterval:countsDown:)` so static and live readouts agree.
    public static func clock(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded()))
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }

    public static func compact(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded())
        if s >= 60 {
            let m = s / 60
            let r = s % 60
            return r == 0 ? "\(m)m" : "\(m)m \(r)s"
        }
        return "\(s)s"
    }
}
