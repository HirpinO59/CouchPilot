import AppKit
import GameController
import QuartzCore

// Frame degli schermi in coordinate CGEvent (origine in alto a sinistra del principale).
struct ScreenMap {
    let rects: [CGRect]

    static func current() -> ScreenMap {
        let screens = NSScreen.screens
        guard let primary = screens.first else {
            return ScreenMap(rects: [CGRect(x: 0, y: 0, width: 1920, height: 1080)])
        }
        // NSScreen ha origine in basso a sinistra: la conversione usa l'altezza del principale
        let primaryHeight = primary.frame.maxY
        return ScreenMap(rects: screens.map {
            CGRect(x: $0.frame.minX, y: primaryHeight - $0.frame.maxY,
                   width: $0.frame.width, height: $0.frame.height)
        })
    }

    func clamp(_ p: CGPoint) -> CGPoint {
        if rects.contains(where: { $0.contains(p) }) { return p }
        var best = p
        var bestDist = CGFloat.greatestFiniteMagnitude
        for r in rects {
            let q = CGPoint(x: min(max(p.x, r.minX), r.maxX - 1),
                            y: min(max(p.y, r.minY), r.maxY - 1))
            let d = hypot(q.x - p.x, q.y - p.y)
            if d < bestDist { bestDist = d; best = q }
        }
        return best
    }
}

// Loop a 120 Hz che campiona gli stick e posta gli eventi.
// Tutto lo stato vive su `queue`; dall'esterno si entra solo con i metodi pubblici.
final class CursorDriver {
    private let poster = EventPoster()
    private let queue = DispatchQueue(label: "com.hirpino.couchpilot.driver", qos: .userInteractive)
    private var timer: DispatchSourceTimer?
    private var gamepad: GCExtendedGamepad?

    private var posX = 0.0, posY = 0.0
    private var wasMoving = false
    private var leftDown = false
    private var rightDown = false
    private var scrollResX = 0.0, scrollResY = 0.0
    private var lastTick = 0.0
    private var lastDebugLog = 0.0
    private var screenMap = ScreenMap.current()
    private var enabled = true
    private var suspended = false

    // Parametri in cache: rileggerli dalle preferenze a 120 Hz è lavoro inutile.
    // Il refresh ogni 60 tick (0,5 s) mantiene l'effetto immediato del menu.
    private var tunables = Tunables.load()
    private var ticksSinceReload = 0

    private var calibrating = false
    private var calibEnd = 0.0
    private var calibSamples = 0
    private var calibSum = (rx: 0.0, ry: 0.0, lx: 0.0, ly: 0.0)

    // Stato dei tasti assegnabili, per id.
    private struct ButtonState {
        var pressed = false
        var since = 0.0
        var lastRepeat = 0.0
    }
    private var buttonStates: [String: ButtonState] = [:]

    // View + Menu insieme. Spegnere è immediato (serve al volo, quando il pad
    // deve tornare a un'altra app); riaccendere richiede due secondi, così non
    // succede per sbaglio mentre il pad è in mano per altro.
    private var togglePairFired = false
    private var comboHeldSince = 0.0
    private static let comboHoldToEnable = 2.0

    // callback sul main thread
    var onEnabledChanged: ((Bool) -> Void)?
    var onCalibrationDone: (() -> Void)?

    func start(gamepad: GCExtendedGamepad) {
        queue.async {
            self.gamepad = gamepad
            self.lastTick = 0
            self.wasMoving = false
            self.togglePairFired = false
            self.comboHeldSince = 0
            self.buttonStates.removeAll()
            self.tunables = Tunables.load()
            self.syncPositionFromSystem()
            guard self.timer == nil else { return }
            let t = DispatchSource.makeTimerSource(flags: .strict, queue: self.queue)
            t.schedule(deadline: .now(), repeating: 1.0 / 120.0, leeway: .microseconds(500))
            t.setEventHandler { [weak self] in self?.tick() }
            t.resume()
            self.timer = t
        }
    }

    func stop() {
        queue.async {
            self.releaseButtons()
            self.gamepad = nil
            self.calibrating = false
            self.timer?.cancel()
            self.timer = nil
        }
    }

    func setEnabled(_ on: Bool) {
        queue.async { self.applyEnabled(on) }
    }

    // Pausa automatica quando un'app esclusa è in primo piano: il pad resta al gioco.
    func setSuspended(_ on: Bool) {
        queue.async {
            guard self.suspended != on else { return }
            self.suspended = on
            if on {
                self.releaseButtons()
                self.wasMoving = false
                // una pressione iniziata prima della pausa non deve valere al rientro
                self.togglePairFired = false
                self.comboHeldSince = 0
                self.buttonStates.removeAll()
            }
        }
    }

    func updateScreens(_ map: ScreenMap) {
        queue.async { self.screenMap = map }
    }

    func calibrate(duration: TimeInterval = 2.0) {
        queue.async {
            guard self.gamepad != nil else { return }
            self.calibrating = true
            self.calibEnd = CACurrentMediaTime() + duration
            self.calibSamples = 0
            self.calibSum = (0, 0, 0, 0)
        }
    }

    // MARK: - Loop

    private func tick() {
        let now = CACurrentMediaTime()
        let dt = lastTick == 0 ? 1.0 / 120.0 : min(now - lastTick, 0.05)
        lastTick = now
        guard let pad = gamepad else { return }
        // in pausa niente input, nemmeno ☰: nei giochi quel tasto ha altri usi
        guard !suspended else { return }

        // View + Menu insieme = toggle globale. I due tasti a specchio non si
        // premono per sbaglio, e va letto anche quando l'app è disattivata.
        let menu = pad.buttonMenu.isPressed
        let view = pad.buttonOptions?.isPressed ?? false
        if menu && view {
            if !togglePairFired {
                if enabled {
                    togglePairFired = true
                    applyEnabled(false)
                } else if comboHeldSince == 0 {
                    comboHeldSince = now
                } else if now - comboHeldSince >= Self.comboHoldToEnable {
                    togglePairFired = true
                    applyEnabled(true)
                }
            }
        } else if !menu && !view {
            togglePairFired = false
            comboHeldSince = 0
        }

        if calibrating {
            calibSum.rx += Double(pad.rightThumbstick.xAxis.value)
            calibSum.ry += Double(pad.rightThumbstick.yAxis.value)
            calibSum.lx += Double(pad.leftThumbstick.xAxis.value)
            calibSum.ly += Double(pad.leftThumbstick.yAxis.value)
            calibSamples += 1
            if now >= calibEnd { finishCalibration() }
            return
        }

        guard enabled else { return }
        ticksSinceReload += 1
        if ticksSinceReload >= 60 {
            ticksSinceReload = 0
            tunables = Tunables.load()
        }
        let s = tunables

        // trigger: R2 tenuto = precisione, L2 tenuto = turbo (su cursore e scroll)
        var speedScale = 1.0
        if pad.rightTrigger.isPressed { speedScale *= s.precisionFactor }
        if pad.leftTrigger.isPressed { speedScale *= s.boostFactor }

        // stick sinistro -> cursore
        let cx = Double(pad.leftThumbstick.xAxis.value) - s.offsetLX
        let cy = Double(pad.leftThumbstick.yAxis.value) - s.offsetLY
        let (vx, vy, moving) = Self.velocity(x: cx, y: cy, deadzone: s.deadzone,
                                             exponent: s.exponent, maxSpeed: s.maxSpeed * speedScale)
        if moving {
            // riparte da dove sta davvero il puntatore (l'utente può aver mosso il mouse)
            if !wasMoving { syncPositionFromSystem() }
            let oldX = posX.rounded(), oldY = posY.rounded()
            posX += vx * dt
            posY -= vy * dt // GameController: Y+ verso l'alto; CGEvent: Y+ verso il basso
            let clamped = screenMap.clamp(CGPoint(x: posX, y: posY))
            posX = clamped.x
            posY = clamped.y
            let newX = posX.rounded(), newY = posY.rounded()
            if newX != oldX || newY != oldY {
                poster.move(to: CGPoint(x: newX, y: newY),
                            dx: Int(newX - oldX), dy: Int(newY - oldY),
                            leftDown: leftDown, rightDown: rightDown)
            }
        }
        wasMoving = moving

        pollSystemButtons(pad, tunables: s, now: now)

        // stick destro -> scroll
        let srx = Double(pad.rightThumbstick.xAxis.value) - s.offsetRX
        let sry = Double(pad.rightThumbstick.yAxis.value) - s.offsetRY
        let (sx, sy, scrolling) = Self.velocity(x: srx, y: sry, deadzone: s.scrollDeadzone,
                                                exponent: s.exponent, maxSpeed: s.scrollSpeed * speedScale)
        if scrolling {
            scrollResY += sy * dt // stick su = scroll su (wheel1 positivo)
            scrollResX -= sx * dt // stick a destra = contenuto verso destra (wheel2 negativo)
            let wy = Int32(scrollResY), wx = Int32(scrollResX)
            if wy != 0 || wx != 0 {
                scrollResY -= Double(wy)
                scrollResX -= Double(wx)
                poster.scroll(vertical: wy, horizontal: wx)
            }
        } else {
            scrollResX = 0
            scrollResY = 0
        }

        if s.debugLog, now - lastDebugLog > 0.5 {
            lastDebugLog = now
            NSLog(String(format: "CouchPilot: L(%.3f, %.3f) R(%.3f, %.3f) pos(%.0f, %.0f)",
                         cx, cy, srx, sry, posX, posY))
        }
    }

    // Ogni tasto esegue l'azione che gli è stata assegnata (Keybinds.swift).
    private func pollSystemButtons(_ pad: GCExtendedGamepad, tunables s: Tunables, now: Double) {
        var wantLeft = false
        var wantRight = false

        for button in PadButton.all {
            let action = s.bindings[button.id] ?? .none
            let pressed = button.isPressed(pad)
            var state = buttonStates[button.id] ?? ButtonState()

            if action.isHold {
                // il click resta premuto finché il tasto è premuto: il drag esce da qui
                if pressed {
                    if action == .leftClick { wantLeft = true } else { wantRight = true }
                }
            } else if pressed && !state.pressed {
                state.since = now
                state.lastRepeat = now
                perform(action)
            } else if pressed, action.repeatsWhenHeld,
                      now - state.since > 0.4, now - state.lastRepeat > 0.12 {
                state.lastRepeat = now
                perform(action)
            }

            state.pressed = pressed
            buttonStates[button.id] = state
        }

        applyMouseButtons(left: wantLeft, right: wantRight)
    }

    private func applyMouseButtons(left: Bool, right: Bool) {
        guard left != leftDown || right != rightDown else { return }
        let p = wasMoving ? CGPoint(x: posX.rounded(), y: posY.rounded()) : Self.systemLocation()
        posX = p.x
        posY = p.y
        if left != leftDown { leftDown = left; poster.left(down: left, at: p) }
        if right != rightDown { rightDown = right; poster.right(down: right, at: p) }
    }

    private func perform(_ action: PadAction) {
        switch action {
        case .none, .leftClick, .rightClick: break // gestiti come pressione continua
        case .middleClick: poster.middleClick(at: Self.systemLocation())
        case .mute: poster.mediaKey(.mute)
        case .playPause: poster.mediaKey(.play)
        case .volumeUp: poster.mediaKey(.soundUp)
        case .volumeDown: poster.mediaKey(.soundDown)
        case .previousTrack: poster.mediaKey(.previous)
        case .nextTrack: poster.mediaKey(.next)
        case .brightnessUp: poster.mediaKey(.brightnessUp)
        case .brightnessDown: poster.mediaKey(.brightnessDown)
        case .missionControl: poster.systemShortcut(.missionControl)
        case .showDesktop: poster.systemShortcut(.showDesktop)
        case .spaceLeft: poster.systemShortcut(.spaceLeft)
        case .spaceRight: poster.systemShortcut(.spaceRight)
        case .screenshotArea: poster.keyCombo(21, [.maskCommand, .maskShift]) // Cmd+Shift+4
        }
    }

    // MARK: - Helpers (solo su queue)

    private func applyEnabled(_ on: Bool) {
        guard enabled != on else { return }
        enabled = on
        if !on { releaseButtons() }
        wasMoving = false
        DispatchQueue.main.async { self.onEnabledChanged?(on) }
    }

    private func releaseButtons() {
        let p = CGPoint(x: posX.rounded(), y: posY.rounded())
        if leftDown { leftDown = false; poster.left(down: false, at: p) }
        if rightDown { rightDown = false; poster.right(down: false, at: p) }
    }

    private func finishCalibration() {
        calibrating = false
        let n = Double(max(calibSamples, 1))
        let d = UserDefaults.standard
        d.set(calibSum.rx / n, forKey: "offsetRX")
        d.set(calibSum.ry / n, forKey: "offsetRY")
        d.set(calibSum.lx / n, forKey: "offsetLX")
        d.set(calibSum.ly / n, forKey: "offsetLY")
        Log.write(String(format: "calibrazione — offset R(%.4f, %.4f) L(%.4f, %.4f)",
                         calibSum.rx / n, calibSum.ry / n, calibSum.lx / n, calibSum.ly / n))
        DispatchQueue.main.async { self.onCalibrationDone?() }
    }

    private func syncPositionFromSystem() {
        let p = Self.systemLocation()
        posX = p.x
        posY = p.y
    }

    private static func systemLocation() -> CGPoint {
        CGEvent(source: nil)?.location ?? .zero
    }

    // Deadzone radiale + riscalatura + curva di risposta -> velocità in px/s
    private static func velocity(x: Double, y: Double, deadzone: Double,
                                 exponent: Double, maxSpeed: Double) -> (Double, Double, Bool) {
        let mag = hypot(x, y)
        guard mag > deadzone, deadzone < 1 else { return (0, 0, false) }
        let norm = min((mag - deadzone) / (1 - deadzone), 1)
        let speed = pow(norm, exponent) * maxSpeed
        return (x / mag * speed, y / mag * speed, true)
    }
}
