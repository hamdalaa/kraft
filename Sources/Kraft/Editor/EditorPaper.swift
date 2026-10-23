import KraftCore
import SwiftUI

/// The sticky at writing size: title, body and checklist are typed straight onto the paper in handwriting.
/// Each field picks its handwriting and direction from its own text, so Arabic lines run right to left.
struct EditorPaper: View {
    let sticky: Sticky
    let edit: StickyEditing
    let side: CGFloat
    var focus: FocusState<EditorFocus?>.Binding
    @Environment(\.kraftFormat) private var format

    private var ink: Color { sticky.style.ink.color }
    private var settled: Bool { sticky.kind != .bill && (sticky.money?.isSettled ?? false) }
    /// Empty fields write in the note's direction.
    private func hand(_ text: String) -> Hand {
        Hand(text: text.isEmpty ? sticky.primaryText : text, style: sticky.style.handwriting)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            PaperSurface(color: sticky.style.color.color(customHex: sticky.style.customHex), ruling: sticky.style.ruling,
                         lifted: true)
            VStack(alignment: .leading, spacing: 12) {
                title
                content
                footer
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.layoutDirection, hand(sticky.primaryText).layoutDirection)
            }
            .foregroundStyle(ink.opacity(0.92))
            .tint(ink)
            .padding(.horizontal, 36)
            .padding(.top, 46)
            .padding(.bottom, 28)
        }
        .frame(width: side, height: side)
        .overlay(alignment: .topTrailing) {
            DieCutSticker(art: sticky.kind.sticker, size: 30, tilt: .degrees(sticky.style.tilt > 0 ? 7 : -9))
                .offset(x: 26, y: -30)
                .allowsHitTesting(false)
        }
        .overlay(alignment: sticky.style.fastener == .clip ? .topLeading : .top) { fastener.allowsHitTesting(false) }
        .overlay {
            if settled {
                PaidStamp().scaleEffect(1.9).offset(y: 70).allowsHitTesting(false)
            }
        }
    }

    // MARK: Title

    private var title: some View {
        let hand = hand(sticky.title)
        return TextField("", text: edit.text(\.title), prompt: Text(titlePrompt).foregroundStyle(ink.opacity(0.3)), axis: .vertical)
            .textFieldStyle(.plain)
            .font(hand.font(30, medium: true))
            .lineLimit(1...2)
            .focused(focus, equals: .title)
            .onSubmit(submitTitle)
            .editorWriting(hand.direction)
            .accessibilityLabel(Text("Title"))
    }

    private var titlePrompt: LocalizedStringKey {
        switch sticky.kind {
        case .note: "Title"
        case .todo: "List name"
        case .reminder: "Remind me to…"
        case .owedToMe, .iOwe: "What for"
        case .bill: "Bill name"
        }
    }

    private func submitTitle() {
        guard sticky.kind == .todo else { focus.wrappedValue = .body; return }
        if let first = sticky.checklist.first {
            focus.wrappedValue = .item(first.id)
        } else {
            let (items, id) = StickyEdits.insertItem(after: nil, in: sticky.checklist)
            edit.change(StickyEditing.typing) { $0.checklist = items }
            Task { @MainActor in focus.wrappedValue = .item(id) }
        }
    }

    // MARK: Content per kind

    @ViewBuilder private var content: some View {
        switch sticky.kind {
        case .note, .reminder:
            bodyField(size: 20)
        case .todo:
            EditorChecklist(sticky: sticky, edit: edit, focus: focus)
        case .owedToMe, .iOwe, .bill:
            if let money = sticky.money { EditorMoneyLines(kind: sticky.kind, money: money, hand: hand(money.person)) }
            bodyField(size: 17)
        }
    }

    private func bodyField(size: CGFloat) -> some View {
        let hand = hand(sticky.body)
        return TextEditor(text: edit.text(\.body))
            .font(hand.font(size))
            .scrollContentBackground(.hidden)
            .scrollIndicators(.never)
            .lineSpacing(3)
            .focused(focus, equals: .body)
            .background(alignment: hand.direction == .rightToLeft ? .topTrailing : .topLeading) {
                if sticky.body.isEmpty {
                    Text(bodyPrompt)
                        .font(hand.font(size))
                        .foregroundStyle(ink.opacity(0.3))
                        .padding(.horizontal, 5)
                        .allowsHitTesting(false)
                }
            }
            .padding(.horizontal, -5)
            .accessibilityLabel(Text("Note"))
    }

    private var bodyPrompt: String {
        sticky.kind.isMoney ? String(localized: "Add a note…") : String(localized: "Write anything — English or عربي")
    }

    // MARK: Footer

    @ViewBuilder private var footer: some View {
        switch sticky.kind {
        case .reminder:
            if let r = sticky.reminder {
                GlossyTag(text: EditorText.reminder(r, format), symbol: "bell.fill", tint: .amber, size: .regular)
            }
        case .owedToMe, .iOwe:
            if let money = sticky.money, !money.isSettled, let due = money.dueDate {
                GlossyTag(text: String(localized: "Due \(format.weekdayDayMonth(due))"),
                          symbol: "calendar", tint: sticky.kind == .owedToMe ? .mint : .pink, size: .regular)
            }
        case .bill:
            if let due = sticky.money?.dueDate {
                GlossyTag(text: String(localized: "Monthly · next \(format.dayMonth(due))"),
                          symbol: "arrow.clockwise", tint: .lime, size: .regular)
            }
        case .note, .todo:
            EmptyView()
        }
    }

    @ViewBuilder private var fastener: some View {
        switch sticky.style.fastener {
        case .none: EmptyView()
        case .tape: WashiTape().scaleEffect(1.7).rotationEffect(.degrees(sticky.style.tilt > 0 ? -4 : 3)).offset(y: -12)
        case .pin: PushPin().scaleEffect(1.6).offset(y: -4)
        case .clip: PaperClip().scaleEffect(1.6).rotationEffect(.degrees(-8)).offset(x: 44, y: -26)
        }
    }
}

/// Big handwritten amount, what has come back, and a pencil progress line.
private struct EditorMoneyLines: View {
    let kind: StickyKind
    let money: MoneyInfo
    let hand: Hand
    @Environment(\.kraftFormat) private var format

    var body: some View {
        let arabic = hand.direction == .rightToLeft
        VStack(alignment: .leading, spacing: 4) {
            Text(format.money(money.isSettled || kind == .bill ? money.amount : money.remaining, money.currency, arabic: arabic))
                .font(Hand.amount(54))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if kind == .bill {
                let line = String(localized: "every month")
                Hand(text: line, style: hand.style).text(line, 18).opacity(0.7)
            } else if money.paid > 0, !money.isSettled {
                let line = String(localized: "left of \(format.money(money.amount, money.currency, arabic: arabic)) · \(format.money(money.paid, money.currency, arabic: arabic)) back")
                Hand(text: line, style: hand.style).text(line, 18)
                    .opacity(0.7)
                PencilProgress(progress: money.progress)
                    .scaleEffect(x: 1.8, y: 1.4, anchor: .leading)
                    .padding(.top, 4)
            }
        }
        // Written in the note's direction, wherever the UI's leading edge is.
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.layoutDirection, hand.layoutDirection)
    }
}

/// Short strings shared by the paper and the side card.
enum EditorText {
    static func reminder(_ r: ReminderInfo, _ format: KraftFormat) -> String {
        let when = format.dayAndTime(r.fireDate)
        return r.repeatRule == .never ? when : when + " · " + r.repeatRule.label
    }
}
