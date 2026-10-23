import Foundation

public enum StickyKind: String, Codable, CaseIterable, Sendable {
    case note, todo, reminder, owedToMe, iOwe, bill

    public var isMoney: Bool { self == .owedToMe || self == .iOwe || self == .bill }
}

public struct ChecklistItem: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var text: String
    public var isDone: Bool

    public init(id: UUID = UUID(), text: String, isDone: Bool = false) {
        self.id = id
        self.text = text
        self.isDone = isDone
    }
}

public enum RepeatRule: String, Codable, CaseIterable, Sendable {
    case never, daily, weekly, monthly, yearly
}

public struct ReminderInfo: Codable, Hashable, Sendable {
    /// The next time this reminder rings (for repeating reminders: the current occurrence).
    public var fireDate: Date
    public var repeatRule: RepeatRule
    /// Set by a notification's Snooze / Tomorrow action; rings then instead of `fireDate`.
    public var snoozedUntil: Date?
    /// First occurrence of a repeating series, so "every 31st" survives short months (31 Jan → 28 Feb → 31 Mar).
    /// Nil until the series is first advanced; ignored once `fireDate` is moved off the series.
    public var anchor: Date?

    public init(fireDate: Date, repeatRule: RepeatRule = .never, snoozedUntil: Date? = nil, anchor: Date? = nil) {
        self.fireDate = fireDate
        self.repeatRule = repeatRule
        self.snoozedUntil = snoozedUntil
        self.anchor = anchor
    }
}

/// One sticky. Every record carries `updatedAt` and a tombstone (`deletedAt`) so two copies of the
/// store (Mac + a future iPhone app over iCloud Drive) can merge record by record.
public struct Sticky: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var kind: StickyKind
    public var title: String
    public var body: String
    public var checklist: [ChecklistItem]
    public var money: MoneyInfo?
    public var reminder: ReminderInfo?
    public var style: PaperStyle
    public var isDone: Bool
    public var completedAt: Date?
    public var isOnDesktop: Bool
    public var desktopOrigin: DesktopPoint?
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        kind: StickyKind,
        title: String = "",
        body: String = "",
        checklist: [ChecklistItem] = [],
        money: MoneyInfo? = nil,
        reminder: ReminderInfo? = nil,
        style: PaperStyle = PaperStyle(),
        isDone: Bool = false,
        completedAt: Date? = nil,
        isOnDesktop: Bool = false,
        desktopOrigin: DesktopPoint? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.body = body
        self.checklist = checklist
        self.money = money
        self.reminder = reminder
        self.style = style
        self.isDone = isDone
        self.completedAt = completedAt
        self.isOnDesktop = isOnDesktop
        self.desktopOrigin = desktopOrigin
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.deletedAt = deletedAt
    }

    /// Done for board purposes: ticked off, or a debt that has been fully paid.
    public var isFinished: Bool {
        if isDone { return true }
        if let money, kind != .bill { return money.isSettled }
        return false
    }

    /// The date that makes this sticky "due": reminder time, or money/bill due date.
    public var dueDate: Date? { reminder?.fireDate ?? money?.dueDate }

    /// All text on the paper, used to pick handwriting and direction.
    public var primaryText: String {
        [title, body, money?.person ?? ""].first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? ""
    }
}

public struct DesktopPoint: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}
