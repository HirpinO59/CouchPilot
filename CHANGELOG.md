# Changelog

## 1.1.0 — 2026-07-26

Everything in this release comes from what people asked for after 1.0.0.

### Buttons are called by the names printed on *your* pad

- **The controller is now recognised by the profile it declares to macOS, not by its name.** The old check treated any pad whose name contained "Wireless Controller" as a PlayStation pad — which is right for a DualShock 4, and wrong for every third-party pad with a longer name. Those pads were shown a DualSense with ✕ ◯ ▢ △ on buttons labelled A B X Y
- **Triggers are named after the pad**: LT/RT on Xbox and 8BitDo, L2/R2 on PlayStation. They appear in the keybinds header and in Settings, where the two items now read *RT precision* / *LT boost* and follow the pad as it changes
- **8BitDo pads are recognised as their own family**, with their own diagram: Xbox-style letters, and the two centre buttons called − and + as they are on the pad. Asymmetric sticks, left stick above the D-pad, like the Ultimate Wireless this was drawn from
- **The DualSense diagram has been redrawn**, more faithful and in the same hand as the 8BitDo one. Brand logos are gone from both: where the PlayStation logo was there is now a plain empty circle, and the 8BitDo home button keeps its rings without the mark inside
- Every label anchor was re-measured on the new drawings, and the leader lines were checked pair by pair on all three pads: no crossings

### Other changes

- **Update checking**, and with it the first network request in the app's life — worth stating plainly, because up to 1.0.0 there was none and the README said so. CouchPilot asks GitHub's public API for the version number of the latest release, once at launch and at most once a day. Nothing is sent: no identifier, no usage data, User-Agent `CouchPilot` and nothing else. When there is a newer version the menu says so, and the click opens the releases page — downloading stays your move. **Settings → Check for updates** turns it off, and off means the app contacts nobody at all. It is one readable file, `UpdateCheck.swift`, and README and SECURITY.md have been rewritten to say exactly this
- **Keybinds opens as its own window**, no longer as the third page of the quick guide — no step dots, no *Next*, just the screen and a *Close* button
- **A button can now open an app.** In the keybinds screen, each button's menu has *Open an app…* — pick Steam, CrossOver, anything in Applications, and that button launches it (or brings it to the front if it's already running). Asked for on the first day by r/macgaming
- ☰ pressed a second time now closes the menu instead of doing nothing. An open menu holds the main thread inside its own tracking loop, so the second synthetic click never arrived; the driver sends Esc instead, straight from its own queue
- **Calibrate sticks** is gone from the menu. It sampled two seconds of stick rest position, which is not how drift actually behaves — it will come back when it works properly
- Added `LICENSE` (source-available, not open source) and `SECURITY.md`
- The connected pad's profile is now written to the log, so a report about the wrong diagram says at once whether the pad declared anything at all

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
