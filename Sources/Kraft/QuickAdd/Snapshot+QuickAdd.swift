import KraftCore
import SwiftUI

extension Snapshot {
    /// Offscreen renders for this area: (file name without extension, view). Owned by the QuickAdd session.
    static func quickAddShots() -> [(String, AnyView)] {
        let store = StickyStore()
        func shot(_ text: String, tilt: Double = -1.6, kind: StickyKind? = nil) -> AnyView {
            let model = QuickAddModel(text: text, tilt: tilt)
            if let kind { model.setKind(kind) }
            return AnyView(
                QuickAddView(store: store, presentation: .panel, model: model, isSnapshot: true) {}
                    .shadow(color: .black.opacity(0.22), radius: 26, y: 16)
                    .shadow(color: .black.opacity(0.12), radius: 1.5, y: 1)
                    .padding(48)
                    .background(LinearGradient(colors: [Color(hex: 0x8E9AAB), Color(hex: 0x5F6B7C)], startPoint: .top, endPoint: .bottom))
            )
        }
        return [
            ("quickadd-empty", shot("")),
            ("quickadd-english", shot("Ali owes me 40$ friday")),
            ("quickadd-arabic", shot("ذكرني بالدواء الساعة ٩ كل يوم", tilt: 1.8)),
            ("quickadd-list", shot("buy milk, bread, eggs", tilt: -2.4)),
            ("quickadd-reminder", shot("remind me to call mum tomorrow 6pm", tilt: 2.2)),
            ("quickadd-iowe-ar", shot("علي يطلبني ٤٠ دولار الجمعة", tilt: -1.6)),
            ("quickadd-kinds", AnyView(KindPicker(selected: .reminder) { _ in }.background(Tok.Page.base))),
        ]
    }
}
