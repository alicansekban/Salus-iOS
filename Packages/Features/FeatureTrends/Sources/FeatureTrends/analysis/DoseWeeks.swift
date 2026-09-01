// Ported 1:1 from Android
// `feature/trends/src/main/kotlin/com/alicansekban/salus/feature/trends/analysis/DoseWeeks.kt`.

import SalusModel

/// One week of dose records, next to the measurements logged in the same week (`DoseWeeks.kt:36-43`).
///
/// `takenPercent` is the share of the doses this week *recorded* that were marked taken, and the
/// denominator is the whole point: a dose the user never wrote down is not in `loggedDoses` at
/// all, so a week where two doses were logged and both taken reads as 100 even if the schedule
/// called for fourteen. This number can therefore only ever describe what was written down, and
/// every line of copy built on it has to say so. It is `nil`, never zero, when nothing was
/// logged: no records is the absence of a ratio, while zero would be the claim that a week's
/// doses all went untaken.
///
/// The averages carry the same distinction. They are `nil` when the week holds no reading of
/// that metric, so a week nobody measured stays visibly unmeasured. Blood pressure is reduced to
/// its systolic number, the way the overlay reduces it, because one number per metric is what a
/// row of this card can hold.
///
/// Plain numbers only — no chart model and no UI type — so the analysis stays portable and the
/// mapping to bars happens at the UI edge.
public struct DoseWeek: Equatable, Sendable {
    /// The Monday this week began on, which may fall before the window.
    public let startEpochDay: Int
    /// Doses recorded inside the window and inside this week.
    public let loggedDoses: Int
    /// The subset of `loggedDoses` marked taken; never greater than it.
    public let takenDoses: Int
    /// The share of `loggedDoses` that were taken, as a whole percent, or `nil` when none were
    /// logged.
    public let takenPercent: Int?
    /// This week's mean systolic reading in mmHg, or `nil`.
    public let systolicAverage: Double?
    /// This week's mean glucose reading in canonical mg/dL, or `nil`.
    public let glucoseAverage: Double?

    public init(
        startEpochDay: Int,
        loggedDoses: Int,
        takenDoses: Int,
        takenPercent: Int?,
        systolicAverage: Double?,
        glucoseAverage: Double?
    ) {
        self.startEpochDay = startEpochDay
        self.loggedDoses = loggedDoses
        self.takenDoses = takenDoses
        self.takenPercent = takenPercent
        self.systolicAverage = systolicAverage
        self.glucoseAverage = glucoseAverage
    }
}

/// Groups `doses` and `measurements` into the weeks `days` covers (`DoseWeeks.kt:76-105`).
///
/// Pure and total. Every week the window touches comes back, oldest first and with no gaps —
/// including the first and last, which are usually partial. A partial week is not dropped: the
/// records in it are records the user asked about, and leaving the edges out would silently
/// shorten the window. It is also why the sequence is built from `days` rather than from the
/// records: a week nobody logged anything in still exists, and it comes back with a `nil` ratio
/// and `nil` averages rather than being skipped, so consecutive bars are always consecutive
/// weeks.
///
/// Records outside `days` are dropped first, for the same reason the overlay drops them: the
/// window is the question the user asked, and a stray dose from the week before would change a
/// ratio the user is looking at.
///
/// Weight is not averaged here. This card pairs the dose ratio with the two metrics a
/// medication schedule is normally watched against; a kilogram figure would sit in the row
/// saying nothing about the doses beside it.
public func doseWeeksOf(
    doses: [TrendDose],
    measurements: [TrendMeasurement],
    days: ClosedRange<Int>
) -> [DoseWeek] {
    if days.isEmpty {
        return []
    }

    let dosesByWeek = doses
        .filter { days.contains($0.epochDay) }
        .groupedBy { weekStartOf($0.epochDay) }
    let readingsByWeek = measurements
        .filter { days.contains($0.epochDay) }
        .groupedBy { weekStartOf($0.epochDay) }

    let weekStarts = stride(
        from: weekStartOf(days.lowerBound),
        through: weekStartOf(days.upperBound),
        by: daysPerWeek
    )
    return weekStarts.map { weekStart in
        let weekDoses = dosesByWeek[weekStart] ?? []
        let weekReadings = readingsByWeek[weekStart] ?? []
        let logged = weekDoses.count
        let taken = weekDoses.filter(\.taken).count
        return DoseWeek(
            startEpochDay: weekStart,
            loggedDoses: logged,
            takenDoses: taken,
            takenPercent: takenPercentOrNull(logged: logged, taken: taken),
            systolicAverage: weekReadings.averageOrNil(type: .bloodPressure),
            glucoseAverage: weekReadings.averageOrNil(type: .bloodGlucose)
        )
    }
}

/// The weeks the trends screen shows, or `nil` when no dose was logged in the window
/// (`DoseWeeks.kt:115-120`).
///
/// A window with measurements but no dose record has nothing this card can say: every bar would
/// be absent and every ratio undefined. `nil` rather than a list of empty weeks, so the screen
/// physically cannot draw that card — the same shape `metricOverlayOrNull` and
/// `timeOfDayBreakdownOrNull` use for the same reason.
public func doseWeeksOrNull(
    doses: [TrendDose],
    measurements: [TrendMeasurement],
    days: ClosedRange<Int>
) -> [DoseWeek]? {
    let weeks = doseWeeksOf(doses: doses, measurements: measurements, days: days)
    return weeks.contains { $0.takenPercent != nil } ? weeks : nil
}

/// The Monday of the week `epochDay` falls in, as an epoch day of its own (`DoseWeeks.kt:55`).
///
/// Epoch day 0 is a *Thursday*, so a Monday-start week is three days behind the natural modulo:
/// shifting by three puts Monday at a remainder of zero and makes the arithmetic total for
/// negative days too, since `mod` — unlike `%` — never answers a negative remainder.
///
/// Weeks start on Monday because that is what both locales this app ships in treat as the first
/// day; a Sunday-start grid would split every weekend across two bars. This is the canonical home
/// of the week grid, and `Overlay.swift` references it so the two analyses' weeks line up to read
/// against each other.
public func weekStartOf(_ epochDay: Int) -> Int {
    epochDay - mod(epochDay + thursdayOffset, daysPerWeek)
}

/// `Int.mod` (`DoseWeeks.kt`) — a remainder that is always non-negative, unlike Swift's `%` which
/// takes the dividend's sign and would answer a negative start for a negative epoch day.
private func mod(_ dividend: Int, _ divisor: Int) -> Int {
    let remainder = dividend % divisor
    return remainder >= 0 ? remainder : remainder + divisor
}

/// The share of `logged` doses that were `taken`, as a whole percent, or `nil` when none were
/// logged (`DoseWeeks.kt:129-130`).
///
/// Rounded to the nearest whole number rather than truncated: two doses out of three is 66.67,
/// and reporting it as 66 would under-state every week that does not divide evenly.
private func takenPercentOrNull(logged: Int, taken: Int) -> Int? {
    if logged <= 0 {
        return nil
    }
    return Int((Double(taken) * Double(percentScale) / Double(logged)).rounded())
}

/// This metric's mean `primary` over the receiver, or `nil` when it has none (`DoseWeeks.kt:133-137`).
extension [TrendMeasurement] {
    fileprivate func averageOrNil(type: VitalType) -> Double? {
        let values = filter { $0.type == type }.map(\.primary)
        return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }
}

/// Groups the receiver by `key`, preserving nothing about order — the caller sorts the keys it
/// cares about (`DoseWeeks.kt:83-86`).
extension Array {
    fileprivate func groupedBy<Key: Hashable>(_ key: (Element) -> Key) -> [Key: [Element]] {
        reduce(into: [Key: [Element]]()) { buckets, element in
            buckets[key(element), default: []].append(element)
        }
    }
}

private let daysPerWeek = 7
private let percentScale = 100

/// Monday is three days before epoch day 0, which is a Thursday (`DoseWeeks.kt:140`).
private let thursdayOffset = 3
