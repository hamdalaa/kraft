import KraftCore
import UserNotifications

/// Notification categories: one per note language, so an Arabic note's buttons read in Arabic too.
enum AlertCategory {
    enum Action: String, CaseIterable {
        case done = "kraft.done"
        case tenMinutes = "kraft.snooze.10m"
        case oneHour = "kraft.snooze.1h"
        case tomorrow = "kraft.snooze.tomorrow"
    }

    static func identifier(arabic: Bool) -> String { arabic ? "kraft.alert.ar" : "kraft.alert.en" }

    static func all(digits: DigitStyle) -> Set<UNNotificationCategory> {
        [category(arabic: false, digits: digits), category(arabic: true, digits: digits)]
    }

    private static func category(arabic: Bool, digits: DigitStyle) -> UNNotificationCategory {
        let t = AlertCopy.actionTitles(arabic: arabic, digits: digits)
        let actions = [
            UNNotificationAction(identifier: Action.done.rawValue, title: t.done, options: [],
                                 icon: UNNotificationActionIcon(systemImageName: "checkmark")),
            UNNotificationAction(identifier: Action.tenMinutes.rawValue, title: t.tenMinutes, options: [],
                                 icon: UNNotificationActionIcon(systemImageName: "zzz")),
            UNNotificationAction(identifier: Action.oneHour.rawValue, title: t.oneHour, options: [],
                                 icon: UNNotificationActionIcon(systemImageName: "clock")),
            UNNotificationAction(identifier: Action.tomorrow.rawValue, title: t.tomorrow, options: [],
                                 icon: UNNotificationActionIcon(systemImageName: "sunrise")),
        ]
        return UNNotificationCategory(identifier: identifier(arabic: arabic), actions: actions, intentIdentifiers: [], options: [])
    }
}
