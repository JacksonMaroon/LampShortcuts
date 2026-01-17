import SwiftUI

struct ContentView: View {
    @StateObject private var model = LampViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Selected Lamp") {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(model.selectedName)
                            .foregroundColor(.secondary)
                    }
                    if !model.selectedID.isEmpty {
                        HStack {
                            Text("ID")
                            Spacer()
                            Text(model.selectedID)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    } else {
                        Text("Select a lamp to enable Shortcuts actions.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    Button("Clear Selection") {
                        model.clearSelection()
                    }
                }

                Section("Quick Actions") {
                    Button("Toggle Power") {
                        model.togglePower()
                    }

                    HStack {
                        Button("On") {
                            model.sendPower(on: true)
                        }
                        Spacer()
                        Button("Off") {
                            model.sendPower(on: false)
                        }
                    }

                    HStack {
                        Slider(value: $model.brightness, in: 0...100, step: 1)
                        Text("\(Int(model.brightness))%")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    Button("Set Brightness") {
                        model.sendBrightness()
                    }

                    Picker("Color", selection: $model.color) {
                        ForEach(LampColor.allCases, id: \.self) { color in
                            Text(color.displayName).tag(color)
                        }
                    }
                    Button("Set Color") {
                        model.sendColor()
                    }

                    HStack(spacing: 12) {
                        TextField("R", text: $model.rgbR)
                            .keyboardType(.numberPad)
                            .frame(width: 60)
                        TextField("G", text: $model.rgbG)
                            .keyboardType(.numberPad)
                            .frame(width: 60)
                        TextField("B", text: $model.rgbB)
                            .keyboardType(.numberPad)
                            .frame(width: 60)
                    }
                    Button("Set RGB") {
                        model.sendRGB()
                    }
                }

                Section("Scan") {
                    let scanLabel = model.scanState == "Scanning" ? "Stop Scan" : (model.scanState == "Starting" ? "Starting..." : "Start Scan")
                    Button(scanLabel) {
                        if model.scanState == "Scanning" {
                            model.stopScan(reason: "user")
                        } else if model.scanState != "Starting" {
                            model.startScan()
                        }
                    }
                    .disabled(model.scanState == "Starting")

                    if model.peripherals.isEmpty {
                        Text("No devices yet.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(model.peripherals) { device in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(device.name)
                                        Text(device.id.uuidString)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Button("Select") {
                                        model.selectPeripheral(device)
                                    }
                                }
                                HStack {
                                    Text("RSSI \(device.rssi)")
                                    Spacer()
                                    Text(device.isConnectable ? "Connectable" : "Not connectable")
                                }
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section("Bluetooth Debug") {
                    HStack {
                        Text("State")
                        Spacer()
                        Text(model.bluetoothState)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Authorization")
                        Spacer()
                        Text(model.bluetoothAuthorization)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Scan")
                        Spacer()
                        Text(model.scanState)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Central")
                        Spacer()
                        Text(model.centralScanState)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Devices")
                        Spacer()
                        Text("\(model.deviceCount)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Discoveries")
                        Spacer()
                        Text("\(model.discoveryCount)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Last")
                        Spacer()
                        Text(model.lastDiscovery)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Button("Refresh Bluetooth Status") {
                        model.refreshBluetoothStatus()
                    }
                }

                if !model.statusMessage.isEmpty {
                    Section("Status") {
                        Text(model.statusMessage)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Lamp Shortcuts")
        }
    }
}
