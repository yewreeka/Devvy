import SwiftUI

struct TanksView: View {
    @Environment(AppState.self) private var app
    @State private var showingStart = false
    @State private var heartbeat = HeartbeatClock()
    @Namespace private var ns

    var body: some View {
        NavigationStack {
            Group {
                if app.sessions.isEmpty {
                    EmptyTanksView { showingStart = true }
                } else {
                    sessionsList
                }
            }
            .navigationTitle("Tanks")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.tap()
                        showingStart = true
                    } label: {
                        Label("Start Tank", systemImage: "plus")
                    }
                    .buttonStyle(.glassProminent)
                }
            }
            .sheet(isPresented: $showingStart) {
                StartTankSheet()
            }
        }
        .environment(heartbeat)
        .onAppear { heartbeat.start() }
        .onDisappear { heartbeat.stop() }
    }

    private var sessionsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(app.sessions) { session in
                    NavigationLink(value: session.id) {
                        TimerCardView(session: session, namespace: ns)
                            .matchedTransitionSource(id: session.id, in: ns)
                    }
                    .buttonStyle(.plain)
                    .contextMenu { contextMenu(for: session) }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.85).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .animation(.devvy, value: app.sessions.map(\.id))
        }
        .navigationDestination(for: UUID.self) { id in
            if let session = app.sessions.first(where: { $0.id == id }) {
                TimerDetailView(sessionId: session.id)
                    .navigationTransition(.zoom(sourceID: session.id, in: ns))
            }
        }
    }

    @ViewBuilder
    private func contextMenu(for session: TimerSession) -> some View {
        if !session.isFinished {
            if session.isPaused {
                Button {
                    Haptics.tap()
                    Task { await app.resume(session) }
                } label: {
                    Label("Resume", systemImage: "play.fill")
                }
            } else {
                Button {
                    Haptics.tap()
                    Task { await app.pause(session) }
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                }
            }

            Button {
                Haptics.tap()
                Task { await app.advance(session) }
            } label: {
                Label(
                    session.stepIndex + 1 >= session.steps.count ? "Finish Step" : "Next Step",
                    systemImage: "forward.end.fill"
                )
            }

            Button {
                Haptics.tap()
                Task { await app.restartCurrentStep(session) }
            } label: {
                Label("Restart Step", systemImage: "arrow.counterclockwise")
            }
        }

        Divider()

        Button(role: .destructive) {
            Haptics.warning()
            Task { await app.stop(session) }
        } label: {
            Label("Stop Tank", systemImage: "xmark")
        }
    }
}

private struct EmptyTanksView: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(.tint.opacity(0.12))
                    .frame(width: 160, height: 160)
                Image(systemName: "timer")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(.tint)
                    .symbolEffect(.pulse, options: .repeating)
            }

            VStack(spacing: 6) {
                Text("No tanks running")
                    .font(.title2.weight(.semibold))
                Text("Start a recipe to begin developing.")
                    .foregroundStyle(.secondary)
            }

            Button {
                Haptics.tap()
                onStart()
            } label: {
                Label("Start a Tank", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
