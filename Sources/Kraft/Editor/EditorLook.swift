import AppKit
import KraftCore
import SwiftUI

/// Paper colour swatches, cut like tiny sticky notes, plus a rainbow swatch for a custom colour.
struct EditorSwatches: View {
    let style: PaperStyle
    let edit: StickyEditing
    var side: CGFloat = 22

    var body: some View {
        HStack(spacing: side * 0.32) {
            ForEach(PaperColor.allCases.filter { $0 != .custom }, id: \.self) { color in
                Button { set(color) } label: {
                    swatch(color.color(customHex: nil), isOn: style.color == color)
                }
                .buttonStyle(.plain)
                .help(Text(color.title))
            }
            custom
        }
    }

    private func swatch(_ fill: Color, isOn: Bool) -> some View {
        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
            .fill(fill)
            .overlay { RoundedRectangle(cornerRadius: 2.5, style: .continuous).strokeBorder(.black.opacity(0.08), lineWidth: 0.5) }
            .frame(width: side, height: side)
            .shadow(color: .black.opacity(0.18), radius: isOn ? 3 : 1, y: isOn ? 2.5 : 1)
            .overlay {
                if isOn {
                    Image(systemName: "checkmark").font(.system(size: side * 0.45, weight: .heavy)).foregroundStyle(Tok.Sticker.ink.opacity(0.7))
                }
            }
            .scaleEffect(isOn ? 1.12 : 1)
            .rotationEffect(.degrees(isOn ? -6 : 0))
            .animation(.spring(duration: 0.3), value: isOn)
    }

    /// The custom swatch shows the chosen colour once there is one; the native colour panel sits invisibly on top.
    private var custom: some View {
        let chosen = style.customHex.flatMap { Color(hexString: $0) }
        return ZStack {
            if let chosen, style.color == .custom {
                swatch(chosen, isOn: true)
            } else {
                Circle()
                    .fill(AngularGradient(colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink, .red], center: .center))
                    .overlay { Circle().fill(.white.opacity(0.35)) }
                    .frame(width: side * 0.9, height: side * 0.9)
                    .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
            }
            ColorPicker("", selection: customColor, supportsOpacity: false)
                .labelsHidden()
                .opacity(0.02)
                .frame(width: side, height: side)
                .clipped()
        }
        .frame(width: side, height: side)
        .help(Text("Custom colour"))
    }

    private var customColor: Binding<Color> {
        Binding(
            get: { style.customHex.flatMap { Color(hexString: $0) } ?? PaperColor.lemon.color(customHex: nil) },
            set: { color in
                guard let hex = EditorHex.string(color) else { return }
                edit.change(String(localized: "Change Paper"), coalesce: true) {
                    $0.style.color = .custom
                    $0.style.customHex = hex
                }
            }
        )
    }

    private func set(_ color: PaperColor) {
        withAnimation(.spring(duration: 0.3)) { edit.change(String(localized: "Change Paper")) { $0.style.color = color } }
    }
}

enum EditorHex {
    /// `#RRGGBB` in sRGB.
    static func string(_ color: Color) -> String? {
        guard let c = NSColor(color).usingColorSpace(.sRGB) else { return nil }
        func byte(_ v: CGFloat) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(c.redComponent), byte(c.greenComponent), byte(c.blueComponent))
    }
}

/// Everything about how the paper looks. Each change lands on the editor paper and the board card at once.
struct EditorLookPanel: View {
    let sticky: Sticky
    let edit: StickyEditing

    private var style: PaperStyle { sticky.style }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            row("Paper") { EditorSwatches(style: style, edit: edit, side: 24) }
            row("Handwriting") {
                HStack(spacing: 8) {
                    ForEach(Handwriting.allCases, id: \.self) { h in
                        tile(isOn: style.handwriting == h, width: 76, label: handwritingTitle(h)) {
                            set("Change Handwriting") { $0.handwriting = h }
                        } content: {
                            handwritingSample(h)
                        }
                    }
                }
            }
            HStack(alignment: .top, spacing: 18) {
                row("Size") {
                    HStack(spacing: 5) {
                        ForEach(StickySize.allCases, id: \.self) { s in
                            EditorChip(sizeTitle(s), isOn: style.size == s, size: .regular) { set("Change Size") { $0.size = s } }
                        }
                    }
                }
                row("Ink") {
                    HStack(spacing: 7) {
                        ForEach(InkColor.allCases, id: \.self) { ink in
                            Button { set("Change Ink") { $0.ink = ink } } label: { inkDot(ink, isOn: style.ink == ink) }
                                .buttonStyle(.plain)
                                .help(Text(ink.title))
                        }
                    }
                    .frame(height: 30)
                }
            }
            row("Ruling") {
                HStack(spacing: 8) {
                    ForEach(Ruling.allCases, id: \.self) { r in
                        tile(isOn: style.ruling == r, width: 56, label: rulingTitle(r)) { set("Change Ruling") { $0.ruling = r } } content: {
                            RulingView(ruling: r).frame(width: 100, height: 64).scaleEffect(0.6).frame(width: 56, height: 36).clipped()
                        }
                    }
                }
            }
            row("Fastener") {
                HStack(spacing: 8) {
                    ForEach(Fastener.allCases, id: \.self) { f in
                        tile(isOn: style.fastener == f, width: 56, label: fastenerTitle(f)) { set("Change Fastener") { $0.fastener = f } } content: {
                            fastenerSample(f)
                        }
                    }
                }
            }
            row("Tilt") {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 2).fill(style.color.color(customHex: style.customHex))
                        .frame(width: 18, height: 18)
                        .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
                        .rotationEffect(.degrees(style.tilt * 3))
                    Slider(value: Binding(get: { style.tilt }, set: { v in
                        edit.change(String(localized: "Change Tilt"), coalesce: true) { $0.style.tilt = (v * 2).rounded() / 2 }
                    }), in: -4...4)
                    .tint(Tok.Kraft.base)
                    EditorChip("Straight", isOn: style.tilt == 0, tint: .amber) { set("Change Tilt") { $0.tilt = 0 } }
                }
            }
        }
        .padding(18)
        .frame(width: 344)
    }

    private func set(_ actionName: String.LocalizationValue, _ body: @escaping (inout PaperStyle) -> Void) {
        withAnimation(.spring(duration: 0.35)) {
            edit.change(String(localized: actionName)) { body(&$0.style) }
        }
    }

    private func row(_ title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            EditorLabel(title)
            content()
        }
    }

    /// A small paper tile with a caption, raised when chosen.
    private func tile(isOn: Bool, width: CGFloat, label: LocalizedStringKey, action: @escaping () -> Void,
                      @ViewBuilder content: () -> some View) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack { content() }
                    .frame(width: width, height: 36)
                    .background(style.color.color(customHex: style.customHex), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(isOn ? TagTint.blue.ink : .black.opacity(0.08), lineWidth: isOn ? 2 : 0.5)
                    }
                    .shadow(color: .black.opacity(isOn ? 0.16 : 0.08), radius: isOn ? 3 : 1, y: isOn ? 2 : 1)
                Text(label)
                    .font(.system(size: 10.5, weight: isOn ? .semibold : .medium))
                    .foregroundStyle(isOn ? TagTint.blue.ink : Tok.Kraft.ink.opacity(0.7))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func inkDot(_ ink: InkColor, isOn: Bool) -> some View {
        Circle()
            .fill(RadialGradient(colors: [ink.color.mix(with: .white, by: 0.35), ink.color], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 12))
            .frame(width: 20, height: 20)
            .overlay { Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1) }
            .padding(3)
            .overlay { if isOn { Circle().strokeBorder(ink.color.opacity(0.55), lineWidth: 1.5) } }
            .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
    }

    @ViewBuilder private func handwritingSample(_ h: Handwriting) -> some View {
        let ink = style.ink.color
        switch h {
        case .auto:
            HStack(spacing: 3) {
                Text(verbatim: "Aa").font(.custom(FontRegistry.playpen, fixedSize: 14))
                Text(verbatim: "أب").font(FontRegistry.hasMolhim ? .custom(FontRegistry.molhim, fixedSize: 18) : .custom(FontRegistry.playpen, fixedSize: 14))
            }
            .foregroundStyle(ink)
        case .playpen:
            Text(verbatim: "Aa أب").font(.custom(FontRegistry.playpen, fixedSize: 14)).foregroundStyle(ink)
        case .molhim:
            Text(verbatim: "أبجد").font(FontRegistry.hasMolhim ? .custom(FontRegistry.molhim, fixedSize: 18) : .custom(FontRegistry.playpen, fixedSize: 14))
                .foregroundStyle(ink)
        }
    }

    @ViewBuilder private func fastenerSample(_ f: Fastener) -> some View {
        switch f {
        case .none: Image(systemName: "circle.slash").font(.system(size: 13, weight: .medium)).foregroundStyle(Tok.Kraft.ink.opacity(0.4))
        case .tape: WashiTape().scaleEffect(0.55).rotationEffect(.degrees(-6))
        case .pin: PushPin()
        case .clip: PaperClip().scaleEffect(0.6).rotationEffect(.degrees(-60))
        }
    }

    private func handwritingTitle(_ h: Handwriting) -> LocalizedStringKey {
        switch h {
        case .auto: "Auto"
        case .playpen: "Playpen"
        case .molhim: "Molhim"
        }
    }

    private func sizeTitle(_ s: StickySize) -> LocalizedStringResource {
        switch s {
        case .small: "S"
        case .medium: "M"
        case .large: "L"
        }
    }

    private func rulingTitle(_ r: Ruling) -> LocalizedStringKey {
        switch r {
        case .none: "Plain"
        case .lines: "Lines"
        case .grid: "Grid"
        case .dots: "Dots"
        }
    }

    private func fastenerTitle(_ f: Fastener) -> LocalizedStringKey {
        switch f {
        case .none: "None"
        case .tape: "Tape"
        case .pin: "Pin"
        case .clip: "Clip"
        }
    }
}
