import AppKit
@preconcurrency import ApplicationServices
import Foundation

struct FocusedSentence {
    let element: AXUIElement
    let processIdentifier: pid_t
    let fullValue: String
    let range: CFRange
    let sentence: String
}

enum FocusedTextError: LocalizedError {
    case focusChanged
    case replacementUnsupported
    case keyboardEventUnavailable

    var errorDescription: String? {
        switch self {
        case .focusChanged: "The focused text changed before translation finished."
        case .replacementUnsupported: "This app does not allow text replacement through Accessibility."
        case .keyboardEventUnavailable: "macOS could not create a replacement keyboard event."
        }
    }
}

enum FocusedText {
    static func readLastSentence() -> FocusedSentence? {
        let system = AXUIElementCreateSystemWide()
        guard let element: AXUIElement = copyAttribute(system, kAXFocusedUIElementAttribute as CFString),
              let value: String = copyAttribute(element, kAXValueAttribute as CFString),
              let rangeValue: AXValue = copyAttribute(element, kAXSelectedTextRangeAttribute as CFString)
        else { return nil }

        var selectedRange = CFRange()
        guard AXValueGetValue(rangeValue, .cfRange, &selectedRange), selectedRange.location >= 0 else { return nil }

        let text = value as NSString
        let caret = min(selectedRange.location, text.length)
        guard caret > 0 else { return nil }

        var end = caret
        while end > 0, isWhitespace(text.character(at: end - 1)) { end -= 1 }
        guard end > 0, isPunctuation(text.character(at: end - 1)) else { return nil }

        var start = end - 1
        while start > 0 {
            if isTerminator(text.character(at: start - 1)) { break }
            start -= 1
        }
        while start < end, isWhitespace(text.character(at: start)) { start += 1 }
        guard start < end else { return nil }

        let sentenceRange = NSRange(location: start, length: end - start)
        var processIdentifier: pid_t = 0
        AXUIElementGetPid(element, &processIdentifier)
        return FocusedSentence(
            element: element,
            processIdentifier: processIdentifier,
            fullValue: value,
            range: CFRange(location: sentenceRange.location, length: sentenceRange.length),
            sentence: text.substring(with: sentenceRange)
        )
    }

    static func replace(_ context: FocusedSentence, with translated: String) throws {
        guard let currentValue: String = copyAttribute(context.element, kAXValueAttribute as CFString),
              currentValue == context.fullValue else { throw FocusedTextError.focusChanged }

        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == context.processIdentifier else {
            throw FocusedTextError.focusChanged
        }

        let canSetSelectedText = isSettable(context.element, kAXSelectedTextAttribute as CFString)
        let canSetValue = isSettable(context.element, kAXValueAttribute as CFString)

        // Terminal emulators and some web-based editors expose readable text but neither
        // writable selected text nor a writable value. Erase the just-typed sentence at
        // the insertion point instead of creating an Accessibility selection they cannot replace.
        if !canSetSelectedText && !canSetValue {
            try KeyboardReplacement.eraseAndInsert(original: context.sentence, replacement: translated)
            return
        }

        var range = context.range
        guard let rangeValue = AXValueCreate(.cfRange, &range) else { throw FocusedTextError.replacementUnsupported }

        let selectResult = canSetSelectedText
            ? AXUIElementSetAttributeValue(context.element, kAXSelectedTextRangeAttribute as CFString, rangeValue)
            : .attributeUnsupported
        if selectResult == .success, canSetSelectedText {
            let replaceResult = AXUIElementSetAttributeValue(context.element, kAXSelectedTextAttribute as CFString, translated as CFString)
            if replaceResult == .success { return }

            // Rich editors commonly allow selecting through AX but reject setting
            // AXSelectedText. A Unicode keyboard event replaces the active selection.
            try KeyboardReplacement.insert(translated)
            return
        }

        guard canSetValue else { throw FocusedTextError.replacementUnsupported }

        let mutable = NSMutableString(string: currentValue)
        mutable.replaceCharacters(in: NSRange(location: range.location, length: range.length), with: translated)
        guard AXUIElementSetAttributeValue(context.element, kAXValueAttribute as CFString, mutable as CFString) == .success else {
            throw FocusedTextError.replacementUnsupported
        }

        var newSelection = CFRange(location: range.location + (translated as NSString).length, length: 0)
        if let newSelectionValue = AXValueCreate(.cfRange, &newSelection) {
            AXUIElementSetAttributeValue(context.element, kAXSelectedTextRangeAttribute as CFString, newSelectionValue)
        }
    }

    private static func copyAttribute<T>(_ element: AXUIElement, _ attribute: CFString) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        return value as? T
    }

    private static func isSettable(_ element: AXUIElement, _ attribute: CFString) -> Bool {
        var settable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(element, attribute, &settable) == .success && settable.boolValue
    }

    private static func isPunctuation(_ codeUnit: unichar) -> Bool {
        codeUnit == 46 || codeUnit == 33 || codeUnit == 63 // . ! ?
    }

    private static func isTerminator(_ codeUnit: unichar) -> Bool {
        isPunctuation(codeUnit) || codeUnit == 10 || codeUnit == 13 // LF / CR
    }

    private static func isWhitespace(_ codeUnit: unichar) -> Bool {
        guard let scalar = UnicodeScalar(codeUnit) else { return false }
        return CharacterSet.whitespacesAndNewlines.contains(scalar)
    }
}

enum KeyboardReplacement {
    static let eventMarker: Int64 = 0x564552424154494D // "VERBATIM"

    static func eraseAndInsert(original: String, replacement: String) throws {
        // The original text was just typed, so one Delete per grapheme removes it from
        // shell prompts and non-AX-writable editors without touching the clipboard.
        for _ in original {
            try postKey(keyCode: 51, keyDown: true)
            try postKey(keyCode: 51, keyDown: false)
        }
        try insert(replacement)
    }

    static func insert(_ text: String) throws {
        let codeUnits = Array(text.utf16)
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)
        else { throw FocusedTextError.keyboardEventUnavailable }

        down.setIntegerValueField(.eventSourceUserData, value: eventMarker)
        up.setIntegerValueField(.eventSourceUserData, value: eventMarker)
        codeUnits.withUnsafeBufferPointer { buffer in
            down.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress)
            up.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress)
        }
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    private static func postKey(keyCode: CGKeyCode, keyDown: Bool) throws {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: keyDown) else {
            throw FocusedTextError.keyboardEventUnavailable
        }
        event.setIntegerValueField(.eventSourceUserData, value: eventMarker)
        event.post(tap: .cghidEventTap)
    }
}
