import SwiftUI

struct TimerDetailView: View {
    let sessionId: UUID
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var clock = HeartbeatClock()

    private var session: TimerSession? {
        app.sessions.first { $0.id == sessionId }
    }

    var body: some View {
        Group {
            if let session {
                content(for: session)
            } else {
                ContentUnavailableView("Tank ended", systemImage: "checkmark.seal")
                    .onAppear { dismiss() }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { clock.start() }
        .onDisappear { clock.stop() }
    }

    @ViewBuilder
    private func content(for session: TimerSession) -> some View {
        let now = clock.now
        let remaining = session.remainingNow(at: now)

        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    headerSection(session: session)
                    timerSection(session: session, now: now, remaining: remaining)
                    stepsSection(session: session)
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            controlsBar(session: session)
        }
        .background {
            LinearGradient(
                colors: [
                    session.tint.opacity(0.18),
                    session.tint.opacity(0.05),
                    .clear
                ],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Restart Step", systemImage: "arrow.counterclockwise") {
                        Task { await app.restartCurrentStep(session) }
                    }
                    Button("Stop Tank", systemImage: "xmark", role: .destructive) {
                        Task {
                            await app.stop(session)
                            dismiss()
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .tint(session.tint)
    }

    private func headerSection(session: TimerSession) -> some View {
        VStack(spacing: 6) {
            Text(session.tankLabel.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(session.tint)
                .tracking(1.5)
            Text(session.recipeName)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func timerSection(session: TimerSession, now: Date, remaining: TimeInterval) -> some View {
        let step = session.currentStep
        let progress = stepProgress(session: session, now: now)
        let agitating = session.currentAgitation(at: now)

        return VStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(session.tint.opacity(0.15), lineWidth: 14)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(session.tint.gradient, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.3), value: progress)

                VStack(spacing: 6) {
                    if session.isFinished {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.green.gradient)
                            .symbolEffect(.bounce, value: session.isFinished)
                        Text("Done!")
                            .font(.title.weight(.bold))
                    } else if session.isPaused {
                        Text(TimeFormat.clock(remaining))
                            .font(.system(size: 64, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.primary)
                        Text("Paused")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    } else if let cycle = agitating {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(session.tint)
                            .symbolEffect(.rotate, options: .repeating)
                        CountdownText(now: now, endsAt: cycle.endsAt)
                            .font(.system(size: 56, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(session.tint)
                            .multilineTextAlignment(.center)
                        Text("Agitate · \(step?.name ?? "")")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .contentTransition(.opacity)
                            .lineLimit(1)
                    } else {
                        CountdownText(now: now, endsAt: session.stepEndsAt)
                            .font(.system(size: 64, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                        Text(step?.name ?? "")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .contentTransition(.opacity)
                    }
                }
            }
            .frame(width: 280, height: 280)
            .padding(.vertical, 8)

            if let step, !session.isFinished {
                HStack(spacing: 16) {
                    StatPill(label: "Step", value: "\(session.stepIndex + 1)/\(session.steps.count)")
                    StatPill(label: "Duration", value: TimeFormat.clock(step.duration))
                    if let next = session.nextStep {
                        StatPill(label: "Next", value: next.name)
                    }
                }
            }
        }
    }

    private func stepsSection(session: TimerSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Steps")
                .font(.headline)
                .padding(.horizontal, 4)

            VStack(spacing: 8) {
                ForEach(Array(session.steps.enumerated()), id: \.element.id) { idx, step in
                    StepRow(
                        index: idx,
                        step: step,
                        state: idx < session.stepIndex ? .done :
                               idx == session.stepIndex ? .current :
                               .upcoming,
                        tint: session.tint
                    )
                }
            }
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.background.secondary)
            }
            .glassEffect(in: .rect(cornerRadius: 22))
        }
    }

    private func controlsBar(session: TimerSession) -> some View {
        HStack(spacing: 14) {
            if session.isFinished {
                Button {
                    Haptics.success()
                    Task {
                        await app.stop(session)
                        dismiss()
                    }
                } label: {
                    Label("Finish Tank", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
            } else {
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
                    .padding(.vertical, 4)
                    .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.glass)
                .controlSize(.large)

                Button {
                    Haptics.tap()
                    Task { await app.advance(session) }
                } label: {
                    Label(
                        session.stepIndex + 1 >= session.steps.count ? "Finish" : "Next Step",
                        systemImage: "forward.end.fill"
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private func stepProgress(session: TimerSession, now: Date) -> CGFloat {
        guard let step = session.currentStep, step.duration > 0 else { return 1 }
        let remaining = session.remainingNow(at: now)
        return CGFloat(min(1, max(0, 1 - remaining / step.duration)))
    }
}

private struct StatPill: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.8)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.background.secondary)
        }
        .glassEffect(in: .rect(cornerRadius: 14))
    }
}

private struct StepRow: View {
    enum State { case done, current, upcoming }

    let index: Int
    let step: Step
    let state: State
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(state == .current ? tint : tint.opacity(0.15))
                    .frame(width: 30, height: 30)
                if state == .done {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(index + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(state == .current ? .white : tint)
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(step.name)
                    .font(.subheadline.weight(state == .current ? .semibold : .regular))
                    .lineLimit(1)
                if state == .current {
                    Text("Now")
                        .font(.caption2)
                        .foregroundStyle(tint)
                }
            }

            Spacer()

            Text(TimeFormat.clock(step.duration))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .opacity(state == .upcoming ? 0.7 : 1)
        .animation(.devvyFast, value: state)
    }
}
