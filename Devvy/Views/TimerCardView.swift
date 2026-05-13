import SwiftUI

struct TimerCardView: View {
    let session: TimerSession
    var namespace: Namespace.ID

    @Environment(AppState.self) private var app
    @Environment(HeartbeatClock.self) private var clock

    var body: some View {
        let now = clock.now
        let remaining = session.remainingNow(at: now)
        let stepName = session.currentStep?.name ?? "Done"
        let progress = stepProgress(now: now)
        let agitating = session.currentAgitation(at: now)
        let headsUp = session.upcomingAgitation(within: 15, at: now)

        VStack(spacing: 12) {
        HStack(spacing: 16) {
            // Progress ring with step number.
            ZStack {
                Circle()
                    .stroke(.tint.opacity(0.15), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(session.tint.gradient, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.3), value: progress)
                if agitating != nil {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(.title3).weight(.bold))
                        .foregroundStyle(session.tint)
                        .symbolEffect(.rotate, options: .repeating)
                } else {
                    Text("\(session.stepIndex + 1)")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(session.tint)
                        .contentTransition(.numericText())
                }
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(session.tankLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    if session.isPaused {
                        Image(systemName: "pause.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                if agitating != nil {
                    Text("Agitate")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(session.tint)
                        .lineLimit(1)
                        .contentTransition(.opacity)
                    Text(stepName)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(stepName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(session.tint.tintedInk)
                        .lineLimit(1)
                        .contentTransition(.opacity)
                    if let cycle = headsUp {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.caption2.weight(.semibold))
                                .symbolEffect(.rotate, options: .repeating)
                            Text("Agitate in ")
                                .font(.footnote)
                            CountdownText(now: now, endsAt: cycle.startsAt)
                                .font(.footnote.monospacedDigit())
                        }
                        .foregroundStyle(session.tint)
                        .lineLimit(1)
                    } else {
                        Text(session.recipeName)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 0)

            // Big remaining-time readout.
            VStack(alignment: .trailing, spacing: 2) {
                if session.isFinished {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title)
                        .foregroundStyle(.green.gradient)
                } else if session.isPaused {
                    Text(TimeFormat.clock(remaining))
                        .font(.system(.title2, design: .rounded).weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                } else if let cycle = agitating {
                    CountdownText(now: now, endsAt: cycle.endsAt)
                        .font(.system(.title2, design: .rounded).weight(.semibold).monospacedDigit())
                        .foregroundStyle(session.tint)
                        .multilineTextAlignment(.trailing)
                } else {
                    CountdownText(now: now, endsAt: session.stepEndsAt)
                        .font(.system(.title2, design: .rounded).weight(.semibold).monospacedDigit())
                        .foregroundStyle(session.tint.tintedInk)
                        .multilineTextAlignment(.trailing)
                }

                if let next = session.nextStep, !session.isFinished, agitating == nil {
                    Text("Next: \(next.name)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 78, alignment: .trailing)
        }

        if !session.isFinished {
            let stepElapsed = session.stepHasElapsed(at: now)
            HStack(spacing: 10) {
                if !stepElapsed {
                    Button {
                        Haptics.tap()
                        Task {
                            if session.isPaused {
                                await app.resume(session)
                            } else {
                                await app.pause(session)
                            }
                        }
                    } label: {
                        Label(
                            session.isPaused ? "Resume" : "Pause",
                            systemImage: session.isPaused ? "play.fill" : "pause.fill"
                        )
                        .frame(maxWidth: .infinity)
                        .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .buttonBorderShape(.capsule)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                }

                Button {
                    Haptics.tap()
                    Task { await app.advance(session) }
                } label: {
                    Label(
                        session.stepIndex + 1 >= session.steps.count ? "Finish" : "Next",
                        systemImage: "forward.end.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.small)
                .buttonBorderShape(.capsule)
            }
            .animation(.bouncy(duration: 0.5, extraBounce: 0.12), value: stepElapsed)
        }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.background.secondary)
        }
        .glassEffect(in: .rect(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(session.tint.opacity(0.18), lineWidth: 1)
        }
        .tint(session.tint)
        .animation(.devvyFast, value: session.isPaused)
        .animation(.devvyFast, value: session.stepIndex)
    }

    private func stepProgress(now: Date) -> CGFloat {
        guard let step = session.currentStep, step.duration > 0 else { return 1 }
        let remaining = session.remainingNow(at: now)
        let p = 1 - remaining / step.duration
        return CGFloat(min(1, max(0, p)))
    }
}
