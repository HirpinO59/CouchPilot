import Foundation
import GameController

// Osserva connessione/disconnessione dei controller. Ne guida uno alla volta.
final class ControllerMonitor {
    var onConnect: ((GCController) -> Void)?
    var onDisconnect: ((GCController) -> Void)?
    private(set) var current: GCController?

    func start() {
        let nc = NotificationCenter.default
        nc.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] note in
            guard let controller = note.object as? GCController else { return }
            self?.adopt(controller)
        }
        nc.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] note in
            guard let self, let controller = note.object as? GCController, controller === self.current else { return }
            self.current = nil
            Controllers.adopt(nil)
            NSLog("CouchPilot: controller disconnesso (%@)", controller.vendorName ?? "sconosciuto")
            self.onDisconnect?(controller)
            if let next = GCController.controllers().first(where: { $0.extendedGamepad != nil }) {
                self.adopt(next)
            }
        }
        if let already = GCController.controllers().first(where: { $0.extendedGamepad != nil }) {
            adopt(already)
        }
    }

    private func adopt(_ controller: GCController) {
        guard current == nil, controller !== current else { return }
        guard controller.extendedGamepad != nil else {
            NSLog("CouchPilot: controller senza profilo esteso, ignorato (%@)", controller.vendorName ?? "?")
            return
        }
        current = controller
        // Da qui in poi disegno e sigle seguono la famiglia del pad.
        Controllers.adopt(controller)
        Log.write("controller connesso (\(controller.vendorName ?? "sconosciuto")), \(Controllers.describe(controller))")
        onConnect?(controller)
    }
}
