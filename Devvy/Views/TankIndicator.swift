import SwiftUI

/// Glass capsule pill mirroring the Convos `ConversationIndicator` design:
/// avatar-style circle on the left, a stacked title/subtitle on the right,
/// wrapped in a `GlassEffectContainer` so future state morphs can use
/// matched-geometry transitions like Convos does.
///
/// Two flavors:
/// - `init(session:)` — the running-tank version: solid tint avatar, tank
///   label + recipe-name/temperature subtitle, title in `tintedInk`.
/// - `init(recipe:)` — the recipe page version: faded-tint avatar with a
///   drop icon, recipe name + temperature subtitle, primary-color title.
struct TankIndicator: View {
    let title: String
    let subtitle: String
    let avatarColor: Color
    let avatarSymbol: String?
    /// When non-nil the title text uses this color's `tintedInk`; otherwise
    /// `.primary` so the indicator works on un-tinted screens too.
    let tintedTitleColor: Color?

    @Namespace private var namespace: Namespace.ID

    init(
        title: String,
        subtitle: String,
        avatarColor: Color,
        avatarSymbol: String? = nil,
        tintedTitleColor: Color? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.avatarColor = avatarColor
        self.avatarSymbol = avatarSymbol
        self.tintedTitleColor = tintedTitleColor
    }

    private var titleStyle: Color {
        tintedTitleColor?.tintedInk ?? .primary
    }

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 0) {
                avatar
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .lineLimit(1)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(titleStyle)
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
        .accessibilityLabel("\(title), \(subtitle)")
        .animation(.bouncy(duration: 0.4, extraBounce: 0.01), value: title)
        .animation(.bouncy(duration: 0.4, extraBounce: 0.01), value: subtitle)
    }

    @ViewBuilder
    private var avatar: some View {
        if let symbol = avatarSymbol {
            // Recipe-style avatar: faded tint with a contrasting glyph.
            ZStack {
                Circle().fill(avatarColor.opacity(0.18))
                Image(systemName: symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(avatarColor)
                Circle().strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
            }
        } else {
            // Tank-style avatar: solid tint disc.
            Circle()
                .fill(avatarColor.gradient)
                .overlay {
                    Circle().strokeBorder(.white.opacity(0.25), lineWidth: 0.5)
                }
        }
    }
}

extension TankIndicator {
    init(session: TimerSession) {
        let subtitle: String
        if let tempF = session.temperatureF {
            let temp = tempF.formatted(.number.precision(.fractionLength(0...1)))
            subtitle = "\(session.recipeName) · \(temp)°F"
        } else {
            subtitle = session.recipeName
        }
        self.init(
            title: session.tankLabel,
            subtitle: subtitle,
            avatarColor: session.tint,
            avatarSymbol: nil,
            tintedTitleColor: session.tint
        )
    }

    init(recipe: Recipe) {
        let temp = recipe.baseTemperatureF.formatted(.number.precision(.fractionLength(0...1)))
        self.init(
            title: recipe.name,
            subtitle: "\(temp)°F",
            avatarColor: .accentColor,
            avatarSymbol: "drop.halffull",
            tintedTitleColor: nil
        )
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
    VStack(spacing: 20) {
        TankIndicator(session: session)
        TankIndicator(recipe: Recipe(
            name: "XTOL 1:1 250",
            steps: [],
            baseTemperatureF: 68
        ))
    }
    .padding()
}
