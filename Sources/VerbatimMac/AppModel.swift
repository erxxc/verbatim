import AppKit
@preconcurrency import ApplicationServices
import Foundation
@preconcurrency import Translation

struct LanguageChoice: Identifiable, Hashable {
    let identifier: String
    let displayName: String
    let fromKeyboard: Bool
    var id: String { identifier }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var isEnabled = true {
        didSet { updateStatus() }
    }
    @Published var sourceIdentifier = "en" {
        didSet { Task { await validatePair() } }
    }
    @Published var targetIdentifier = "ru" {
        didSet { Task { await validatePair() } }
    }
    @Published var followCurrentKeyboard = true {
        didSet { updateStatus() }
    }
    @Published private(set) var availableLanguages: [LanguageChoice] = []
    @Published private(set) var statusMessage = "Starting…"
    @Published private(set) var statusSymbol = "hourglass"
    @Published private(set) var statusIsError = false
    @Published private(set) var isAccessibilityTrusted = AXIsProcessTrusted()

    private var monitor: Any?
    private var started = false
    private var pairIsInstalled = false
    private var isTranslating = false
    private let translator = AppleTranslator()

    init() {
        Task { @MainActor [weak self] in
            await self?.start()
        }
    }

    func start() async {
        guard !started else { return }
        started = true
        installGlobalMonitor()
        await refreshLanguages()
        requestAccessibilityAccess(prompt: false)
    }

    func refreshLanguages() async {
        statusMessage = "Reading keyboard and Translation languages…"
        statusSymbol = "arrow.triangle.2.circlepath"
        statusIsError = false

        let keyboardIdentifiers = Set(InputSources.installedLanguageIdentifiers().map(Self.baseLanguage))
        let supported = await LanguageAvailability().supportedLanguages
        let choices = supported.compactMap { language -> LanguageChoice? in
            guard let identifier = language.minimalIdentifier.split(separator: "-").first.map(String.init) else { return nil }
            let base = Self.baseLanguage(identifier)
            let name = Locale.current.localizedString(forLanguageCode: base)?.capitalized ?? base.uppercased()
            return LanguageChoice(identifier: base, displayName: name, fromKeyboard: keyboardIdentifiers.contains(base))
        }

        availableLanguages = Dictionary(grouping: choices, by: \.identifier)
            .compactMap { $0.value.first }
            .sorted {
                if $0.fromKeyboard != $1.fromKeyboard { return $0.fromKeyboard }
                return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }

        if !availableLanguages.contains(where: { $0.identifier == sourceIdentifier }), let first = availableLanguages.first {
            sourceIdentifier = first.identifier
        }
        if !availableLanguages.contains(where: { $0.identifier == targetIdentifier }), let target = availableLanguages.first(where: { $0.identifier != sourceIdentifier }) {
            targetIdentifier = target.identifier
        }
        await validatePair()
    }

    func swapLanguages() {
        (sourceIdentifier, targetIdentifier) = (targetIdentifier, sourceIdentifier)
    }

    func requestAccessibilityAccess() {
        requestAccessibilityAccess(prompt: true)
    }

    private func requestAccessibilityAccess(prompt: Bool) {
        // The exported ApplicationServices constant is mutable in the legacy C header,
        // which Swift 6 rejects under strict concurrency. Its documented CFDictionary key
        // is stable, so use the value directly instead of reading shared C state.
        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        isAccessibilityTrusted = AXIsProcessTrustedWithOptions(options)
        updateStatus()
    }

    private func validatePair() async {
        guard sourceIdentifier != targetIdentifier else {
            pairIsInstalled = false
            statusMessage = "Choose two different languages."
            statusSymbol = "exclamationmark.triangle"
            statusIsError = true
            return
        }
        let source = Locale.Language(identifier: sourceIdentifier)
        let target = Locale.Language(identifier: targetIdentifier)
        let state = await LanguageAvailability().status(from: source, to: target)
        switch state {
        case .installed:
            pairIsInstalled = true
            updateStatus()
        case .supported:
            pairIsInstalled = false
            statusMessage = "Download required: System Settings › General › Language & Region › Translation Languages. Then enable On-Device Mode."
            statusSymbol = "arrow.down.circle"
            statusIsError = true
        case .unsupported:
            pairIsInstalled = false
            statusMessage = "Apple Translation does not support this language pair."
            statusSymbol = "nosign"
            statusIsError = true
        @unknown default:
            pairIsInstalled = false
            statusMessage = "The selected language pair is unavailable."
            statusSymbol = "questionmark.circle"
            statusIsError = true
        }
    }

    private func updateStatus() {
        isAccessibilityTrusted = AXIsProcessTrusted()
        guard isAccessibilityTrusted else {
            statusMessage = "Accessibility access is required to replace text in other apps."
            statusSymbol = "hand.raised"
            statusIsError = true
            return
        }
        guard pairIsInstalled else { return }
        if isEnabled {
            statusMessage = followCurrentKeyboard
                ? "Offline ready. The current keyboard automatically chooses direction."
                : "Offline ready. Type a period, question mark, or exclamation point in an editable text field."
            statusSymbol = "checkmark.circle"
            statusIsError = false
        } else {
            statusMessage = "Paused."
            statusSymbol = "pause.circle"
            statusIsError = false
        }
    }

    private func installGlobalMonitor() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.cgEvent?.getIntegerValueField(.eventSourceUserData) == KeyboardReplacement.eventMarker { return }
            guard let characters = event.characters, characters.contains(where: { ".!?".contains($0) }) else { return }
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(90))
                await self?.translateFocusedSentence()
            }
        }
    }

    private func translateFocusedSentence() async {
        guard isEnabled, isAccessibilityTrusted, pairIsInstalled, !isTranslating else { return }
        guard let context = FocusedText.readLastSentence(), !context.sentence.isEmpty else {
            statusMessage = "The focused app does not expose editable text through Accessibility."
            statusSymbol = "exclamationmark.bubble"
            statusIsError = true
            return
        }

        isTranslating = true
        statusMessage = "Translating…"
        statusSymbol = "ellipsis.circle"
        statusIsError = false
        defer { isTranslating = false }

        do {
            var eventSource = sourceIdentifier
            var eventTarget = targetIdentifier
            if followCurrentKeyboard, let current = InputSources.currentLanguageIdentifier() {
                let keyboardLanguage = Self.baseLanguage(current)
                if keyboardLanguage == targetIdentifier {
                    (eventSource, eventTarget) = (targetIdentifier, sourceIdentifier)
                } else if keyboardLanguage == sourceIdentifier {
                    (eventSource, eventTarget) = (sourceIdentifier, targetIdentifier)
                }
            }
            let translated = try await translator.translate(
                context.sentence,
                from: eventSource,
                to: eventTarget
            )
            try FocusedText.replace(context, with: translated)
            updateStatus()
        } catch {
            statusMessage = error.localizedDescription
            statusSymbol = "exclamationmark.triangle"
            statusIsError = true
        }
    }

    private static func baseLanguage(_ identifier: String) -> String {
        identifier.replacingOccurrences(of: "_", with: "-").split(separator: "-").first.map(String.init)?.lowercased() ?? identifier.lowercased()
    }
}

actor AppleTranslator {
    func translate(_ text: String, from sourceID: String, to targetID: String) async throws -> String {
        let source = Locale.Language(identifier: sourceID)
        let target = Locale.Language(identifier: targetID)
        let session = TranslationSession(installedSource: source, target: target)
        let response = try await session.translate(text)
        return response.targetText
    }
}
