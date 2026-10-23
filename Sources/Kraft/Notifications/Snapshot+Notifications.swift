import SwiftUI

extension Snapshot {
    /// Offscreen renders for this area: (file name without extension, view). Owned by the Notifications session.
    /// `appicon-1024` renders the shipped icon (512 pt @2x = 1024 px) to check it; its source is `Resources/AppIcon-1024.png`.
    static func notificationsShots() -> [(String, AnyView)] {
        [
            ("appicon-1024", AnyView(AppIconArt())),
            ("appicon-sizes", AnyView(iconSizes)),
        ]
    }

    /// The icon at Finder / Dock sizes on light and dark, to check it still reads small.
    private static var iconSizes: some View {
        VStack(spacing: 0) {
            ForEach([Color(hex: 0xF4F2EE), Color(hex: 0x2A2A2C)], id: \.self) { bg in
                HStack(alignment: .bottom, spacing: 28) {
                    ForEach([16, 32, 64, 128, 256] as [CGFloat], id: \.self) { side in
                        AppIconArt()
                            .scaleEffect(side / AppIconArt.canvas)
                            .frame(width: side, height: side)
                    }
                }
                .padding(32)
                .background(bg)
            }
        }
    }
}
