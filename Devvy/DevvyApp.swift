import SwiftUI
import UserNotifications

@main
struct DevvyApp: App {
    @State private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        SeedRecipes.runIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .tint(.accentColor)
                .task {
                    await NotificationScheduler.requestAuthorizationIfNeeded()
                    appState.refresh()
                    await appState.tickAndAdvanceFinishedSteps()
                    await appState.reconcileLiveActivities()
                }
                .onReceive(NotificationCenter.default.publisher(for: SharedConstants.stateChangedNotification)) { _ in
                    appState.refresh()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        appState.refresh()
                        Task {
                            await appState.tickAndAdvanceFinishedSteps()
                            await appState.reconcileLiveActivities()
                        }
                    }
                }
        }
    }
}
