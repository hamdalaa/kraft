import Foundation

/// Pure edits the sticky editor makes. Each returns a new value; callers write it back through the store.
public enum StickyEdits {
    // MARK: Checklist

    /// Inserts an empty item after `id` (or at the end). Returns the new list and the new item's id.
    public static func insertItem(after id: ChecklistItem.ID?, in items: [ChecklistItem]) -> ([ChecklistItem], ChecklistItem.ID) {
        let item = ChecklistItem(text: "")
        var copy = items
        if let id, let index = items.firstIndex(where: { $0.id == id }) {
            copy.insert(item, at: index + 1)
        } else {
            copy.append(item)
        }
        return (copy, item.id)
    }

    /// Removes `id`. Returns the new list and the item that should take focus (the one before, else the next).
    public static func removeItem(_ id: ChecklistItem.ID, from items: [ChecklistItem]) -> ([ChecklistItem], ChecklistItem.ID?) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return (items, nil) }
        let rest = items.filter { $0.id != id }
        let focus = index > 0 ? rest[index - 1].id : rest.first?.id
        return (rest, focus)
    }

    /// Moves `id` to where `target` sits (drag and drop reorder).
    public static func moveItem(_ id: ChecklistItem.ID, to target: ChecklistItem.ID, in items: [ChecklistItem]) -> [ChecklistItem] {
        guard id != target,
              let from = items.firstIndex(where: { $0.id == id }),
              let to = items.firstIndex(where: { $0.id == target }) else { return items }
        var copy = items
        let item = copy.remove(at: from)
        copy.insert(item, at: to)
        return copy
    }

    // MARK: Kind

    /// Switches kind, carrying content across so nothing typed is lost:
    /// note lines become to-do items and back; money and reminder details appear with sensible defaults
    /// and are cleared when they no longer apply (so a former reminder stops firing).
    public static func switchKind(_ sticky: Sticky, to kind: StickyKind, now: Date = Date(), calendar: Calendar = .current) -> Sticky {
        guard sticky.kind != kind else { return sticky }
        var s = sticky
        s.kind = kind
        if kind == .todo, s.checklist.isEmpty {
            s.checklist = s.body.split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .map { ChecklistItem(text: $0) }
            if !s.checklist.isEmpty { s.body = "" }
        }
        if sticky.kind == .todo, kind != .todo, s.body.isEmpty {
            s.body = s.checklist.map(\.text).filter { !$0.isEmpty }.joined(separator: "\n")
            s.checklist = []
        }
        if kind == .reminder {
            if s.reminder == nil { s.reminder = ReminderInfo(fireDate: nextWholeHour(after: now, calendar: calendar)) }
        } else {
            s.reminder = nil
        }
        if kind.isMoney {
            var money = s.money ?? MoneyInfo(person: "", amount: 0, currency: .iqd)
            if kind == .bill, let due = money.dueDate {
                money.dueDate = billDue(day: calendar.component(.day, from: due), after: now, calendar: calendar)
            }
            s.money = money
        } else {
            s.money = nil
        }
        return s
    }

    static func nextWholeHour(after date: Date, calendar: Calendar) -> Date {
        let hour = calendar.dateInterval(of: .hour, for: date)?.start ?? date
        return calendar.date(byAdding: .hour, value: 1, to: hour) ?? date
    }

    // MARK: Money

    public static func addPayment(_ amount: Decimal, on date: Date, to money: MoneyInfo) -> MoneyInfo {
        guard amount > 0 else { return money }
        var copy = money
        copy.payments = money.payments + [Payment(amount: amount, date: date)]
        return copy
    }

    public static func removePayment(_ id: Payment.ID, from money: MoneyInfo) -> MoneyInfo {
        var copy = money
        copy.payments = money.payments.filter { $0.id != id }
        return copy
    }

    /// The next time a monthly bill falls due on `day` (1…31, clamped to short months), today included.
    public static func billDue(day: Int, after now: Date, calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: now)
        for offset in 0...1 {
            guard let month = calendar.date(byAdding: .month, value: offset, to: today),
                  let range = calendar.range(of: .day, in: .month, for: month) else { continue }
            var parts = calendar.dateComponents([.year, .month], from: month)
            parts.day = min(max(day, 1), range.upperBound - 1)
            if let date = calendar.date(from: parts), date >= today { return date }
        }
        return today
    }

    /// Parses an amount typed in Western or Arabic-Indic digits, with `,` `٬` `'` or spaces as grouping
    /// and `.` or `٫` as the decimal point: "150,000", "١٥٠٬٠٠٠", "12.5", "١٢٫٥". Nil if it is not a number.
    public static func parseAmount(_ text: String) -> Decimal? {
        var ascii = ""
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x30...0x39: ascii.unicodeScalars.append(scalar)
            case 0x0660...0x0669: ascii.append(Character(String(scalar.value - 0x0660)))
            case 0x06F0...0x06F9: ascii.append(Character(String(scalar.value - 0x06F0)))
            case 0x2E, 0x066B: ascii.append(".")
            case 0x2C, 0x066C, 0x27, 0x20, 0xA0, 0x202F: continue
            default: return nil
            }
        }
        guard !ascii.isEmpty, ascii.filter({ $0 == "." }).count <= 1, ascii != "." else { return nil }
        return Decimal(string: ascii, locale: Locale(identifier: "en_US_POSIX"))
    }

    // MARK: Duplicate

    /// A fresh copy: new ids, not on the desktop, not done, placed now.
    public static func duplicate(_ sticky: Sticky, now: Date = Date()) -> Sticky {
        var copy = sticky
        copy.id = UUID()
        copy.checklist = sticky.checklist.map { ChecklistItem(text: $0.text, isDone: $0.isDone) }
        copy.isDone = false
        copy.completedAt = nil
        copy.isOnDesktop = false
        copy.desktopOrigin = nil
        copy.createdAt = now
        copy.updatedAt = now
        copy.deletedAt = nil
        return copy
    }
}
