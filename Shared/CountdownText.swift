import SwiftUI

/// Counting-down `Text` that's safe when `endsAt` has slipped into the past.
///
/// `Text(timerInterval:)` requires a valid `ClosedRange<Date>` — if the upper
/// bound is earlier than `now`, the range initializer traps. That happens
/// naturally when a step's wall-clock end has elapsed while the app was
/// suspended and we haven't auto-advanced yet. We render `"0:00"` for that
/// brief window instead of crashing.
public struct CountdownText: View {
    public let now: Date
    public let endsAt: Date

    public init(now: Date, endsAt: Date) {
        self.now = now
        self.endsAt = endsAt
    }

    public var body: some View {
        if endsAt > now {
            Text(timerInterval: now ... endsAt, countsDown: true)
        } else {
            Text("0:00")
        }
    }
}
