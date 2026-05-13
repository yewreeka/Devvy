import SwiftUI

/// Standard-style step row used inside `Form` / `List` sections by the
/// recipe detail and start-tank views. Shows the step number, name, an
/// optional single-line agitation summary subtitle, and the duration on
/// the trailing edge. No glass chrome — the surrounding section provides
/// the grouped-list background.
struct StepCard: View {
    let index: Int
    let step: Step
    /// Time to display on the trailing edge. Lets callers show temperature-
    /// adjusted durations without mutating the underlying `step`.
    let displayDuration: TimeInterval
    /// When true, the duration is rendered in the current tint with
    /// `.semibold` weight (used by the start sheet to flag a temperature-
    /// shifted developer step).
    let highlightDuration: Bool

    init(
        index: Int,
        step: Step,
        displayDuration: TimeInterval? = nil,
        highlightDuration: Bool = false
    ) {
        self.index = index
        self.step = step
        self.displayDuration = displayDuration ?? step.duration
        self.highlightDuration = highlightDuration
    }

    /// Single-line summary describing this step's agitation pattern, or nil
    /// if there's no agitation at all.
    private var agitationSummary: String? {
        var parts: [String] = []
        if step.initialAgitation > 0 {
            parts.append("\(TimeFormat.compact(TimeInterval(step.initialAgitation))) at start")
        }
        if step.agitationInterval > 0, step.agitationDuration > 0 {
            let dur = TimeFormat.compact(TimeInterval(step.agitationDuration))
            let interval = TimeFormat.compact(TimeInterval(step.agitationInterval))
            parts.append("\(dur) every \(interval)")
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: ", then ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(index + 1).")
                .foregroundStyle(.secondary)
                .monospacedDigit()
            VStack(alignment: .leading, spacing: 2) {
                Text(step.name)
                if let summary = agitationSummary {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption2)
                        Text(summary)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Text(TimeFormat.clock(displayDuration))
                .font(.subheadline.monospacedDigit().weight(highlightDuration ? .semibold : .regular))
                .foregroundStyle(highlightDuration ? AnyShapeStyle(TintShapeStyle()) : AnyShapeStyle(HierarchicalShapeStyle.secondary))
                .contentTransition(.numericText())
        }
    }
}
