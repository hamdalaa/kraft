import KraftCore
import Observation
import SwiftUI

/// Board UI state. Data lives in `StickyStore`.
@MainActor
@Observable
final class BoardModel {
    let store: StickyStore
    var tab: BoardTab = .all
    /// The sticky open in the editor, if any.
    var editingID: Sticky.ID?
    var isQuickAddPresented = false

    init(store: StickyStore) { self.store = store }

    var stickies: [Sticky] { store.stickies }
    var visible: [Sticky] { tab.filter(stickies) }
    func count(_ tab: BoardTab) -> Int { tab.filter(stickies).count }

    /// Thrown away in the last 30 days, newest first (tombstones the bin can put back).
    var recentlyThrown: [Sticky] {
        let cutoff = Date().addingTimeInterval(-30 * 86_400)
        return stickies.filter { ($0.deletedAt ?? .distantPast) > cutoff }.sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }
    }

    func restore(_ id: Sticky.ID) {
        guard var s = store.sticky(id) else { return }
        s.deletedAt = nil
        withAnimation(.spring(duration: 0.5, bounce: 0.2)) { store.update(s, actionName: String(localized: "Put Back")) }
    }

    func open(_ id: Sticky.ID) {
        withAnimation(.spring(duration: 0.45, bounce: 0.18)) { editingID = id }
    }

    func closeEditor() {
        withAnimation(.spring(duration: 0.4, bounce: 0.12)) { editingID = nil }
    }

    /// Open money totals per currency, for the header chips.
    func openTotal(_ kind: StickyKind, _ currency: Currency) -> Decimal {
        BoardTab.all.filter(stickies)
            .filter { $0.kind == kind }
            .compactMap(\.money)
            .filter { $0.currency == currency }
            .reduce(0) { $0 + $1.remaining }
    }
}

struct BoardScreen: View {
    @Bindable var model: BoardModel
    /// Snapshot mode renders without a ScrollView (ImageRenderer cannot draw scroll views).
    var scrolls = true
    @Namespace private var stickyNamespace
    @Environment(\.undoManager) private var undoManager
    @Environment(\.kraftFormat) private var format
    @State private var thrower = ThrowController()

    var body: some View {
        content
            .overlay { ThrowLayer() }
            .coordinateSpace(.named(BoardSpace.name))
            .environment(thrower)
            .overlay { StickyEditorHost(model: model, namespace: stickyNamespace) }
            .sheet(isPresented: $model.isQuickAddPresented) {
                QuickAddView(store: model.store) { model.isQuickAddPresented = false }
            }
            .onAppear { model.store.undoManager = undoManager }
            .onChange(of: undoManager) { model.store.undoManager = undoManager }
    }

    private var content: some View {
        ZStack {
            PageBackground()
            VStack(spacing: 0) {
                HStack(alignment: .bottom, spacing: 0) {
                    FolderTabs(selection: model.tab, count: model.count) { tab in
                        withAnimation(.spring(duration: 0.35)) { model.tab = tab }
                    }
                    Spacer(minLength: 16)
                    Button { model.isQuickAddPresented = true } label: {
                        EmbossedLabel(text: String(localized: "New Sticky"), symbol: "plus", tint: .blue, size: .regular)
                    }
                    .buttonStyle(GlossyButtonStyle(tint: .blue))
                    .help("New Sticky (⌘N)")
                    .padding(.bottom, 9)
                }
                .padding(.horizontal, 18)
                .zIndex(1)

                BoardSurface {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        stickies
                    }
                    .overlay(alignment: .bottomTrailing) {
                        WasteBinControl(model: model).padding(.trailing, 30).padding(.bottom, 26)
                    }
                }
            }
            .padding(.top, 40)
            .padding([.horizontal, .bottom], Tok.Space.page)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 18) {
                    Text(model.tab.heading)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Tok.Kraft.ink.opacity(0.92))
                        .shadow(color: .white.opacity(0.3), radius: 0, y: 1)
                        .contentTransition(.opacity)
                    DateLabel(date: Date())
                }
                Text(summary)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Tok.Kraft.ink.opacity(0.72))
            }
            Spacer()
            HStack(spacing: 10) {
                let owed = model.openTotal(.owedToMe, .usd)
                if owed > 0 {
                    GlossyTag(text: String(localized: "Owed to you  \(format.money(owed, .usd))"),
                              symbol: format.symbol("arrow.down.left"), tint: .mint, size: .regular)
                }
                let owe = model.openTotal(.iOwe, .iqd)
                if owe > 0 {
                    GlossyTag(text: String(localized: "You owe  \(format.money(owe, .iqd))"),
                              symbol: format.symbol("arrow.up.right"), tint: .pink, size: .regular)
                }
                let today = model.count(.today)
                if today > 0 { GlossyTag(text: String(localized: "Due today  \(format.number(today))"), symbol: "sun.max.fill", tint: .amber, size: .regular) }
            }
        }
        .padding(.horizontal, Tok.Space.board)
        .padding(.top, 24)
        .padding(.bottom, 8)
    }

    private var summary: String { Plural.string("count.stickies", model.visible.count, format) }

    @ViewBuilder private var stickies: some View {
        if model.visible.isEmpty {
            EmptyBoard(tab: model.tab) { model.isQuickAddPresented = true }
                .id(model.tab)
                .transition(.opacity)
            Spacer(minLength: 0)
        } else if scrolls {
            ScrollView { collage }.scrollIndicators(.automatic)
        } else {
            collage
            Spacer(minLength: 0)
        }
    }

    private var collage: some View {
        CollageLayout {
            ForEach(Array(model.visible.enumerated()), id: \.element.id) { index, sticky in
                HoverableSticky(sticky: sticky, order: index, delete: { model.store.delete($0) }) { item in
                    model.store.toggleChecklistItem(item, in: sticky.id)
                }
                    .matchedGeometryEffect(id: sticky.id, in: stickyNamespace, isSource: model.editingID != sticky.id)
                    .opacity(model.editingID == sticky.id || thrower.isCarrying(sticky.id) ? 0 : 1)
                    .onTapGesture { model.open(sticky.id) }
                    // VoiceOver: a sticky is a button that opens it; throwing away has its own action.
                    .accessibilityLabel(Text(verbatim: sticky.primaryText))
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { model.open(sticky.id) }
                    .accessibilityAction(named: Text("Open Sticky")) { model.open(sticky.id) }
                    .accessibilityAction(named: Text("Throw Away")) {
                        withAnimation(.spring(duration: 0.5, bounce: 0.2)) { model.store.delete(sticky.id) }
                    }
                    .contextMenu { DesktopPinButton(sticky: sticky, store: model.store) }
                    .transition(.opacity)
            }
        }
        .id(model.tab)
        .padding(.horizontal, Tok.Space.board + 8)
        .padding(.top, 34)
        .padding(.bottom, 44)
    }
}

/// A sticky on the board: pressed on when it appears, tilts toward the pointer in 3D while hovered.
private struct HoverableSticky: View {
    let sticky: Sticky
    let order: Int
    let delete: (Sticky.ID) -> Void
    let toggleItem: (ChecklistItem.ID) -> Void

    @State private var pointer: CGPoint?
    @State private var frame: CGRect = .zero
    @Environment(ThrowController.self) private var thrower
    @State private var placed = !Motion.enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let inset: CGFloat = 14

    var body: some View {
        let box = sticky.style.size.side + Self.inset * 2
        let tilt = tilt(in: box)
        StickyCard(sticky: sticky, lifted: pointer != nil || !placed, toggleItem: toggleItem)
            .rotation3DEffect(.degrees(tilt.angle), axis: (x: tilt.x, y: tilt.y, z: 0), perspective: 0.45)
            .padding(Self.inset)
            .contentShape(Rectangle())
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(BoardSpace.name)) } action: { frame = $0 }
            .throwable(sticky, frame: frame, thrower: thrower, reduceMotion: reduceMotion, delete: delete)
            .onContinuousHover { phase in
                switch phase {
                case .active(let location): pointer = location
                case .ended: pointer = nil
                }
            }
            .pointerStyle(.link)
            // Press-on: dropped from just above the board with a slight spin, then settles.
            .scaleEffect(placed ? 1 : 1.16)
            .rotationEffect(.degrees(placed ? 0 : (order.isMultiple(of: 2) ? -7 : 6)))
            .offset(y: placed ? 0 : -26)
            .opacity(placed ? 1 : 0)
            .animation(.spring(duration: 0.4, bounce: 0.2), value: pointer)
            .zIndex(pointer != nil ? 1 : 0)
            .onAppear {
                guard !placed else { return }
                if reduceMotion { placed = true; return }
                withAnimation(.spring(duration: 0.55, bounce: 0.3).delay(0.05 + Double(order) * 0.065)) { placed = true }
            }
    }

    /// Up to 7° toward the pointer; none with Reduce Motion.
    private func tilt(in box: CGFloat) -> (angle: Double, x: CGFloat, y: CGFloat) {
        guard let pointer, !reduceMotion else { return (0, 0, 1) }
        let dx = pointer.x / box - 0.5, dy = pointer.y / box - 0.5
        let strength = min(1, hypot(dx, dy) * 2)
        return (7 * strength, -dy, dx)
    }
}

/// Today's date, handwritten on a scrap of paper taped to the kraft.
private struct DateLabel: View {
    let date: Date
    @Environment(\.kraftFormat) private var format

    var body: some View {
        let text = format.longDay(date)
        Hand(text: text).text(text, 15)
            .foregroundStyle(InkColor.graphite.color.opacity(0.85))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background {
                PaperSurface(color: PaperColor.white.color(customHex: nil), ruling: .none)
            }
            .overlay(alignment: .leading) {
                WashiTape(tint: Tok.Sticker.lime).scaleEffect(0.5).rotationEffect(.degrees(-68)).offset(x: -26)
            }
            .rotationEffect(.degrees(-2.5))
    }
}

/// Loose stickers pressed onto the kraft, like the collaged objects in ref-8. Purely decorative.
private struct BoardProps: View {
    var body: some View {
        ZStack {
            DieCutSticker(art: StickerArt(symbol: "sparkle", fill: Tok.Sticker.lime), size: 26, tilt: .degrees(-12))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.leading, 30).padding(.bottom, 26)
            DieCutSticker(art: StickerArt(symbol: "heart", fill: Tok.Sticker.pink), size: 18, tilt: .degrees(14))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.leading, 82).padding(.bottom, 20)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Warm off-white page with faint grain.
struct PageBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Tok.Page.hi, Tok.Page.base], startPoint: .top, endPoint: .bottom)
            GrainOverlay(image: Grain.paper, opacity: 0.18).blendMode(.multiply)
        }
        .compositingGroup()
        .ignoresSafeArea()
    }
}

/// Kraft board with a grid sheet tucked behind it (ref-8).
struct BoardSurface<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background {
                ZStack {
                    shape.fill(LinearGradient(stops: [
                        .init(color: Tok.Kraft.light, location: 0),
                        .init(color: Tok.Kraft.base, location: 0.45),
                        .init(color: Tok.Kraft.base.mix(with: Tok.Kraft.deep, by: 0.25), location: 1),
                    ], startPoint: .top, endPoint: .bottom))
                    GrainOverlay(image: Grain.kraft, opacity: 0.5).blendMode(.multiply).clipShape(shape)
                    // Warm desk-lamp light from the top-left, falling off into a soft vignette.
                    shape.fill(RadialGradient(colors: [Color(hex: 0xFFEBC8).opacity(0.22), .clear],
                                              center: UnitPoint(x: 0.18, y: -0.05), startRadius: 20, endRadius: 820))
                    shape.fill(EllipticalGradient(colors: [.clear, Tok.Kraft.ink.opacity(0.16)], center: .center,
                                                  startRadiusFraction: 0.55, endRadiusFraction: 0.95))
                    shape.strokeBorder(Tok.Kraft.deep.opacity(0.7), lineWidth: 1)
                    BoardProps()
                }
                .compositingGroup()
                .shadow(color: .black.opacity(0.16), radius: 1, y: 1)
                .shadow(color: Tok.Kraft.ink.opacity(0.16), radius: 18, y: 10)
            }
            .background(alignment: .topTrailing) {
                GridSheet()
                    .frame(width: 420, height: 300)
                    .rotationEffect(.degrees(2.2))
                    .offset(x: 10, y: -16)
            }
            .clipShape(Rectangle().inset(by: -60))
    }
}

private struct GridSheet: View {
    var body: some View {
        Rectangle()
            .fill(Tok.Grid.paper)
            .overlay {
                Canvas { ctx, size in
                    var p = Path()
                    var v: CGFloat = 12
                    while v < max(size.width, size.height) {
                        p.move(to: CGPoint(x: v, y: 0)); p.addLine(to: CGPoint(x: v, y: size.height))
                        p.move(to: CGPoint(x: 0, y: v)); p.addLine(to: CGPoint(x: size.width, y: v))
                        v += 12
                    }
                    ctx.stroke(p, with: .color(Tok.Grid.line.opacity(0.8)), lineWidth: 0.6)
                }
            }
            .overlay { Rectangle().strokeBorder(Tok.Grid.line, lineWidth: 0.5) }
            .shadow(color: .black.opacity(0.08), radius: 3, y: 2)
    }
}
