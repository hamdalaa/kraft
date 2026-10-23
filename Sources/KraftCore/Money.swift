import Foundation

public enum Currency: String, Codable, CaseIterable, Sendable {
    case iqd = "IQD"
    case usd = "USD"
}

public struct Payment: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var amount: Decimal
    public var date: Date

    public init(id: UUID = UUID(), amount: Decimal, date: Date) {
        self.id = id
        self.amount = amount
        self.date = date
    }
}

public struct MoneyInfo: Codable, Hashable, Sendable {
    public var person: String
    public var amount: Decimal
    public var currency: Currency
    public var dueDate: Date?
    public var payments: [Payment]

    public init(person: String, amount: Decimal, currency: Currency, dueDate: Date? = nil, payments: [Payment] = []) {
        self.person = person
        self.amount = amount
        self.currency = currency
        self.dueDate = dueDate
        self.payments = payments
    }

    public var paid: Decimal { payments.reduce(0) { $0 + $1.amount } }
    public var remaining: Decimal { max(0, amount - paid) }
    public var isSettled: Bool { amount > 0 && remaining == 0 }
    /// 0…1, for progress marks on the paper.
    public var progress: Double {
        guard amount > 0 else { return 0 }
        return min(1, NSDecimalNumber(decimal: paid / amount).doubleValue)
    }
}
