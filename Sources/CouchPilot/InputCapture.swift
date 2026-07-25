import AppKit
import CoreGraphics

enum CaptureResult {
    case captured(Binding)
    case cancelled
}

// Registra un input vero e proprio: quello che l'utente preme viene copiato
// tale e quale, combinazioni comprese.
//
// Serve un tap sugli eventi e non i normali monitor perché i tasti multimediali
// (volume, play, luminosità) non arrivano alle app come eventi di tastiera: il
// sistema li consegna come eventi NX_SYSDEFINED. Il tap è attivo — cioè si
// mangia gli eventi mentre registra — così premere il volume per assegnarlo non
// cambia anche il volume del Mac.
final class InputCapture {
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var monitors: [Any] = []
    private var bail: DispatchWorkItem?

    // Area in cui i click valgono come input da registrare. Fuori di qui il
    // mouse continua a funzionare normalmente, altrimenti non si potrebbe più
    // premere "Annulla" né chiudere la finestra.
    private var mouseArea = CGRect.zero
    private var onResult: ((CaptureResult) -> Void)?

    // NX_SYSDEFINED: il tipo degli eventi dei tasti media. Non è un case di
    // CGEventType, quindi si lavora sul valore grezzo e mai sull'enum.
    private static let systemDefinedRaw: UInt32 = 14
    private static let limit: TimeInterval = 20

    var isRunning: Bool { onResult != nil }

    func start(mouseArea: CGRect, onResult: @escaping (CaptureResult) -> Void) {
        stop()
        self.mouseArea = mouseArea
        self.onResult = onResult

        let mask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.leftMouseUp.rawValue)
            | (1 << CGEventType.rightMouseDown.rawValue)
            | (1 << CGEventType.rightMouseUp.rawValue)
            | (1 << CGEventType.otherMouseDown.rawValue)
            | (1 << CGEventType.otherMouseUp.rawValue)
            | (1 << Self.systemDefinedRaw)

        let callback: CGEventTapCallBack = { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let capture = Unmanaged<InputCapture>.fromOpaque(context).takeUnretainedValue()
            return capture.handle(type: type, event: event)
        }

        if let port = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                        place: .headInsertEventTap,
                                        options: .defaultTap,
                                        eventsOfInterest: CGEventMask(mask),
                                        callback: callback,
                                        userInfo: Unmanaged.passUnretained(self).toOpaque()) {
            tap = port
            runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: port, enable: true)
        } else {
            // Senza accessibilità il tap non parte: si registra lo stesso da
            // tastiera e mouse, si perdono solo i tasti media.
            Log.write("cattura input: tap non disponibile, uso i monitor locali")
            installLocalMonitors()
        }

        // Rete di sicurezza: un tap attivo dimenticato si mangerebbe la tastiera.
        let work = DispatchWorkItem { [weak self] in self?.cancel() }
        bail = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.limit, execute: work)
    }

    func cancel() {
        finish(.cancelled)
    }

    func stop() {
        bail?.cancel()
        bail = nil
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        tap = nil
        runLoopSource = nil
        for monitor in monitors { NSEvent.removeMonitor(monitor) }
        monitors.removeAll()
        onResult = nil
    }

    deinit { stop() }

    // MARK: - Eventi

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return pass
        }
        guard isRunning else { return pass }

        if type.rawValue == Self.systemDefinedRaw {
            guard let wrapped = NSEvent(cgEvent: event), wrapped.subtype.rawValue == 8 else { return pass }
            let code = Int32((wrapped.data1 & 0xFFFF0000) >> 16)
            guard let key = MediaKey(rawValue: code) else { return pass }
            if (wrapped.data1 & 0xFF00) >> 8 == 0x0A { finish(.captured(.media(key))) }
            return nil
        }

        switch type {
        case .keyDown:
            let code = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            handleKey(code, flags: event.flags)
            return nil
        case .flagsChanged:
            return nil   // i modificatori da soli non sono un'assegnazione
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            guard mouseArea.contains(event.location), let button = Self.button(for: type, event) else {
                return pass
            }
            finish(.captured(.mouse(button)))
            return nil
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            return mouseArea.contains(event.location) ? nil : pass
        default:
            return pass
        }
    }

    private static func button(for type: CGEventType, _ event: CGEvent) -> MouseButton? {
        switch type {
        case .leftMouseDown: return .left
        case .rightMouseDown: return .right
        default:
            // solo la rotellina: i tasti laterali del mouse non sono assegnabili
            return event.getIntegerValueField(.mouseEventButtonNumber) == 2 ? .middle : nil
        }
    }

    private func handleKey(_ code: CGKeyCode, flags rawFlags: CGEventFlags) {
        let flags = rawFlags.intersection(Binding.usefulFlags)
        switch (Int(code), flags.isEmpty) {
        case (53, true):            finish(.cancelled)                  // esc
        case (51, true), (117, true): finish(.captured(.none))          // ⌫ e ⌦ = nessuna azione
        default:                    finish(.captured(.key(code, flags)))
        }
    }

    private func finish(_ result: CaptureResult) {
        guard let handler = onResult else { return }
        onResult = nil          // da qui in poi gli eventi tornano a passare
        DispatchQueue.main.async {
            self.stop()
            handler(result)
        }
    }

    // MARK: - Ripiego senza tap

    private func installLocalMonitors() {
        let keyboard = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self, self.isRunning else { return event }
            self.handleKey(CGKeyCode(event.keyCode), flags: event.cgEvent?.flags ?? [])
            return nil
        }
        let mouse = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] event in
            guard let self, self.isRunning,
                  self.mouseArea.contains(Self.pointerInEventSpace()) else { return event }
            let button: MouseButton? = {
                switch event.type {
                case .leftMouseDown: return .left
                case .rightMouseDown: return .right
                default: return event.buttonNumber == 2 ? .middle : nil
                }
            }()
            guard let button else { return event }
            self.finish(.captured(.mouse(button)))
            return nil
        }
        monitors = [keyboard, mouse].compactMap { $0 }
    }

    // NSEvent misura dal basso a sinistra, CGEvent dall'alto: l'area arriva già
    // in coordinate CGEvent, quindi il puntatore va convertito.
    static func pointerInEventSpace() -> CGPoint {
        let location = NSEvent.mouseLocation
        let height = NSScreen.screens.first?.frame.maxY ?? 0
        return CGPoint(x: location.x, y: height - location.y)
    }
}
