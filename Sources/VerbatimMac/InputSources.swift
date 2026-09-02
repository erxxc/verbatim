import Carbon
import Foundation

enum InputSources {
    static func currentLanguageIdentifier() -> String? {
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        guard let pointer = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) else { return nil }
        let values = Unmanaged<CFArray>.fromOpaque(pointer).takeUnretainedValue() as NSArray
        return values.firstObject as? String
    }

    static func installedLanguageIdentifiers() -> [String] {
        let filter = [kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource] as CFDictionary
        guard let unmanaged = TISCreateInputSourceList(filter, false) else { return Locale.preferredLanguages }
        let sources = unmanaged.takeRetainedValue() as NSArray
        var languages = Set(Locale.preferredLanguages)

        for case let source as TISInputSource in sources {
            guard let pointer = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) else { continue }
            let values = Unmanaged<CFArray>.fromOpaque(pointer).takeUnretainedValue() as NSArray
            for case let language as String in values { languages.insert(language) }
        }
        return Array(languages)
    }
}
