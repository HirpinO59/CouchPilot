# Security Policy

CouchPilot asks for the Accessibility permission, which is one of the most powerful things you can grant an app on macOS. That deserves a straight answer about what it does with it, and a way to tell me when something looks wrong.

## Reporting a vulnerability

Email **gamerfromif95@gmail.com** with `CouchPilot security` in the subject.

Please don't open a public issue for a security problem — send the email first so it can be fixed before it's public.

Include the app version (menu → the version is in the pre-filled report), your macOS version, and what you found. A proof of concept helps but isn't required.

**What to expect:** this is a one-person project, not a company. I'll acknowledge within a few days and tell you honestly whether I can fix it and when. If I can't, I'll say so publicly rather than leave it quiet.

## What the app can and cannot do

- **The Accessibility permission is used to *generate* input**: mouse movement, clicks, scrolling and key presses. That is what makes a controller able to drive the Mac.
- **There is one place where CouchPilot reads input**, and only one: while you are recording a binding in the Keybinds screen, it opens a CGEvent tap to capture the key, combination or click you press — including media keys, which macOS never delivers to apps as ordinary key events. The tap closes when you finish, when the window loses focus, when it's closed, and in any case after 20 seconds. Nothing you press is stored except the binding you chose. It is one file, readable end to end: [`Sources/CouchPilot/InputCapture.swift`](Sources/CouchPilot/InputCapture.swift).
- **There is no network code in the app.** No servers, no analytics, no telemetry, no update check. You can confirm it: `otool -L` on the binary links no networking library, and `grep -r URLSession Sources/` returns nothing. Menu items that open GitHub or Ko-fi hand a URL to your browser; the app itself never connects anywhere.
- **Nothing is collected.** Preferences live in `UserDefaults`; a technical log lives at `~/Library/Logs/CouchPilot.log`. Both stay on your Mac.
- **Battery reading** runs `system_profiler` locally, because Xbox pads over Bluetooth don't report battery through Apple's GameController API.

## Verifying what you downloaded

Releases are code-signed but **not notarized** — notarization requires a paid Apple Developer membership, which this free app doesn't have. That means macOS will warn you on first launch, and it also means you should check what you got:

```bash
# the signature is intact and nothing was tampered with after building
codesign --verify --deep --strict --verbose=2 /Applications/CouchPilot.app

# who signed it
codesign -dv --verbose=4 /Applications/CouchPilot.app 2>&1 | grep Authority

# the file matches the SHA-256 published in the release notes
shasum -a 256 ~/Downloads/CouchPilot-1.0.0.dmg
```

`spctl -a` will say `rejected`. That is Gatekeeper reporting the missing notarization, not a problem with the bundle.

If you'd rather not trust a download at all, build it yourself: `./build.sh install` signs with an identity from your own keychain and raises no warnings.

## Supported versions

The latest release is the only supported version. Fixes go into the next release; there are no backports.

| Version | Supported |
|---|---|
| 1.0.x | ✅ |
