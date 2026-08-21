// The token registry — the drift detector against `salus-android/docs/design/design-tokens.md`.
//
// Every token group exposes an `allTokens` dictionary keyed by the token's own name. This
// file only sums those dictionaries, so a token that is added, removed or renamed changes the
// total, and the pinning test that asserts 213 fails until the document and the transcription
// agree again.
//
// Keying by name also catches a duplicated key: two tokens transcribed under one name collapse
// into a single dictionary entry and the count drops.

/// Counts of the transcribed design tokens, per group and in total.
public enum SalusTokens {
    /// The document's token groups, in document order, with the number of tokens each holds.
    public static var groupCounts: [(group: String, count: Int)] {
        [
            // §1 Material color roles — light
            ("colors.light", SalusColorScheme.light.allTokens.count),
            // §2 Material color roles — dark
            ("colors.dark", SalusColorScheme.dark.allTokens.count),
            // §3.1 feature accents — light (5 features x 4 members)
            ("featureAccents.light", SalusExtendedColors.light.accentTokens.count),
            // §3.2 feature accents — dark
            ("featureAccents.dark", SalusExtendedColors.dark.accentTokens.count),
            // §3.3 success + warning, in both themes
            (
                "statusColors",
                SalusExtendedColors.light.statusTokens.count
                    + SalusExtendedColors.dark.statusTokens.count
            ),
            // §4 four palettes x 8 roles x light+dark
            ("premiumAccents", SalusPremiumAccents.allTokens.count),
            // §5 spacing
            ("spacing", SalusSpacing.allTokens.count),
            // §6 corner radii — the pill is `Capsule()`, a shape rather than a radius token
            ("shapes", SalusShapes.allTokens.count),
            // §7 elevation
            ("elevation", SalusElevation.allTokens.count),
            // §8 touch target
            ("touchTarget", SalusTouchTarget.allTokens.count),
            // §9 six overridden + six inherited type roles
            ("typography", SalusTypography.allTokens.count),
            // §10 motion
            ("motion", SalusMotion.allTokens.count),
        ]
    }

    /// The total number of tokens this package transcribes. The document declares 213.
    public static var allTokenCount: Int {
        groupCounts.reduce(0) { $0 + $1.count }
    }
}
