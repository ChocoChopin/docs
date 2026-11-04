import Foundation
import XCTest
@testable import SolarDimCore

final class DailyScheduleCacheTests: XCTestCase {
    private let config = SolarDimConfiguration()

    private func localDate(_ year: Int, _ month: Int, _ day: Int,
                           _ hour: Int, _ minute: Int = 0, _ second: Int = 0) -> Date {
        let calendar = SolarSchedule.calendar(for: config)
        return calendar.date(from: DateComponents(year: year, month: month, day: day,
                                                    hour: hour, minute: minute, second: second))!
    }

    func testManyPollsDoNotRecalculateSun() throws {
        let cache = DailyScheduleCache(config: config)
        let atThree = localDate(2026, 11, 4, 3, 0)
        for i in 0..<120 {
            let time = atThree.addingTimeInterval(Double(i) * 30)
            _ = try cache.level(at: time, now: time)
        }
        XCTAssertEqual(cache.refreshCount, 1, "30-second polls must only interpolate")
    }

    func testRefreshAtFourAMExactlyOnce() throws {
        let cache = DailyScheduleCache(config: config)
        let before = localDate(2026, 11, 4, 3, 59, 59)
        let after = localDate(2026, 11, 4, 4, 0, 0)
        _ = try cache.level(at: before, now: before)
        XCTAssertEqual(cache.refreshCount, 1)
        _ = try cache.level(at: after, now: after)
        XCTAssertEqual(cache.refreshCount, 2)
        for i in 0..<200 {
            let sample = after.addingTimeInterval(Double(i) * 30)
            _ = try cache.level(at: sample, now: sample)
        }
        XCTAssertEqual(cache.refreshCount, 2)
    }

    func testMidnightUsesTomorrowPrecomputedAtFourAM() throws {
        let cache = DailyScheduleCache(config: config)
        let evening = localDate(2026, 11, 4, 23, 59, 59)
        let nextDay = localDate(2026, 11, 5, 0, 0, 0)
        _ = try cache.level(at: evening, now: evening)
        let count = cache.refreshCount
        let atMidnight = try cache.level(at: nextDay, now: nextDay)
        let beforeFour = localDate(2026, 11, 5, 3, 59)
        _ = try cache.level(at: beforeFour, now: beforeFour)
        XCTAssertEqual(cache.refreshCount, count)
        XCTAssertEqual(atMidnight, 1, accuracy: 0.00001)
        XCTAssertEqual(try cache.day(containing: nextDay, now: nextDay).points[0].time, nextDay)
    }

    func testWakeAfterFourRefreshes() throws {
        let cache = DailyScheduleCache(config: config)
        let before = localDate(2026, 11, 4, 2, 30)
        let wake = localDate(2026, 11, 4, 9, 0)
        _ = try cache.level(at: before, now: before)
        _ = try cache.level(at: wake, now: wake)
        XCTAssertEqual(cache.refreshCount, 2)
    }

    func testConfigEditRebuildsImmediately() throws {
        let cache = DailyScheduleCache(config: config)
        let noon = localDate(2026, 11, 4, 12)
        _ = try cache.level(at: noon, now: noon)
        var changed = config
        changed.levels.solarNoon = 12
        cache.replaceConfiguration(changed)
        _ = try cache.level(at: noon, now: noon)
        XCTAssertEqual(cache.refreshCount, 2)
        let solarNoon = try cache.day(containing: noon, now: noon).solarNoon
        XCTAssertEqual(try cache.level(at: solarNoon, now: noon), 12, accuracy: 0.0001)
    }

    func testDSTChangesRespectLocalFourAM() throws {
        let cache = DailyScheduleCache(config: config)
        let fallEarly = localDate(2026, 11, 1, 0, 30)
        let fallThree = localDate(2026, 11, 1, 3, 0)
        let fallFour = localDate(2026, 11, 1, 4, 0)
        _ = try cache.level(at: fallEarly, now: fallEarly)
        _ = try cache.level(at: fallThree, now: fallThree)
        XCTAssertEqual(cache.refreshCount, 1)
        _ = try cache.level(at: fallFour, now: fallFour)
        XCTAssertEqual(cache.refreshCount, 2)
        let cal = SolarSchedule.calendar(for: config)
        XCTAssertEqual(cal.component(.hour, from: cache.nextRefreshAt), 4)
        XCTAssertEqual(cal.component(.day, from: cache.nextRefreshAt), 2)
    }
}
