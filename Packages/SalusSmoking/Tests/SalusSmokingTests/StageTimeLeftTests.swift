import Testing

@testable import SalusSmoking

// Twin of `StageTimeLeftTest.kt` (contract §8.15): the one rounded-up "time left to the next stage"
// rule that Home, Main and the timeline share. Case for case, so a drift shows on both platforms.

private let minute: Int64 = 60000
private let hour: Int64 = 3_600_000
private let day: Int64 = 86_400_000

@Suite("StageTimeLeft (contract section 8.15)")
struct StageTimeLeftTests {
    private func left(_ ms: Int64) -> TimeLeft {
        StageTimeLeft.of(remainingMs: ms)
    }

    @Test("an exact unit is that unit")
    func exactUnit() {
        #expect(left(3 * day) == TimeLeft(unit: .days, count: 3))
        #expect(left(day) == TimeLeft(unit: .days, count: 1))
        #expect(left(5 * hour) == TimeLeft(unit: .hours, count: 5))
        #expect(left(hour) == TimeLeft(unit: .hours, count: 1))
        #expect(left(20 * minute) == TimeLeft(unit: .minutes, count: 20))
    }

    @Test("one millisecond over rounds the count up")
    func oneMillisecondOver() {
        #expect(left(3 * day + 1) == TimeLeft(unit: .days, count: 4))
        #expect(left(day + 1) == TimeLeft(unit: .days, count: 2))
        #expect(left(5 * hour + 1) == TimeLeft(unit: .hours, count: 6))
        #expect(left(20 * minute + 1) == TimeLeft(unit: .minutes, count: 21))
    }

    @Test("under a minute still reads one minute, never zero")
    func underAMinute() {
        #expect(left(1) == TimeLeft(unit: .minutes, count: 1))
        #expect(left(59999) == TimeLeft(unit: .minutes, count: 1))
        #expect(left(0) == TimeLeft(unit: .minutes, count: 1))
        #expect(left(-5000) == TimeLeft(unit: .minutes, count: 1))
    }

    @Test("2 days 23 hours reads 3 days")
    func twoDaysTwentyThreeHours() {
        #expect(left(2 * day + 23 * hour) == TimeLeft(unit: .days, count: 3))
    }

    @Test("the unit rolls over after rounding, at all four boundaries")
    func unitRollsOverAfterRounding() {
        // 59 min 30 s rounds to 60 minutes, which is 1 hour; 23 h 59 min rounds to 24 hours, 1 day.
        #expect(left(59 * minute + 30000) == TimeLeft(unit: .hours, count: 1))
        #expect(left(23 * hour + 59 * minute) == TimeLeft(unit: .days, count: 1))
        #expect(left(hour) == TimeLeft(unit: .hours, count: 1))
        #expect(left(day) == TimeLeft(unit: .days, count: 1))
        #expect(left(59 * minute) == TimeLeft(unit: .minutes, count: 59))
        #expect(left(23 * hour) == TimeLeft(unit: .hours, count: 23))
    }

    @Test("a huge remainder does not overflow the rounding")
    func hugeRemainderDoesNotOverflow() {
        #expect(left(Int64.max).unit == .days)
        #expect(left(Int64.max).count > 0)
    }
}
