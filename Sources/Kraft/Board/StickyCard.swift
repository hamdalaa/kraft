import AppKit
import KraftCore
import SwiftUI

/// One sticky as it sits on the board (and, later, on the desktop).
struct StickyCard: View {
    let sticky: Sticky
    var lifted = false
    var now = Date()
    var toggleItem: ((ChecklistItem.ID) -> Void)?
    /// Paper only — no sticker, fastener or stamp (used for the crumple render).
    var bare = false
    /// Off for the in-hand crumple render: the paper was pulled off its tape / pin / clip.
    var showsFastener = true
    var castsShadow = true

    private var hand: Hand { Hand(text: sticky.primaryText, style: sticky.style.handwriting) }
    private var settled: Bool { sticky.kind != .bill && (sticky.money?.isSettled ?? false) }

    var body: some View {
        let side = sticky.style.size.side
        let tilt = sticky.style.tilt
        ZStack(alignment: .topLeading) {
            PaperSurface(color: sticky.style.color.color(customHex: sticky.style.customHex), ruling: sticky.style.ruling,
                         lifted: lifted, curl: lifted ? 18 : 0, castsShadow: castsShadow)
            StickyContent(sticky: sticky, hand: hand, now: now, toggleItem: toggleItem)
                .padding(.horizontal, 18)
                .padding(.top, 24)
                .padding(.bottom, 15)
                .environment(\.layoutDirection, hand.layoutDirection)
        }
        .frame(width: side, height: side)
        .overlay(alignment: .topTrailing) {
            if !bare { kindSticker(tilt: tilt) }
        }
        .overlay(alignment: fastenerAlignment) { if !bare && showsFastener { fastener } }
        .overlay { if settled && !bare { PaidStamp().offset(y: 34) } }
        .rotationEffect(.degrees(lifted ? tilt * 0.4 : tilt))
        .scaleEffect(lifted ? 1.025 : 1)
        .accessibilityElement(children: .contain)
    }

    private func kindSticker(tilt: Double) -> some View {
            // The sticker peels up a little when the note is picked up.
            DieCutSticker(art: sticky.kind.sticker, size: 17, tilt: .degrees((tilt > 0 ? 7 : -9) + (lifted ? 7 : 0)))
                .scaleEffect(lifted ? 1.1 : 1, anchor: .bottomLeading)
                .offset(x: 16, y: lifted ? -21 : -18)
    }

    private var fastenerAlignment: Alignment { sticky.style.fastener == .clip ? .topLeading : .top }

    @ViewBuilder private var fastener: some View {
        switch sticky.style.fastener {
        case .none: EmptyView()
        case .tape: WashiTape().rotationEffect(.degrees(sticky.style.tilt > 0 ? -4 : 3)).offset(y: -9)
        case .pin: PushPin().offset(y: lifted ? -4 : -2)
        case .clip: PaperClip().rotationEffect(.degrees(-8)).offset(x: 22, y: -14)
        }
    }
}

private struct StickyContent: View {
    let sticky: Sticky
    let hand: Hand
    let now: Date
    let toggleItem: ((ChecklistItem.ID) -> Void)?

    @Environment(\.kraftFormat) private var format

    private var ink: Color { sticky.style.ink.color }
    private var isArabic: Bool { hand.direction == .rightToLeft }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !sticky.title.isEmpty {
                hand.text(sticky.title, 21, medium: true)
                    .lineLimit(2)
            }
            switch sticky.kind {
            case .note, .reminder:
                if !sticky.body.isEmpty {
                    hand.text(sticky.body, 16).lineSpacing(2).lineLimit(5)
                }
            case .todo:
                Checklist(items: sticky.checklist, hand: hand, ink: ink, toggle: toggleItem)
            case .owedToMe, .iOwe, .bill:
                if let money = sticky.money { MoneyLines(kind: sticky.kind, money: money, hand: hand, isArabic: isArabic) }
            }
            Spacer(minLength: 0)
            footer
        }
        .foregroundStyle(ink.opacity(0.92))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder private var footer: some View {
        switch sticky.kind {
        case .reminder:
            if let r = sticky.reminder {
                GlossyTag(text: reminderText(r), symbol: "bell.fill", tint: .amber, size: .mini)
            }
        case .owedToMe, .iOwe:
            if let money = sticky.money, !money.isSettled, let due = money.dueDate {
                GlossyTag(text: String(localized: "Due \(format.weekday(due))"), symbol: "calendar",
                          tint: sticky.kind == .owedToMe ? .mint : .pink, size: .mini)
            }
        case .bill:
            if let due = sticky.money?.dueDate {
                GlossyTag(text: String(localized: "Monthly · \(format.dayMonth(due))"), symbol: "arrow.clockwise", tint: .lime, size: .mini)
            }
        case .note, .todo:
            EmptyView()
        }
    }

    private func reminderText(_ r: ReminderInfo) -> String {
        let time = format.time(r.fireDate)
        return r.repeatRule == .never ? time : time + " · " + r.repeatRule.label
    }
}

private struct Checklist: View {
    let items: [ChecklistItem]
    let hand: Hand
    let ink: Color
    let toggle: ((ChecklistItem.ID) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(items.prefix(5)) { item in
                Button {
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                    withAnimation(.spring(duration: 0.35)) { toggle?(item.id) }
                } label: {
                    HStack(spacing: 8) {
                        CheckDoodle(isDone: item.isDone, ink: ink)
                        hand.text(item.text, 16)
                            .strikethrough(item.isDone, color: ink.opacity(0.6))
                            .opacity(item.isDone ? 0.5 : 1)
                            .lineLimit(1)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(toggle == nil)
                .accessibilityAddTraits(item.isDone ? .isSelected : [])
            }
        }
    }
}

/// A pen-drawn box; ticking draws the check stroke in.
struct CheckDoodle: View {
    let isDone: Bool
    let ink: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                .stroke(ink.opacity(0.55), lineWidth: 1.3)
                .frame(width: 13, height: 13)
                .rotationEffect(.degrees(-3))
            Path { p in
                p.move(to: CGPoint(x: 2, y: 8))
                p.addQuadCurve(to: CGPoint(x: 6, y: 13), control: CGPoint(x: 4, y: 11))
                p.addQuadCurve(to: CGPoint(x: 17, y: -1), control: CGPoint(x: 9, y: 5))
            }
            .trim(from: 0, to: isDone ? 1 : 0)
            .stroke(ink, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            .frame(width: 16, height: 14)
            .offset(x: 2, y: -1)
            .animation(.easeOut(duration: 0.28), value: isDone)
        }
        .frame(width: 16, height: 16)
    }
}

private struct MoneyLines: View {
    let kind: StickyKind
    let money: MoneyInfo
    let hand: Hand
    let isArabic: Bool
    @Environment(\.kraftFormat) private var format

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(format.money(money.isSettled || kind == .bill ? money.amount : money.remaining, money.currency, arabic: isArabic))
                .font(Hand.amount(28))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if kind != .bill, money.paid > 0, !money.isSettled {
                let line = String(localized: "of \(format.money(money.amount, money.currency, arabic: isArabic)) · \(format.money(money.paid, money.currency, arabic: isArabic)) back")
                Hand(text: line, style: hand.style).text(line, 13)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .opacity(0.7)
                PencilProgress(progress: money.progress)
                    .padding(.top, 3)
            }
        }
    }
}

/// Progress drawn like a pencil line over a faint guide.
struct PencilProgress: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.1)).frame(height: 3)
                Capsule().fill(.primary.opacity(0.65)).frame(width: geo.size.width * progress, height: 3)
            }
        }
        .frame(height: 3)
        .frame(maxWidth: 120)
    }
}
