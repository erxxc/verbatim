# Verbatim

An offline-first macOS menu-bar translator that replaces each completed sentence in place after you type `.`, `!`, or `?`.

[![CI](https://github.com/erxxc/verbatim/actions/workflows/ci.yml/badge.svg)](https://github.com/erxxc/verbatim/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## Run it

No installation is required. Start any static file server from this directory:

```bash
python3 -m http.server 4173
```

Then open `http://localhost:4173`.

Use `Cmd/Ctrl + Shift + M` to start or stop Macro mode. The direction button switches English → Russian and Russian → English instantly. With Macro mode off, Verbatim keeps the original and translation in a paired history.

## Macro integration

Browser macros and automation tools can call a stable page API:

```js
window.Verbatim.start();
window.Verbatim.stop();
window.Verbatim.toggle();
window.Verbatim.swap();
window.Verbatim.state();
```

Startup state can also be controlled from the URL:

- `?macro=1&direction=en-ru`
- `?macro=1&direction=ru-en`
- `?macro=0` to open with replacement disabled

Verbatim translates common phrases with an on-device phrasebook, then attempts broader translation through MyMemory. The interface itself can also be switched between English and Russian.

## Native macOS Tahoe helper

The Swift menu-bar helper in `Sources/VerbatimMac` extends sentence replacement to accessible text fields in other macOS applications.

- Watches globally for `.`, `!`, or `?`.
- Reads the sentence immediately before the insertion point through macOS Accessibility.
- Translates it with Apple's Translation framework.
- Replaces the original sentence in place.
- Lists every language supported by Apple Translation, sorting languages from installed keyboard/input sources first.
- Can follow the current keyboard automatically: switching between the selected two keyboard languages reverses translation direction without opening Verbatim.
- Runs without a dock icon and offers quick language swapping from the menu bar.

### Offline behavior

The native helper does **not** use MyMemory, another translation website, or an API key. Text is translated on the Mac using Apple's installed Translation models.

Before using a language pair, download both languages in:

**System Settings → General → Language & Region → Translation Languages**

Enable **On-Device Mode** there as well. Internet access is needed only for that one-time model download from Apple. Once the model is installed, normal translation and cross-application replacement work offline. The menu reports whether the selected pair is offline-ready or needs a download.

Keyboard/input-source languages and Translation languages are separate. Installing a keyboard layout makes it appear near the top of Verbatim's list, but Apple must also support the language and its Translation model must be downloaded.

### Build

This helper targets macOS 26 Tahoe:

```bash
chmod +x scripts/build-macos-app.sh
./scripts/build-macos-app.sh
open dist/Verbatim.app
```

The first launch may require Accessibility approval under **System Settings → Privacy & Security → Accessibility**. On some configurations, macOS may additionally request **Input Monitoring** permission for observing punctuation globally. Some secure fields, terminal emulators, games, and applications with incomplete Accessibility text support may not permit replacement.


## Contributing and security

Contributions are welcome; see [CONTRIBUTING.md](CONTRIBUTING.md). Report vulnerabilities privately according to [SECURITY.md](SECURITY.md). Verbatim is available under the [MIT License](LICENSE).
