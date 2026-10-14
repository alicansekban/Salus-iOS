// Twin of `feature/smoking/.../reminder/SmokingNotificationText.kt` on branch
// `feature/m17-smoking-cessation`.
//
// The wording of the smoking notifications, behind a protocol so how the kinds combine stays pure
// (testable without a bundle). The system implementation, `SystemSmokingNotificationStrings`, reads
// the catalog in the app language.

import SalusSmoking

public protocol SmokingNotificationStrings: Sendable {
    /// "Yeni aşama: 20 dakika · Nabız ve tansiyon". The stage part is the title from
    /// `smoking-health-stages.md` and nothing else — no figure of our own. Nil for an id the strings
    /// do not know, so an unknown stage is left out instead of invented.
    func stageReached(stageId: String) -> String?

    /// "7 gün oldu!"; a whole number of years reads as years.
    func daysReached(_ days: Int64) -> String

    /// "100 adet içmedin".
    func unitsSkipped(_ units: Int64) -> String

    /// "₺1.000 biriktirdin", the amount in the plan's own currency and the app language.
    func moneySaved(minor: Int64, currencyCode: String) -> String

    /// The line under a stage: where the tap leads.
    func stageHint() -> String

    /// The line under a day, unit or money milestone.
    func cheer() -> String

    func eveningTitle() -> String

    func eveningText() -> String
}

/// A notification's title and body.
public struct SmokingNotificationCopy: Equatable, Sendable {
    public let title: String
    public let text: String

    public init(title: String, text: String) {
        self.title = title
        self.text = text
    }
}

/// Turns the kinds merged into one planned notification into the copy the person reads.
public enum SmokingNotificationText {
    private static let separator = " · "

    /// The first milestone is the title (the good news); any others follow in the body, so a merged
    /// day reads as one notification and not a list to scroll. A lone milestone gets a short
    /// supportive line instead. Nil when no kind produces any text.
    public static func compose(
        kinds: [MilestoneKind],
        currencyCode: String,
        strings: any SmokingNotificationStrings
    ) -> SmokingNotificationCopy? {
        if kinds.contains(where: {
            if case .evening = $0 {
                true
            } else {
                false
            }
        }) {
            return SmokingNotificationCopy(title: strings.eveningTitle(), text: strings.eveningText())
        }
        let headlines = kinds.compactMap { kind in
            headline(kind, currencyCode: currencyCode, strings: strings).map { (kind: kind, text: $0) }
        }
        guard let first = headlines.first else { return nil }
        let body: String = if headlines.count == 1 {
            if case .stage = first.kind {
                strings.stageHint()
            } else {
                strings.cheer()
            }
        } else {
            headlines.dropFirst().map(\.text).joined(separator: separator)
        }
        return SmokingNotificationCopy(title: first.text, text: body)
    }

    private static func headline(
        _ kind: MilestoneKind,
        currencyCode: String,
        strings: any SmokingNotificationStrings
    ) -> String? {
        switch kind {
        case let .stage(stageId): strings.stageReached(stageId: stageId)
        case let .days(days): strings.daysReached(days)
        case let .units(units): strings.unitsSkipped(units)
        case let .money(minor): strings.moneySaved(minor: minor, currencyCode: currencyCode)
        case .evening: nil
        }
    }
}
