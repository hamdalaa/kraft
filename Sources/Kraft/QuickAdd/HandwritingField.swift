import AppKit
import KraftCore
import SwiftUI

/// A recognised phrase to mark in the field, with the highlighter colour for its tag.
struct FieldMark: Equatable {
    let range: Range<String.Index>
    let color: Color
}

/// The one handwriting line of quick add. Direction and font follow the first strong character
/// (Arabic → Molhim RTL, otherwise Playpen LTR). Return submits, ⌥Return breaks the line, Esc cancels.
/// Recognised phrases get a soft highlighter wash under the words.
struct HandwritingField: NSViewRepresentable {
    @Binding var text: String
    var marks: [FieldMark] = []
    var size: CGFloat = 25
    var onSubmit: () -> Void
    var onCancel: () -> Void

    static let maxLines: CGFloat = 4

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = false
        scroll.hasHorizontalScroller = false
        scroll.borderType = .noBorder

        let storage = NSTextStorage()
        let layout = HighlighterLayoutManager()
        storage.addLayoutManager(layout)
        let container = NSTextContainer(size: NSSize(width: 400, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        container.lineFragmentPadding = 0
        layout.addTextContainer(container)

        let tv = FieldTextView(frame: .zero, textContainer: container)
        tv.delegate = context.coordinator
        tv.isRichText = false
        tv.importsGraphics = false
        tv.drawsBackground = false
        tv.allowsUndo = true
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isContinuousSpellCheckingEnabled = false
        tv.textContainerInset = .zero
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.minSize = .zero
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.insertionPointColor = .swatch(Palette.Card.text)
        tv.setAccessibilityLabel(String(localized: "New sticky"))
        tv.string = text
        scroll.documentView = tv
        context.coordinator.restyle(tv, force: true)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let tv = scroll.documentView as? FieldTextView else { return }
        if tv.string != text, !tv.hasMarkedText() {
            tv.string = text
            tv.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))
        }
        context.coordinator.restyle(tv, force: false)
        context.coordinator.mark(tv, in: context.environment)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSScrollView, context: Context) -> CGSize? {
        let width = proposal.width ?? 420
        let line = context.coordinator.lineHeight
        guard let tv = nsView.documentView as? NSTextView, let lm = tv.layoutManager, let tc = tv.textContainer else {
            return CGSize(width: width, height: line)
        }
        tc.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        lm.ensureLayout(for: tc)
        let used = max(lm.usedRect(for: tc).height, line)
        return CGSize(width: width, height: min(ceil(used), line * Self.maxLines))
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: HandwritingField
        private var direction: ScriptDirection?

        init(_ parent: HandwritingField) { self.parent = parent }

        var lineHeight: CGFloat { (parent.size * 1.62).rounded() }

        func textDidChange(_ note: Notification) {
            guard let tv = note.object as? NSTextView else { return }
            if parent.text != tv.string { parent.text = tv.string }
            restyle(tv, force: false)
        }

        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.insertNewline(_:)):
                parent.onSubmit()
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                parent.onCancel()
                return true
            case #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)):
                textView.insertText("\n", replacementRange: textView.selectedRange())
                return true
            case #selector(NSResponder.insertTab(_:)):
                textView.window?.selectNextKeyView(nil)
                return true
            default:
                return false
            }
        }

        /// Font and writing direction follow the text; only re-applied when the direction flips.
        func restyle(_ tv: NSTextView, force: Bool) {
            let dir = ScriptDirection.detect(tv.string)
            guard force || dir != direction, !tv.hasMarkedText() else { return }
            direction = dir
            let attrs = Self.attributes(dir, size: parent.size, lineHeight: lineHeight)
            tv.typingAttributes = attrs
            tv.defaultParagraphStyle = attrs[.paragraphStyle] as? NSParagraphStyle
            if let storage = tv.textStorage, storage.length > 0 {
                storage.setAttributes(attrs, range: NSRange(location: 0, length: storage.length))
            }
            tv.baseWritingDirection = dir == .rightToLeft ? .rightToLeft : .leftToRight
        }

        /// Marks resolve against the field's appearance (the highlighter is a deeper wash at night).
        func mark(_ tv: NSTextView, in environment: EnvironmentValues) {
            guard let lm = tv.layoutManager, !tv.hasMarkedText() else { return }
            let full = NSRange(location: 0, length: (tv.string as NSString).length)
            lm.removeTemporaryAttribute(.backgroundColor, forCharacterRange: full)
            guard tv.string == parent.text else { return }
            for m in parent.marks {
                let r = NSRange(m.range, in: tv.string)
                guard NSMaxRange(r) <= full.length else { continue }
                lm.addTemporaryAttribute(.backgroundColor, value: NSColor(Color(m.color.resolve(in: environment))), forCharacterRange: r)
            }
        }

        static func attributes(_ dir: ScriptDirection, size: CGFloat, lineHeight: CGFloat) -> [NSAttributedString.Key: Any] {
            let p = NSMutableParagraphStyle()
            p.baseWritingDirection = dir == .rightToLeft ? .rightToLeft : .leftToRight
            p.alignment = .natural
            p.minimumLineHeight = lineHeight
            p.maximumLineHeight = lineHeight
            return [.font: HandFont.nsFont(dir, size: size), .paragraphStyle: p,
                    .foregroundColor: NSColor.swatch(Palette.Card.text.opacity(0.92))]
        }
    }
}

/// AppKit twin of `Hand.font`: same faces and the same ×1.2 optical size for Molhim.
enum HandFont {
    static func nsFont(_ dir: ScriptDirection, size: CGFloat) -> NSFont {
        if dir == .rightToLeft, let molhim = NSFont(name: FontRegistry.molhim, size: size * 1.2) { return molhim }
        return NSFont(name: FontRegistry.playpen, size: size) ?? .systemFont(ofSize: size)
    }
}

final class FieldTextView: NSTextView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.window === window else { return }
            window.makeFirstResponder(self)
        }
    }
}

/// Draws background-colour runs as a highlighter stroke over the lower half of the words, not a full-height block.
final class HighlighterLayoutManager: NSLayoutManager {
    override func fillBackgroundRectArray(_ rectArray: UnsafePointer<NSRect>, count rectCount: Int,
                                          forCharacterRange charRange: NSRange, color: NSColor) {
        color.setFill()
        for i in 0..<rectCount {
            let r = rectArray[i]
            let band = NSRect(x: r.minX - 2, y: r.minY + r.height * 0.46, width: r.width + 4, height: r.height * 0.36)
            NSBezierPath(roundedRect: band, xRadius: band.height * 0.35, yRadius: band.height * 0.35).fill()
        }
    }
}
