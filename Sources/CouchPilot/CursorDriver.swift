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
        var vetoed = false   // solo View: durante la pressione è arrivato anche Menu
    }
    private var buttonStates: [String: ButtonState] = [:]

    // View + Menu tenuti insieme due secondi = accende e spegne, nei due sensi.
    // I due tasti hanno anche un'azione da soli, quindi la combinazione deve
    // volerci: due secondi la distinguono da una pressione qualsiasi.
    private var togglePairFired = false
    private var comboHeldSince = 0.0
    private static let comboHold = 2.0

    // Menu da solo apre il menu di CouchPilot. Come View, si guarda il rilascio
    // e si annulla se nel frattempo è arrivato l'altro tasto della coppia.
    private var menuPressed = false
    private var menuVetoed = false
    private var menuOpen = false


    // callback sul main thread
    var onEnabledChanged: ((Bool) -> Void)?
    var onCalibrationDone: (() -> Void)?
    var onOpenMenu: (() -> Void)?

    func start(gamepad: GCExtendedGamepad) {
        queue.async {
            self.gamepad = gamepad
            self.lastTick = 0
            self.wasMoving = false
            self.togglePairFired = false
            self.comboHeldSince = 0
            self.menuPressed = false
            self.menuVetoed = false
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
                self.menuPressed = false
                self.menuVetoed = false
                self.buttonStates.removeAll()
            }
        }
    }

    func updateScreens(_ map: ScreenMap) {
        queue.async { self.screenMap = map }
    }

    // Lo stato del menu arriva dall'AppDelegate: serve al driver per sapere se
    // il prossimo ☰ deve aprirlo o chiuderlo.
    func setMenuOpen(_ open: Bool) {
        queue.async { self.menuOpen = open }
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
                if comboHeldSince == 0 {
                    comboHeldSince = now
                } else if now - comboHeldSince >= Self.comboHold {
                    togglePairFired = true
                    applyEnabled(!enabled)
                }
            }
        } else if !menu && !view {
            togglePairFired = false
            comboHeldSince = 0
        }

        // Menu da solo apre il menu di CouchPilot. Sta qui e non fra i tasti
        // assegnabili perché è fisso, e va seguito anche ad app spenta: lo
        // stato dev'essere aggiornato comunque, altrimenti al riaccendersi una
        // pressione vecchia verrebbe letta come un rilascio appena avvenuto.
        if menu {
            if !menuPressed { menuVetoed = false }
            menuVetoed = menuVetoed || view
        } else if menuPressed, !menuVetoed, enabled {
            if menuOpen {
                // Un menu aperto tiene il thread principale nel suo ciclo di
                // tracciamento: un secondo click programmatico non arriverebbe
                // mai. Esc lo chiude, e parte da qui senza passare dal main.
                poster.keyCombo(53)
            } else {
                DispatchQueue.main.async { self.onOpenMenu?() }
            }
        }
        menuPressed = menu

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

        // Quale stick muove il cursore e quale scorre lo decide la configurazione.
        let lx = Double(pad.leftThumbstick.xAxis.value) - s.offsetLX
        let ly = Double(pad.leftThumbstick.yAxis.value) - s.offsetLY
        let rx = Double(pad.rightThumbstick.xAxis.value) - s.offsetRX
        let ry = Double(pad.rightThumbstick.yAxis.value) - s.offsetRY

        var vx = 0.0, vy = 0.0, moving = false
        var sx = 0.0, sy = 0.0, scrolling = false
        for (x, y, role) in [(lx, ly, s.leftStick), (rx, ry, s.rightStick)] {
            switch role {
            case .off:
                continue
            case .cursor:
                let (dx, dy, active) = Self.velocity(x: x, y: y, deadzone: s.deadzone,
                                                     exponent: s.exponent,
                                                     maxSpeed: s.maxSpeed * speedScale)
                if active { vx += dx; vy += dy; moving = true }
            case .scroll:
                let (dx, dy, active) = Self.velocity(x: x, y: y, deadzone: s.scrollDeadzone,
                                                     exponent: s.exponent,
                                                     maxSpeed: s.scrollSpeed * speedScale)
                if active { sx += dx; sy += dy; scrolling = true }
            }
        }

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
                         lx, ly, rx, ry, posX, posY))
        }
    }

    // Ogni tasto esegue l'input che gli è stato registrato (Keybinds.swift).
    private func pollSystemButtons(_ pad: GCExtendedGamepad, tunables s: Tunables, now: Double) {
        var wantLeft = false
        var wantRight = false

        for control in PadControl.buttons {
            let binding = s.bindings[control.id] ?? .none
            let pressed = control.isPressed(pad)
            var state = buttonStates[control.id] ?? ButtonState()

            if control.firesOnRelease {
                // View è anche metà del comando di accensione, che comincia
                // sempre con uno dei due tasti premuto per primo: se agisse
                // alla pressione, spegnere CouchPilot farebbe scattare anche
                // la sua azione. Quindi si guarda il rilascio, e solo se nel
                // frattempo Menu non è stato toccato.
                if pressed {
                    if !state.pressed { state.vetoed = false }
                    state.vetoed = state.vetoed || pad.buttonMenu.isPressed
                } else if state.pressed, !state.vetoed {
                    perform(binding)
                }
            } else if binding.isHold {
                // il click resta premuto finché il tasto è premuto: il drag esce da qui
                if pressed {
                    if binding == .mouse(.left) { wantLeft = true } else { wantRight = true }
                }
            } else if pressed && !state.pressed {
                state.since = now
                state.lastRepeat = now
                perform(binding)
            } else if pressed, binding.repeatsWhenHeld,
                      now - state.since > 0.4, now - state.lastRepeat > 0.12 {
                state.lastRepeat = now
                perform(binding)
            }

            state.pressed = pressed
            buttonStates[control.id] = state
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

    private func perform(_ binding: Binding) {
        switch binding {
        case .none: break
        case .mouse(.left), .mouse(.right): break   // gestiti come pressione continua
        case .mouse(.middle): poster.middleClick(at: Self.systemLocation())
        case .key(let code, let flags): poster.keyCombo(code, flags)
        case .media(let key): poster.mediaKey(key)
        case .system(let shortcut): poster.systemShortcut(shortcut)
        case .app(let id): Self.openApp(id)
        }
    }

    // Apre l'app, o la porta davanti se è già aperta — è quello che si aspetta
    // chi premerà quel tasto. NSWorkspace va usato dal thread principale.
    private static func openApp(_ bundleID: String) {
        DispatchQueue.main.async {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
                Log.write("apri app: \(bundleID) non è installata")
                return
            }
            let options = NSWorkspace.OpenConfiguration()
            options.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: options) { _, error in
                if let error { Log.write("apri app \(bundleID): \(error.localizedDescription)") }
            }
        }
    }

    // MARK: - Helpers (solo su queue)

    private func applyEnabled(_ on: Bool) {
        guard enabled != on else { return }
        enabled = on
        if !on { releaseButtons() }
        wasMoving = false
        // Mentre l'app è spenta i tasti non vengono letti, quindi lo stato
        // rimasto è vecchio: senza azzerarlo, un tasto che risulta ancora
        // premuto da prima verrebbe visto come appena rilasciato — e View,
        // che agisce proprio al rilascio, farebbe partire la sua azione da sé.
        buttonStates.removeAll()
        menuPressed = false
        menuVetoed = false
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
