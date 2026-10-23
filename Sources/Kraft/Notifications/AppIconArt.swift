import AppKit
import SwiftUI

/// The app icon as the bundle ships it (`Resources/AppIcon.icns`, made from the designer's artwork
/// `Resources/AppIcon-1024.png` by `scripts/make-icon.sh`): a lined note page with a curled corner on a dark slab,
/// on the macOS icon grid (824/1024 tile, 100 px margins, soft drop shadow). Drawn in a 512 pt space.
struct AppIconArt: View {
    static let canvas: CGFloat = 512

    var body: some View {
        Image(nsImage: NSApplication.shared.applicationIconImage)
            .resizable()
            .interpolation(.high)
            .frame(width: Self.canvas, height: Self.canvas)
            .accessibilityHidden(true)
    }
}
