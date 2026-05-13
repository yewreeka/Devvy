import SwiftUI

/// Mirrors Convos's `ConversationPresenter`: wraps a screen's content and
/// overlays the `TankIndicator` at the top of the screen (above the nav bar)
/// in a `ZStack`, instead of letting it scroll inline.
///
/// The indicator floats with `zIndex(1000)`, padded down by the *window*
/// safe-area inset so it lands where the nav-bar title would sit. Non-
/// interactive (matches the Convos look but without the expand/edit affordance).
struct TankPresenter<Content: View>: View {
    let session: TimerSession?
    @ViewBuilder let content: () -> Content

    @State private var topInset: CGFloat = 0

    var body: some View {
        ZStack {
            content()

            VStack {
                if let session {
                    TankIndicator(session: session)
                        .padding(.top, topInset)
                        .padding(.horizontal, 16)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .identity
                        ))
                }
                Spacer()
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .zIndex(1000)
        }
        .animation(.bouncy(duration: 0.4, extraBounce: 0.15), value: session != nil)
        .onAppear { refreshInset() }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            DispatchQueue.main.async { refreshInset() }
        }
    }

    private func refreshInset() {
        guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
                ?? UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first
        else { return }
        topInset = window.safeAreaInsets.top
    }
}
