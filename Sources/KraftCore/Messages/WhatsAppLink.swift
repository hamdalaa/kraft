import Foundation

/// `https://wa.me/?text=…` — opens WhatsApp with the message ready to send and lets the user pick the chat.
public enum WhatsAppLink {
    /// RFC 3986 unreserved characters. Everything else (spaces, Arabic, `&`, `+`, `#`, newlines) is percent-encoded.
    private static let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    public static func encode(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
    }

    /// `phone` is optional; only its digits are kept (international format without `+`).
    public static func url(text: String, phone: String? = nil) -> URL? {
        let digits = (phone ?? "").filter { $0.isASCII && $0.isNumber }
        return URL(string: "https://wa.me/\(digits)?text=\(encode(text))")
    }
}
