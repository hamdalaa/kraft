import KraftCore
import SwiftUI

/// ⌘, — a card of page stock taped to the warm page: appearance, language and digits as glossy choice tags, then updates.
struct SettingsView: View {
    @Environment(AppPreferences.self) private var preferences
    var updater: Updater = .shared
    @Environment(\.kraftFormat) private var format

    static let width: CGFloat = 460

    var body: some View {
        @Bindable var preferences = preferences
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                DieCutSticker(art: StickerArt(symbol: "gearshape", fill: Tok.Sticker.yellow), size: 24, tilt: .degrees(-8))
                Text("Settings")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Tok.Kraft.ink.opacity(0.92))
                    .shadow(color: Tok.Light.emboss.opacity(0.8), radius: 0, y: 1)
            }
            .padding(.bottom, 2)

            appearance
            EditorPerforation()
            language
            EditorPerforation()
            digits
            EditorPerforation()
            currency
            EditorPerforation()
            SettingsUpdates(updater: updater)
        }
        .padding(.horizontal, 26)
        .padding(.top, 26)
        .padding(.bottom, 24)
        .frame(width: Self.width)
        .background(EditorCardBackground())
        .overlay(alignment: .top) {
            WashiTape(tint: Tok.Sticker.sky).scaleEffect(0.8).rotationEffect(.degrees(-2)).offset(y: -10)
                .allowsHitTesting(false)
        }
        .padding(28)
        .background(PageBackground())
        .animation(Motion.enabled ? .spring(duration: 0.3) : nil, value: preferences.needsRelaunch)
    }

    private var appearance: some View {
        VStack(alignment: .leading, spacing: 10) {
            EditorLabel("Appearance")
            HStack(spacing: 8) {
                ForEach(AppAppearance.allCases, id: \.self) { choice in
                    SettingsChoice(title: title(choice), isOn: preferences.appearance == choice, tint: .mint) {
                        preferences.appearance = choice
                    }
                }
            }
            Text("System follows the appearance of your Mac.")
                .font(.system(size: 12.5))
                .foregroundStyle(Tok.Kraft.ink.opacity(0.62))
        }
    }

    private var language: some View {
        VStack(alignment: .leading, spacing: 10) {
            EditorLabel("Language")
            HStack(spacing: 8) {
                ForEach(AppLanguage.allCases, id: \.self) { choice in
                    SettingsChoice(title: title(choice), isOn: preferences.language == choice, tint: .blue) {
                        preferences.language = choice
                    }
                }
            }
            if preferences.needsRelaunch {
                HStack(spacing: 12) {
                    Text("Kraft changes language when it opens again.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Tok.Kraft.ink.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Button { preferences.relaunch() } label: {
                        EmbossedLabel(text: String(localized: "Relaunch Kraft"), symbol: "arrow.clockwise", tint: .blue, size: .regular)
                            .fixedSize()
                    }
                    .buttonStyle(GlossyButtonStyle(tint: .blue))
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Text("System follows the language of your Mac.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Tok.Kraft.ink.opacity(0.62))
            }
        }
    }

    private var digits: some View {
        VStack(alignment: .leading, spacing: 10) {
            EditorLabel("Digits")
            HStack(spacing: 8) {
                SettingsChoice(title: String(localized: "Western 123"), isOn: preferences.digits == .western, tint: .amber) {
                    preferences.digits = .western
                }
                SettingsChoice(title: String(localized: "Arabic ١٢٣"), isOn: preferences.digits == .arabic, tint: .amber) {
                    preferences.digits = .arabic
                }
            }
            // A live sample of what changes: money, dates, times and counts.
            HStack(spacing: 8) {
                GlossyTag(text: format.money(1_250, preferences.currency), symbol: "banknote", tint: .pink, size: .mini)
                GlossyTag(text: format.dayMonth(Date()), symbol: "calendar", tint: .blue, size: .mini)
                GlossyTag(text: format.time(Self.nineAM), symbol: "bell.fill", tint: .amber, size: .mini)
            }
            .padding(.top, 2)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("Sample"))
        }
    }

    /// System follows the Mac's region; any other currency can be picked from the full list.
    private var currency: some View {
        VStack(alignment: .leading, spacing: 10) {
            EditorLabel("Currency")
            HStack(spacing: 8) {
                SettingsChoice(title: String(localized: "System"), isOn: preferences.currencyChoice == nil, tint: .pink) {
                    preferences.currencyChoice = nil
                }
                Menu {
                    CurrencyMenuItems(selected: preferences.currency) { preferences.currencyChoice = $0 }
                } label: {
                    let t: TagTint = preferences.currencyChoice == nil ? .paper : .pink
                    EmbossedLabel(text: preferences.currency.menuTitle(format), symbol: "chevron.down", tint: t, size: .regular)
                        .fixedSize()
                }
                .menuStyle(.button)
                .buttonStyle(GlossyButtonStyle(tint: preferences.currencyChoice == nil ? .paper : .pink))
                .menuIndicator(.hidden)
                .fixedSize()
            }
            Text("Used when you write an amount without a currency. System follows your Mac’s region.")
                .font(.system(size: 12.5))
                .foregroundStyle(Tok.Kraft.ink.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private static var nineAM: Date {
        Calendar.current.date(bySettingHour: 9, minute: 30, second: 0, of: Date()) ?? Date()
    }

    private func title(_ choice: AppAppearance) -> String {
        switch choice {
        case .system: String(localized: "System")
        case .light: String(localized: "Light")
        case .dark: String(localized: "Dark")
        }
    }

    /// Language names stay in their own script, as on every Mac.
    private func title(_ choice: AppLanguage) -> String {
        switch choice {
        case .system: String(localized: "System")
        case .english: "English" // not localized
        case .arabic: "العربية" // not localized
        }
    }
}

/// A regular-size glossy choice tag: paper when off, tinted with a tick when chosen.
private struct SettingsChoice: View {
    let title: String
    let isOn: Bool
    let tint: TagTint
    let action: () -> Void

    var body: some View {
        let t = isOn ? tint : .paper
        Button(action: action) {
            EmbossedLabel(text: title, symbol: isOn ? "checkmark" : nil, tint: t, size: .regular).fixedSize()
        }
        .buttonStyle(GlossyButtonStyle(tint: t))
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .animation(.spring(duration: 0.25), value: isOn)
    }
}
