import Foundation
import XCTest
@testable import SolarDimCore

final class ScheduleTests: XCTestCase {
    private var config = SolarDimConfiguration()

    private func localDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        let cal = SolarSchedule.calendar(for: config)
        return cal.date(from: DateComponents(year: year, month: month, day: day,
                                             hour: hour, minute: minute))!
    }

    func testDefaults() throws {
        try config.validate()
        XCTAssertEqual(config.levels.midnight, 1)
        XCTAssertEqual(config.levels.sunrise, 4)
        XCTAssertEqual(config.levels.solarNoon, 9)
        XCTAssertEqual(config.levels.darkness, 4)
        XCTAssertEqual(config.levels.eveningEnd, 2)
        XCTAssertEqual(config.darknessSunAltitudeDegrees, -18)
    }

    func testAnchorLevels() throws {
        let date = localDate(2026, 11, 4, 12)
        let today = try SolarSchedule.day(containing: date, config: config)
        for point in today.points {
            XCTAssertEqual(try SolarSchedule.level(at: point.time, config: config), point.level,
                           accuracy: 0.00001, point.name)
        }
    }

    func testMidpointsInterpolate() throws {
        let day = try SolarSchedule.day(containing: localDate(2026, 11, 4, 12), config: config)
        for (first, second) in zip(day.points, day.points.dropFirst()) {
            let middle = first.time.addingTimeInterval(second.time.timeIntervalSince(first.time) / 2)
            XCTAssertEqual(try SolarSchedule.level(at: middle, config: config),
                           (first.level + second.level) / 2, accuracy: 0.0001)
        }
    }

    func testSolarEventOrderingAndReasonableDCNoon() throws {
        let day = try SolarSchedule.day(containing: localDate(2026, 11, 4, 12), config: config)
        XCTAssertTrue(day.sunrise < day.solarNoon)
        XCTAssertTrue(day.solarNoon < day.darkness)
        let cal = SolarSchedule.calendar(for: config)
        let hour = cal.component(.hour, from: day.solarNoon)
        XCTAssertTrue((11...12).contains(hour))
    }

    func testDSTForwardAndBackDoNotShiftSolarNoonByOneHour() throws {
        // Solar noon should be around 13:xx in EDT and 12:xx in EST,
        // including on the calendar days on which the clock switches.
        let cal = SolarSchedule.calendar(for: config)
        let spring = try SolarSchedule.day(containing: localDate(2026, 3, 8, 12), config: config)
        let fall = try SolarSchedule.day(containing: localDate(2026, 11, 1, 12), config: config)
        XCTAssertEqual(cal.component(.hour, from: spring.solarNoon), 13)
        XCTAssertEqual(cal.component(.hour, from: fall.solarNoon), 11)
        XCTAssertEqual(try SolarSchedule.level(at: spring.sunrise, config: config), 4)
        XCTAssertEqual(try SolarSchedule.level(at: fall.sunrise, config: config), 4)
    }

    func testMidnightContinuityAcrossDays() throws {
        let midnight = localDate(2026, 11, 5, 0)
        let previous = try SolarSchedule.level(at: midnight.addingTimeInterval(-1), config: config)
        let next = try SolarSchedule.level(at: midnight, config: config)
        XCTAssertLessThan(abs(previous - next), 0.001)
    }

    func testInvalidConfigurationRejected() {
        config.levels.solarNoon = 20
        XCTAssertThrowsError(try config.validate())
        config.levels.solarNoon = 9
        config.timeZone = "Unknown/TimeZone"
        XCTAssertThrowsError(try config.validate())
    }

    func testMonotonicDaylightAndEveningChanges() throws {
        let day = try SolarSchedule.day(containing: localDate(2026, 6, 21, 12), config: config)
        for (left, right) in zip(day.points, day.points.dropFirst()) {
            let middle = left.time.addingTimeInterval(right.time.timeIntervalSince(left.time) / 2)
            let val = try SolarSchedule.level(at: middle, config: config)
            XCTAssertGreaterThanOrEqual(val, min(left.level, right.level))
            XCTAssertLessThanOrEqual(val, max(left.level, right.level))
        }
    }
}
