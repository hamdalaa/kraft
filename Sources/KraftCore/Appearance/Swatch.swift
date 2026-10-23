import Foundation

/// The owner's appearance choice. `system` follows the Mac.
public enum AppAppearance: String, CaseIterable, Sendable {
    case system, light, dark

    /// Unknown or missing stored values fall back to `system`.
    public init(storedValue: String?) {
        self = storedValue.flatMap(AppAppearance.init(rawValue:)) ?? .system
    }
}

/// An sRGB colour as plain numbers (0…1), so colour maths can be tested without SwiftUI.
public struct RGB: Hashable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }

    /// `#RRGGBB` → RGB. Nil for malformed input.
    public init?(hexString: String) {
        let s = hexString.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(hex: v)
    }

    public var hex: UInt32 {
        func byte(_ v: Double) -> UInt32 { UInt32((min(max(v, 0), 1) * 255).rounded()) }
        return byte(red) << 16 | byte(green) << 8 | byte(blue)
    }

    /// Straight sRGB blend: `amount` 0 is self, 1 is `other`.
    public func mix(with other: RGB, by amount: Double) -> RGB {
        let t = min(max(amount, 0), 1)
        return RGB(red: red + (other.red - red) * t, green: green + (other.green - green) * t, blue: blue + (other.blue - blue) * t)
    }

    /// This colour laid over `background` at `alpha`.
    public func over(_ background: RGB, alpha: Double) -> RGB { background.mix(with: self, by: alpha) }

    /// WCAG 2 relative luminance.
    public var luminance: Double {
        func channel(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }

    /// WCAG 2 contrast ratio, 1…21.
    public func contrast(with other: RGB) -> Double {
        let a = luminance, b = other.luminance
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    /// Paper under the night-desk lamp: a touch dimmer and warmer, still clearly its own pastel.
    public var lamplit: RGB { mix(with: RGB(hex: Swatch.lampShade), by: Swatch.lampDim) }
}

/// One design token in both appearances. Alpha is part of the token where the design calls for a translucent colour.
public struct Swatch: Hashable, Sendable {
    public let light: UInt32
    public let dark: UInt32
    public let lightAlpha: Double
    public let darkAlpha: Double

    public init(_ light: UInt32, dark: UInt32, alpha: Double = 1, darkAlpha: Double? = nil) {
        self.light = light
        self.dark = dark
        lightAlpha = alpha
        self.darkAlpha = darkAlpha ?? alpha
    }

    /// The same colour in both appearances (sticker fills, stamp red).
    public static func fixed(_ hex: UInt32) -> Swatch { Swatch(hex, dark: hex) }

    /// A sticky paper: the light colour, lamplit at night.
    public static func paper(_ hex: UInt32) -> Swatch { Swatch(hex, dark: RGB(hex: hex).lamplit.hex) }

    /// The same colours with both alphas scaled.
    public func opacity(_ factor: Double) -> Swatch {
        Swatch(light, dark: dark, alpha: lightAlpha * factor, darkAlpha: darkAlpha * factor)
    }

    public func rgb(dark isDark: Bool) -> RGB { RGB(hex: isDark ? dark : light) }
    public func alpha(dark isDark: Bool) -> Double { isDark ? darkAlpha : lightAlpha }

    /// Warm brown the papers are dimmed toward at night, and by how much.
    static let lampShade: UInt32 = 0x2A1E14
    static let lampDim = 0.1
}
