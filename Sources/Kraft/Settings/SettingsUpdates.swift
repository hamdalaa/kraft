import KraftCore
import SwiftUI

/// Settings › Updates: the running version, the newest release on GitHub, and one button for what comes next.
struct SettingsUpdates: View {
    @Bindable var updater: Updater
    @Environment(\.kraftFormat) private var format

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                EditorLabel("Updates")
                Spacer(minLength: 8)
                Button { NSWorkspace.shared.open(Updater.repoURL) } label: {
                    Label("Kraft on GitHub", systemImage: "arrow.up.forward")
                        .labelStyle(TrailingIcon())
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Tok.Kraft.ink.opacity(0.7))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointerStyle(.link)
                .help(Text("Open the Kraft repository on GitHub"))
                .accessibilityAddTraits(.isLink)
            }
            status
                .frame(minHeight: 20, alignment: .leading)
            action
            HStack(spacing: 8) {
                Toggle(isOn: $updater.checksAutomatically) {
                    Text("Check automatically every day")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Tok.Kraft.ink.opacity(0.75))
                }
                .toggleStyle(.checkbox)
                .tint(Tok.Kraft.ink)
            }
        }
        .animation(Motion.enabled ? .spring(duration: 0.3) : nil, value: updater.state)
    }

    private var versionText: String { format.digits(in: updater.currentVersionText) }

    @ViewBuilder private var status: some View {
        switch updater.state {
        case .idle:
            line(symbol: "shippingbox", tint: Tok.Kraft.ink.opacity(0.55), Text("Kraft \(versionText)"))
        case .checking:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                caption(Text("Checking GitHub…"))
            }
        case .upToDate:
            line(symbol: "checkmark.seal.fill", tint: TagTint.mint.ink, Text("Kraft \(versionText) is the latest version."))
        case .available(let release):
            line(symbol: "arrow.down.circle.fill", tint: TagTint.blue.ink,
                 Text("Kraft \(format.digits(in: release.version.description)) is available — you have \(versionText)."))
        case .installing(let release):
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                caption(Text("Installing Kraft \(format.digits(in: release.version.description))…"))
            }
        case .failed(let message):
            line(symbol: "exclamationmark.triangle.fill", tint: TagTint.amber.ink, Text(message))
        }
    }

    @ViewBuilder private var action: some View {
        switch updater.state {
        case .available(let release):
            HStack(spacing: 8) {
                Button { NSWorkspace.shared.open(release.pageURL) } label: {
                    EmbossedLabel(text: String(localized: "What’s New"), symbol: nil, tint: .paper, size: .regular).fixedSize()
                }
                .buttonStyle(GlossyButtonStyle(tint: .paper))
                Button { Task { await updater.install(release) } } label: {
                    EmbossedLabel(text: String(localized: "Install & Relaunch"), symbol: "arrow.down.circle", tint: .mint, size: .regular)
                        .fixedSize()
                }
                .buttonStyle(GlossyButtonStyle(tint: .mint))
            }
        case .checking, .installing:
            EmptyView()
        case .failed:
            HStack(spacing: 8) {
                Button { NSWorkspace.shared.open(Updater.releasesURL) } label: {
                    EmbossedLabel(text: String(localized: "Open Releases"), symbol: nil, tint: .paper, size: .regular).fixedSize()
                }
                .buttonStyle(GlossyButtonStyle(tint: .paper))
                checkButton
            }
        case .idle, .upToDate:
            checkButton
        }
    }

    private var checkButton: some View {
        Button { Task { await updater.check() } } label: {
            EmbossedLabel(text: String(localized: "Check for Updates"), symbol: "arrow.triangle.2.circlepath", tint: .blue, size: .regular)
                .fixedSize()
        }
        .buttonStyle(GlossyButtonStyle(tint: .blue))
    }

    private func line(symbol: String, tint: Color, _ text: Text) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Image(systemName: symbol).foregroundStyle(tint).accessibilityHidden(true)
            caption(text)
        }
    }

    private func caption(_ text: Text) -> some View {
        text.font(.system(size: 12.5))
            .foregroundStyle(Tok.Kraft.ink.opacity(0.75))
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Title then icon (the arrow sits after the words in both directions).
private struct TrailingIcon: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.title
            configuration.icon.imageScale(.small)
        }
    }
}
