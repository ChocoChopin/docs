import Foundation
import SolarDimCore

func printSchedule(_ configuration: SolarDimConfiguration, fullDay: Bool) throws {
    let calendar = SolarSchedule.calendar(for: configuration)
    let now = Date()
    let day = try SolarSchedule.day(containing: now, config: configuration)
    let formatter = DateFormatter()
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss zzz"
    print("SolarDim schedule (\(configuration.latitude), \(configuration.longitude); \(configuration.timeZone))")
    for point in day.points {
        print(String(format: "%@: %.2f / 16", formatter.string(from: point.time), point.level) + " — \(point.name)")
    }
    if fullDay {
        let start = day.points[0].time
        let end = day.points[day.points.count - 1].time
        for i in 0...48 {
            let date = start.addingTimeInterval(end.timeIntervalSince(start) * Double(i) / 48)
            print(String(format: "%@ -> %.3f / 16", formatter.string(from: date),
                         SolarSchedule.level(at: date, in: day)))
        }
    }
}

#if os(macOS)
import AppKit
import CoreGraphics
import Darwin

private enum DisplayError: LocalizedError {
    case unavailable(String)
    var errorDescription: String? {
        switch self { case .unavailable(let message): return "Display brightness: \(message)" }
    }
}

/// Hardware brightness of the built-in iMac panel, not a black-window overlay.
/// DisplayServices is Apple's private but widely used display control framework.
private final class BuiltInBrightness {
    private typealias Get = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    private typealias Set = @convention(c) (UInt32, Float) -> Int32
    private typealias Changed = @convention(c) (UInt32, Double) -> Void
    private let library: UnsafeMutableRawPointer
    private let getBrightness: Get
    private let setBrightness: Set
    private let brightnessChanged: Changed?

    init() throws {
        let path = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        guard let lib = dlopen(path, RTLD_NOW) else {
            throw DisplayError.unavailable("DisplayServices.framework could not be loaded")
        }
        guard let getSymbol = dlsym(lib, "DisplayServicesGetBrightness"),
              let setSymbol = dlsym(lib, "DisplayServicesSetBrightness") else {
            dlclose(lib)
            throw DisplayError.unavailable("DisplayServices brightness functions not found")
        }
        library = lib
        getBrightness = unsafeBitCast(getSymbol, to: Get.self)
        setBrightness = unsafeBitCast(setSymbol, to: Set.self)
        brightnessChanged = dlsym(lib, "DisplayServicesBrightnessChanged").map {
            unsafeBitCast($0, to: Changed.self)
        }
    }

    deinit { dlclose(library) }

    private func builtInDisplayID() throws -> CGDirectDisplayID {
        var count: UInt32 = 0
        var ids = [CGDirectDisplayID](repeating: 0, count: 32)
        let result = CGGetOnlineDisplayList(UInt32(ids.count), &ids, &count)
        guard result == .success else {
            throw DisplayError.unavailable("could not enumerate screens (\(result.rawValue))")
        }
        guard let id = ids.prefix(Int(count)).first(where: { CGDisplayIsBuiltin($0) != 0 }) else {
            throw DisplayError.unavailable("no built-in display found; external TVs are not controlled")
        }
        return id
    }

    func read() throws -> Double {
        let id = try builtInDisplayID()
        var value: Float = 0
        let result = getBrightness(id, &value)
        guard result == 0, value.isFinite else {
            throw DisplayError.unavailable("cannot read built-in backlight (error \(result))")
        }
        return Double(value)
    }

    func set(normalized: Double) throws {
        let id = try builtInDisplayID()
        // A successful read is a necessary capability check; Set alone can report
        // success for unsupported display identifiers on some macOS versions.
        var current: Float = 0
        guard getBrightness(id, &current) == 0 else {
            throw DisplayError.unavailable("built-in screen has no readable hardware brightness")
        }
        let desired = Float(max(0, min(1, normalized)))
        let result = setBrightness(id, desired)
        guard result == 0 else {
            throw DisplayError.unavailable("setting brightness failed (error \(result))")
        }
        brightnessChanged?(id, Double(desired))
    }
}

private enum LoginAgent {
    static let label = "com.chocochopin.SolarDim"
    static var url: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }
    static var isEnabled: Bool { FileManager.default.fileExists(atPath: url.path) }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            guard let binary = Bundle.main.executableURL?.path else {
                throw DisplayError.unavailable("cannot identify application executable")
            }
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            let plist: [String: Any] = [
                "Label": label,
                "ProgramArguments": [binary],
                "RunAtLoad": true
            ]
            let data = try PropertyListSerialization.data(fromPropertyList: plist,
                                                           format: .xml, options: 0)
            try data.write(to: url, options: .atomic)
        } else if isEnabled {
            try FileManager.default.removeItem(at: url)
        }
        // launchd loads RunAtLoad LaunchAgents at the next user login.
        // No KeepAlive: choosing Quit should actually quit.
    }
}

@MainActor
private final class SolarDimApp: NSObject, NSApplicationDelegate {
    private var config = SolarDimConfiguration()
    private var scheduleCache = DailyScheduleCache(config: SolarDimConfiguration())
    private var configProblem: String?
    private var statusItem: NSStatusItem!
    private var statusLine: NSMenuItem!
    private var timer: Timer?
    private var controller: BuiltInBrightness?
    private var paused = false
    private var lastError: String?
    private var currentLevel: Double = 0

    private struct TestRun {
        let uptime: TimeInterval
        let startOfDay: Date
        let endOfDay: Date
    }
    private var test: TestRun?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        do {
            config = try ConfigurationStore.loadOrCreate()
            scheduleCache.replaceConfiguration(config)
        }
        catch { configProblem = error.localizedDescription }
        do { controller = try BuiltInBrightness() }
        catch { lastError = error.localizedDescription }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: "SolarDim")
            button.image?.isTemplate = true
            button.toolTip = "SolarDim — solar-scheduled iMac brightness"
        }
        rebuildMenu()
        resetTimer()
        applyBrightness()
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(didWake(_:)), name: NSWorkspace.didWakeNotification, object: nil)
    }

    private func menuItem(_ title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        statusLine = NSMenuItem(title: "SolarDim", action: nil, keyEquivalent: "")
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        let timesLine = NSMenuItem(title: solarTimesText(), action: nil, keyEquivalent: "")
        timesLine.isEnabled = false
        menu.addItem(timesLine)
        menu.addItem(.separator())

        let levelsItem = NSMenuItem(title: "Brightness at…", action: nil, keyEquivalent: "")
        let levelsMenu = NSMenu()
        for anchor in BrightnessAnchor.allCases {
            let item = NSMenuItem(title: anchor.label, action: nil, keyEquivalent: "")
            let choices = NSMenu()
            for level in 0...16 {
                let choice = menuItem("\(level) / 16", action: #selector(chooseLevel(_:)))
                choice.representedObject = "\(anchor.rawValue)|\(level)"
                if config.levels.value(for: anchor) == Double(level) { choice.state = .on }
                choices.addItem(choice)
            }
            item.submenu = choices
            levelsMenu.addItem(item)
        }
        levelsItem.submenu = levelsMenu
        menu.addItem(levelsItem)

        let darknessItem = NSMenuItem(title: "Darkness means…", action: nil, keyEquivalent: "")
        let darknessMenu = NSMenu()
        let duskChoices: [(String, Double)] = [
            ("Sunset", -0.833), ("Civil dusk (−6°)", -6),
            ("Nautical dusk (−12°)", -12), ("Astronomical dusk (−18°)", -18)
        ]
        for (label, angle) in duskChoices {
            let item = menuItem(label, action: #selector(chooseDarkness(_:)))
            item.representedObject = angle
            if config.darknessSunAltitudeDegrees == angle { item.state = .on }
            darknessMenu.addItem(item)
        }
        darknessItem.submenu = darknessMenu
        menu.addItem(darknessItem)

        let intervalItem = NSMenuItem(title: "Update interval", action: nil, keyEquivalent: "")
        let intervals = NSMenu()
        for seconds in [1.0, 5.0, 10.0, 30.0, 60.0] {
            let choice = menuItem("\(Int(seconds)) seconds", action: #selector(chooseInterval(_:)))
            choice.representedObject = seconds
            if config.updateIntervalSeconds == seconds { choice.state = .on }
            intervals.addItem(choice)
        }
        intervalItem.submenu = intervals
        menu.addItem(intervalItem)
        menu.addItem(menuItem("Set Location…", action: #selector(editLocation(_:))))
        menu.addItem(menuItem("Open Configuration File", action: #selector(openConfiguration(_:))))
        menu.addItem(menuItem("Reload Configuration File", action: #selector(reloadConfiguration(_:))))
        menu.addItem(.separator())

        menu.addItem(menuItem(test == nil ? "Test Full Day in 24 Seconds" : "Stop 24-Second Test",
                              action: #selector(toggleTest(_:))))
        menu.addItem(menuItem(paused ? "Resume Scheduling" : "Pause Scheduling",
                              action: #selector(togglePause(_:))))
        let startOnLogin = menuItem("Start at Login", action: #selector(toggleLogin(_:)))
        startOnLogin.state = LoginAgent.isEnabled ? .on : .off
        menu.addItem(startOnLogin)
        menu.addItem(.separator())
        menu.addItem(menuItem("Quit SolarDim", action: #selector(quit(_:))))
        statusItem.menu = menu
        updateStatusLine()
    }

    private func solarTimesText() -> String {
        guard let day = try? scheduleCache.day(containing: Date()) else {
            return "Solar times unavailable (check configuration)"
        }
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: config.timeZone)
        formatter.dateFormat = "h:mm a"
        return "Rise \(formatter.string(from: day.sunrise)) · Noon \(formatter.string(from: day.solarNoon)) · Dark \(formatter.string(from: day.darkness))"
    }

    private func updateStatusLine() {
        guard statusLine != nil else { return }
        if let error = configProblem ?? lastError {
            statusLine.title = "SolarDim ⚠ \(error)"
        } else if paused {
            statusLine.title = String(format: "SolarDim paused · %.2f / 16", currentLevel)
        } else if test != nil {
            statusLine.title = String(format: "SolarDim TEST · %.2f / 16", currentLevel)
        } else {
            statusLine.title = String(format: "SolarDim · %.2f / 16", currentLevel)
        }
    }

    private func resetTimer() {
        timer?.invalidate()
        let interval = test == nil ? config.updateIntervalSeconds : 0.05
        timer = Timer.scheduledTimer(timeInterval: interval, target: self,
                                     selector: #selector(timerFired(_:)), userInfo: nil, repeats: true)
        timer?.tolerance = test == nil ? min(1, interval * 0.1) : 0.01
    }

    @objc private func timerFired(_ timer: Timer) { applyBrightness() }
    @objc private func didWake(_ notification: Notification) { applyBrightness() }

    private func applyBrightness() {
        guard !paused, configProblem == nil else { updateStatusLine(); return }
        var effectiveDate = Date()
        if let run = test {
            let progress = (ProcessInfo.processInfo.systemUptime - run.uptime) / 24.0
            if progress >= 1 {
                self.test = nil
                resetTimer()
                rebuildMenu()
            } else {
                effectiveDate = run.startOfDay.addingTimeInterval(
                    (run.endOfDay.timeIntervalSince(run.startOfDay)) * max(0, progress))
            }
        }
        do {
            let level = try scheduleCache.level(at: effectiveDate)
            guard let controller = controller else {
                throw DisplayError.unavailable("display controller is not initialized")
            }
            try controller.set(normalized: level / 16)
            currentLevel = level
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        updateStatusLine()
    }

    private func saveAndApply(_ newConfig: SolarDimConfiguration) {
        do {
            try ConfigurationStore.save(newConfig)
            config = newConfig
            scheduleCache.replaceConfiguration(newConfig)
            configProblem = nil
            lastError = nil
            resetTimer()
            rebuildMenu()
            applyBrightness()
        } catch { showError(error) }
    }

    private func showError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "SolarDim"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func chooseLevel(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String else { return }
        let parts = raw.split(separator: "|")
        guard parts.count == 2, let anchor = BrightnessAnchor(rawValue: String(parts[0])),
              let value = Double(parts[1]) else { return }
        var next = config
        next.levels.set(value, for: anchor)
        saveAndApply(next)
    }

    @objc private func chooseDarkness(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Double else { return }
        var next = config
        next.darknessSunAltitudeDegrees = value
        saveAndApply(next)
    }

    @objc private func chooseInterval(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Double else { return }
        var next = config
        next.updateIntervalSeconds = value
        saveAndApply(next)
    }

    @objc private func editLocation(_ sender: NSMenuItem) {
        let alert = NSAlert()
        alert.messageText = "Location for solar calculations"
        alert.informativeText = "Enter decimal latitude, east-positive longitude, and an IANA time zone."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        let pane = NSView(frame: NSRect(x: 0, y: 0, width: 325, height: 94))
        let entries: [(String, String)] = [
            ("Latitude", String(config.latitude)),
            ("Longitude", String(config.longitude)),
            ("Time zone", config.timeZone)
        ]
        var fields: [NSTextField] = []
        for (index, entry) in entries.enumerated() {
            let y = CGFloat(64 - index * 31)
            let label = NSTextField(labelWithString: entry.0)
            label.frame = NSRect(x: 0, y: y + 3, width: 95, height: 20)
            let field = NSTextField(frame: NSRect(x: 100, y: y, width: 220, height: 24))
            field.stringValue = entry.1
            pane.addSubview(label)
            pane.addSubview(field)
            fields.append(field)
        }
        alert.accessoryView = pane
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        guard let lat = Double(fields[0].stringValue),
              let lon = Double(fields[1].stringValue) else {
            showError(SolarDimError.invalidConfiguration("coordinates must be numeric"))
            return
        }
        var next = config
        next.latitude = lat
        next.longitude = lon
        next.timeZone = fields[2].stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        saveAndApply(next)
    }

    @objc private func openConfiguration(_ sender: NSMenuItem) {
        NSWorkspace.shared.open(ConfigurationStore.url)
    }

    @objc private func reloadConfiguration(_ sender: NSMenuItem) {
        do {
            let next = try ConfigurationStore.loadOrCreate()
            config = next
            scheduleCache.replaceConfiguration(next)
            configProblem = nil
            lastError = nil
            resetTimer()
            rebuildMenu()
            applyBrightness()
        } catch { showError(error) }
    }

    @objc private func toggleTest(_ sender: NSMenuItem) {
        if test == nil {
            let calendar = SolarSchedule.calendar(for: config)
            let start = calendar.startOfDay(for: Date())
            guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return }
            paused = false
            test = TestRun(uptime: ProcessInfo.processInfo.systemUptime,
                           startOfDay: start, endOfDay: end)
        } else { test = nil }
        resetTimer()
        rebuildMenu()
        applyBrightness()
    }

    @objc private func togglePause(_ sender: NSMenuItem) {
        paused.toggle()
        if paused { test = nil; resetTimer() }
        rebuildMenu()
        applyBrightness()
    }

    @objc private func toggleLogin(_ sender: NSMenuItem) {
        do {
            try LoginAgent.setEnabled(!LoginAgent.isEnabled)
            rebuildMenu()
        } catch { showError(error) }
    }

    @objc private func quit(_ sender: NSMenuItem) {
        timer?.invalidate()
        NSApplication.shared.terminate(nil)
    }
}
#endif

@main
struct SolarDimMain {
    static func main() {
        let args = CommandLine.arguments
        if args.contains("--print-schedule") || args.contains("--dry-run") {
            do {
                let settings = try ConfigurationStore.loadOrCreate()
                try printSchedule(settings, fullDay: args.contains("--dry-run"))
            } catch {
                fputs("SolarDim: \(error.localizedDescription)\n", stderr)
                exit(EXIT_FAILURE)
            }
            return
        }
        #if os(macOS)
        let app = NSApplication.shared
        let delegate = SolarDimApp()
        app.delegate = delegate
        app.run()
        #else
        print("SolarDim menu-bar app requires macOS. Use --print-schedule or --dry-run here.")
        #endif
    }
}
