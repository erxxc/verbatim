# Contributing

Thank you for helping improve Verbatim.

## Development

Verbatim targets macOS 26 Tahoe and uses Swift Package Manager.

```bash
swift build
swift run VerbatimMac
```

To package the menu-bar application:

```bash
./scripts/build-macos-app.sh
```

## Pull requests

Keep changes focused, explain their user impact, and test text replacement in TextEdit plus every application-specific path affected by the change. Preserve on-device translation by default. Never commit translated user content, credentials, `.build`, or packaged applications.

By participating, you agree to follow the project's [Code of Conduct](CODE_OF_CONDUCT.md). Security problems must be reported privately according to [SECURITY.md](SECURITY.md).

