// The twin of `feature/paywall/src/test/kotlin/com/alicansekban/salus/feature/paywall/
// ui/PaywallFeatureListTest.kt` (127 lines) — the 4-shipped-features invariant.
//
// A bullet on the paywall is a claim made to someone before they pay, which makes an unshipped
// entry a store-policy problem rather than a copy problem. Encrypted backup is the one that was
// already here: it was deferred out of v1 by
// `docs/superpowers/specs/2026-08-19-premium-subscription-design.md` §6 and has no module, no
// code and no way to reach it, so it may not be sold. Its string stays for the day the feature
// lands; this test is what stops the *row* from coming back before the feature does.
//
// ### Why the labels are read as text and not as ids
//
// The obvious test — compare `FeatureRows.map { $0.labelKey }` against `PaywallStrings.Key` —
// cannot fail. The catalog keys are `String` raw values, so the list would agree with any
// expectation of the right length and the backup check would be true of any row. Reading the
// constant's declaration out of the source names the keys for real, which is the only form of
// this assertion that can go red. This is the same source-parsing approach Android uses, because
// the list is a code constant, not a resource.
//
// `FeatureRows` is still read at runtime, for the two facts that survive the string comparison:
// how many rows the sheet renders, and whether each carries its own icon. That is what ties the
// parsed text to the list that actually draws — a parser pointed at the wrong block would disagree
// on the count.

import Foundation
import Testing

@testable import FeaturePaywall

@Suite("FeaturePaywall feature list")
struct PaywallFeatureListTests {
    @Test("sells exactly the four features that ship today")
    func sellsExactlyTheFourFeaturesThatShipToday() {
        #expect(Self.declaredFeatureLabels() == Self.shippedFeatures)
    }

    @Test("does not sell encrypted backup, which does not exist")
    func doesNotSellEncryptedBackupWhichDoesNotExist() {
        #expect(
            !Self.declaredFeatureLabels().contains(Self.backupFeature),
            Comment(
                rawValue:
                "The paywall may not promise encrypted backup until the feature ships: it was "
                    + "deferred out of v1 and there is no module behind it. Selling a feature that "
                    + "cannot be reached is a store policy problem, not a copy nit."
            )
        )
    }

    @Test("keeps the backup string, so the row can return with the feature")
    func keepsTheBackupStringSoTheRowCanReturnWithTheFeature() {
        // Deleting it would make restoring the bullet a translation task in two locales, which
        // is how a deferred feature quietly ships back with re-invented copy.
        for path in Self.stringFiles {
            let text = Self.read(path)
            #expect(
                text.contains("\"\(Self.backupFeature)\""),
                Comment(
                    rawValue:
                    "\(path) dropped \(Self.backupFeature). The string is deliberately unused, not "
                        + "dead: it is kept for the day encrypted backup ships."
                )
            )
        }
    }

    @Test("every shipped label is translated in both locales")
    func everyShippedLabelIsTranslatedInBothLocales() {
        for path in Self.stringFiles {
            let text = Self.read(path)
            for name in Self.shippedFeatures {
                #expect(text.contains("\"\(name)\""), "\(path) is missing \(name).")
            }
        }
    }

    @Test("the rendered list matches the one that was parsed")
    func theRenderedListMatchesTheOneThatWasParsed() {
        // The keys are all strings, but the shape of the list is not: this is what says the block
        // read out of the source is the block the sheet draws.
        #expect(Self.shippedFeatures.count == FeatureRows.count)

        // A duplicated icon reads as the same feature listed twice, which is the shape a
        // copy-pasted row arrives in.
        let icons = FeatureRows.map(\.icon)
        #expect(Set(icons).count == icons.count)
    }

    /// The label keys in the `FeatureRows` declaration, in the order they are sold.
    ///
    /// `swift test` runs with the package directory as its working directory, which is what makes
    /// the relative path resolve — the same arrangement `PaywallStringsTests.loadCatalog` relies on.
    private static func declaredFeatureLabels() -> [String] {
        let source = read(Self.sheet)
        let start = source.range(of: Self.declaration)
        #expect(
            start != nil,
            Comment(
                rawValue:
                "\(Self.sheet) no longer declares `\(Self.declaration)`. The constant is read by "
                    + "name, so a rename has to be made here too rather than passing by scanning nothing."
            )
        )
        guard let start else { return [] }

        // The declaration body runs from the opening `[` to the closing `]`; the label keys are
        // the quoted `paywall_feature_*` strings inside it.
        let body = source[start.upperBound...]
        let labels = Self.labelPattern.matches(in: body)
        #expect(!labels.isEmpty, Comment(rawValue: "No feature label was found in `\(Self.declaration)`."))
        return labels
    }

    private static func read(_ path: String) -> String {
        // swiftlint:disable:next force_try
        try! String(contentsOfFile: path, encoding: .utf8)
    }

    private static let sheet = "Sources/FeaturePaywall/ui/PaywallSheet.swift"
    private static let declaration = "let FeatureRows"
    private static let backupFeature = "paywall_feature_backup"

    private static let stringFiles = [
        "Sources/FeaturePaywall/Resources/Localizable.xcstrings"
    ]

    /// Every one of these is reachable in the app today; nothing else may be listed.
    private static let shippedFeatures = [
        "paywall_feature_ai_summary",
        "paywall_feature_doctor_report",
        "paywall_feature_trends",
        "paywall_feature_themes"
    ]

    /// The quoted label keys inside the `FeatureRows` declaration body.
    private static let labelPattern = LabelPattern()

    /// A tiny regex over the declaration body: every `"paywall_feature_*"` literal, in order.
    private struct LabelPattern {
        func matches(in text: Substring) -> [String] {
            // swiftlint:disable:next force_try
            let regex = try! NSRegularExpression(pattern: #""(paywall_feature_\w+)""#)
            let range = NSRange(text.startIndex ..< text.endIndex, in: text)
            return regex.matches(in: String(text), range: range).compactMap { match in
                guard let range = Range(match.range(at: 1), in: text) else { return nil }
                return String(text[range])
            }
        }
    }
}
