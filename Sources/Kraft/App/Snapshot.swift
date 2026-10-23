import AppKit
import KraftCore
import SwiftUI

/// Offscreen visual checks: `KRAFT_SNAPSHOT=/dir Kraft.app/Contents/MacOS/Kraft -ApplePersistenceIgnoreState YES`
/// writes PNGs and quits. Liquid Glass and system materials do not render offscreen.
@MainActor
enum Snapshot {
    static func renderAll(to dir: URL) {
        Motion.enabled = false
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let samples = SampleData.stickies()

        for tab in [BoardTab.all, .money, .done] {
            let model = BoardModel(store: StickyStore(stickies: samples))
            model.tab = tab
            write(BoardScreen(model: model, scrolls: false).frame(width: 1220, height: 820), to: dir.appendingPathComponent("board-\(tab.rawValue).png"))
        }

        let empty = BoardModel(store: StickyStore(stickies: []))
        write(BoardScreen(model: empty, scrolls: false).frame(width: 1220, height: 820), to: dir.appendingPathComponent("board-empty.png"))

        let papers = HStack(spacing: 56) {
            ForEach(samples) { StickyCard(sticky: $0) }
        }
        .padding(60)
        .background(Tok.Kraft.base)
        write(papers, to: dir.appendingPathComponent("papers.png"))

        let parts = VStack(alignment: .leading, spacing: 28) {
            HStack(spacing: 18) {
                GlossyTag(text: "branding", symbol: "sparkle", tint: .blue)
                GlossyTag(text: "website", symbol: "globe", tint: .lime)
                GlossyTag(text: "interface", symbol: "cursorarrow.click.2", tint: .mint)
                GlossyTag(text: "pink", symbol: "heart", tint: .pink)
                GlossyTag(text: "amber", symbol: "bell.fill", tint: .amber, size: .mini)
            }
            HStack(spacing: 30) {
                ForEach(StickyKind.allCases, id: \.self) { DieCutSticker(art: $0.sticker, size: 34) }
            }
        }
        .padding(50)
        .background(Tok.Page.base)
        write(parts, to: dir.appendingPathComponent("parts.png"))

        // Crumple stages + the bin.
        let sample = samples[2]
        let paperRenderer = ImageRenderer(content: ThrowController.handPaper(sample))
        paperRenderer.scale = 2
        if let cg = paperRenderer.cgImage {
            let size = CGSize(width: CGFloat(cg.width) / 2, height: CGFloat(cg.height) / 2)
            let stages = HStack(spacing: 40) {
                ForEach([0.0, 0.24, 0.45, 0.84, 1.0], id: \.self) { t in
                    CrumpleView(image: Image(decorative: cg, scale: 2), size: size,
                                paper: sample.style.color.color(customHex: nil), progress: t)
                }
                WasteBin(balls: [PaperColor.sky, .pink, .lemon].map { $0.color(customHex: nil) })
                    .scaleEffect(1.6)
                    .padding(30)
            }
            .padding(50)
            .background(Tok.Kraft.base)
            write(stages, to: dir.appendingPathComponent("crumple.png"))
        }

        CrumpleGIF.write(sticky: samples[2], to: dir.appendingPathComponent("crumple.gif"))

        for (name, view) in editorShots() + quickAddShots() + desktopShots() + notificationsShots() + settingsShots() {
            write(view, to: dir.appendingPathComponent("\(name).png"))
        }
    }

    static func write(_ view: some View, to url: URL) {
        // Language comes from `-AppleLanguages "(ar)"` (the bundle's choice); direction and formats follow it.
        let renderer = ImageRenderer(content: view.kraftEnvironment().environment(\.colorScheme, .light))
        renderer.scale = 2
        guard let image = renderer.cgImage else { NSLog("Kraft snapshot: render failed for %@", url.lastPathComponent); return }
        let rep = NSBitmapImageRep(cgImage: image)
        do {
            try rep.representation(using: .png, properties: [:])?.write(to: url)
            print("wrote \(url.path)")
        } catch {
            NSLog("Kraft snapshot: %@", error.localizedDescription)
        }
    }
}
