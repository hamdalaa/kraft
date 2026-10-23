import Foundation
import Testing
@testable import KraftCore

@Suite struct ParserListNoteTests {
    static let listsCases: [Expect] = [
        Expect(text: "buy milk, bread, eggs", kind: .todo, title: "Buy", checklist: ["Milk", "Bread", "Eggs"]),
        Expect(text: "todo: call bank, pay rent", kind: .todo, title: "", checklist: ["Call bank", "Pay rent"]),
        Expect(text: "milk, bread and eggs", kind: .todo, checklist: ["Milk", "Bread", "Eggs"]),
        Expect(text: "Groceries: rice, tea", kind: .todo, title: "Groceries", checklist: ["Rice", "Tea"]),
        Expect(text: "- passport\n- charger\n- tickets", kind: .todo, checklist: ["Passport", "Charger", "Tickets"]),
        Expect(text: "buy milk and bread", kind: .todo, title: "Buy", checklist: ["Milk", "Bread"]),
        Expect(text: "اشتري حليب، خبز، بيض", kind: .todo, title: "اشتري", checklist: ["حليب", "خبز", "بيض"]),
        Expect(text: "مهام: غسل السيارة، ترتيب الغرفة", kind: .todo, checklist: ["غسل السيارة", "ترتيب الغرفة"]),
        Expect(text: "جيب طماطة وخيار وبصل", kind: .todo, title: "جيب", checklist: ["طماطة", "خيار", "بصل"]),
        Expect(text: "buy milk, bread, eggs tomorrow", kind: .todo, date: PF.date(2026, 10, 22, 9), checklist: ["Milk", "Bread", "Eggs"]),
    ]

    static let notesCases: [Expect] = [
        Expect(text: "Gift idea: the blue scarf", kind: .note), // one item after a colon is not a list
        Expect(text: "The blue scarf from the souq", kind: .note, title: "The blue scarf from the souq", body: ""),
        Expect(text: "فكرة هدية: الوشاح الأزرق", kind: .note),
        Expect(text: "Gift idea\nThe blue scarf from the souq — ask Sara which shop.", kind: .note, title: "Gift idea",
               body: "The blue scarf from the souq — ask Sara which shop."),
        Expect(text: "A long thought that keeps going past the length of a title on a small paper", kind: .note, title: "",
               body: "A long thought that keeps going past the length of a title on a small paper"),
        Expect(text: "buy milk", kind: .note, title: "buy milk"),
        Expect(text: "40 is the answer", kind: .note, title: "40 is the answer"),
    ]

    @Test(arguments: listsCases) func lists(_ e: Expect) { check(e) }
    @Test(arguments: notesCases) func notes(_ e: Expect) { check(e) }
}
