# Changelog

## Unreleased

- The quick guide's second card is now the demo and nothing else: no title, no text, a looping muted clip. It ships as H.264 rather than a GIF — same weight, three times the pixels and three times the frames
- `Tools/videotoclip.swift` turns any screen recording into that clip, speeding it up on its own to fit the requested length

- Keybinds are now **recorded, not picked from a list**: choose one of the three suggestions for that button, or hit *Record input* and press any key, key combination or mouse button — CouchPilot copies it verbatim
- Each stick's **movement** is configurable on its own, separately from the stick click: cursor, scroll or nothing
- Keybinds screen redesigned: title and fixed commands on top, bigger labels, and leader lines that never overlap or cross
- Quick guide rewritten: intro card with Send feedback and Buy Me a Coffee buttons and a 1.1 preview, a dedicated on/off card with room for a demo GIF, and a Back button
- The intro card now asks for the Accessibility permission when it's missing, with a button that opens the right settings pane — and turns into a confirmation by itself as soon as it's granted
- The toggle buttons are named after the connected pad everywhere: View + Menu on Xbox, Create + Options on DualSense
- Menu (Options on DualSense) pressed alone opens the CouchPilot menu bar menu — and since the cursor keeps working, you can drive that menu with the pad
- The on/off command now takes a 2-second hold **both ways**, not just to switch back on: View and Menu each do something on their own now, so the combo has to be deliberate
- View (Create on DualSense) is remappable too, with its own callout above the drawing. Its action fires on release and is skipped if Menu was pressed too, so the on/off combo never triggers it
- Fixed: View alone stopped doing anything when the on/off command moved to View + Menu; Show Desktop is back as its default
- Fixed: an "Xbox Wireless Controller" was drawn as a DualSense, because the generic DualShock name is a substring of it
- Fixed: the input-recording prompt could overflow its box; it now sizes itself to the text

## 1.0.0 — 2026-07-24

First release.

- Cursor on the left stick with sub-pixel precision, radial deadzone, response curve, multi-monitor clamping
- Click, drag, double click, right click (A / X), middle click available on stick buttons
- Vertical and horizontal scrolling on the right stick
- Media keys: play/pause, volume with hold-to-repeat, track skip
- Mission Control, Spaces, Show Desktop via the user's configured shortcuts (read from `com.apple.symbolichotkeys` at every press)
- Precision (R2) and turbo (L2) speed modifiers
- Configurable L3/R3 actions (11 choices)
- Auto-pause when a game or an excluded app is frontmost; GeForce Now and Steam preloaded
- Controller battery indicator in the menu (GameController API with Bluetooth fallback for Xbox pads)
- Global toggle on long-press of the Menu (☰) button
- Settings menu with presets for every parameter
- Localization: English, Italian, Spanish, Simplified Chinese (auto-follows system language)
- Stick drift calibration
- Launch at login
- Pre-filled GitHub issue reporting from the menu
