# SolarDim -> Lunar-complete competitor: product specification and build roadmap

**Planning baseline:** 2026-11-04. **Competitor baseline:** Lunar v6.11.3 (2026-10-25). **Release objective:** a direct macOS competitor with documented Lunar v6.11.3 functional parity, then better implementation quality and genuinely useful additional features. **Target price:** approximately US $11.49 one-time, subject to distribution costs and testing. **Status:** specification; not a claim of completed parity.

**Non-negotiable scope:** Do not quietly reduce this to a solar brightness scheduler. Every SOURCE-VERIFIED feature below is a release requirement wherever the corresponding hardware/OS can support it. Stages control engineering order, not the product's final scope. All unfinished features remain visible in this ledger.

**Scope of audit:** Lunar's official home page, Pro manual, Shortcuts documentation, official changelog through v6.11.3, FAQ, v6.0 release notes, and public source README. This is an auditable inventory of *publicly documented* behavior, not a claim to have reverse-engineered every hidden setting or future Lunar v7 feature. During parity testing, reconcile discrepancies against an installed Lunar v6.11.3 trial and add newly discovered behavior to this ledger.

## 1. Current implementation versus target

Existing SolarDim branch contains a native macOS status-menu prototype, internal-screen DisplayServices brightness adapter, JSON settings, fixed solar/clock profile, four-a.m. schedule cache with lookahead, smooth interpolation, 24-second simulated-day mode, and 14 reported tests for the schedule/cache. **None of the hardware/UI work is yet verified on the actual iMac.** That source is the seed, not an adequate architecture for full parity.

Coverage status notation: **S** = existing scaffold (not accepted as finished); **T** = to implement; **V** = verified via hardware/device and automated tests. All features start as T unless explicitly described as S. A feature becomes V only when its acceptance criterion passes on supported hardware.

## 2. Source-verified feature parity ledger

Each line is a separately testable contract; groups reference milestone numbers in section 3. The 'Better' column is an intentional improvement, not a description of Lunar.

### A. Display discovery, native control, DDC, fallback (M0-M2)

| ID | Lunar behavior to reproduce | Implementation / acceptance evidence | Better |
|---|---|---|---|
| A01 | Detect internal, external, virtual, DisplayLink and Sidecar screens | Display registry; test connect/disconnect, sleep, arrangement change | Explicit capability badges and diagnostics |
| A02 | Stable per-monitor settings | EDID vendor/product/serial + hardware port + persisted fallback; test duplicate serials | Explain identity collisions and permit manual pairing |
| A03 | Hardware brightness on internal Apple displays | Apple-native adapter; test read/write and restoration on Intel and Apple silicon | Avoid enumerate/readback on every no-op brightness tick |
| A04 | Apple-native controls for Studio Display, Pro Display XDR, LG UltraFine, Thunderbolt and LED Cinema where available | Per-model capability probes and brightness transitions | Prefer supported native transport automatically |
| A05 | Hardware DDC over HDMI/DP/USB-C/Thunderbolt on Intel | IOKit/I2C transport; read/write MCCS VCP codes; verify on monitors | Detect broken cables/docks instead of silent failure |
| A06 | Hardware DDC on Apple silicon, including built-in HDMI when supported | Apple silicon transport backend; hardware test matrix | Adaptive command scheduling per bus |
| A07 | DDC brightness | VCP 0x10 with raw max/min, reads, write/ack if available | Calibrated percent vs native raw levels |
| A08 | DDC contrast | VCP 0x12; monitor-specific bounds and lock handling | Independent contrast curve and safeguards |
| A09 | DDC monitor volume | VCP 0x62; volume media keys on active monitor | Device-specific dB mapping where known |
| A10 | DDC input switch, including LG/vendor-specific mappings | VCP 0x60; query, drop-down, up to three input hotkeys | Grouped KVM actions directly in app |
| A11 | DDC monitor power commands | VCP 0xD6, confirm exact vendor behavior, non-reversible cases | Capability-aware preflight and recovery hint |
| A12 | Arbitrary DDC read/write command | General VCP service + CLI/Shortcuts; raw hex tests | Reusable named per-model commands |
| A13 | DDC read fallback, port matching, latency estimates and delays | Async command queue, port discovery, retry/backoff and per-display metrics | No UI/main-thread DDC calls; write coalescing |
| A14 | User-defined brightness/contrast min/max, offsets, and raw values | Clamp in all control modes; test 0%/100% and nonstandard ranges | Visible hardware/visual scale distinction |
| A15 | DDC smooth transitions / adaptive pacing | Transition controller that respects measured transport rate | Rate-limit writes and skip changes below epsilon |
| A16 | Explicit enable/disable of DDC, Apple Native, Network and Gamma per screen | Per-display controls and CLI flags; persistence | Deterministic backend preference order |
| A17 | Software gamma fallback for non-DDC screens | Capture and restore gamma ramps; preserve calibrated color profiles; test after crash | Detect HDR/ColorSync incompatibility before applying |
| A18 | Overlay-based software dimming including virtual/DisplayLink displays | Color-accurate screen-local overlay, display relayout and screen capture behavior | Independently control overlay opacity/interaction |
| A19 | Sub-zero dimming below native minimum | Explicit extra-dim range; smooth transition from backlight to gamma/overlay | Show distinct hardware and software contributions |
| A20 | Automatic fallback when DDC unavailable / no native backend | Capability probes, fallback chain, error-state recovery | User-visible reason for fallback and retry button |
| A21 | Network DDC via Raspberry Pi or remote DDC relay | Companion DDC server with authenticated LAN transport; test DisplayLink workaround | Pairing and authenticated transport rather than unprotected writes |
| A22 | Connection and vendor quirks incl. LG-specific inputs, docks and monitors | Monitor quirk DB and override mechanism | Export diagnostics to improve shared compatibility DB |

### B. Manual control and interfaces (M2)

| ID | Lunar behavior to reproduce | Implementation / acceptance evidence | Better |
|---|---|---|---|
| B01 | Global brightness media keys on all monitors | Event capture and routing; no double-change on native screen | Configurable target and modifier hints |
| B02 | Target display under cursor, main screen, non-main screens, or all | Key routing rules and UI selector; multi-monitor tests | Per-app/input-device targeting |
| B03 | Ctrl-/Shift-modified per-display brightness keys | Native keyboard modifiers and repeat-on-hold | Custom repeat curve and fine stepping |
| B04 | Volume media-key control for monitor audio | Active monitor routing, audio output change awareness | Respect active CoreAudio device |
| B05 | User hotkeys for brightness, contrast, volume, rotation, restart and input | Hotkey editor with collision detection and scope | Keyboard-first searchable command palette |
| B06 | Fine adjustment and press-and-hold continuous control | Key repeat debouncing and stepped/fractional adjustments | Calibrated step size |
| B07 | Merged or separate brightness and contrast sliders | Per-display menu / settings; test both modes | Consistent units across modes |
| B08 | Menubar QuickActions with per-monitor sliders, volume and inputs | SwiftUI/AppKit menu with display cards and controls | Compact default; advanced on demand |
| B09 | Custom and native brightness on-screen display (OSD) | Screen-local OSD; macOS native where supported; force system option | Text contrast adapts to background |
| B10 | Menu layout customization / density / hide unused widgets | Persisted per-user menu preferences | Fully customizable quick menu |
| B11 | Screen-specific settings, controls and status | Visible transport, lock and disconnected state | Live explanation of why a control cannot work |
| B12 | Start at login; pause/resume adaptive controls; reset/restart/quit | LaunchAgent or SMAppService, pause state, reset variants | Quit means no resident daemon |
| B13 | Manual Mode with unlimited brightness, contrast, volume and input adjustments | Consistent backend behavior; zero artificial limits in paid edition | Free trial with no artificial rate limitations |
| B14 | Smooth manual screen transitions, display hotplug reconciliation | Target-agnostic transition engine and state observer | No abrupt jumps when changing mode |

### C. Adaptive modes, sensors, location, schedules and presets (M3-M5)

| ID | Lunar behavior to reproduce | Implementation / acceptance evidence | Better |
|---|---|---|---|
| C01 | Manual, Sync, Location, Sensor, Clock and Auto modes | Common AdaptiveMode interface and per-display selection | One explicit mode-state machine |
| C02 | Auto chooses suitable mode based on available sensors/displays | Capability/priority rules; simulated disconnect/wake tests | Show why a mode was selected |
| C03 | Sync with Apple built-in source using macOS light-adapted changes | Event-driven native brightness observation | No polling when events exist |
| C04 | Multiple Sync Sources and target selection | Per-target routing and source fallback | Configurable source priority |
| C05 | Sync brightness and contrast, including manual source changes | Learned target curves and event propagation | Separate learned curves for brightness / contrast |
| C06 | Nits-based Sync Mode on supported Apple silicon displays | Native brightness in nits, per-display min/max nits model | Calibration wizard with luminance points |
| C07 | Sync without source via All Displays group slider | Virtual normalized source and group changes | Named display groups |
| C08 | Persist and auto-learn manual correction to Sync curve | Monotone curve/interpolation + change events | Reversible adjustment history |
| C09 | Location via user coordinates, local location service or IP fallback | Local solar engine and optional permissioned location; test timezone & DST | Manual location is completely offline |
| C10 | Location-based brightness/contrast from sun elevation | Solar elevation-to-output curve; min at dark, max near solar zenith | Optional room orientation and window exposure |
| C11 | Location mode learns each screen's adjustment curve | Feedback updates, reset and curve-factor copying | Graphical editable response curve |
| C12 | Clock mode fixed-time brightness and contrast anchors | Arbitrary number of clock points, not just five | Unlimited anchors; import/export |
| C13 | Clock anchors at sunrise, solar noon, sunset with ± offsets | Solar event parser and offsets; tests against solar day | Add twilight, dusk, solar elevation thresholds |
| C14 | Clock transitions: instant, 30-minute, full schedule-to-schedule | Generic transition types; exact boundary tests | Custom duration and interpolation easing |
| C15 | Reapply relevant schedule on app launch, wake, display attach/detach | Event reconciliation, user-controlled reapply flag | Preserve legitimate temporary overrides |
| C16 | Solar calculations updated daily and when location changes | Cached daily schedules at 04:00, next-day lookahead; currently scaffolded | No solar recomputation every 30 seconds |
| C17 | 24-second accelerated-day simulation | Hardware/software or dry-run simulation, cancel + restore | Interactive visual 24-hour graph |
| C18 | Sensor Mode: Apple built-in ambient-light sensor where supported | Permissioned low-level capability probe; report lux | Sensor-quality/availability indicators |
| C19 | Sensor Mode: Apple and LG external display ambient sensors | Model-specific ALS adapter and lux changes | Multi-sensor blending with confidence |
| C20 | DIY wireless light sensor and sensor server | Documented HTTP/WebSocket/Bonjour endpoint; resilient reconnect | Guided setup and local authentication |
| C21 | Home Assistant / third-party sensor integration | Configurable host/port/path and data schema | First-class MQTT/Home Assistant mapping |
| C22 | Lux-to-brightness/nits/contrast curves | Default documented response curve, editable min/max nits | Perceptual calibration wizard |
| C23 | Sensor mode auto-learning after manual corrections | Persist monotone samples; jitter rejection and hysteresis | Per-mode learning reset/undo |
| C24 | Per-display min/max, offsets, curve factors, source/target | Display-scoped persisted settings | Profile cloning and compare |
| C25 | User can temporarily override automatic brightness | Explicit temporary override TTL and conflict policy | Adjustable override until next anchor / duration |
| C26 | Pause/resume adaptive algorithm via UI, CLI, Shortcuts | Single authoritative paused state and events | Pausing doesn't erase curve/profile |
| C27 | App exceptions based on visible windows *on each monitor*, including negative offsets | NSWorkspace/CGWindow observation and per-display rules | Conflicts show priority in UI |
| C28 | App presets as offsets or absolute brightness/contrast | Bundle ID matching, visibility, exclusion and precedence | Explicit per-app rules tested in simulator |
| C29 | Named custom presets, standard presets, apply via UI/CLI | Reusable multi-display snapshots; metadata and restoration | Exportable presets and hotkey groups |
| C30 | Adaptive correctness on sleep, clamshell, no source, blackout and disconnected screens | Event graph and integration regression suite | Never oscillate between unavailable sources |
| C31 | Force system adaptive-brightness preference when requested | Explicit on/off per screen and restore on exit | Detect contention with other brightness apps |

### D. HDR, XDR, color and high-brightness features (M6)

| ID | Lunar behavior to reproduce | Implementation / acceptance evidence | Better |
|---|---|---|---|
| D01 | Extend XDR brightness beyond normal SDR ceiling on supported Apple displays | Versioned XDR backend per OS/panel; measure hardware luminance where possible | Graceful no-XDR fallback |
| D02 | Optional XDR/EDR on compatible non-Apple HDR screens | Vendor/model capability gate and explicit opt-in | Vendor-tested capability list |
| D03 | Full Range XDR on OS versions where supported | Full Range implementation plus OS-version gate | Advertise real available result, never stale toggles |
| D04 | macOS 26.3+ alternate XDR behavior when prior native preset method blocked | Version-aware fallback matching Lunar v6.9.6+ behavior | Explicitly report HDR color-clipping risk/state |
| D05 | Unified SDR/XDR slider, nits readout and brightness keys above 100% | End-to-end UI, metrics and hotkeys | Calibrate perceptual/absolute scales separately |
| D06 | Auto XDR based on ambient light, battery and context | Sensor + machine state policy, override, state restoration | Rule editor and on-screen preview |
| D07 | Enhanced contrast in XDR / sub-zero dimming where system allows | OS-gated pixel tone curve; automatic disable where blocked | Reversible color transform with visual sample |
| D08 | Toggle HDR, remember/force HDR on compatible monitors | Per-display HDR settings; wake/restoration tests | HDR-aware scene policies |
| D09 | Reference/display presets (e.g. P3-D65) selection | Discover and apply supported display preset APIs | Expose color space and currently active preset |
| D10 | Gamma whites, blacks, contrast tweaks and saved presets | ColorSync/Gamma pipeline, safe limits, persistence | Before/after comparison, rollback |
| D11 | Preserve Night Shift / True Tone / f.lux interoperability when possible | Avoid incompatible gamma paths; explicit backend arbitration | Explain exactly which system feature conflicts |
| D12 | HDR compatibility workarounds and adaptive-brightness interactions | OS feature matrix for SDR/HDR/XDR transitions | Instrument HDR tone mapping and show active pathway |
| D13 | XDR-related nits sync and clipping safeguards | Range clamp; HDR source transition tests | No oscillation when sensor nits fluctuate |
| D14 | Keyboard backlight adjustments in sub-zero and blackout | Conditional control and exact restoration | Never turn previously-off backlight on automatically |

**Important implementation note:** Lunar states that macOS 26.3 blocked its native preset-based XDR path and some contrast behavior. Full parity means replicating *current functioning behavior on the target OS*, not pretending an OS-blocked algorithm still works.

### E. BlackOut, FaceLight and power management (M7)

| ID | Lunar behavior to reproduce | Implementation / acceptance evidence | Better |
|---|---|---|---|
| E01 | BlackOut a selected internal or external display with hotkey/menu | Disconnect where supported, preserve state | Differentiate disconnected, blanked, powered off |
| E02 | Shift variant: black screen without disconnect | Input-transparent black overlay; reversible | Clear state and always-available recovery |
| E03 | Option variant: turn off external screen via DDC | VCP power mode with supported-screen gate | Explain if software cannot power it back on |
| E04 | Option+Shift: BlackOut all except display with cursor | Multi-screen transaction + rollback if partial failure | One-click focus scene |
| E05 | Auto BlackOut built-in screen when external display attached | Event-driven attach/detach; restore when removed | Configurable external monitor eligibility |
| E06 | Auto Disconnect survives sleep/wake and lid changes | Persist desired topology + recovery reconciliation | Recovery timer and failsafe on last screen |
| E07 | Sidecar display connect/disconnect with restore | Sidecar adapter and Shortcuts actions | Arrangement-preserving reconnect |
| E08 | BlackOut emergency escape (8+ Command presses), Esc cancel Auto BlackOut | Separate recovery handler survives UI problems | Dedicated external restore hotkey |
| E09 | Restore previous brightness, resolution, rotation and layout | Pre-action snapshot and atomic restoration where possible | Crash-recovery journal |
| E10 | Keep MacBook keyboard, trackpad, Touch ID, camera, audio and USB active while screen is black | Non-sleep / open-lid behavior tests | Explicit display power vs computer power distinction |
| E11 | FaceLight bright warm-white screen overlay with hotkey | Cursor-selected display, warm-white overlay, max brightness/contrast | Color-temperature and coverage adjustment |
| E12 | FaceLight toggle reverts the *exact* prior screen state | Snapshot and cancellation tests | Scene expiration/restore on meeting end |

### F. Display arrangement, resolution, rotation and Sidecar (M8)

| ID | Lunar behavior to reproduce | Implementation / acceptance evidence | Better |
|---|---|---|---|
| F01 | Per-screen name, input, controls and capabilities | Stable display settings pages | Readable identity + connection route |
| F02 | Current and hidden resolutions, grouped by refresh rate | Mode discovery including hidden modes and safe apply | Preview with timed automatic rollback |
| F03 | Rotation 0/90/180/270° from UI and hotkeys | Display config transactions and restore | Named orientation presets |
| F04 | Set main display through UI/Shortcuts | Atomic main screen transaction | Safe revert if display disappears |
| F05 | Position, swap and arrange displays | Reusable topology model and layout Shortcuts | Automatically restore remembered arrangements |
| F06 | Display mirroring / return to previous configuration | Mode/topology snapshot and restore | Explain incompatible mirror modes |
| F07 | Connection/disconnection via software when supported | Hardware/OS-gated display topology operations | Capability-aware controls |
| F08 | Sidecar connection and monitor placement | Connect/disconnect to known iPad, restore geometry | One-step room/workspace scene |
| F09 | Read and switch relevant display color profiles / reference modes | ColorSync/ref mode integration without corrupting profiles | Snapshot and export color settings |
| F10 | Support multiple OS users, clamshell and wake/login transitions | Session-aware state machine; fast user switching tests | Clear session ownership of hardware controls |

### G. Automation, CLI, Shortcuts and integrations (M9)

| ID | Lunar behavior to reproduce | Implementation / acceptance evidence | Better |
|---|---|---|---|
| G01 | CLI get/set generic screen properties | Standalone CLI binary + app control socket, documented exit codes | Stable machine-readable JSON |
| G02 | CLI list/manage specific displays and fuzzy name matching | Display selectors by ID/name/index/all/cursor | Predictable ambiguity errors |
| G03 | CLI raw DDC commands | Safe VCP get/set, transport errors | Optional read-back verification |
| G04 | CLI gamma commands | Per-screen color pipeline actions | Atomically restore default ramp |
| G05 | CLI lux/nits readings | Sensor and nits API; omit unsupported data | Include sensor origin and timestamp |
| G06 | CLI event listener for brightness, nits, sensors and topology | Unix domain socket + event stream; proper cleanup | Typed events, stable schema, low overhead |
| G07 | CLI lid, connection, input, HDR and preset operations | Commands/queries and scripts tested | Idempotent operation mode |
| G08 | Apple Shortcuts/App Intents for all controllable settings | App Intents action catalog: brightness, contrast, volume, mode, blackout, sensor, resolution, rotation, HDR, display, preset | Discoverability via named actions |
| G09 | Keyboard Maestro, Raycast, Shortery usage via CLI/Shortcuts | End-to-end recipe tests | Document example automation templates |
| G10 | Shortcut recipes: layout swap/fix, Sidecar, HDR toggle, 20/20/20, input sequence, cleaning, screen sharing resolution, reference/gamma presets | Sample library and automated replay where possible | One-click installable scene templates |
| G11 | Per-app exceptions and presets exposed to automation | Input validation and stable external identifiers | Versioned JSON scene format |
| G12 | Concurrent command arbitration | Single control service serializes mutations per display | Prevent CLI/UI/scheduler fights |

### H. Operational and commercial parity (M0 and M10)

| ID | Lunar or market requirement | Implementation / acceptance evidence | Better |
|---|---|---|---|
| H01 | Native menu-bar-only app with no mandatory Dock window | LSUIElement app bundle; launch/login tests | Minimal idle memory and no background polling where avoidable |
| H02 | Intel and Apple silicon macOS support | x86_64/arm64 binaries or universal app; baseline macOS 12+ | Report supported OS/CPU feature differences |
| H03 | Onboarding and permissions for Accessibility, location, hotkeys, screen integration | Capability-driven permission prompts | Never ask for permissions for unused features |
| H04 | Per-display setting persistence and reset | Versioned config store with schema migrations, atomic writes | Text JSON import/export and human-readable diffs |
| H05 | Preferences, advanced settings, menu density, app information | Full searchable preferences window; menu for frequent tasks | Explain feature state and prerequisites |
| H06 | Update checks and reliable app updates | Signed Sparkle feed, rollback notes and release channel | No surprise restart while screen is black |
| H07 | Crash recovery and reliable monitor-state restoration | Unified logging, watchdog-free failsafe, transaction journal | Safe-mode launch and one-click restore |
| H08 | Documented hardware compatibility, connection diagnostics, known monitor caveats | Test matrix and exported support diagnostics | Self-service Monitor Doctor wizard |
| H09 | Accessibility, keyboard-only control, localization | VoiceOver names, contrast and international number formats | Config fully operable without a mouse |
| H10 | Licensed one-time paid offering and evaluation build | Working payment entitlement, offline validation and recovery | Clear, fair licensing with transparent feature table |
| H11 | Installation, uninstallation, launch-at-login, signing and notarization | Developer ID, hardened runtime, notarization, DMG, optional Homebrew cask | One-command uninstall/reset |
| H12 | Security/privacy for on-device automations and network sensors | All local by default, authenticated remote DDC, no telemetry unless opt-in | Activity log can show every automatic change |
| H13 | Idle performance and correct wake/sleep behavior | CPU, memory, energy tests in steady idle and simulated wake storms | Event-driven changes; solar refresh once daily |
| H14 | macOS-version capability flags for private/fragile features | Runtime feature registry and regression tests per OS | Disable unsupported features visibly, not silently |

**Count:** 22 A + 14 B + 31 C + 14 D + 12 E + 10 F + 12 G + 14 H = **129 independently tracked parity/engineering requirements**. Some are commercially important requirements beyond literal Lunar features. All 129 belong to this project's target.

## 3. Engineering roadmap: implementation order, with feature-complete release gate

Milestones are organized by dependencies. An internal milestone completion **does not** mean we market or release a reduced-feature Lunar competitor. A commercially released version must satisfy the parity acceptance gate in section 5.

| Milestone | Scope / parity IDs | Concrete work products | Exit criterion |
|---|---|---|---|
| **M0: Make prototype production-shaped** | H01-04, H07, H13-14; C16-17 | Split Core, Displays, Transports, Automation, UI and Tests targets; dependency injection, OS capability table, state coordinator; build macOS CI; correct any existing compilation issues | Clean build on actual macOS, all existing tests pass; dry-run safe |
| **M1: Hardware and fallback transports** | A01-A22 | Implement adapters AppleNative, DDC Intel, DDC AppleSilicon, Gamma, Overlay, Network DDC; display discovery and IDs; queue, retries, quirk DB | Real monitor brightness/contrast/input/volume and fallback demonstrably work across test matrix |
| **M2: Manual control parity** | B01-B14 | Keyboard control, hotkeys, menu cards, sliders, native/custom OSD, per-display limits and status | Can use app as Lunar's full manual replacement on multiple monitors |
| **M3: Clock & Location parity** | C09-C17 | General rule editor (time, solar events, offsets), brightness AND contrast, transition engine, simulator, pause/override; migrate existing DC JSON profile | Schedule tests including DST/4am/midnight; side-by-side Lunar Clock/Location scenarios |
| **M4: Sync and Sensor modes** | C01-C08, C18-C26, C30-31 | Lux adapters, source/target graph, nits syncing, sensor server and Home Assistant, auto-learning curves, Auto mode selector | Five automation modes and Auto produce expected results during wake and manual corrections |
| **M5: Presets and app exceptions** | C27-C29; G11 | Visible-window screen-local detection, per-app offsets/absolute settings, named presets, priority policy | Test with apps on different monitors, overlapping windows, window moves and quit |
| **M6: HDR/XDR and color** | D01-D14 | Native/alternate XDR strategies, auto-XDR, HDR controls, contrast, gamma color integrity, reference modes | Supported-screen test on relevant macOS versions; never claim unsupported HDR abilities |
| **M7: BlackOut, Auto BlackOut, FaceLight** | E01-E12 | Display disconnection, overlays, DDC power, multi-display focus, Sidecar restore, emergency escape and state journal | Escape route works even if UI is unresponsive; exact restoration after toggles |
| **M8: Topology management** | F01-F10 | Resolution, rotation, main/mirror, arrangement, Sidecar orchestration and persistent layouts | Screen configuration tests across hotplug, standby, alternate resolutions |
| **M9: CLI and Shortcuts** | G01-G12 | CLI/socket API, full App Intents surface, example Shortcuts and documentation | Every app action remotely invocable; no UI/CLI race conditions |
| **M10: Commercial parity verification and ship** | H05-06, H08-12 plus ALL | Side-by-side Lunar baseline review, remaining settings and quirks, compatibility grid, launch-at-login, license, signed/notarized installer, updater, website | All accepted IDs verified or explicitly OS/hardware-inapplicable; release only after gate |

**Critical path:** M0 -> M1 -> M2; M3 and M4 share the state coordinator; M6 and M7 are highest platform-specific risk; M9 must be designed as an API from M0 rather than added as an afterthought. Separate engineers/agents can build independent transport adapters in parallel once protocols are fixed.

## 4. Required architectural design (code organization)

Design everything around one typed, testable action surface instead of many UI controllers directly setting brightness.

    SolarDimCore/
      Domain/DisplayIdentity, Capability, Profile, Schedule, Scene
      Algorithms/SolarTime, Curves, Interpolation, Overrides, Calibration
      Engine/Coordinator, StatePriority, DisplayRegistry, Transactions
    SolarDimTransports/
      AppleNative, DDCIntel, DDCAppleSilicon, Gamma, Overlay,
      XDR, NetworkDDC, LightSensors, Sidecar
    SolarDimAutomation/
      CommandRouter, EventStream, AppIntents, CLI, WindowRules
    SolarDimUI/
      StatusMenu, Onboarding, Settings, ModeEditor, CurveGraph,
      DisplayDoctor, Preview
    SolarDimTests/
      Unit, PropertyBased, Integration, HardwareMatrix, Fixtures

Minimum protocols:

    DisplayTransport:
      detectCapabilities(display) -> CapabilitySet
      read(display, property) -> Value or Unsupported
      write(display, property, value) -> VerifiedResult
      observe(display, event) -> stream
    AdaptiveMode:
      desiredState(now, sensors, topology, profile) -> DisplayTargets
      onUserOverride(display, values)
      onEnvironmentChange(event)
    Coordinator:
      resolve priorities -> deduplicate writes -> transition -> verify/rollback

**State priority (explicit and tested):** emergency restore > user-initiated blackout/FaceLight > manual override > app rule or named scene > adaptive mode > defaults. Never have two independent subsystems continuously writing contradictory values. Each feature must declare whether it owns physical hardware settings, gamma, overlays, or display topology.

**Scheduling performance contract:** solar math at app start, 04:00 local refresh or changed location/config; today + tomorrow cached. Ordinary 30-second timer only evaluates a prebuilt piecewise schedule and writes if changed. Sync uses events, not 30-second polling. DDC transports serialize/coalesce writes and adapt to measured latency. No full display re-enumeration each tick. Battery/CPU performance is benchmarked on at least one Intel and one Apple silicon Mac.

**Persistence:** initial SolarDim config.json remains importable. Add versioned JSON or SQLite-backed profiles with deterministic JSON export. Preserve original per-user settings on update and provide atomic backup/revert.

## 5. Acceptance gates: when is a direct competitor genuinely complete?

1. **Parity traceability:** every feature ID maps to code, unit/integration tests, one user-visible control or command where appropriate, supported-hardware applicability and a verification result. No unchecked features presented as shipped.
2. **Hardware matrix:** test Intel iMac internal screen; Apple silicon MacBook internal with sensor; two DDC monitor brands over HDMI and DisplayPort/USB-C; Apple-native external display if accessible; HDR/XDR panel; one DDC-incompatible or DisplayLink path; multiscreen hotplug. Where hardware is unavailable, mark tests pending, not passing.
3. **OS matrix:** support target macOS 12+ with compatibility-gated functionality; specifically validate macOS 26.3+ XDR restrictions. Build universal where feasible. Reconcile Intel and Apple silicon-specific differences.
4. **Behavioral comparison:** record Lunar v6.11.3 actual behavior for each documented feature, plus screenshots or a fixture; parity test ours under the same scenario and display. Public documentation is necessary but not sufficient.
5. **Fidelity:** persisted values, brightness and contrast bounds, smooth transitions, HDR correct colors, no duplicate DDC changes or UI lag. Benchmark idle CPU, memory, writes/minute, command latency, wake recovery versus Lunar where possible.
6. **State safety:** force-quit during gamma dimming, blackout, resolution switch and XDR; restore safely after relaunch; emergency blackout escape requires neither menu accessibility nor a network connection.
7. **Commercial readiness:** fully functional signed/notarized build, verified payment and offline license, usable install/uninstall, update feed, onboarding, short user guide, compatibility and known-limitations page.
8. **No deceptive claims:** new differentiators are demonstrated and measured; OS-blocked features are clearly identified.

## 6. Improvements to Lunar's existing implementations

| Parity area | Specific way to beat the baseline | Why users will notice |
|---|---|---|
| Clock mode | Unlimited timeline anchors, more solar events, timeline scrubber, 24-second preview, editable easing | Scheduling becomes understandable instead of trial-and-error |
| Location mode | Offline sunrise/noon/dusk cache, solar altitude curve, window orientation and user offsets | High precision at negligible idle computation |
| Sync | Guided two/three-point visual brightness matching plus nits where supported | Screens visibly match at low/mid/high light |
| Auto mode | Explain active mode, sensor health, and which rule won | No mystery brightness changes |
| Manual override | 'Keep until next event', 'keep 15 min', 'keep until resumed' | Auto mode stops fighting the user |
| DDC | Capability diagnostics, protocol probe, vendor quirks, write-latency-aware ramping | Works more predictably with docks/adapters |
| Input switching | First-class grouped monitor/KVM scenes (currently doable in Lunar via Shortcuts) | One hotkey moves every monitor to another computer |
| BlackOut | Recoverable configuration transaction + persistent emergency restore | Less chance of getting stuck with a dark workspace |
| HDR/XDR | OS-specific capability matrix and truthful active pipeline label | Prevents washed-out HDR without warning |
| Presets | Edit, diff, version and share cross-display scenes | Easier to migrate work/home setups |
| UI | Native minimal quick menu plus a full advanced settings window | Simple when desired, complete when needed |
| CLI | Documented JSON event schema, idempotent writes and accurate errors | Reliable scripting without reverse engineering |
| Distribution | No unnecessary background workers, transparent update/license policy | Lower friction and idle overhead |

## 7. New customer-facing differentiators (NOT confirmed absent from installed Lunar)

The following were **not documented as integrated features** in the official sources reviewed. They are *proposed additions*, not categorical claims that Lunar cannot do them. Before advertising exclusivity, inspect the current Lunar UI and competitor releases.

| ID | Proposed new feature | Exact product demo / ad hook | Engineering and validation |
|---|---|---|---|
| N01 | **Time Machine for Displays** | "Watch tomorrow's screen brightness happen in 24 seconds." Animated 24-hour curve with a draggable clock preview | Extend current 24-second test; simulator must restore previous values after exit |
| N02 | **Monitor Doctor** | "Know why your monitor won't respond in one click." Finds DDC, AppleNative, broken dock, gamma fallback | Read-only probe, topology map, VCP results, exportable redacted report |
| N03 | **Automatic Multi-Monitor Matching Wizard** | "Make three different monitors look equally bright." | Calibrate at 3+ perceptual points; nits meter optional; save learned mappings |
| N04 | **One-Click KVM Scenes** | "Move every monitor to your gaming PC with one shortcut." | Grouped DDC input + audio routing + layout snapshots; partial success rollback |
| N05 | **Brightness Change Inspector** | "Why did my screen just dim?" Shows last action, active rule, sensor, effective state | Local event journal with no telemetry and selectable retention |
| N06 | **Visual Rules and Conflict Simulator** | "See exactly which settings will win before enabling them." | Deterministic rule precedence and UI simulation fixtures |
| N07 | **Room-Aware Profiles** | "Your home office and studio each get their own perfect display setup." | User-selected room/sensor/location profiles; optional network/sensor trigger |
| N08 | **Universal Preset Packages** | "Take your calibrated display setup to another Mac." | Portable, versioned JSON scene bundle and monitor reassignment wizard |
| N09 | **Transition Quality Meter** | "Smooth without hammering your monitor with commands." | Count DDC writes, timing, ramp jitter; measured performance comparison |
| N10 | **Calibrated Night / Day Scenes** | "A full HDR-to-night transition with no harsh jumps." | Per-display physical + software dimming combined curve, color guardrails |
| N11 | **Scene Automation Gallery** | "Install your entire workstation workflow in one click." | Curated scene packs: video call, color work, movie, gaming KVM, nighttime |
| N12 | **Privacy-First Offline Automation** | "Your brightness schedule works with Wi-Fi turned off." | All schedules local; optional remote sensors authenticated; publish privacy design |

Strongest launch demonstration sequence: (1) 24-hour preview, (2) unmatched monitors before/after guided calibration, (3) one-hotkey KVM scene, (4) Monitor Doctor diagnosing a faulty DDC path. These are visible benefits, not speculative performance marketing.

## 8. Delivery economics and distribution decisions

- Apple Developer Program is **US $99/year**, not a one-time US $99 purchase: https://developer.apple.com/get-started/
- Because our Apple-native/XDR capabilities may require private or otherwise App-Store-ineligible APIs, plan first for **direct Developer ID-signed + notarized distribution**. Apple states Mac App Store apps may only use public APIs: https://developer.apple.com/app-store/review/guidelines/ . Direct distribution: https://developer.apple.com/macos/distribution/
- Trial / licensing, one-time payment, updater and support must be implemented and tested, not deferred to "after release."
- Proposed introductory price **$11.49** one-time versus Lunar's published **$23** lifetime license. Define number of covered Macs and future upgrade rights before collecting payment. Price is a commercial hypothesis, not proof of sales.
- Target a universal Intel + Apple silicon binary where OS APIs permit. The existing package currently targets macOS 13 and must be adapted for Lunar v6's macOS 12+ baseline.
- Lunar's public repository is MIT-licensed but explicitly omits encrypted/closed Pro code. Study it for documented algorithms/API patterns under its license; do not assume that repository is buildable or provides Pro source: https://github.com/alin23/Lunar

## 9. Immediate Astra/Codex work order — start coding now

**Task 001: Baseline and preserve working code.** Checkout the SolarDim branch. Run all SwiftPM tests and compile the actual macOS app. Document current build errors, compiler/SDK versions, and whether DisplayServices supports the built-in iMac. Do not touch the user's Mac through RDC; Astra handles hardware execution in its own authorized environment. Preserve the exact solar defaults and 04:00 cache schedule. Add a failing regression test for any discovered problem, then fix.

**Task 002: Create the core interfaces, tests, and no-hardware simulation.** Add DisplayIdentity, CapabilitySet, DisplayTransport, DisplayRegistry, DesiredDisplayState, DisplayCoordinator, AdaptiveMode and Scene. Create a FakeDisplayTransport that can simulate transport failure, multiple screens, wake and HDR capability. Refactor existing NativeDisplay brightness writes behind the transport. Add typed error states and no-op write deduplication. Requirements: UI no longer reaches DisplayServices directly; schedule and simulated-day tests must run without a physical monitor.

**Task 003: First external-display end-to-end.** Implement one real external DDC backend for the hardware available to Astra (Intel or Apple silicon), then expand to the other platform. Support discovery, brightness, contrast, volume, input, readback, clamping, and queueing. Show capability/readout in the menu. Add fixtures for DDC unsupported, stale port, disconnection during write, duplicate EDID and monitor power-off. When these tests pass, proceed to M2; do not mark untested Apple silicon or vendor models as done.

**Recommended engineering checkpoint artifacts after each milestone:** updated feature checkboxes in this file; code commit; unit/integration result; concrete tested Mac/monitor/OS matrix; performance measurements if applicable; no "works" statements without evidence.

## 10. Primary sources / audit references

1. Lunar features / free-vs-Pro table: https://lunar.fyi/
2. Lunar Pro manual, including algorithm behavior and BlackOut modifiers: https://lunar.fyi/pro
3. Official changelog through v6.11.3: https://lunar.fyi/changelog
4. Lunar Shortcuts recipes: https://lunar.fyi/shortcuts
5. Lunar v6 release notes (nits sync, DisplayLink, Sidecar): https://files.lunar.fyi/ReleaseNotes/Lunar-6.0.0.html
6. FAQ and hardware compatibility caveats: https://lunar.fyi/faq
7. Public source/repository README and MIT license: https://github.com/alin23/Lunar
8. Apple Developer Program: https://developer.apple.com/get-started/
9. Apple App Review Guidelines, public APIs: https://developer.apple.com/app-store/review/guidelines/
10. Apple notarization/distribution: https://developer.apple.com/macos/distribution/

## 11. Audit follow-through

The ledger covers the publicly documented product. The final audit requires hands-on observation of the installed Lunar trial, particularly hidden advanced settings, lesser-known hotkeys, OSD details, color calibration and OS-specific path behavior. Every finding must be recorded as a new ID before coding or declaring parity. If Lunar v7 ships during development, open a separate version-diff audit; do not silently change the defined v6.11.3 acceptance baseline.
