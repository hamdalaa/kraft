import SwiftUI

/// Die-cut sticker (ref-6 / ref-7): bold ink glyph on a colour blob that follows its silhouette,
/// a white die-cut border, and a soft offset shadow. The blob and border are built by dilating the
/// glyph (stamping copies around a circle), so any SF Symbol becomes a sticker.
struct DieCutSticker: View {
    let art: StickerArt
    var size: CGFloat = 22
    var tilt: Angle = .degrees(-8)

    var body: some View {
        let glyph = Image(systemName: art.symbol).font(.system(size: size, weight: .bold))
        ZStack {
            Dilated(content: glyph, color: .white, radius: size * 0.34)
            Dilated(content: glyph, color: art.fill, radius: size * 0.2)
            glyph.foregroundStyle(Tok.Sticker.ink)
        }
        .padding(size * 0.4)
        .drawingGroup()
        .shadow(color: Tok.Sticker.ink.opacity(0.22), radius: 0.6, x: size * 0.07, y: size * 0.11)
        .shadow(color: .black.opacity(0.10), radius: size * 0.15, y: size * 0.08)
        .rotationEffect(tilt)
        .accessibilityHidden(true)
    }
}

private struct Dilated<Content: View>: View {
    let content: Content
    let color: Color
    let radius: CGFloat

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { ring in
                let r = radius * [1, 0.66, 0.33][ring]
                ForEach(0..<32, id: \.self) { i in
                    let a = Double(i) / 32 * 2 * .pi
                    content
                        .foregroundStyle(color)
                        .offset(x: cos(a) * r, y: sin(a) * r)
                }
            }
        }
    }
}
