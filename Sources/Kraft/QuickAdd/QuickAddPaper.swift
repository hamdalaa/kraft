import KraftCore
import SwiftUI

/// Notepad leaf behind the quick-add line: warm page, fine grain, a pink margin rule.
struct NotepadPaper: View {
    var marginX: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Tok.Card.top, Tok.Card.bottom], startPoint: .top, endPoint: .bottom)
            GrainOverlay(image: Grain.paper, opacity: 0.32).surfaceGrain()
            HStack(spacing: 2.5) {
                Rectangle().frame(width: 1)
                Rectangle().frame(width: 0.6)
            }
            .foregroundStyle(TagTint.pink.edge.opacity(0.6))
            .padding(.leading, marginX - 4)
            // Top lip catching the light.
            Rectangle().fill(Tok.Light.edge.opacity(0.85)).frame(height: 1)
        }
    }
}

/// Strip of kraft board holding a live preview of the sticky being written.
struct PreviewStrip: View {
    let sticky: Sticky
    let isBlank: Bool

    var body: some View {
        ZStack {
            LinearGradient(colors: [Tok.Kraft.light, Tok.Kraft.base], startPoint: .top, endPoint: .bottom)
            GrainOverlay(image: Grain.kraft, opacity: 0.55).surfaceGrain()
            // The paper's edge casts a soft shadow onto the board.
            HStack(spacing: 0) {
                LinearGradient(colors: [.black.opacity(0.16), .black.opacity(0)], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 12)
                Spacer(minLength: 0)
            }
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                StickyCard(sticky: sticky)
                    .scaleEffect(0.86)
                    .frame(width: 204 * 0.86 + 20, height: 204 * 0.86 + 20)
                    .opacity(isBlank ? 0.6 : 1)
                    .id(sticky.kind)
                    .transition(.asymmetric(insertion: .scale(scale: 1.06).combined(with: .opacity), removal: .opacity))
                Spacer(minLength: 0)
                Text(isBlank ? "Preview" : "Lands on your board")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Tok.Kraft.ink.opacity(0.75))
                    .shadow(color: Tok.Light.emboss.opacity(0.28), radius: 0, y: 1)
                    .padding(.bottom, 14)
            }
            .animation(Motion.enabled ? .spring(duration: 0.38, bounce: 0.2) : nil, value: sticky.kind)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Preview"))
    }
}
