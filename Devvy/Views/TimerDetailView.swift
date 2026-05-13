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
        TankPresenter(indicator: session.map { TankIndicator(session: $0) }) {
            Group {
                if let session {
                    content(for: session)
                } else {
                    ContentUnavailableView("Tank ended", systemImage: "checkmark.seal")
                        .onAppear { dismiss() }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            clock.start()
            NotificationDelegate.shared.setViewing(sessionId)
        }
        .onDisappear {
            clock.stop()
            NotificationDelegate.shared.clearViewing(sessionId)
        }
    }

    @ViewBuilder
    private func content(for session: TimerSession) -> some View {
        let now = clock.now
        let remaining = session.remainingNow(at: now)

        // Golden-ratio-ish layout: the ring sits in the upper third (with a
        // capped top spacer for breathing room below the floating indicator),
        // a fixed 32pt gap separates ring and carousel, and the flex space
        // below the carousel pushes the controls to the bottom.
        VStack(spacing: 0) {
            Spacer().frame(maxHeight: 24)
            timerSection(session: session, now: now, remaining: remaining)
            if !session.isFinished {
                Spacer().frame(height: 32)
                StepCarousel(session: session)
            }
            Spacer(minLength: 16)
            controlsBar(session: session, now: now)
        }
        .padding(.horizontal, 20)
        .padding(.top, 72)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            LinearGradient(
                colors: [
                    session.tint.opacity(0.28),
                    session.tint.opacity(0.12),
                    session.tint.opacity(0.04),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .toolbar(.hidden, for: .tabBar)
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

    private func timerSection(session: TimerSession, now: Date, remaining: TimeInterval) -> some View {
        let step = session.currentStep
        let progress = stepProgress(session: session, now: now)
        let agitating = session.currentAgitation(at: now)
        let headsUp = session.upcomingAgitation(within: 15, at: now)

        let ringSize: CGFloat = 304
        let arcColor: Color = agitating != nil ? session.tint.intensified() : session.tint
        return VStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(arcColor.opacity(0.15), lineWidth: 14)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(arcColor.gradient, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.3), value: progress)

                AgitationMarkers(
                    fractions: agitationMarkerFractions(session: session),
                    tint: session.tint,
                    ringSize: ringSize
                )

                VStack(spacing: 6) {
                    if session.isFinished {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.green.gradient)
                            .symbolEffect(.bounce, value: session.isFinished)
                        Text("Done!")
                            .font(.title.weight(.bold))
                            .foregroundStyle(session.tint.tintedInk)
                    } else if session.isPaused {
                        Text(TimeFormat.clock(remaining))
                            .font(.system(size: 64, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(session.tint.tintedInk)
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
                            .foregroundStyle(session.tint.tintedInk)
                            .multilineTextAlignment(.center)
                        if let cycle = headsUp {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.subheadline.weight(.semibold))
                                    .symbolEffect(.rotate, options: .repeating)
                                Text("Agitate in ")
                                    .font(.headline)
                                CountdownText(now: now, endsAt: cycle.startsAt)
                                    .font(.headline.monospacedDigit())
                            }
                            .foregroundStyle(session.tint)
                            .contentTransition(.opacity)
                        } else {
                            Text(step?.name ?? "")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .contentTransition(.opacity)
                        }
                    }
                }
            }
            .frame(width: ringSize, height: ringSize)
            .animation(.easeInOut(duration: 0.45), value: agitating != nil)
        }
    }

    /// Returns the position of each agitation cycle's start as a fraction
    /// (0...1) of the current step's duration — used to plot dots on the
    /// progress ring. Cycles that have already started but haven't ended
    /// still show their start mark; cycles beyond the step are filtered out.
    private func agitationMarkerFractions(session: TimerSession) -> [Double] {
        guard let step = session.currentStep, step.duration > 0 else { return [] }
        let anchor = session.stepLogicalStart
        return session.agitationCycles.compactMap { cycle in
            // Skip the initial cycle — its marker would sit at 12 o'clock,
            // right where the progress arc begins, and reads as noise.
            guard !cycle.isInitial else { return nil }
            let elapsed = cycle.startsAt.timeIntervalSince(anchor)
            let fraction = elapsed / step.duration
            guard fraction > 0, fraction < 1 else { return nil }
            return fraction
        }
    }

    private func controlsBar(session: TimerSession, now: Date) -> some View {
        let stepElapsed = !session.isFinished && session.stepHasElapsed(at: now)

        return HStack(spacing: 14) {
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
                        Image(systemName: session.isPaused ? "play.fill" : "pause.fill")
                            .font(.title3.weight(.semibold))
                            .contentTransition(.symbolEffect(.replace))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel(session.isPaused ? "Resume" : "Pause")
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                }

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
        .padding(.vertical, 4)
        .animation(.bouncy(duration: 0.5, extraBounce: 0.12), value: stepElapsed)
    }

    private func stepProgress(session: TimerSession, now: Date) -> CGFloat {
        guard let step = session.currentStep, step.duration > 0 else { return 1 }
        let remaining = session.remainingNow(at: now)
        return CGFloat(min(1, max(0, 1 - remaining / step.duration)))
    }
}

/// Small "station" dots placed on the progress ring at each agitation cycle's
/// start. Dot fill uses the system background so they read clearly against
/// both the dim background ring and the bright progress arc.
private struct AgitationMarkers: View {
    let fractions: [Double]
    let tint: Color
    let ringSize: CGFloat

    private let dotSize: CGFloat = 5

    var body: some View {
        let radius = ringSize / 2
        ZStack {
            ForEach(Array(fractions.enumerated()), id: \.offset) { _, fraction in
                let angle = fraction * 2 * .pi - .pi / 2
                Circle()
                    .fill(.background.opacity(0.75))
                    .frame(width: dotSize, height: dotSize)
                    .position(
                        x: radius + radius * CGFloat(cos(angle)),
                        y: radius + radius * CGFloat(sin(angle))
                    )
            }
        }
        .frame(width: ringSize, height: ringSize)
        .allowsHitTesting(false)
    }
}

/// Horizontal step indicator: the current step sits centered in the view at
/// full size, and the next step is fully visible to its right, scaled to
/// 80% with reduced opacity for hierarchy. Completed steps clip off the
/// left; the step-after-next sits off-screen right and slides in as the
/// session advances. Card width is computed so a centered current plus a
/// 0.8-scaled next always fits within the view with an 8pt right margin.
private struct StepCarousel: View {
    let session: TimerSession

    private let spacing: CGFloat = 10
    private let nextScale: CGFloat = 0.80
    private let rightMargin: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            // Solve: W/2 + cardWidth + spacing + (nextScale × cardWidth)/2 + rightMargin = W
            // →  cardWidth × (1 + nextScale/2) = W/2 - spacing - rightMargin
            let cardWidth = max(96, (geo.size.width / 2 - spacing - rightMargin) / (1 + nextScale / 2))
            let centerOffset = (geo.size.width - cardWidth) / 2
            let stackOffset = centerOffset - CGFloat(session.stepIndex) * (cardWidth + spacing)

            HStack(spacing: spacing) {
                ForEach(Array(session.steps.enumerated()), id: \.element.id) { idx, step in
                    StepCarouselCard(
                        step: step,
                        index: idx,
                        totalSteps: session.steps.count,
                        state: cardState(for: idx),
                        tint: session.tint,
                        nextScale: nextScale
                    )
                    .frame(width: cardWidth)
                }
            }
            .offset(x: stackOffset)
            .animation(.bouncy(duration: 0.55, extraBounce: 0.08), value: session.stepIndex)
            .frame(width: geo.size.width, alignment: .leading)
        }
        .frame(height: 140)
        .clipShape(.rect)
    }

    private func cardState(for index: Int) -> StepCarouselCard.State {
        if index < session.stepIndex { return .done }
        if index == session.stepIndex { return .current }
        return .upcoming
    }
}

private struct StepCarouselCard: View {
    enum State { case done, current, upcoming }

    let step: Step
    let index: Int
    let totalSteps: Int
    let state: State
    let tint: Color
    let nextScale: CGFloat

    var body: some View {
        VStack(spacing: 8) {
            Text("STEP \(index + 1) OF \(totalSteps)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(state == .current ? tint : .secondary)
                .tracking(0.9)
            Text(step.name)
                .font(.title3.weight(.bold))
                .foregroundStyle(tint.tintedInk)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(TimeFormat.clock(step.duration))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(state == .current ? tint.opacity(0.12) : Color.clear)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(tint.opacity(state == .current ? 0.25 : 0.12), lineWidth: 1)
                }
        }
        .opacity(state == .current ? 1.0 : 0.5)
        .scaleEffect(state == .current ? 1.0 : nextScale, anchor: .center)
        .animation(.bouncy(duration: 0.45, extraBounce: 0.05), value: state)
    }
}
