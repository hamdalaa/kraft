import SwiftUI

/// Glossy, embossed pastel tag (ref-5). Used for buttons, filters and chips.
struct TagTint: Sendable {
    let top: Color
    let bottom: Color
    let edge: Color
    let ink: Color

    static let blue = TagTint(top: Color(hex: 0xDCEFFE), bottom: Color(hex: 0xCFE9FF), edge: Color(hex: 0x93C3F3), ink: Color(hex: 0x5390E0))
    static let lime = TagTint(top: Color(hex: 0xEEFF8D), bottom: Color(hex: 0xE4F86A), edge: Color(hex: 0xC4D698), ink: Color(hex: 0x7A9D0F))
    static let mint = TagTint(top: Color(hex: 0xD7FCDD), bottom: Color(hex: 0xC6F5CE), edge: Color(hex: 0xA3E3AF), ink: Color(hex: 0x27A274))
    static let pink = TagTint(top: Color(hex: 0xFFE3EE), bottom: Color(hex: 0xFFD3E3), edge: Color(hex: 0xF2A7C3), ink: Color(hex: 0xD4497F))
    static let amber = TagTint(top: Color(hex: 0xFFF2CC), bottom: Color(hex: 0xFFE7A6), edge: Color(hex: 0xE8C774), ink: Color(hex: 0xB07C12))
}

enum TagSize {
    case mini, regular

    var height: CGFloat { self == .mini ? 22 : 30 }
    var font: CGFloat { self == .mini ? 11 : 13 }
    var padding: CGFloat { self == .mini ? 8 : 12 }
}

struct GlossyTagBackground: View {
    let tint: TagTint
    let height: CGFloat
    var pressed = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: height * 0.28, style: .continuous)
        shape
            .fill(LinearGradient(colors: [tint.top, tint.bottom], startPoint: .top, endPoint: .bottom))
            .overlay {
                // Soft sheen on the upper half.
                shape.fill(LinearGradient(stops: [
                    .init(color: .white.opacity(0.45), location: 0),
                    .init(color: .white.opacity(0), location: 0.5),
                ], startPoint: .top, endPoint: .bottom))
            }
            .overlay { shape.strokeBorder(tint.edge, lineWidth: 1) }
            .overlay {
                // Inner bevel: bright top lip, faint shade at the bottom lip.
                shape.inset(by: 1).strokeBorder(LinearGradient(stops: [
                    .init(color: .white.opacity(0.95), location: 0),
                    .init(color: .white.opacity(0), location: 0.45),
                    .init(color: tint.edge.opacity(0), location: 0.7),
                    .init(color: tint.edge.opacity(0.55), location: 1),
                ], startPoint: .top, endPoint: .bottom), lineWidth: 1.2)
            }
            .brightness(pressed ? -0.04 : 0)
            .shadow(color: tint.edge.opacity(0.5), radius: 0, y: pressed ? 0.5 : 1.5)
            .shadow(color: .black.opacity(pressed ? 0.06 : 0.10), radius: pressed ? 3 : 6, y: pressed ? 2 : 4)
    }
}

/// Same-hue embossed label: ink with a 1 pt white highlight under it.
struct EmbossedLabel: View {
    let text: String
    var symbol: String?
    let tint: TagTint
    let size: TagSize

    var body: some View {
        HStack(spacing: size == .mini ? 4 : 6) {
            if let symbol {
                Image(systemName: symbol).font(.system(size: size.font, weight: .bold))
            }
            Text(text).font(.system(size: size.font, weight: .semibold))
        }
        .foregroundStyle(LinearGradient(colors: [tint.ink.mix(with: .black, by: 0.08), tint.ink], startPoint: .top, endPoint: .bottom))
        .shadow(color: .white.opacity(0.9), radius: 0, y: 1)
        .lineLimit(1)
    }
}

struct GlossyTag: View {
    let text: String
    var symbol: String?
    var tint: TagTint = .blue
    var size: TagSize = .regular

    var body: some View {
        EmbossedLabel(text: text, symbol: symbol, tint: tint, size: size)
            .padding(.horizontal, size.padding)
            .frame(height: size.height)
            .background(GlossyTagBackground(tint: tint, height: size.height))
    }
}

struct GlossyButtonStyle: ButtonStyle {
    var tint: TagTint = .blue
    var size: TagSize = .regular

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, size.padding)
            .frame(height: size.height)
            .background(GlossyTagBackground(tint: tint, height: size.height, pressed: configuration.isPressed))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}
