import Foundation

/// The folder tabs across the top of the board.
public enum BoardTab: String, CaseIterable, Sendable, Identifiable {
    case all, today, money, reminders, todo, notes, done

    public var id: String { rawValue }

    public func includes(_ sticky: Sticky, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard sticky.deletedAt == nil else { return false }
        if self == .done { return sticky.isFinished }
        guard !sticky.isFinished else { return false }
        switch self {
        case .all: return true
        case .today:
            guard let due = sticky.dueDate else { return false }
            let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
            return due < endOfToday
        case .money: return sticky.kind.isMoney
        case .reminders: return sticky.kind == .reminder
        case .todo: return sticky.kind == .todo
        case .notes: return sticky.kind == .note
        case .done: return false
        }
    }

    public func filter(_ stickies: [Sticky], now: Date = Date(), calendar: Calendar = .current) -> [Sticky] {
        stickies.filter { includes($0, now: now, calendar: calendar) }
    }
}
