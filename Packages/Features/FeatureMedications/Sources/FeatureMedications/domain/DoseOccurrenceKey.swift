// Ported 1:1 from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/
// medications/domain/DoseOccurrenceKey.kt`.

/// PURE SWIFT. The reminder engine identifies a dose occurrence as
/// (entityId = scheduleId, occurrenceKey = "epochDay|minuteOfDay"). This is the single
/// encoder/decoder for that key — receivers and the handler must agree byte-for-byte.
enum DoseOccurrenceKey {
    static func encode(epochDay: Int, minuteOfDay: Int) -> String {
        "\(epochDay)|\(minuteOfDay)"
    }

    /// Kotlin returns a `Pair<Int, Int>`, whose `first`/`second` say nothing about which half is
    /// which; the labelled tuple makes the same two values unmistakable at the call site.
    static func decode(_ key: String) -> (epochDay: Int, minuteOfDay: Int)? {
        // `split(separator:)` drops empty subsequences by default, which would read "20514|" as
        // one part and answer nil for the wrong reason; Kotlin's `split` keeps them, so the count
        // check below is what rejects it.
        let parts = key.split(separator: "|", omittingEmptySubsequences: false)
        if parts.count != 2 {
            return nil
        }
        guard let day = Int(parts[0]), let minutes = Int(parts[1]) else { return nil }
        return (epochDay: day, minuteOfDay: minutes)
    }
}
