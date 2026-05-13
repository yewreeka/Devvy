import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct DevvyLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DevvyActivityAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.recipeName)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Text(context.state.tankLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    timerText(context.state)
                        .font(.system(.title3, design: .rounded).weight(.bold).monospacedDigit())
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.stepName)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        pauseResumeButton(context: context, expanded: true)
                        nextButton(context: context, expanded: true)
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(.tint)
            } compactTrailing: {
                timerText(context.state)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .frame(maxWidth: 56)
            } minimal: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "timer")
                    .foregroundStyle(.tint)
            }
            .keylineTint(.accentColor)
        }
    }

    @ViewBuilder
    private func timerText(_ state: DevvyActivityAttributes.ContentState) -> some View {
        if let remaining = state.pausedRemaining {
            Text(TimeFormat.clock(remaining))
        } else if state.isFinished {
            Text("Done")
        } else {
            CountdownText(now: .now, endsAt: state.stepEndsAt)
        }
    }

    @ViewBuilder
    private func pauseResumeButton(
        context: ActivityViewContext<DevvyActivityAttributes>,
        expanded: Bool
    ) -> some View {
        if context.state.isFinished || context.state.stepHasElapsed(at: .now) {
            EmptyView()
        } else if context.state.isPaused {
            Button(intent: ResumeTimerIntent(sessionId: context.attributes.sessionId)) {
                Label("Resume", systemImage: "play.fill")
            }
            .tint(.green)
        } else {
            Button(intent: PauseTimerIntent(sessionId: context.attributes.sessionId)) {
                Label("Pause", systemImage: "pause.fill")
            }
            .tint(.orange)
        }
    }

    @ViewBuilder
    private func nextButton(
        context: ActivityViewContext<DevvyActivityAttributes>,
        expanded: Bool
    ) -> some View {
        if context.state.isFinished {
            Button(intent: StopTimerIntent(sessionId: context.attributes.sessionId)) {
                Label("Finish", systemImage: "checkmark")
            }
            .tint(.accentColor)
        } else {
            Button(intent: NextStepIntent(sessionId: context.attributes.sessionId)) {
                Label(
                    context.state.stepIndex + 1 >= context.state.stepCount ? "Finish" : "Next Step",
                    systemImage: "forward.end.fill"
                )
            }
            .tint(.accentColor)
        }
    }
}

// MARK: - Lock screen view

private struct LockScreenView: View {
    let context: ActivityViewContext<DevvyActivityAttributes>

    var body: some View {
        let state = context.state
        let progress = stepProgress(state)

        // TimelineView re-renders the surrounding view at each agitation cycle
        // boundary so the "Agitate" overlay can flip on/off without us pushing
        // a Live Activity update from the app process. Outside of cycle
        // transitions the inner Text(timerInterval:) self-updates.
        TimelineView(.explicit(transitionDates(for: state))) { timeline in
            let currentAgit = state.currentAgitation(at: timeline.date)
            let headsUp = state.upcomingAgitation(within: 15, at: timeline.date)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(state.tankLabel.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(.tint)
                    Text("·")
                        .foregroundStyle(.white.opacity(0.4))
                    Text(context.attributes.recipeName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "drop.halffull")
                        .font(.caption)
                        .foregroundStyle(.tint)
                }

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 0) {
                        if let cycle = currentAgit {
                            Text("Agitate")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.tint)
                            Text(state.stepName)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.6))
                                .lineLimit(1)
                            Color.clear.frame(height: 0)
                                .accessibilityHidden(true)
                                .id(cycle.startsAt)
                        } else {
                            Text(state.stepName)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            if let cycle = headsUp {
                                HStack(spacing: 4) {
                                    Image(systemName: "bell.badge")
                                        .font(.caption2)
                                    Text("Agitate in ")
                                        .font(.caption2)
                                    CountdownText(now: timeline.date, endsAt: cycle.startsAt)
                                        .font(.caption2.monospacedDigit())
                                }
                                .foregroundStyle(.tint)
                            } else {
                                Text("Step \(state.stepIndex + 1) of \(state.stepCount)")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                    }
                    Spacer()
                    if let cycle = currentAgit {
                        CountdownText(now: timeline.date, endsAt: cycle.endsAt)
                            .font(.system(.title, design: .rounded).weight(.bold).monospacedDigit())
                            .foregroundStyle(.tint)
                    } else {
                        timerView(state: state)
                            .font(.system(.title, design: .rounded).weight(.bold).monospacedDigit())
                            .foregroundStyle(.white)
                    }
                }

                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(currentAgit == nil ? Color.accentColor : Color.orange)

                HStack(spacing: 10) {
                    if state.isFinished {
                        Button(intent: StopTimerIntent(sessionId: context.attributes.sessionId)) {
                            Label("Finish Tank", systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .tint(.accentColor)
                    } else {
                        let stepElapsed = state.stepHasElapsed(at: timeline.date)
                        if !stepElapsed {
                            if state.isPaused {
                                Button(intent: ResumeTimerIntent(sessionId: context.attributes.sessionId)) {
                                    Label("Resume", systemImage: "play.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .tint(.green)
                            } else {
                                Button(intent: PauseTimerIntent(sessionId: context.attributes.sessionId)) {
                                    Label("Pause", systemImage: "pause.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .tint(.orange)
                            }
                        }

                        Button(intent: NextStepIntent(sessionId: context.attributes.sessionId)) {
                            Label(
                                state.stepIndex + 1 >= state.stepCount ? "Finish" : "Next",
                                systemImage: "forward.end.fill"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .tint(.accentColor)
                    }
                }
                .controlSize(.small)
                .buttonBorderShape(.capsule)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 14)
        }
    }

    /// Dates at which the lock-screen view should re-render: heads-up start
    /// (cycle.startsAt - 15s), each agitation cycle's start + end, and the
    /// step end. Includes `.now` as a floor so `TimelineView` always has at
    /// least one entry.
    private func transitionDates(for state: DevvyActivityAttributes.ContentState) -> [Date] {
        var dates: [Date] = [.now]
        for cycle in state.agitationCycles {
            dates.append(cycle.startsAt.addingTimeInterval(-15))
            dates.append(cycle.startsAt)
            dates.append(cycle.endsAt)
        }
        dates.append(state.stepEndsAt)
        return dates.sorted()
    }

    @ViewBuilder
    private func timerView(state: DevvyActivityAttributes.ContentState) -> some View {
        if let remaining = state.pausedRemaining {
            Text(TimeFormat.clock(remaining))
        } else if state.isFinished {
            Text("Done")
        } else {
            CountdownText(now: .now, endsAt: state.stepEndsAt)
                .multilineTextAlignment(.trailing)
        }
    }

    private func stepProgress(_ state: DevvyActivityAttributes.ContentState) -> Double {
        guard state.stepDuration > 0 else { return 1 }
        if state.isFinished { return 1 }
        let remaining: TimeInterval
        if let r = state.pausedRemaining {
            remaining = r
        } else {
            remaining = max(0, state.stepEndsAt.timeIntervalSinceNow)
        }
        return max(0, min(1, 1 - remaining / state.stepDuration))
    }
}
