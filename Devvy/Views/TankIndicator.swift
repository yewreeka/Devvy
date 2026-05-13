import SwiftUI

/// Glass capsule pill mirroring the Convos `ConversationIndicator` design:
/// avatar-style circle on the left, a stacked title/subtitle on the right,
/// wrapped in a `GlassEffectContainer` so any future state morph can use
/// matched-geometry transitions like Convos does.
///
/// Static / non-interactive — tapping does nothing. The animation hooks are
/// kept so when the underlying session changes (label, recipe, temperature)
/// the content cross-fades with the same bouncy feel.
struct TankIndicator: View {
    let session: TimerSession

    @Namespace private var namespace: Namespace.ID

    private var subtitle: String {
        if let tempF = session.temperatureF {
            let temp = tempF.formatted(.number.precision(.fractionLength(0...1)))
            return "\(session.recipeName) · \(temp)°F"
        }
        return session.recipeName
    }

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 0) {
                avatar
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 0) {
                    Text(session.tankLabel)
                        .lineLimit(1)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(session.tint.tintedInk)
                        .contentTransition(.opacity)
                    Text(subtitle)
                        .lineLimit(1)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .contentTransition(.opacity)
                }
                .padding(.horizontal, 8)
            }
            .padding(8)
            .fixedSize(horizontal: false, vertical: true)
            .clipShape(.capsule)
            .glassEffect(.regular, in: .capsule)
            .glassEffectID("tankInfo", in: namespace)
            .glassEffectTransition(.matchedGeometry)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(session.tankLabel), \(session.recipeName)")
        .animation(.bouncy(duration: 0.4, extraBounce: 0.01), value: session.tankLabel)
        .animation(.bouncy(duration: 0.4, extraBounce: 0.01), value: subtitle)
    }

    private var avatar: some View {
        Circle()
            .fill(session.tint.gradient)
            .overlay {
                Circle()
                    .strokeBorder(.white.opacity(0.25), lineWidth: 0.5)
            }
    }
}

#Preview {
    let session = TimerSession(
        recipeId: UUID(),
        recipeName: "XTOL 1:1 250",
        tankLabel: "Tank A",
        steps: [Step(order: 0, name: "Develop", duration: 600)],
        tintHex: "5DB9E6",
        temperatureF: 72
    )
    TankIndicator(session: session)
        .padding()
}
