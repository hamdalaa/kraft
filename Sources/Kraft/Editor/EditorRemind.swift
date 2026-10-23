import AppKit
import KraftCore
import SwiftUI

/// "Remind them": a polite message in English or Arabic, ready to copy or send through WhatsApp.
/// Starts in the note's language; the text stays editable before it goes out.
struct EditorRemindPopover: View {
    let sticky: Sticky

    @State private var language: MessageLanguage
    @State private var digits: DigitStyle
    @State private var text: String
    @State private var copied = false

    init(sticky: Sticky) {
        self.sticky = sticky
        let language = MessageLanguage.of(sticky.primaryText)
        // Starts in the owner's digit choice (Western by default); the chips switch it for this message only.
        let digits = AppPreferences.shared.digits
        _language = State(initialValue: language)
        _digits = State(initialValue: digits)
        _text = State(initialValue: Self.message(for: sticky, language: language, digits: digits))
    }

    private var generated: String { Self.message(for: sticky, language: language, digits: digits) }

    private static func message(for sticky: Sticky, language: MessageLanguage, digits: DigitStyle) -> String {
        guard let money = sticky.money else { return "" }
        return RemindMessage.text(for: money, kind: sticky.kind, language: language, digits: digits)
    }

    private var direction: LayoutDirection { language == .arabic ? .rightToLeft : .leftToRight }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                EditorLabel(sticky.kind == .owedToMe ? "Remind them" : "Message them")
                Spacer()
                EditorChip("English", isOn: language == .english, tint: .mint) { language = .english } // not localized
                EditorChip("عربي", isOn: language == .arabic, tint: .mint) { language = .arabic } // not localized
            }
            message
            HStack(spacing: 8) {
                if language == .arabic {
                    EditorChip("١٢٣", isOn: digits == .arabic, tint: .amber) { digits = .arabic } // not localized
                        .help(Text("Arabic digits"))
                    EditorChip("123", isOn: digits == .western, tint: .amber) { digits = .western } // not localized
                        .help(Text("Western digits"))
                }
                Spacer()
                Button(action: copy) {
                    EmbossedLabel(text: String(localized: copied ? "Copied" : "Copy"), symbol: copied ? "checkmark" : "doc.on.doc",
                                  tint: .blue, size: .regular)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(GlossyButtonStyle(tint: .blue))
                .keyboardShortcut("c", modifiers: [.command, .shift])
                Button(action: openWhatsApp) {
                    EmbossedLabel(text: String(localized: "WhatsApp"), symbol: "paperplane.fill", tint: .mint, size: .regular)
                }
                .buttonStyle(GlossyButtonStyle(tint: .mint))
                .help(Text("Open in WhatsApp"))
            }
        }
        .padding(16)
        .frame(width: 360)
        .onChange(of: language) { text = generated }
        .onChange(of: digits) { text = generated }
    }

    /// The message on a slip of writing paper.
    private var message: some View {
        TextEditor(text: $text)
            .font(.system(size: 14))
            .lineSpacing(3)
            .scrollContentBackground(.hidden)
            .foregroundStyle(InkColor.graphite.color)
            .environment(\.layoutDirection, direction)
            .padding(10)
            .frame(height: 132)
            .background {
                let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
                shape.fill(PaperColor.white.color(customHex: nil))
                    .overlay { GrainOverlay(image: Grain.paper, opacity: 0.3).blendMode(.multiply).clipShape(shape) }
                    .overlay { shape.strokeBorder(Color(hex: 0xE6D7BC), lineWidth: 1) }
                    .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
            }
            .accessibilityLabel(Text("Message"))
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        withAnimation(.spring(duration: 0.25)) { copied = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.spring(duration: 0.25)) { copied = false }
        }
    }

    private func openWhatsApp() {
        guard let url = WhatsAppLink.url(text: text) else { return }
        NSWorkspace.shared.open(url)
    }
}
