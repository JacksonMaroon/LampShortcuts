# LampShortcuts

Control your BLE smart lamp with Siri Shortcuts instead of a bloated manufacturer app.

## The Problem

I bought a cheap RGB smart lamp. The official app:
- Takes 8+ seconds to load
- Requires account creation and login
- Wants Bluetooth, location, and notification permissions (why?)
- Has no Siri Shortcuts support
- Shows ads

I just wanted to say "lamp on" and have it work.

## The Solution

A native Swift app that:
- Connects directly to the lamp via Bluetooth LE
- Exposes all controls as Siri Shortcuts
- Works in <1 second
- No account, no cloud, no tracking

### Supported Commands

| Shortcut | What it does |
|----------|--------------|
| "Lamp on" | Turn on |
| "Lamp off" | Turn off |
| "Toggle lamp" | Smart toggle using last known state |
| "Set lamp brightness to 50%" | Brightness control |
| "Set lamp color to blue" | Preset colors (12 options) |
| "Set lamp RGB 255, 0, 128" | Custom RGB values |

## Technical Decisions

**Why native Swift instead of React Native / Flutter?**
- AppIntents (Siri Shortcuts) requires native implementation
- CoreBluetooth is more reliable than cross-platform BLE libraries
- No dependencies = no maintenance burden

**Why BLE protocol reverse engineering?**
- The lamp uses a generic Tuya-style BLE protocol (service `FFFF`, characteristic `FF01`)
- Commands are 21-byte packets with HSV color encoding
- Captured via Bluetooth packet sniffing from the original app

**Why local state persistence?**
- BLE lamps don't report their current state
- Toggle requires knowing if lamp is on/off
- App stores last-known state in UserDefaults
- Graceful handling when state is unknown

**Why write commands 3x with delays?**
- BLE write-without-response can be unreliable
- 500ms delays between writes ensure lamp receives command
- Empirically determined through testing

## Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────┐
│  Siri Shortcut  │────▶│   AppIntents     │────▶│  BLE Lamp   │
│  "Lamp on"      │     │  LampOnIntent    │     │  (FFFF/FF01)│
└─────────────────┘     └──────────────────┘     └─────────────┘
                               │
                               ▼
                        ┌──────────────────┐
                        │  LampBLEManager  │
                        │  (async/await)   │
                        └──────────────────┘
                               │
                               ▼
                        ┌──────────────────┐
                        │  LampDeviceStore │
                        │  (state persist) │
                        └──────────────────┘
```

## Setup

1. Build and run in Xcode
2. Open the app and tap "Start Scan"
3. Select your lamp from the list
4. Done - Siri Shortcuts now work

Once configured, you can add the shortcuts to Control Center and Apple Watch via the Shortcuts app.

## Compatibility

Tested with generic BLE RGB lamps using the Tuya/Smart Life protocol. Should work with any lamp advertising:
- Service UUID: `FFFF`
- Characteristic UUID: `FF01`

## Learnings

1. **Apple's AppIntents API is underrated** - Siri Shortcuts "just work" once you implement the intents. No server, no configuration.

2. **BLE is stateless by design** - Don't assume you can query device state. Design around local persistence.

3. **The best product is one that replaces a bad one** - I use this multiple times daily. The official app is deleted.

## Future Ideas

- [x] macOS menu bar app → [LampMenuBar](https://github.com/JacksonMaroon/LampMenuBar)
- [ ] HomeKit bridge (expose as HomeKit accessory)

---

*Built because the official app was annoying.*
