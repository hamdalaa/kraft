import Foundation

public enum PaperColor: String, Codable, CaseIterable, Sendable {
    case lemon, mint, sky, pink, peach, lilac, white, custom
}

public enum Handwriting: String, Codable, CaseIterable, Sendable {
    /// Molhim for Arabic text, Playpen for everything else.
    case auto, playpen, molhim
}

public enum StickySize: String, Codable, CaseIterable, Sendable {
    case small, medium, large
    public var side: Double {
        switch self {
        case .small: 176
        case .medium: 204
        case .large: 236
        }
    }
}

public enum InkColor: String, Codable, CaseIterable, Sendable {
    case graphite, blue, red, green
}

public enum Ruling: String, Codable, CaseIterable, Sendable {
    case none, lines, grid, dots
}

public enum Fastener: String, Codable, CaseIterable, Sendable {
    case none, tape, pin, clip
}

public struct PaperStyle: Codable, Hashable, Sendable {
    public var color: PaperColor
    /// `#RRGGBB`, used when `color == .custom`.
    public var customHex: String?
    public var handwriting: Handwriting
    public var size: StickySize
    public var ink: InkColor
    public var ruling: Ruling
    public var fastener: Fastener
    /// Degrees, −4…4.
    public var tilt: Double

    public init(
        color: PaperColor = .lemon,
        customHex: String? = nil,
        handwriting: Handwriting = .auto,
        size: StickySize = .medium,
        ink: InkColor = .graphite,
        ruling: Ruling = .none,
        fastener: Fastener = .none,
        tilt: Double = 0
    ) {
        self.color = color
        self.customHex = customHex
        self.handwriting = handwriting
        self.size = size
        self.ink = ink
        self.ruling = ruling
        self.fastener = fastener
        self.tilt = tilt
    }
}
