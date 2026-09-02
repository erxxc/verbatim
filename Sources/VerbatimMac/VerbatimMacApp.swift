import SwiftUI

@main
struct VerbatimMacApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra("Verbatim", systemImage: model.isEnabled ? "character.book.closed.fill" : "character.book.closed") {
            MenuContent(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuContent: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Verbatim")
                        .font(.headline)
                    Text("System-wide sentence translation")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: $model.isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            Divider()

            languagePicker("From", selection: $model.sourceIdentifier)

            HStack {
                Spacer()
                Button {
                    model.swapLanguages()
                } label: {
                    Label("Swap", systemImage: "arrow.up.arrow.down")
                }
                .buttonStyle(.borderless)
                .keyboardShortcut("r", modifiers: [.command, .shift])
                Spacer()
            }

            languagePicker("To", selection: $model.targetIdentifier)

            Toggle("Follow current keyboard", isOn: $model.followCurrentKeyboard)
                .font(.caption)
                .help("Switching between the selected keyboard languages automatically reverses translation direction.")

            Divider()

            HStack(alignment: .top, spacing: 9) {
                Image(systemName: model.statusSymbol)
                    .foregroundStyle(model.statusIsError ? Color.orange : Color.secondary)
                    .frame(width: 16)
                Text(model.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !model.isAccessibilityTrusted {
                Button("Allow Accessibility Access…") {
                    model.requestAccessibilityAccess()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }

            HStack {
                Button("Refresh Languages") {
                    Task { await model.refreshLanguages() }
                }
                .buttonStyle(.borderless)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.borderless)
            }
            .font(.caption)
        }
        .padding(16)
        .frame(width: 330)
        .task { await model.start() }
    }

    private func languagePicker(_ label: String, selection: Binding<String>) -> some View {
        HStack {
            Text(label)
                .frame(width: 38, alignment: .leading)
                .foregroundStyle(.secondary)
            Picker(label, selection: selection) {
                ForEach(model.availableLanguages) { language in
                    HStack {
                        Text(language.displayName)
                        if language.fromKeyboard { Text("⌨") }
                    }
                    .tag(language.identifier)
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)
        }
    }
}
