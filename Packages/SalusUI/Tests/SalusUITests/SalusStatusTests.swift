import SalusDesignSystem
import Testing

@testable import SalusUI

/// The `when (status)` table of `SalusStatusChip.kt:41-46`, which is the whole of what
/// `SalusStatus` decides. The chip around it is a `#Preview` build; the mapping is the part
/// that can silently drift, so it is asserted against the theme's own token properties —
/// never against a hex literal, which would pin the value twice and let the two copies part.
@Suite("SalusStatus")
struct SalusStatusTests {
    private let light = SalusTheme.resolve(systemIsDark: false)
    private let dark = SalusTheme.resolve(systemIsDark: true)

    @Test("success is the §3.3 extended success token")
    func successIsTheExtendedSuccessToken() {
        #expect(SalusStatus.success.tint(in: light) == light.extendedColors.success)
        #expect(SalusStatus.success.tint(in: dark) == dark.extendedColors.success)
    }

    @Test("warning is the §3.3 extended warning token")
    func warningIsTheExtendedWarningToken() {
        #expect(SalusStatus.warning.tint(in: light) == light.extendedColors.warning)
        #expect(SalusStatus.warning.tint(in: dark) == dark.extendedColors.warning)
    }

    /// `SalusStatusChip.kt:44` reads `MaterialTheme.colorScheme.error`, not an extended token —
    /// error is a Material role and there is no `SalusExtendedColors.error` to reach for.
    @Test("error is the Material error role, not an extended token")
    func errorIsTheMaterialErrorRole() {
        #expect(SalusStatus.error.tint(in: light) == light.colorScheme.error)
        #expect(SalusStatus.error.tint(in: dark) == dark.colorScheme.error)
    }

    /// The same tint the accent-less `SalusStatusChip(label:)` has drawn since iOS-M2, so the
    /// two ways of asking for a neutral chip cannot diverge.
    @Test("neutral is onSurfaceVariant — the accent-less chip's tint")
    func neutralIsOnSurfaceVariant() {
        #expect(SalusStatus.neutral.tint(in: light) == light.colorScheme.onSurfaceVariant)
        #expect(SalusStatus.neutral.tint(in: dark) == dark.colorScheme.onSurfaceVariant)
    }

    /// The four tints have to be four *different* colors in either theme, or a status chip
    /// stops carrying the meaning it is drawn for.
    @Test("the four statuses are four distinct tints in both themes")
    func theFourStatusesAreDistinct() {
        for theme in [light, dark] {
            let tints = [SalusStatus.success, .warning, .error, .neutral].map { $0.tint(in: theme) }

            #expect(Set(tints).count == tints.count)
        }
    }
}
