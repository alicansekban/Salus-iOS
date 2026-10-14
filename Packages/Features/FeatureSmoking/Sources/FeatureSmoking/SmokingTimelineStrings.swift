// The accessors for the keys `:feature:smoking` owns on the health timeline and its stage sheet —
// an extension of ``SmokingStrings`` so the enum itself stays inside SwiftLint's 300-line
// `type_body_length`. The key names are in `SmokingStrings.Key`.
//
// The two attributions and the chip labels are keyed by the stage's source, not by a stage id, so
// they are reached through ``StageCopy``; the rest are read straight off the screen.

import Foundation

extension SmokingStrings {
    public static var timelineTitle: String { localized(.timelineTitle) }
    public static var timelineOverline: String { localized(.timelineOverline) }
    public static var timelineReduceTitle: String { localized(.timelineReduceTitle) }
    public static var timelineDoneLabel: String { localized(.timelineDoneLabel) }
    public static var timelineNextLabel: String { localized(.timelineNextLabel) }
    public static var timelineSwitch: String { localized(.timelineSwitch) }
    public static var timelineCountingAgain: String { localized(.timelineCountingAgain) }
    public static var timelineCombustionOnly: String { localized(.timelineCombustionOnly) }
    public static var timelineDisclaimer: String { localized(.timelineDisclaimer) }
    public static var timelineSourceWho: String { localized(.timelineSourceWho) }
    public static var timelineSourceNhs: String { localized(.timelineSourceNhs) }
    public static var timelineAttributionWho: String { localized(.timelineAttributionWho) }
    public static var timelineAttributionNhs: String { localized(.timelineAttributionNhs) }
    public static var timelineStateDone: String { localized(.timelineStateDone) }
    public static var timelineStateInProgress: String { localized(.timelineStateInProgress) }
    public static var timelineStatePending: String { localized(.timelineStatePending) }

    /// `smoking_timeline_count`: "4 / 10", the header's completed stages against the catalog.
    public static func timelineCount(_ done: Int, _ total: Int) -> String {
        String(format: localized(.timelineCount), locale: .current, done, total)
    }
}
