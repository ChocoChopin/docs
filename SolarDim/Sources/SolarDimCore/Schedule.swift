import Foundation

/// Levels are expressed in macOS's familiar 0...16 brightness-key increments.
/// Intermediate values are intentional: the hardware receives continuous 0...1 values.
public enum BrightnessAnchor: String, CaseIterable, Codable {
    case midnight, sunrise, solarNoon, darkness, eveningStart, eveningEnd

    public var label: String {
        switch self {
        case .midnight: return "Midnight (00:00)"
        case .sunrise: return "Sunrise"
        case .solarNoon: return "Solar noon"
        case .darkness: return "Darkness / dusk"
        case .eveningStart: return "11:00 PM"
        case .eveningEnd: return "11:30 PM"
        }
    }
}

public enum SolarDimError: LocalizedError {
    case invalidConfiguration(String)
    case noSolarEvent(String)

    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let message): return "Invalid configuration: \(message)"
        case .noSolarEvent(let message): return "Cannot calculate solar schedule: \(message)"
        }
    }
}

public struct BrightnessLevels: Codable, Equatable {
    public var midnight: Double = 1
    public var sunrise: Double = 4
    public var solarNoon: Double = 9
    public var darkness: Double = 4
    public var eveningStart: Double = 4
    public var eveningEnd: Double = 2

    public init() {}

    public func value(for anchor: BrightnessAnchor) -> Double {
        switch anchor {
        case .midnight: return midnight
        case .sunrise: return sunrise
        case .solarNoon: return solarNoon
        case .darkness: return darkness
        case .eveningStart: return eveningStart
        case .eveningEnd: return eveningEnd
        }
    }

    public mutating func set(_ value: Double, for anchor: BrightnessAnchor) {
        switch anchor {
        case .midnight: midnight = value
        case .sunrise: sunrise = value
        case .solarNoon: solarNoon = value
        case .darkness: darkness = value
        case .eveningStart: eveningStart = value
        case .eveningEnd: eveningEnd = value
        }
    }
}

public struct SolarDimConfiguration: Codable, Equatable {
    /// Washington, DC; east-positive longitude. No network lookup or geolocation permission.
    public var latitude: Double = 38.9072
    public var longitude: Double = -77.0369
    public var timeZone: String = "America/New_York"
    /// Elevation of sun's center below horizon at "darkness"; -18 = astronomical dusk.
    public var darknessSunAltitudeDegrees: Double = -18
    public var updateIntervalSeconds: Double = 30
    public var levels: BrightnessLevels = BrightnessLevels()

    public init() {}

    public func validate() throws {
        guard latitude.isFinite, (-89.9...89.9).contains(latitude) else {
            throw SolarDimError.invalidConfiguration("latitude must be between -89.9 and 89.9")
        }
        guard longitude.isFinite, (-180...180).contains(longitude) else {
            throw SolarDimError.invalidConfiguration("longitude must be between -180 and 180")
        }
        guard TimeZone(identifier: timeZone) != nil else {
            throw SolarDimError.invalidConfiguration("unknown IANA time zone '\(timeZone)'")
        }
        guard [-0.833, -6.0, -12.0, -18.0].contains(darknessSunAltitudeDegrees) else {
            throw SolarDimError.invalidConfiguration("darknessSunAltitudeDegrees must be -0.833, -6, -12 or -18")
        }
        guard updateIntervalSeconds.isFinite, (0.05...3600).contains(updateIntervalSeconds) else {
            throw SolarDimError.invalidConfiguration("updateIntervalSeconds must be between 0.05 and 3600")
        }
        for anchor in BrightnessAnchor.allCases {
            let value = levels.value(for: anchor)
            guard value.isFinite, (0...16).contains(value) else {
                throw SolarDimError.invalidConfiguration("\(anchor.rawValue) brightness must be between 0 and 16")
            }
        }
    }
}

public struct SchedulePoint {
    public let name: String
    public let time: Date
    public let level: Double
    public init(name: String, time: Date, level: Double) {
        self.name = name
        self.time = time
        self.level = level
    }
}

public struct SolarDay {
    public let sunrise: Date
    public let solarNoon: Date
    public let darkness: Date
    public let points: [SchedulePoint]
}

/// NOAA fractional-year approximation: equation of time, declination and hour angle.
/// Calculation is fully offline. Local calendar dates respect the configured time zone / DST.
public enum SolarSchedule {
    public static func calendar(for config: SolarDimConfiguration) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: config.timeZone) ?? .gmt
        return calendar
    }

    public static func day(containing date: Date, config: SolarDimConfiguration) throws -> SolarDay {
        try config.validate()
        let calendar = calendar(for: config)
        let dayStart = calendar.startOfDay(for: date)
        guard let nextMidnight = calendar.date(byAdding: .day, value: 1, to: dayStart),
              let noonForDay = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: dayStart),
              let dayNumber = calendar.ordinality(of: .day, in: .year, for: noonForDay),
              let daysInYear = calendar.range(of: .day, in: .year, for: noonForDay)?.count else {
            throw SolarDimError.invalidConfiguration("unable to construct local day")
        }

        let gamma = (2 * Double.pi / Double(daysInYear)) * Double(dayNumber - 1)
        let eqTime = 229.18 * (
            0.000075 + 0.001868 * cos(gamma) - 0.032077 * sin(gamma)
            - 0.014615 * cos(2 * gamma) - 0.040849 * sin(2 * gamma)
        )
        let declination = 0.006918 - 0.399912 * cos(gamma)
            + 0.070257 * sin(gamma) - 0.006758 * cos(2 * gamma)
            + 0.000907 * sin(2 * gamma) - 0.002697 * cos(3 * gamma)
            + 0.00148 * sin(3 * gamma)
        let localUTCOffsetMinutes = Double(calendar.timeZone.secondsFromGMT(for: noonForDay)) / 60
        let noonMinutes = 720 - 4 * config.longitude - eqTime + localUTCOffsetMinutes
        let latitude = config.latitude * .pi / 180

        func hourAngle(for altitudeDegrees: Double) throws -> Double {
            let altitude = altitudeDegrees * .pi / 180
            let divisor = cos(latitude) * cos(declination)
            let cosine = (sin(altitude) - sin(latitude) * sin(declination)) / divisor
            guard cosine >= -1, cosine <= 1 else {
                throw SolarDimError.noSolarEvent("sun does not cross \(altitudeDegrees)° today")
            }
            return acos(cosine) * 180 / .pi
        }

        // Build from civil clock components, NOT by adding seconds to midnight:
        // a DST change between midnight and noon would introduce a one-hour error.
        func localClockDate(minutes: Double) -> Date? {
            let rounded = Int((minutes * 60).rounded())
            var components = calendar.dateComponents([.year, .month, .day], from: noonForDay)
            components.hour = Int(floor(Double(rounded) / 3600))
            components.minute = (rounded / 60 % 60 + 60) % 60
            components.second = (rounded % 60 + 60) % 60
            return calendar.date(from: components)
        }

        let sunriseHA = try hourAngle(for: -0.833)
        let darknessHA = try hourAngle(for: config.darknessSunAltitudeDegrees)
        guard let sunrise = localClockDate(minutes: noonMinutes - 4 * sunriseHA),
              let noon = localClockDate(minutes: noonMinutes),
              let darkness = localClockDate(minutes: noonMinutes + 4 * darknessHA),
              let eveningStart = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: dayStart),
              let eveningEnd = calendar.date(bySettingHour: 23, minute: 30, second: 0, of: dayStart) else {
            throw SolarDimError.invalidConfiguration("unable to construct schedule anchors")
        }

        let levels = config.levels
        let points = [
            SchedulePoint(name: "Midnight", time: dayStart, level: levels.midnight),
            SchedulePoint(name: "Sunrise", time: sunrise, level: levels.sunrise),
            SchedulePoint(name: "Solar noon", time: noon, level: levels.solarNoon),
            SchedulePoint(name: "Darkness", time: darkness, level: levels.darkness),
            SchedulePoint(name: "11:00 PM", time: eveningStart, level: levels.eveningStart),
            SchedulePoint(name: "11:30 PM", time: eveningEnd, level: levels.eveningEnd),
            SchedulePoint(name: "Next midnight", time: nextMidnight, level: levels.midnight)
        ]
        guard zip(points, points.dropFirst()).allSatisfy({ $0.time < $1.time }) else {
            throw SolarDimError.invalidConfiguration("solar events overlap the 11 PM / midnight anchors at this location")
        }
        return SolarDay(sunrise: sunrise, solarNoon: noon, darkness: darkness, points: points)
    }

    /// Piecewise-linear interpolation across real elapsed time; returns a fractional key step.
    public static func level(at date: Date, config: SolarDimConfiguration) throws -> Double {
        let points = try day(containing: date, config: config).points
        for index in 0..<(points.count - 1) {
            let start = points[index]
            let end = points[index + 1]
            if date >= start.time && date < end.time {
                let progress = date.timeIntervalSince(start.time) / end.time.timeIntervalSince(start.time)
                return start.level + (end.level - start.level) * progress
            }
        }
        return config.levels.midnight
    }
}

public enum ConfigurationStore {
    public static var url: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/SolarDim/config.json")
    }

    public static func loadOrCreate() throws -> SolarDimConfiguration {
        let path = url
        if !FileManager.default.fileExists(atPath: path.path) {
            let defaults = SolarDimConfiguration()
            try save(defaults)
            return defaults
        }
        let configuration = try JSONDecoder().decode(SolarDimConfiguration.self, from: Data(contentsOf: path))
        try configuration.validate()
        return configuration
    }

    public static func save(_ configuration: SolarDimConfiguration) throws {
        try configuration.validate()
        let path = url
        try FileManager.default.createDirectory(at: path.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(configuration).write(to: path, options: .atomic)
    }
}
