# Changelog

## Unreleased

- ☰ pressed a second time now closes the menu instead of doing nothing. An open menu holds the main thread in its own tracking loop, so a second synthetic click never arrived; the driver sends Esc instead, straight from its own queue
- Added `LICENSE` (source-available, not open source) and `SECURITY.md`

## 1.0.0 — 2026-07-25

First release.

### Pointer and scrolling

- Cursor on the left stick with sub-pixel precision, radial deadzone, response curve and multi-monitor clamping
- Click, drag, double click and right click (A / X); middle click available on the stick buttons
- Vertical and horizontal scrolling on the right stick
- Precision (hold R2, ¼ speed) and turbo (hold L2, ×2), on both cursor and scrolling
- Each stick's **movement** is configurable on its own, separately from the stick click: cursor, scroll or nothing
- Stick drift calibration

### Keybinds

- Bindings are **recorded, not picked from a list**: every control offers the three most sensible choices for that button, then *Record input* — press any key, key combination or mouse button and it is copied verbatim
- Media keys (volume, play/pause, brightness) can be recorded too, and are swallowed while recording so assigning the volume key doesn't also change the volume
- Keys are stored by key code, so a binding survives a change of keyboard layout
- Visual keybinds screen drawn over a diagram of *your* controller, Xbox or DualSense, with the button names of that pad
- Mission Control, Spaces and Show Desktop are invoked through *your* configured macOS shortcuts, so remappings are respected
- View (Create) is remappable; Menu (Options) pressed alone opens the menu bar menu — and since the cursor keeps working, that menu is navigable with the pad
- Global on/off: hold View + Menu together for 2 seconds, both ways

### Around the app

- Menu bar only — no Dock icon, no window
- Controller battery indicator in macOS style (GameController API, with a Bluetooth fallback for Xbox pads, which don't report it)
- Auto-pause when a game or a chosen app is frontmost; GeForce Now and Steam preloaded
- Settings menu with presets for every parameter, all also reachable via `defaults write`
- Quick guide on first launch: an intro card, a demo clip, and the keybinds screen
- Launch at login
- Feedback from the menu, pre-filled with the technical details: a GitHub issue, or an email for people without an account
- Localized in English, Italian, Spanish and Simplified Chinese, following the system language by default
- No dependencies, no network code, no data collected
