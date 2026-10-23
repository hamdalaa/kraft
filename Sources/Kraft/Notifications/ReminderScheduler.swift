import AppKit
import KraftCore
import OSLog
import UserNotifications

private let log = Logger(subsystem: "io.github.hamdalaa.kraft", category: "reminders")

/// One calm notification per reminder (Done / Snooze 10 min / 1 h / Tomorrow). Nothing pops up unasked:
/// permission is requested only once a reminder or due date exists, there are no badges, and each
/// sticky has at most one pending notification (identifier = sticky id).
@MainActor
final class ReminderScheduler: NSObject {
    let store: StickyStore

    /// Nil when not running from an app bundle (e.g. `swift run`), where the notification center is unavailable.
    private var center: UNUserNotificationCenter?
    private var authorization: UNAuthorizationStatus = .notDetermined
    private var isAskingPermission = false
    private var pendingSync: Task<Void, Never>?
    private var wakeTimer: Timer?
    private var observers: [NSObjectProtocol] = []

    init(store: StickyStore) { self.store = store }

    func start() {
        guard Bundle.main.bundleIdentifier != nil, Bundle.main.bundleURL.pathExtension == "app" else { return }
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.setNotificationCategories(AlertCategory.all(digits: AppPreferences.shared.digits))
        self.center = center

        // Repeating reminders are scheduled one occurrence at a time; catch up after sleep and at midnight.
        let nc = NotificationCenter.default, ws = NSWorkspace.shared.notificationCenter
        observers = [
            nc.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { AppServices.shared.reminders.sync() }
            },
            ws.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { AppServices.shared.reminders.sync() }
            },
        ]

        sync()
    }

    private var isAllowed: Bool { authorization == .authorized || authorization == .provisional }

    /// Reconcile pending notifications with `store`. Cheap to call often: rapid edits are coalesced.
    func sync() {
        guard center != nil else { return }
        pendingSync?.cancel()
        pendingSync = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            await reconcile()
        }
    }

    private func reconcile() async {
        guard let center else { return }
        let now = Date()
        let digits = AppPreferences.shared.digits
        center.setNotificationCategories(AlertCategory.all(digits: digits))
        let plan = AlertPlanner.plan(store.stickies, now: now, calendar: .current, digits: digits)
        scheduleWake(at: plan.first?.date)

        if !isAllowed {
            // Re-read each time: the owner may have switched Kraft on in System Settings since.
            authorization = await center.notificationSettings().authorizationStatus
        }
        if authorization == .notDetermined {
            guard !plan.isEmpty else { return }
            await askPermission(center)
        }
        guard isAllowed else {
            log.info("\(plan.count, privacy: .public) alerts planned, not scheduled (permission \(self.authorization.rawValue, privacy: .public))")
            return
        }

        let wanted = Dictionary(plan.map { ($0.id.uuidString, $0) }, uniquingKeysWith: { first, _ in first })
        let pending = await center.pendingNotificationRequests()
        var upToDate = Set<String>()
        var stale: [String] = []
        for request in pending {
            if let alert = wanted[request.identifier], Self.matches(request, alert) {
                upToDate.insert(request.identifier)
            } else if wanted[request.identifier] == nil {
                stale.append(request.identifier)
            }
        }
        if !stale.isEmpty { center.removePendingNotificationRequests(withIdentifiers: stale) }

        // Finished or deleted stickies also leave Notification Center.
        let gone = store.stickies.filter { $0.deletedAt != nil || $0.isFinished }.map(\.id.uuidString)
        if !gone.isEmpty { center.removeDeliveredNotifications(withIdentifiers: gone) }

        log.info("\(plan.count, privacy: .public) alerts planned, \(upToDate.count, privacy: .public) unchanged, \(stale.count, privacy: .public) removed")
        for alert in plan where !upToDate.contains(alert.id.uuidString) {
            do {
                try await center.add(Self.request(for: alert, kind: store.sticky(alert.id)?.kind))
            } catch {
                log.error("could not schedule \(alert.id.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func askPermission(_ center: UNUserNotificationCenter) async {
        guard !isAskingPermission else { return }
        isAskingPermission = true
        defer { isAskingPermission = false }
        log.info("first reminder exists: asking for notification permission")
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            log.error("notification permission: \(error.localizedDescription, privacy: .public)")
        }
        authorization = await center.notificationSettings().authorizationStatus
        log.info("notification permission answered: \(self.authorization.rawValue, privacy: .public)")
    }

    /// Re-plan just after the earliest alert rings, so the next occurrence of a repeating reminder gets queued.
    private func scheduleWake(at date: Date?) {
        wakeTimer?.invalidate()
        guard let date else { wakeTimer = nil; return }
        let timer = Timer(fire: date.addingTimeInterval(2), interval: 0, repeats: false) { _ in
            MainActor.assumeIsolated { AppServices.shared.reminders.sync() }
        }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        wakeTimer = timer
    }

    // MARK: Requests

    private static func request(for alert: PlannedAlert, kind: StickyKind?) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = alert.copy.title
        content.body = alert.copy.body
        content.categoryIdentifier = AlertCategory.identifier(arabic: alert.copy.isArabic)
        content.threadIdentifier = "kraft"
        content.userInfo = [UserInfo.sticky: alert.id.uuidString, UserInfo.occurrence: alert.date.timeIntervalSince1970]
        // Reminders chime; money due dates arrive quietly.
        content.sound = kind?.isMoney == true ? nil : .default
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: alert.date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        return UNNotificationRequest(identifier: alert.id.uuidString, content: content, trigger: trigger)
    }

    private static func matches(_ request: UNNotificationRequest, _ alert: PlannedAlert) -> Bool {
        guard let fire = (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() else { return false }
        let c = request.content
        return abs(fire.timeIntervalSince(alert.date)) < 1
            && c.title == alert.copy.title && c.body == alert.copy.body
            && c.categoryIdentifier == AlertCategory.identifier(arabic: alert.copy.isArabic)
    }

    // MARK: Responses

    func handle(action: String, id: Sticky.ID, occurrence: Date) {
        if action == UNNotificationDefaultActionIdentifier {
            showBoard()
            if let sticky = store.sticky(id), sticky.deletedAt == nil { AppServices.shared.board.open(id) }
            return
        }
        guard let sticky = store.sticky(id), sticky.deletedAt == nil else { return }
        let now = Date()
        switch AlertCategory.Action(rawValue: action) {
        case .done:
            store.update(sticky.completingAlert(occurrence: occurrence, now: now, calendar: .current), actionName: String(localized: "Done"))
        case .tenMinutes:
            store.update(sticky.snoozed(.tenMinutes, now: now, calendar: .current), actionName: String(localized: "Snooze"))
        case .oneHour:
            store.update(sticky.snoozed(.oneHour, now: now, calendar: .current), actionName: String(localized: "Snooze"))
        case .tomorrow:
            store.update(sticky.snoozed(.tomorrow, now: now, calendar: .current), actionName: String(localized: "Snooze"))
        case nil:
            return
        }
        center?.removeDeliveredNotifications(withIdentifiers: [id.uuidString])
        sync()
    }

    /// Bring the board forward; if its window was closed, a reopen event makes SwiftUI create it again.
    private func showBoard() {
        NSApp.activate()
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue.hasPrefix("board") == true && $0.isVisible }) {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
        } else {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: config)
        }
    }

    enum UserInfo {
        static let sticky = "sticky"
        static let occurrence = "occurrence"
    }
}

extension ReminderScheduler: UNUserNotificationCenterDelegate {
    /// Show alerts even while Kraft is frontmost.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions
    {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let request = response.notification.request
        let info = request.content.userInfo
        guard let id = (info[UserInfo.sticky] as? String).flatMap(UUID.init(uuidString:)) ?? UUID(uuidString: request.identifier) else { return }
        let occurrence = (info[UserInfo.occurrence] as? Double).map(Date.init(timeIntervalSince1970:)) ?? response.notification.date
        let action = response.actionIdentifier
        await handle(action: action, id: id, occurrence: occurrence)
    }
}
