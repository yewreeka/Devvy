import Foundation
import UserNotifications

/// Schedules and cancels local notifications for a TimerSession's current step.
///
/// We schedule three kinds of alerts per step:
///   1. End-of-step (always).
///   2. Heads-up at `step.leadInNotice` seconds before the end (if non-zero).
///   3. Recurring inversion reminders every `step.recurringNotice` seconds (if non-zero).
public enum NotificationScheduler {
    private static var center: UNUserNotificationCenter { UNUserNotificationCenter.current() }

    /// Identifier prefix for a session's notifications. Cancellation matches by prefix.
    public static func idPrefix(for sessionId: UUID) -> String {
        "devvy.session.\(sessionId.uuidString)."
    }

    public static func reschedule(for session: TimerSession) {
        cancelAll(for: session.id)
        guard !session.isPaused, !session.isFinished, let step = session.currentStep else { return }

        let prefix = idPrefix(for: session.id)
        let endsAt = session.stepEndsAt
        let now = Date()
        let remaining = endsAt.timeIntervalSince(now)
        guard remaining > 0 else { return }

        // 1. End-of-step.
        schedule(
            id: prefix + "end",
            title: "\(session.tankLabel) — \(step.name) done",
            body: session.nextStep.map { "Up next: \($0.name)" } ?? "Recipe complete!",
            after: remaining,
            sound: .default,
            interruption: .active
        )

        // 2. A chime at the start of each *recurring* agitation cycle. The
        // initial agitation gets no chime (the user just tapped Start, they
        // know it began). The Live Activity / app UI then takes over and
        // displays an "Agitate {countdown}" overlay for the cycle duration.
        let cycles = session.agitationCycles
        for (i, cycle) in cycles.enumerated() where !cycle.isInitial {
            let delay = cycle.startsAt.timeIntervalSince(now)
            guard delay > 0, delay < remaining else { continue }
            schedule(
                id: prefix + "agitate.\(i)",
                title: "\(session.tankLabel) — Agitate",
                body: "\(step.agitationDuration)s · \(step.name)",
                after: delay,
                sound: .default,
                interruption: .active
            )
        }
    }

    public static func cancelAll(for sessionId: UUID) {
        let prefix = idPrefix(for: sessionId)
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
            if !ids.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: ids)
            }
        }
        center.getDeliveredNotifications { delivered in
            let ids = delivered.map(\.request.identifier).filter { $0.hasPrefix(prefix) }
            if !ids.isEmpty {
                center.removeDeliveredNotifications(withIdentifiers: ids)
            }
        }
    }

    public static func requestAuthorizationIfNeeded() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    private static func schedule(
        id: String,
        title: String,
        body: String,
        after seconds: TimeInterval,
        sound: UNNotificationSound,
        interruption: UNNotificationInterruptionLevel
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound
        content.interruptionLevel = interruption
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }
}
