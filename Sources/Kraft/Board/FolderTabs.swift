import KraftCore
import SwiftUI

/// Folder-divider tab (ref-8). `flare` adds the outward fillets that let the active tab
/// melt into the board; `closed: false` returns only the sides and top, for the outline.
struct FolderTabShape: Shape {
    var slant: CGFloat = 8
    var radius: CGFloat = 9
    var flare: CGFloat = 0
    var closed = true

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: flare, dy: 0)
        var p = Path()
        p.move(to: CGPoint(x: r.minX - flare, y: r.maxY))
        if flare > 0 {
            p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - flare), control: CGPoint(x: r.minX, y: r.maxY))
        }
        p.addLine(to: CGPoint(x: r.minX + slant, y: r.minY + radius))
        p.addQuadCurve(to: CGPoint(x: r.minX + slant + radius, y: r.minY), control: CGPoint(x: r.minX + slant + 1, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - slant - radius, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX - slant, y: r.minY + radius), control: CGPoint(x: r.maxX - slant - 1, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - flare))
        if flare > 0 {
            p.addQuadCurve(to: CGPoint(x: r.maxX + flare, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
        }
        if closed { p.closeSubpath() }
        return p
    }
}

struct FolderTabs: View {
    let selection: BoardTab
    let count: (BoardTab) -> Int
    let select: (BoardTab) -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(BoardTab.allCases) { tab in
                FolderTabButton(tab: tab, count: count(tab), isActive: tab == selection) { select(tab) }
                    .zIndex(tab == selection ? 1 : 0)
            }
        }
    }
}

private struct FolderTabButton: View {
    let tab: BoardTab
    let count: Int
    let isActive: Bool
    let action: () -> Void
    @State private var hovering = false

    private static let flare: CGFloat = 9

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                DieCutSticker(art: tab.sticker, size: 10, tilt: .degrees(hovering ? 8 : -8))
                    .scaleEffect(hovering ? 1.15 : 1)
                    .padding(-2)
                    .animation(.spring(duration: 0.35, bounce: 0.5), value: hovering)
                Text(tab.title)
                    .font(.system(size: 13, weight: .semibold))
                if count > 0 {
                    Text(count, format: .number)
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .opacity(0.6)
                }
            }
            .foregroundStyle(Tok.Kraft.ink.opacity(isActive ? 1 : 0.78))
            .shadow(color: .white.opacity(isActive ? 0.32 : 0.2), radius: 0, y: 1)
            .padding(.leading, 12)
            .padding(.trailing, 16)
            .frame(height: isActive ? 38 : 33)
            .padding(.bottom, isActive ? 0 : 1)
            .background(alignment: .bottom) { background }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .pointerStyle(.link)
        .offset(y: isActive ? 2 : (hovering ? -2 : 0))
        .animation(.spring(duration: 0.25), value: hovering)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    @ViewBuilder private var background: some View {
        if isActive {
            ZStack {
                FolderTabShape(flare: Self.flare).fill(Tok.Kraft.light)
                GrainOverlay(image: Grain.kraft, opacity: 0.5).blendMode(.multiply).clipShape(FolderTabShape(flare: Self.flare))
                FolderTabShape(flare: Self.flare, closed: false).stroke(Tok.Kraft.deep.opacity(0.7), lineWidth: 1)
                FolderTabShape(flare: Self.flare, closed: false)
                    .stroke(.white.opacity(0.28), lineWidth: 1)
                    .offset(y: 1)
                    .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .bottom))
            }
            .padding(.horizontal, -Self.flare)
            .padding(.bottom, -2)
        } else {
            ZStack {
                FolderTabShape().fill(LinearGradient(colors: [Tok.Kraft.tabTop, Tok.Kraft.tabBottom], startPoint: .top, endPoint: .bottom))
                GrainOverlay(image: Grain.kraft, opacity: 0.45).blendMode(.multiply).clipShape(FolderTabShape())
                FolderTabShape(closed: false).stroke(Tok.Kraft.deep.opacity(0.8), lineWidth: 1)
                // Shade where the tab tucks behind the front folder.
                LinearGradient(colors: [.black.opacity(0), .black.opacity(0.12)], startPoint: .center, endPoint: .bottom)
                    .clipShape(FolderTabShape())
            }
            .brightness(hovering ? 0.03 : 0)
        }
    }
}
