import AppIntents

struct LampOnIntent: AppIntent {
    static var title: LocalizedStringResource = "Lamp On"
    static var description = IntentDescription("Turn the lamp on.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        let id = try LampDeviceStore.shared.requireID()
        try await LampBLEManager.shared.sendSequence([LampCommands.power(on: true)], to: id)
        LampDeviceStore.shared.savePowerState(isOn: true)
        return .result()
    }
}

struct LampOffIntent: AppIntent {
    static var title: LocalizedStringResource = "Lamp Off"
    static var description = IntentDescription("Turn the lamp off.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        let id = try LampDeviceStore.shared.requireID()
        try await LampBLEManager.shared.sendSequence([LampCommands.power(on: false)], to: id)
        LampDeviceStore.shared.savePowerState(isOn: false)
        return .result()
    }
}

struct LampToggleIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Lamp Power"
    static var description = IntentDescription("Toggle the lamp power using the last known state from this app.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = LampDeviceStore.shared
        let id = try store.requireID()
        let lastKnown = store.loadPowerState()
        let target = !(lastKnown ?? false)
        try await LampBLEManager.shared.sendSequence([LampCommands.power(on: target)], to: id)
        store.savePowerState(isOn: target)
        let dialog: IntentDialog
        if lastKnown == nil {
            dialog = IntentDialog("Lamp state unknown. Turning it \(target ? "on" : "off").")
        } else {
            dialog = IntentDialog(target ? "Lamp on." : "Lamp off.")
        }
        return .result(dialog: dialog)
    }
}

struct LampToggleIntensityIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Lamp Intensity"
    static var description = IntentDescription("Toggle lamp brightness between 50% and 100%.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = LampDeviceStore.shared
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
        try await LampBLEManager.shared.sendSequence(sequence, to: id)
        store.savePowerState(isOn: true)
        store.saveHSV(h: hue, s: saturation, v: targetValue)
        return .result(dialog: IntentDialog("Brightness set to \(targetValue)%."))
    }
}

struct LampSetBrightnessIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Lamp Brightness"
    static var description = IntentDescription("Set the lamp brightness.")
    static var openAppWhenRun = false

    @Parameter(title: "Brightness", default: 100)
    var level: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Set brightness to \(\.$level)%")
    }

    func perform() async throws -> some IntentResult {
        let id = try LampDeviceStore.shared.requireID()
        let clamped = max(0, min(100, level))
        let store = LampDeviceStore.shared
        let lastHSV = store.loadHSV()
        let hue = lastHSV?.h ?? 0
        let saturation = lastHSV?.s ?? 0
        let sequence = [
            LampCommands.power(on: true),
            LampCommands.color(h: hue, s: saturation, v: clamped)
        ]
        try await LampBLEManager.shared.sendSequence(sequence, to: id)
        store.savePowerState(isOn: true)
        store.saveHSV(h: hue, s: saturation, v: clamped)
        return .result()
    }
}

struct LampSetColorIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Lamp Color"
    static var description = IntentDescription("Set the lamp to a preset color.")
    static var openAppWhenRun = false

    @Parameter(title: "Color")
    var color: LampColor

    static var parameterSummary: some ParameterSummary {
        Summary("Set lamp color to \(\.$color)")
    }

    func perform() async throws -> some IntentResult {
        let id = try LampDeviceStore.shared.requireID()
        let hsv = color.hsv
        let sequence = [
            LampCommands.power(on: true),
            LampCommands.color(h: hsv.h, s: hsv.s, v: hsv.v)
        ]
        try await LampBLEManager.shared.sendSequence(sequence, to: id)
        LampDeviceStore.shared.savePowerState(isOn: true)
        LampDeviceStore.shared.saveHSV(h: hsv.h, s: hsv.s, v: hsv.v)
        return .result()
    }
}

struct LampSetRGBIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Lamp RGB"
    static var description = IntentDescription("Set the lamp color using RGB values.")
    static var openAppWhenRun = false

    @Parameter(title: "Red", default: 255)
    var red: Int

    @Parameter(title: "Green", default: 255)
    var green: Int

    @Parameter(title: "Blue", default: 255)
    var blue: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Set RGB to \(\.$red), \(\.$green), \(\.$blue)")
    }

    func perform() async throws -> some IntentResult {
        let id = try LampDeviceStore.shared.requireID()
        let r = max(0, min(255, red))
        let g = max(0, min(255, green))
        let b = max(0, min(255, blue))
        let hsv = LampCommands.rgbToHSV(r: r, g: g, b: b)
        let sequence = [
            LampCommands.power(on: true),
            LampCommands.color(h: hsv.h, s: hsv.s, v: hsv.v)
        ]
        try await LampBLEManager.shared.sendSequence(sequence, to: id)
        LampDeviceStore.shared.savePowerState(isOn: true)
        LampDeviceStore.shared.saveHSV(h: hsv.h, s: hsv.s, v: hsv.v)
        return .result()
    }
}

struct LampShortcutsProvider: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .orange

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LampOnIntent(),
            phrases: [
                "\(.applicationName) lamp on",
                "Turn on \(.applicationName) lamp",
                "Light on in \(.applicationName)"
            ]
        )
        AppShortcut(
            intent: LampOffIntent(),
            phrases: [
                "\(.applicationName) lamp off",
                "Turn off \(.applicationName) lamp",
                "Light off in \(.applicationName)"
            ]
        )
        AppShortcut(
            intent: LampToggleIntent(),
            phrases: [
                "Toggle \(.applicationName) lamp",
                "\(.applicationName) lamp toggle power"
            ]
        )
        AppShortcut(
            intent: LampToggleIntensityIntent(),
            phrases: [
                "Toggle \(.applicationName) lamp intensity",
                "\(.applicationName) lamp brightness toggle"
            ]
        )
        AppShortcut(
            intent: LampSetColorIntent(),
            phrases: [
                "Set \(.applicationName) lamp color",
                "\(.applicationName) lamp color to \(\.$color)"
            ]
        )
        AppShortcut(
            intent: LampSetBrightnessIntent(),
            phrases: [
                "Set \(.applicationName) lamp brightness",
                "Adjust \(.applicationName) lamp brightness"
            ]
        )
        AppShortcut(
            intent: LampSetRGBIntent(),
            phrases: [
                "Set \(.applicationName) lamp RGB",
                "\(.applicationName) lamp custom RGB"
            ]
        )
    }
}
