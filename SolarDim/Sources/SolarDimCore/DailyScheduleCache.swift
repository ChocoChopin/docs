import Foundation

/// Computes the local solar schedule at startup, then refreshes at 4:00 a.m.
/// A one-day lookahead ensures midnight is seamless without an extra solar calculation.
/// Brightness polls only interpolate across the cached points.
public final class DailyScheduleCache {
    private var config: SolarDimConfiguration
    private var days: [Date: SolarDay] = [:]
    private var builtAt: Date?

    public private(set) var nextRefreshAt: Date = .distantPast
    /// Counts refresh *batches* (today and tomorrow), not interpolation polls.
    public private(set) var refreshCount = 0

    public init(config: SolarDimConfiguration) {
        self.config = config
    }

    /// A location, threshold, or brightness-anchor edit requires an immediate rebuild.
    public func replaceConfiguration(_ newConfig: SolarDimConfiguration) {
        config = newConfig
        days.removeAll()
        builtAt = nil
        nextRefreshAt = .distantPast
    }

    public func refreshIfNeeded(at now: Date = Date()) throws {
        let calendar = SolarSchedule.calendar(for: config)
        let todayStart = calendar.startOfDay(for: now)
        let clockMovedBackwards = builtAt.map { now < $0.addingTimeInterval(-60) } ?? false

        guard days[todayStart] == nil || now >= nextRefreshAt || clockMovedBackwards else {
            return
        }

        guard let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart),
              let nextRefresh = calendar.nextDate(
                after: now,
                matching: DateComponents(hour: 4, minute: 0, second: 0),
                matchingPolicy: .nextTime,
                repeatedTimePolicy: .first,
                direction: .forward
              ) else {
            throw SolarDimError.invalidConfiguration("unable to construct the next 4 a.m. refresh")
        }

        // Both schedules must succeed before replacing the existing cache.
        let today = try SolarSchedule.day(containing: todayStart, config: config)
        let tomorrow = try SolarSchedule.day(containing: tomorrowStart, config: config)
        days = [todayStart: today, tomorrowStart: tomorrow]
        builtAt = now
        nextRefreshAt = nextRefresh
        refreshCount += 1
    }

    public func day(containing date: Date, now: Date = Date()) throws -> SolarDay {
        try refreshIfNeeded(at: now)
        let start = SolarSchedule.calendar(for: config).startOfDay(for: date)
        guard let day = days[start] else {
            throw SolarDimError.invalidConfiguration("requested day outside the cached today/tomorrow schedule")
        }
        return day
    }

    public func level(at date: Date, now: Date = Date()) throws -> Double {
        let schedule = try day(containing: date, now: now)
        return SolarSchedule.level(at: date, in: schedule)
    }
}
