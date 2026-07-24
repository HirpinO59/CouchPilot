import Foundation
import GameController

// Batteria del controller.
//
// `GCController.battery` è la via ufficiale e funziona su DualSense e simili,
// ma sui pad Xbox via Bluetooth riporta livello 0 e stato sconosciuto
// (verificato su macOS 26). Il dato però il sistema ce l'ha: sta nello stack
// Bluetooth, leggibile con `system_profiler` (~0,2 s). Quindi: si prova la via
// ufficiale e, se non risponde, si ripiega sul Bluetooth in background.
enum BatteryReader {
    struct Reading {
        let percent: Int
        let charging: Bool
    }

    // Via ufficiale, immediata. nil se il pad non espone davvero il dato.
    static func fromGameController(_ controller: GCController?) -> Reading? {
        guard let battery = controller?.battery else { return nil }
        guard battery.batteryState != .unknown else { return nil }
        let percent = Int((battery.batteryLevel * 100).rounded())
        guard percent > 0 else { return nil }
        return Reading(percent: percent, charging: battery.batteryState == .charging)
    }

    // Ripiego via Bluetooth: fuori dal thread principale, il processo esterno
    // non deve far attendere l'apertura del menu.
    static func fromBluetooth(deviceName: String, completion: @escaping (Reading?) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            let reading = readBluetooth(deviceName: deviceName)
            DispatchQueue.main.async { completion(reading) }
        }
    }

    private static func readBluetooth(deviceName: String) -> Reading? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        task.arguments = ["SPBluetoothDataType", "-json"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do { try task.run() } catch {
            Log.write("batteria: impossibile eseguire system_profiler — \(error.localizedDescription)")
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()

        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sections = root["SPBluetoothDataType"] as? [[String: Any]]
        else {
            Log.write("batteria: output di system_profiler non interpretabile (\(data.count) byte)")
            return nil
        }

        for section in sections {
            guard let connected = section["device_connected"] as? [[String: Any]] else { continue }
            for entry in connected {
                for (name, info) in entry {
                    guard name == deviceName, let fields = info as? [String: Any] else { continue }
                    guard let raw = fields["device_batteryLevelMain"] as? String else { return nil }
                    let digits = raw.trimmingCharacters(in: CharacterSet.decimalDigits.inverted)
                    guard let percent = Int(digits) else { return nil }
                    return Reading(percent: percent, charging: false)
                }
            }
        }
        return nil
    }
}
