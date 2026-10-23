import Foundation

public enum ScriptDirection: Sendable, Equatable {
    case leftToRight, rightToLeft

    /// Direction of the first strong character (Unicode bidi "P2" rule, simplified to Arabic vs. Latin).
    /// Digits, punctuation and spaces are neutral and skipped.
    public static func detect(_ text: String) -> ScriptDirection {
        for scalar in text.unicodeScalars {
            if isArabic(scalar) { return .rightToLeft }
            if scalar.properties.isAlphabetic { return .leftToRight }
        }
        return .leftToRight
    }

    static func isArabic(_ s: Unicode.Scalar) -> Bool {
        switch s.value {
        case 0x0600...0x065F, 0x066E...0x06EF, 0x06FA...0x06FF, 0x0750...0x077F, 0x08A0...0x08FF,
             0xFB50...0xFDFF, 0xFE70...0xFEFF:
            // Arabic-Indic digits (0660–0669, 06F0–06F9) are excluded: they are neutral, not strong.
            return !(0x0660...0x0669).contains(s.value)
        default:
            return false
        }
    }
}
