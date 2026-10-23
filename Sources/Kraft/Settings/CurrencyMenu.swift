import KraftCore
import SwiftUI

extension Currency {
    /// "US Dollar", "دولار أمريكي" in the UI language.
    func displayName(_ format: KraftFormat) -> String { name(in: format.locale) }

    /// A menu line: "US Dollar · USD".
    func menuTitle(_ format: KraftFormat) -> String { "\(displayName(format)) · \(code)" }
}

/// Every currency in one menu: yours first, then the common ones, then all of them by name.
struct CurrencyMenuItems: View {
    let selected: Currency
    let choose: (Currency) -> Void
    @Environment(\.kraftFormat) private var format

    var body: some View {
        let preferred = Currency.preferred
        item(preferred)
        Divider()
        ForEach(Currency.common.filter { $0 != preferred }) { item($0) }
        Divider()
        Menu {
            ForEach(Currency.all.sorted { $0.displayName(format) < $1.displayName(format) }) { item($0) }
        } label: {
            Text("All Currencies")
        }
    }

    private func item(_ c: Currency) -> some View {
        Toggle(isOn: Binding(get: { c == selected }, set: { _ in choose(c) })) { Text(verbatim: c.menuTitle(format)) }
    }
}

/// A glossy tag showing the currency code that opens `CurrencyMenuItems`.
struct CurrencyMenuButton: View {
    let selected: Currency
    var tint: TagTint = .mint
    var size: TagSize = .mini
    let choose: (Currency) -> Void
    @Environment(\.kraftFormat) private var format

    var body: some View {
        Menu {
            CurrencyMenuItems(selected: selected, choose: choose)
        } label: {
            EmbossedLabel(text: selected.code, symbol: "chevron.down", tint: tint, size: size).fixedSize()
        }
        .menuStyle(.button)
        .buttonStyle(GlossyButtonStyle(tint: tint, size: size))
        .menuIndicator(.hidden)
        .fixedSize()
        .help(Text(verbatim: selected.displayName(format)))
        .accessibilityLabel(Text(verbatim: selected.displayName(format)))
    }
}
