// Ported 1:1 from Android
// `feature/cycle/src/main/kotlin/com/alicansekban/salus/feature/cycle/domain/model/CyclePeriod.kt`.
//
// Kotlin's `Instant` is `Foundation.Date` — the absolute-instant carve-out of the LocalDate rule.
// `startDate` / `endDate` are days, so they stay `SalusModel.LocalDate`.

import Foundation
import SalusModel

/// A recorded menstrual period. Only real records exist — predictions are always computed on
/// the fly and never persisted (`CyclePeriod.kt:13-22`).
public struct CyclePeriod: Equatable, Hashable, Sendable {
    public let id: String
    public let startDate: LocalDate
    /// `nil` while the period is still running.
    public let endDate: LocalDate?
    public let flowPeak: FlowLevel?
    public let note: String?
    public let createdAt: Date

    /// `CyclePeriod.kt:21`.
    public var isOpen: Bool { endDate == nil }

    public init(
        id: String,
        startDate: LocalDate,
        endDate: LocalDate?,
        flowPeak: FlowLevel?,
        note: String?,
        createdAt: Date
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.flowPeak = flowPeak
        self.note = note
        self.createdAt = createdAt
    }
}
