# SolarDim

A tiny, dependency-free native macOS menu-bar app that automatically sets an iMac's **actual panel brightness** by the sun. No subscription, network, API key, overlays, or external packages.

**Status:** The scheduling engine passed eight automated tests on Linux. The macOS AppKit UI and hardware brightness backend still need to be compiled and verified on the iMac by Astra.

## Default schedule — 0–16 brightness scale

| Anchor | Brightness |
|---|---:|
| Midnight | 1 |
| Sunrise | 4 |
| Solar noon (not wall-clock noon) | 9 |
| Astronomical dusk (sun 18° below horizon) | 4 |
| 11:00 p.m. | 4 |
| 11:30 p.m. | 2 |
| Next midnight | 1 |

Linear interpolation between anchors; updates every 30 seconds. Brightness can be fractional between whole key steps. Between midnight and sunrise it rises from 1 to 4. Between sunrise and true solar noon it rises to 9. At full astronomical darkness it reaches 4, holds until 11 p.m., then steps down gradually as specified. Times are calculated entirely offline from NOAA's solar equations, with timezone and daylight-saving transitions handled. Initial position: **Washington, DC**, latitude 38.9072, longitude −77.0369, timezone America/New_York.

## Building on macOS (requires Swift / Xcode Command Line Tools)

From the SolarDim folder:

    swift test
    bash scripts/build-macos.sh
    open dist/SolarDim.app

Or build and install into ~/Applications/SolarDim.app:

    bash scripts/install-macos.sh

Launch only one copy of the app at once. It has no Dock icon or window; use its system-native sun icon at the right of the menu bar. Enable **Start at Login** in the menu if wanted. It writes ~/Library/LaunchAgents/com.chocochopin.SolarDim.plist, effective at the next login.

## Native menu

- **Brightness at…**: choose 0–16 for each of the six daily anchors.
- **Darkness means…**: sunset, civil dusk, nautical dusk, or astronomical dusk (default).
- **Update interval**: 1 / 5 / 10 / 30 / 60 seconds.
- **Set Location…**: latitude, longitude, and IANA time zone.
- **Open Configuration File** and **Reload Configuration File**: external edits via JSON.
- **Test Full Day in 24 Seconds**: animate the actual screen through 24 hours in 24 seconds, at 20 updates per second, then return to the correct real-time level. Click again to cancel.
- **Pause Scheduling** and **Resume Scheduling**: stop or restart automatic changes.
- **Start at Login**: toggle the per-user launch agent.
- **Quit SolarDim**: exit without forcibly resetting the backlight.

The JSON is created on first run at:

    ~/Library/Application Support/SolarDim/config.json

See examples/config.json. Fractional levels are accepted in the JSON file. External edits require choosing Reload Configuration File.

## Dry runs — do not touch the display

    swift run SolarDim --print-schedule
    swift run SolarDim --dry-run

The second prints brightness samples every half hour. These modes also work on Linux (no AppKit).

## Hardware controller

Uses CGGetOnlineDisplayList and CGDisplayIsBuiltin to target **only the iMac internal screen**. Dynamically loads Apple's DisplayServices.framework and calls DisplayServicesGetBrightness / DisplayServicesSetBrightness to change actual panel brightness. Normalization: key level divided by 16. The hardware API is private and may be changed by Apple, hence the need for testing on the physical iMac. No external monitor or LG TV brightness is touched. If automatic ambient brightness control is present, disable it to avoid competing writes.

## Astra acceptance checks

1. On iMac, run the Swift tests, then compile the app bundle using the build script. Fix any macOS SDK-specific issues.
2. Run both dry-run commands and verify solar noon, sunrise and darkness for Washington, DC.
3. Open the app; confirm the native menu, configuration creation and an actual backlight adjustment of the built-in screen.
4. Run the 24-second simulation and verify smooth transitions, cancellation and the return to current-time brightness.
5. Check menu edits, JSON persistence/reload, pause/resume and Start at Login.
6. Make sure no other brightness automation is competing and only one SolarDim instance is running.

## Astronomical reference

NOAA Global Monitoring Laboratory solar calculations: https://gml.noaa.gov/grad/solcalc/calcdetails.html

Apple Core Graphics built-in-display selection: https://developer.apple.com/documentation/coregraphics/cgdisplayisbuiltin(_:)
