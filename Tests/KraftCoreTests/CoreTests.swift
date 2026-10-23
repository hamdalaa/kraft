import Foundation
import Testing
@testable import KraftCore

@Suite struct ScriptDirectionTests {
    @Test func arabicFirstStrongCharacterIsRTL() {
        #expect(ScriptDirection.detect("ذكرني بالدواء الساعة ٩") == .rightToLeft)
        #expect(ScriptDirection.detect("  ٩ ذكرني") == .rightToLeft)
    }

    @Test func latinAndNeutralTextIsLTR() {
        #expect(ScriptDirection.detect("Ali owes me 40$") == .leftToRight)
        #expect(ScriptDirection.detect("40$ علي") == .rightToLeft)
        #expect(ScriptDirection.detect("123 ...") == .leftToRight)
    }
}

@Suite struct MoneyTests {
    @Test func partialPaymentsLeaveRemainder() {
        let m = MoneyInfo(person: "Ali", amount: 40, currency: .usd, payments: [Payment(amount: 10, date: .now)])
        #expect(m.remaining == 30)
        #expect(!m.isSettled)
        #expect(m.progress == 0.25)
    }

    @Test func overpaymentIsSettledWithZeroRemaining() {
        let m = MoneyInfo(person: "Ali", amount: 40, currency: .usd, payments: [Payment(amount: 50, date: .now)])
        #expect(m.remaining == 0)
        #expect(m.isSettled)
    }
}

@Suite struct BoardTabTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let samples = SampleData.stickies(now: Date(timeIntervalSince1970: 1_800_000_000))

    @Test func settledDebtMovesToDone() {
        let done = BoardTab.done.filter(samples, now: now)
        #expect(done.map(\.kind) == [.iOwe])
        #expect(!BoardTab.all.filter(samples, now: now).contains { $0.kind == .iOwe })
    }

    @Test func moneyTabHoldsOpenMoneyOnly() {
        #expect(Set(BoardTab.money.filter(samples, now: now).map(\.kind)) == [.owedToMe, .bill])
    }

    @Test func todayIncludesTodaysReminder() {
        #expect(BoardTab.today.filter(samples, now: now).contains { $0.kind == .reminder })
    }

    @Test func deletedStickiesAreHiddenEverywhere() {
        var s = samples[0]
        s.deletedAt = now
        for tab in BoardTab.allCases { #expect(!tab.includes(s, now: now)) }
    }
}
