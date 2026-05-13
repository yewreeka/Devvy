import Foundation
import UserNotifications
import os

/// Notification center delegate. In the default case foreground notifications
/// get banner + sound so the user hears each step transition. When the user
/// has a specific tank's detail view on screen we silence that tank's
/// notifications — banner + sound are redundant when they're already
/// watching the timer. The entry still lands in Notification Center for
/// history.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationDelegate()

    /// The session whose detail view is currently on screen, if any. Stored
    /// in an `OSAllocatedUnfairLock` because the UN delegate callback is
    /// nonisolated and view lifecycle hooks run on the main actor.
    private let viewingLock = OSAllocatedUnfairLock<UUID?>(initialState: nil)

    func setViewing(_ id: UUID) {
        viewingLock.withLock { $0 = id }
    }

    /// Clear the viewing slot, but only if it still matches `id`. Guards the
    /// race where a new detail view's `onAppear` runs before the previous
    /// view's `onDisappear` and would otherwise nil out the freshly-set id.
    func clearViewing(_ id: UUID) {
        viewingLock.withLock { current in
            if current == id { current = nil }
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let viewing = viewingLock.withLock { $0 }
        if let sessionId = Self.sessionId(from: notification.request.identifier),
           sessionId == viewing {
            completionHandler([.list])
        } else {
            completionHandler([.banner, .list, .sound])
        }
    }

    /// Extract the session UUID from a notification identifier produced by
    /// `NotificationScheduler.idPrefix(for:)` (`devvy.session.<UUID>.<kind>`).
    private static func sessionId(from identifier: String) -> UUID? {
        let prefix = "devvy.session."
        guard identifier.hasPrefix(prefix) else { return nil }
        let rest = identifier.dropFirst(prefix.count)
        guard let dotIndex = rest.firstIndex(of: ".") else { return nil }
        return UUID(uuidString: String(rest[..<dotIndex]))
    }
}
