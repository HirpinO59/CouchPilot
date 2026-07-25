<p align="center">
  <img src="docs/images/icon.png" width="140" alt="CouchPilot">
</p>

<h1 align="center">CouchPilot</h1>

<p align="center">
  <b>Control your Mac from the couch with a game controller.</b><br>
  Cursor, clicks, scrolling, media keys, Mission Control — from a menu bar app with no dependencies,
  no network code and nothing to configure before it works.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-black" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-5.9-orange" alt="Swift 5.9">
  <img src="https://img.shields.io/badge/dependencies-none-brightgreen" alt="No dependencies">
  <img src="https://img.shields.io/badge/data%20collected-none-brightgreen" alt="No data collected">
</p>

<p align="center">
  <a href="README.it.md">Leggilo in italiano</a>
</p>

<p align="center">
  <img src="docs/images/demo.gif" width="640" alt="Browsing YouTube, opening Mission Control and switching apps with a controller">
</p>

---

Written in Swift with **zero external dependencies** and **zero data collection**. Connect a controller and your Mac answers to it — no configuration required to start.

## Features

- **Cursor** on the left stick — smooth sub-pixel movement, adjustable speed, deadzone and response curve, multi-monitor aware
- **Click, drag, double click, right click** on A and X
- **Scrolling** (vertical and horizontal) on the right stick
- **Media keys**: play/pause, volume with hold-to-repeat, previous/next track
- **Mission Control, Spaces, Show Desktop** — invoked through *your* configured macOS shortcuts, so remappings are respected
- **Precision mode** (hold R2, ¼ speed) and **turbo** (hold L2, ×2) for cursor and scrolling
- **Every button is remappable** from a visual keybinds screen, and the binding is *recorded, not picked from a list*: click the action next to the drawing of *your* controller, take one of the three suggestions for that button, or hit **Record input** and press any key, key combination or mouse button — it gets copied verbatim. 12 buttons, plus each stick's movement (cursor, scroll or nothing) set separately from the stick click
- **Controller battery indicator** in the menu, macOS style
- **Auto-pause in games**: when a game or a chosen app (GeForce Now and Steam are preloaded) is frontmost, CouchPilot steps aside and the controller belongs to the game
- **Localized**: English, Italian, Spanish, Simplified Chinese — follows the system language by default
- **Quick guide** on first launch: an intro card, the on/off command, and the keybinds screen — with the diagram and button names matching the controller you actually have (View + Menu on Xbox, Create + Options on DualSense). Recallable any time from the menu
- Global on/off: hold **View + Menu** together for 2 seconds, both ways. Each of the two also has its own job when pressed alone — View is remappable, Menu opens the menu bar menu

## Controls

| Input | Action |
|---|---|
| Left stick | Move the cursor |
| A | Left click (hold to drag) |
| X | Right click |
| Right stick | Scroll vertically/horizontally |
| B | Mission Control |
| Y | Play/Pause |
| D-pad up/down | Volume up/down (hold to repeat) — configurable |
| D-pad left/right | Previous / next track — configurable |
| LB / RB | Previous / next Space |
| R2 (hold) | Precision: ¼ speed |
| L2 (hold) | Turbo: ×2 speed |
| L3 / R3 | Configurable — defaults: Mute / Middle click |

Every button in this table can be reassigned from **Keybinds** in the menu — except View + Menu, reserved for the on/off command.
| View (⧉) alone | Show Desktop — remappable. Fires on release, so it doesn't go off when View is part of the on/off combo |
| Menu (☰) alone | Opens the CouchPilot menu bar menu — fixed, not remappable |
| View (⧉) + Menu (☰) together, 2 s | Switches CouchPilot on and off, both ways |

The app activates when a controller connects and deactivates when it disconnects (releasing any held button, so a drag never gets stuck).

## Requirements

- macOS 14 or later
- A game controller macOS recognises as an extended gamepad: Xbox Wireless, DualSense, DualShock 4, Switch Pro and MFi pads. Button names differ across brands but the layout maps to the same positions (A = Cross, View = Create/Share, Menu = Options/Start). Developed and tested on an Xbox Wireless Controller.

## Install

### From a release

1. Download `CouchPilot-1.0.0.dmg` from [Releases](../../releases), open it and drag **CouchPilot** onto the **Applications** shortcut.

2. **Open it once and let macOS refuse.** Double-click CouchPilot in Applications; a dialog says it can't be opened because Apple can't check it for malicious software. Click **Done** — this step is not optional, it is what makes the next one appear.

3. Open **System Settings → Privacy & Security**, scroll down to **Security**. There is now a line saying CouchPilot was blocked, with an **"Open Anyway"** button. Click it, authenticate, and confirm in the last dialog. You only do this once.

4. Grant the **Accessibility** permission when asked (System Settings → Privacy & Security → Accessibility). CouchPilot needs it to move the cursor and press keys — the menu bar icon shows ⚠️ until granted, and a menu item takes you straight to the right pane.

Prefer the terminal? One line does steps 2 and 3 at once:

```bash
xattr -dr com.apple.quarantine /Applications/CouchPilot.app
```

CouchPilot lives in the menu bar: it has **no Dock icon and no window**, so it won't show up in Launchpad. Look for the controller icon next to the clock.

<details>
<summary><b>Why does macOS block it?</b></summary>

Because CouchPilot is **not notarized**. Notarizing means uploading each build to Apple for an automated malware scan, and that requires a paid Apple Developer Program membership (99 €/year). This is a free app that collects nothing and makes no money, so it doesn't have one.

The app *is* code-signed, and the signature is intact — you can check it yourself before trusting it:

```bash
codesign --verify --deep --strict --verbose=2 /Applications/CouchPilot.app
spctl -a -vvv /Applications/CouchPilot.app
```

The first command confirms nothing has been tampered with since it was built. The second will say `rejected`: that is Gatekeeper reporting the missing notarization, not a problem with the app.

If you'd rather not take anyone's word for it, **build it yourself** from the section below — the source is all here, it takes one command, and a build signed on your own Mac raises no warnings at all.
</details>

### From source (no Gatekeeper prompts)

```bash
git clone https://github.com/HirpinO59/CouchPilot.git
cd CouchPilot
./build.sh install   # builds and installs into /Applications (plain ./build.sh only builds)
```

Requires the Xcode Command Line Tools (`xcode-select --install`). The script builds with Swift Package Manager, assembles the bundle, generates the icon from code and signs with whatever identity it finds in your keychain (ad-hoc otherwise).

## Settings

Everything lives in the menu bar icon → **Settings**: cursor and scroll speed presets, stick deadzone, response curve, R2/L2 factors, L3/R3 actions, excluded apps, auto-pause in games, language, reset. Changes take effect immediately.

Advanced values outside the presets can be set from the terminal (`UserDefaults` domain `com.hirpino.couchpilot`):

```bash
defaults write com.hirpino.couchpilot maxSpeed -float 1800
```

| Key | Default | Meaning |
|---|---|---|
| `deadzone` | 0.15 | Radial deadzone of the cursor stick |
| `exponent` | 2.0 | Response curve (higher = more precision at low deflection) |
| `maxSpeed` | 1400 | Max cursor speed (px/s) |
| `scrollDeadzone` | 0.20 | Deadzone of the scroll stick |
| `scrollSpeed` | 700 | Max scroll speed (px/s) |
| `precisionFactor` | 0.25 | Speed multiplier while R2 is held |
| `boostFactor` | 2.0 | Speed multiplier while L2 is held |
| `actionL3` / `actionR3` | mute / middleClick | Stick-button actions |
| `actionDpadUp` … `actionDpadRight` | volume / track | D-pad actions, `none` to leave the direction free |
| `excludedApps` | GeForce Now, Steam | Bundle ids that auto-pause CouchPilot |
| `autoPauseGames` | true | Auto-pause when the frontmost app declares itself a game |
| `language` | auto | Menu language: `auto`, `it`, `en`, `es`, `zh` |
| `debugLog` | false | Log stick values twice a second (Console.app) |

## Privacy

CouchPilot collects nothing. There is **no network code** in the app — no servers, no analytics, no telemetry. Preferences and a small technical log (`~/Library/Logs/CouchPilot.log`) stay on your Mac.

The Accessibility permission is used to *generate* mouse and keyboard events. CouchPilot reads input in exactly one place: while you are recording a binding in the Keybinds screen, it opens an event tap so it can capture the key, combination or click you press — including media keys, which macOS never delivers to apps as ordinary key events. That tap exists only during the recording: it closes when you finish, when the window loses focus or is closed, and in any case after 20 seconds. Nothing you press is stored except the one binding you chose, and nothing ever leaves your Mac. It lives in one file you can read end to end: [`InputCapture.swift`](Sources/CouchPilot/InputCapture.swift).

## Known limitations

- Xbox controllers over Bluetooth don't report battery through Apple's GameController API; CouchPilot reads the level from the system's Bluetooth stack instead. Some controllers may show no battery at all.
- Brightness actions may have no effect on external displays (macOS limitation).
- Don't run other controller-mapping apps (Controlly, Enjoyable…) at the same time: both would emit events and inputs double up.
- Xbox controllers auto-sleep after ~15 minutes of inactivity — that's the controller, not the app.
- macOS itself lets a connected controller navigate some system interfaces (Spotlight, Launchpad) with the D-pad, and that cannot be turned off in System Settings. If a D-pad action of yours fires *while* macOS is also moving the selection, set that direction to **No action** in Keybinds.

## Roadmap

Per-app profiles (1.1)

## Feedback

Use **"Report an issue or idea…"** in the app menu — it opens a pre-filled issue with the technical details already attached (visible and editable before you send) — or [open an issue](../../issues) directly.

No GitHub account? The menu also has **"Send an email…"**, which opens a draft to `gamerfromif95@gmail.com` with the same details filled in. Nothing is sent until you press send.

## Support

CouchPilot is free and always will be. If it saved you a trip across the room, you can [buy me a coffee](https://ko-fi.com/hirpino59) — entirely optional, and it changes nothing about the app.

## Security

How the Accessibility permission is used, the one place the app reads input, and how to verify a download before trusting it: [SECURITY.md](SECURITY.md). Vulnerabilities go to `gamerfromif95@gmail.com`, not to a public issue.

## License

The source is published so you can see exactly what the app does with the Accessibility permission, and so you can build it yourself instead of trusting a download.

**It is not open source** — [source-available](LICENSE) is the accurate word. You may read the code and build it for your own use; you may not redistribute it or publish modified versions. If you want to do something the licence doesn't cover, ask — the answer will probably be yes.

---

© 2026 HirpinO. All rights reserved.
