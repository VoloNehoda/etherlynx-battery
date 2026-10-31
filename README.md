# Etherlynx Battery

A macOS menu-bar battery app: live charge, health, cycles and temperature, a power-flow view, energy by app, Bluetooth device batteries, custom alerts — and a charge limit with Sailing mode and heat protection.

Requires macOS 14+ on Apple silicon.

## Build

```sh
./build.sh
open "Etherlynx Battery.app"
```

Plain `swiftc`, no Xcode project. `build.sh` compiles the app (`Sources/`) and the root helper (`Helper/`), bundles fonts and marks from `Resources/`, and signs ad-hoc.

## What's inside

- **Overview** — charge, health (full ÷ design capacity), cycles, battery temperature (SMC `TB0T/TB1T`), Mac draw, 24h/7d/30d history, Low Power Mode.
- **Charge** — charge limit 50–100 %, Sailing mode, heat protection (35° with a 5-minute hold), top up to 100 % once, stay awake until the limit, MagSafe LED.
- **Power** — Sankey power flow (adapter → battery / Mac), energy by app (live, 24h, 7d, 30d) grouped by app bundle.
- **Devices** — AirPods (L/R/case), Magic Mouse/Keyboard/Trackpad, and anything connected that exposes the Bluetooth Battery Service.
- **Alerts** — a draggable pill with jelly physics, screen glow, full-screen alert at critical levels.
- **Percent modes** — as macOS shows, true charge (remaining ÷ full), or of original capacity.
- Right-click the menu bar icon to toggle Low Power Mode.

## Charge limit helper

The limit runs in a small root LaunchDaemon (`xyz.etherlynx.battery.helper`), installed from the Charge tab with an admin prompt. Settings and status live in `/Library/Application Support/Etherlynx Battery/`, the log in `/var/log/etherlynx-battery-helper.log`.

The helper picks a lever per firmware: `CHTE` or `CH0B`+`CH0C` to pause charging, `CH0I` to cut the adapter. `CHIE` behaves differently across firmware, so its role is self-tested on first use. macOS can reset these keys, so the helper re-checks them every 3 s while something is paused. On exit, when the limit is off, or below 10 %, it restores normal charging. **Remove helper** in the Charge tab uninstalls it.

## Not supported

- iPhone, iPad and Apple Watch through Apple's private battery APIs — they're limited to Apple's own processes. iPhone and iPad appear only when paired and sharing their battery over Bluetooth.
- Widgets (need an Xcode app extension).
