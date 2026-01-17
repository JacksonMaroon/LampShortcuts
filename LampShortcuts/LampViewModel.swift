import Foundation
import os

@MainActor
final class LampViewModel: ObservableObject {
    @Published var peripherals: [LampBLEManager.PeripheralInfo] = []
    @Published var selectedName: String = "None"
    @Published var selectedID: String = ""
    @Published var statusMessage: String = ""
    @Published var bluetoothState: String = "Unknown"
    @Published var bluetoothAuthorization: String = "Unknown"
    @Published var scanState: String = "Idle"
    @Published var centralScanState: String = "Unknown"
    @Published var deviceCount: Int = 0
    @Published var discoveryCount: Int = 0
    @Published var lastDiscovery: String = "None"

    @Published var brightness: Double = 50
    @Published var color: LampColor = .white
    @Published var rgbR: String = "255"
    @Published var rgbG: String = "255"
    @Published var rgbB: String = "255"

    private var scanTask: Task<Void, Never>?
    private var scanTaskID: UUID?
    private var peripheralMap: [UUID: LampBLEManager.PeripheralInfo] = [:]

    private let manager = LampBLEManager.shared
    private let store = LampDeviceStore.shared
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "LampShortcuts",
                                category: "ViewModel")

    init() {
        logger.info("LampViewModel init")
        loadSelected()
        refreshBluetoothStatus()
    }

    deinit {
        logger.info("LampViewModel deinit")
    }

    func loadSelected() {
        selectedName = store.loadName() ?? "None"
        selectedID = store.loadID()?.uuidString ?? ""
    }

    func clearSelection() {
        store.clear()
        loadSelected()
    }

    func startScan() {
        logger.info("startScan tapped")
        stopScan(reason: "startScan")
        scanState = "Starting"
        statusMessage = "Checking Bluetooth..."
        peripheralMap.removeAll()
        peripherals.removeAll()
        deviceCount = 0

        let taskID = UUID()
        scanTaskID = taskID
        logger.info("scanTask create id=\(taskID.uuidString, privacy: .public)")
        scanTask = Task { @MainActor in
            do {
                logger.info("scanTask started id=\(taskID.uuidString, privacy: .public)")
                let stream = try await manager.startScan()
                statusMessage = "Scanning..."
                scanState = "Scanning"
                refreshBluetoothStatus()
                for await info in stream {
                    peripheralMap[info.id] = info
                    peripherals = peripheralMap.values.sorted { $0.rssi > $1.rssi }
                    deviceCount = peripherals.count
                }
                logger.info("scanTask stream ended id=\(taskID.uuidString, privacy: .public) cancelled=\(Task.isCancelled)")
            } catch {
                statusMessage = error.localizedDescription
                scanState = "Idle"
                refreshBluetoothStatus()
                logger.error("scanTask error \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func stopScan(reason: String = "unknown") {
        logger.info("stopScan tapped reason=\(reason, privacy: .public)")
        manager.stopScan()
        if let scanTaskID {
            logger.info("scanTask cancel id=\(scanTaskID.uuidString, privacy: .public) reason=\(reason, privacy: .public)")
        }
        scanTask?.cancel()
        scanTask = nil
        scanTaskID = nil
        if statusMessage == "Scanning..." {
            statusMessage = ""
        }
        scanState = "Idle"
        refreshBluetoothStatus()
    }

    func refreshBluetoothStatus() {
        let info = manager.debugInfo()
        bluetoothState = info.state
        bluetoothAuthorization = info.authorization
        scanState = info.isScanning ? "Scanning" : scanState
        centralScanState = info.centralIsScanning ? "Scanning" : "Not Scanning"
        discoveryCount = info.discoveryCount
        lastDiscovery = info.lastDiscovery
    }

    func selectPeripheral(_ info: LampBLEManager.PeripheralInfo) {
        statusMessage = "Connecting..."
        Task { @MainActor in
            do {
                try await manager.verifyPeripheral(id: info.id)
                store.save(id: info.id, name: info.name)
                loadSelected()
                statusMessage = "Lamp selected."
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    func sendPower(on: Bool) {
        Task { @MainActor in
            do {
                let id = try store.requireID()
                try await manager.sendSequence([LampCommands.power(on: on)], to: id)
                store.savePowerState(isOn: on)
                statusMessage = on ? "Lamp on." : "Lamp off."
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    func togglePower() {
        Task { @MainActor in
            do {
                let id = try store.requireID()
                let lastKnown = store.loadPowerState()
                let target = !(lastKnown ?? false)
                try await manager.sendSequence([LampCommands.power(on: target)], to: id)
                store.savePowerState(isOn: target)
                if lastKnown == nil {
                    statusMessage = "Lamp state unknown. Turning it \(target ? "on" : "off")."
                } else {
                    statusMessage = target ? "Lamp on." : "Lamp off."
                }
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    func toggleIntensity() {
        Task { @MainActor in
            do {
                let id = try store.requireID()
                let lastHSV = store.loadHSV()
                let hue = lastHSV?.h ?? 0
                let saturation = lastHSV?.s ?? 0
                let currentValue = lastHSV?.v ?? 100
                let targetValue = currentValue >= 75 ? 50 : 100
                let sequence = [
                    LampCommands.power(on: true),
                    LampCommands.color(h: hue, s: saturation, v: targetValue)
                ]
                try await manager.sendSequence(sequence, to: id)
                store.savePowerState(isOn: true)
                store.saveHSV(h: hue, s: saturation, v: targetValue)
                brightness = Double(targetValue)
                statusMessage = "Brightness set to \(targetValue)%."
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    func sendColor() {
        Task { @MainActor in
            do {
                let id = try store.requireID()
                let hsv = color.hsv
                let sequence = [
                    LampCommands.power(on: true),
                    LampCommands.color(h: hsv.h, s: hsv.s, v: hsv.v)
                ]
                try await manager.sendSequence(sequence, to: id)
                store.savePowerState(isOn: true)
                store.saveHSV(h: hsv.h, s: hsv.s, v: hsv.v)
                statusMessage = "Color set to \(color.displayName)."
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    func sendBrightness() {
        Task { @MainActor in
            do {
                let id = try store.requireID()
                let level = Int(brightness)
                let lastHSV = store.loadHSV()
                let hue = lastHSV?.h ?? 0
                let saturation = lastHSV?.s ?? 0
                let sequence = [
                    LampCommands.power(on: true),
                    LampCommands.color(h: hue, s: saturation, v: level)
                ]
                try await manager.sendSequence(sequence, to: id)
                store.savePowerState(isOn: true)
                store.saveHSV(h: hue, s: saturation, v: level)
                statusMessage = "Brightness set to \(level)%."
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    func sendRGB() {
        Task { @MainActor in
            do {
                let id = try store.requireID()
                guard let r = Int(rgbR), let g = Int(rgbG), let b = Int(rgbB) else {
                    statusMessage = "RGB values must be numbers."
                    return
                }
                let hsv = LampCommands.rgbToHSV(r: r, g: g, b: b)
                let sequence = [
                    LampCommands.power(on: true),
                    LampCommands.color(h: hsv.h, s: hsv.s, v: hsv.v)
                ]
                try await manager.sendSequence(sequence, to: id)
                store.savePowerState(isOn: true)
                store.saveHSV(h: hsv.h, s: hsv.s, v: hsv.v)
                statusMessage = "RGB set."
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }
}
