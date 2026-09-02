// The twin of `feature/onboarding/src/main/res/values/strings.xml` (Turkish, the source
// language) and `feature/onboarding/src/main/res/values-en/strings.xml` — every key
// `:feature:onboarding` owns, name and text verbatim, resolved against this package's own
// bundle exactly as `R.string` resolves against `:feature:onboarding`.
//
// NO KEY IS DROPPED: all 46 Android keys are here. `onboarding_back` ("Geri" / "Back") was
// briefly left out on the divergence-(d) precedent — the shell's single `NavigationStack` draws
// the back button for every pushed destination, so `reminder_health_back` (iOS-M3) and
// `settings_back` / `profile_back` (iOS-M8 settings) all went unported. **Controller ruling H-8
// (iOS-M8) reversed that for this one key**: divergence (d) holds for a *pushed* screen and the
// onboarding flow is not one. The gate is an overlay with no navigation container, so
// `OnboardingHeader` draws the only hand-made back button in the app, and it is the only back
// button in the tree that needs a spoken label of its own.
//
// PLACEHOLDER MAPPING, the one place the port is not byte-for-byte. Two keys carry two
// integer arguments:
//
//   Android          Swift            Key                     Why
//   -----------------------------------------------------------------------------------------
//   %1$d, %2$d       %1$lld, %2$lld   onboarding_progress     Swift's `Int` is 64-bit; `%d` is
//   %1$d, %2$d       %1$lld, %2$lld   onboarding_step_counter  the C `int` (32-bit). The
//                                                             sentence around the specifier
//                                                             never changes.
//
// TOOLCHAIN NOTE, and it costs an hour to rediscover: a `.xcstrings` catalog is compiled into
// `.lproj/Localizable.strings` by **Xcode's** build system only. Command-line `swift build` /
// `swift test` copies the catalog into the resource bundle verbatim, so a lookup under
// `swift test` finds no table and `String(localized:)` returns the key. The real app build
// (`scripts/build-app.sh`, xcodebuild) does compile it, which is where the translations appear.
// That is why the tests assert against the FILE and never against a resolved string; the
// end-to-end check is the simulator run.

import Foundation
import SalusCommon

/// The strings `:feature:onboarding` owns.
public enum OnboardingStrings {
    // MARK: - Actions

    /// The header back button's accessibility label — the one back button in the port that draws
    /// itself, so the one that carries this key (ruling H-8).
    public static var onboardingBack: String { localized(.onboardingBack) }
    public static var onboardingSkip: String { localized(.onboardingSkip) }
    public static var onboardingStart: String { localized(.onboardingStart) }
    public static var onboardingNext: String { localized(.onboardingNext) }
    public static var onboardingFinish: String { localized(.onboardingFinish) }
    public static var onboardingAllowNotifications: String { localized(.onboardingAllowNotifications) }

    // MARK: - Progress

    public static var onboardingSectionPersonal: String { localized(.onboardingSectionPersonal) }
    public static var onboardingSectionNotes: String { localized(.onboardingSectionNotes) }
    public static var onboardingSectionPrivacy: String { localized(.onboardingSectionPrivacy) }

    // MARK: - Welcome

    public static var onboardingWelcomeTitle: String { localized(.onboardingWelcomeTitle) }
    public static var onboardingWelcomeBody: String { localized(.onboardingWelcomeBody) }

    // MARK: - Name

    public static var onboardingNameTitle: String { localized(.onboardingNameTitle) }
    public static var onboardingNameBody: String { localized(.onboardingNameBody) }
    public static var onboardingNameLabel: String { localized(.onboardingNameLabel) }
    public static var onboardingNamePlaceholder: String { localized(.onboardingNamePlaceholder) }

    // MARK: - Sex

    public static var onboardingSexTitle: String { localized(.onboardingSexTitle) }
    public static var onboardingSexBody: String { localized(.onboardingSexBody) }
    public static var onboardingSexFemale: String { localized(.onboardingSexFemale) }
    public static var onboardingSexMale: String { localized(.onboardingSexMale) }
    public static var onboardingSexOther: String { localized(.onboardingSexOther) }

    // MARK: - Birth date

    public static var onboardingBirthTitle: String { localized(.onboardingBirthTitle) }
    public static var onboardingBirthBody: String { localized(.onboardingBirthBody) }
    public static var onboardingBirthSelect: String { localized(.onboardingBirthSelect) }

    // MARK: - Height

    public static var onboardingHeightTitle: String { localized(.onboardingHeightTitle) }
    public static var onboardingHeightBody: String { localized(.onboardingHeightBody) }
    public static var onboardingHeightLabel: String { localized(.onboardingHeightLabel) }
    public static var onboardingHeightPlaceholder: String { localized(.onboardingHeightPlaceholder) }
    public static var onboardingHeightInvalid: String { localized(.onboardingHeightInvalid) }

    // MARK: - Weight

    public static var onboardingWeightTitle: String { localized(.onboardingWeightTitle) }
    public static var onboardingWeightBody: String { localized(.onboardingWeightBody) }
    public static var onboardingWeightLabel: String { localized(.onboardingWeightLabel) }
    public static var onboardingWeightPlaceholder: String { localized(.onboardingWeightPlaceholder) }
    public static var onboardingWeightInvalid: String { localized(.onboardingWeightInvalid) }

    // MARK: - Health notes

    public static var onboardingNotesTitle: String { localized(.onboardingNotesTitle) }
    public static var onboardingNotesBody: String { localized(.onboardingNotesBody) }
    public static var onboardingNotesLabel: String { localized(.onboardingNotesLabel) }
    public static var onboardingNotesPlaceholder: String { localized(.onboardingNotesPlaceholder) }
    public static var onboardingNotesPrivate: String { localized(.onboardingNotesPrivate) }
    public static var onboardingNotesPrivacyBody: String { localized(.onboardingNotesPrivacyBody) }

    // MARK: - Notifications

    public static var onboardingNotificationsTitle: String { localized(.onboardingNotificationsTitle) }
    public static var onboardingNotificationsBody: String { localized(.onboardingNotificationsBody) }
    public static var onboardingNotificationsBenefitTitle: String {
        localized(.onboardingNotificationsBenefitTitle)
    }

    public static var onboardingNotificationsBenefitBody: String {
        localized(.onboardingNotificationsBenefitBody)
    }

    public static var onboardingNotificationsLater: String { localized(.onboardingNotificationsLater) }

    // MARK: - Formatted strings

    /// `onboarding_progress` — "Adım %1$lld / %2$lld" / "Step %1$lld of %2$lld".
    public static func onboardingProgress(_ step: Int, _ total: Int) -> String {
        formatted(.onboardingProgress, step, total)
    }

    /// `onboarding_step_counter` — "%1$lld/%2$lld" / "%1$lld/%2$lld".
    public static func onboardingStepCounter(_ step: Int, _ total: Int) -> String {
        formatted(.onboardingStepCounter, step, total)
    }

    // MARK: - Keys

    /// The catalog keys, named once. Internal so the parity test can prove every accessor asks for
    /// a key the catalog really carries — a typo here would otherwise ship the key as the label.
    enum Key: String, CaseIterable {
        case onboardingBack = "onboarding_back"
        case onboardingSkip = "onboarding_skip"
        case onboardingStart = "onboarding_start"
        case onboardingNext = "onboarding_next"
        case onboardingFinish = "onboarding_finish"
        case onboardingAllowNotifications = "onboarding_allow_notifications"
        case onboardingProgress = "onboarding_progress"
        case onboardingStepCounter = "onboarding_step_counter"
        case onboardingSectionPersonal = "onboarding_section_personal"
        case onboardingSectionNotes = "onboarding_section_notes"
        case onboardingSectionPrivacy = "onboarding_section_privacy"
        case onboardingWelcomeTitle = "onboarding_welcome_title"
        case onboardingWelcomeBody = "onboarding_welcome_body"
        case onboardingNameTitle = "onboarding_name_title"
        case onboardingNameBody = "onboarding_name_body"
        case onboardingNameLabel = "onboarding_name_label"
        case onboardingNamePlaceholder = "onboarding_name_placeholder"
        case onboardingSexTitle = "onboarding_sex_title"
        case onboardingSexBody = "onboarding_sex_body"
        case onboardingSexFemale = "onboarding_sex_female"
        case onboardingSexMale = "onboarding_sex_male"
        case onboardingSexOther = "onboarding_sex_other"
        case onboardingBirthTitle = "onboarding_birth_title"
        case onboardingBirthBody = "onboarding_birth_body"
        case onboardingBirthSelect = "onboarding_birth_select"
        case onboardingHeightTitle = "onboarding_height_title"
        case onboardingHeightBody = "onboarding_height_body"
        case onboardingHeightLabel = "onboarding_height_label"
        case onboardingHeightPlaceholder = "onboarding_height_placeholder"
        case onboardingHeightInvalid = "onboarding_height_invalid"
        case onboardingWeightTitle = "onboarding_weight_title"
        case onboardingWeightBody = "onboarding_weight_body"
        case onboardingWeightLabel = "onboarding_weight_label"
        case onboardingWeightPlaceholder = "onboarding_weight_placeholder"
        case onboardingWeightInvalid = "onboarding_weight_invalid"
        case onboardingNotesTitle = "onboarding_notes_title"
        case onboardingNotesBody = "onboarding_notes_body"
        case onboardingNotesLabel = "onboarding_notes_label"
        case onboardingNotesPlaceholder = "onboarding_notes_placeholder"
        case onboardingNotesPrivate = "onboarding_notes_private"
        case onboardingNotesPrivacyBody = "onboarding_notes_privacy_body"
        case onboardingNotificationsTitle = "onboarding_notifications_title"
        case onboardingNotificationsBody = "onboarding_notifications_body"
        case onboardingNotificationsBenefitTitle = "onboarding_notifications_benefit_title"
        case onboardingNotificationsBenefitBody = "onboarding_notifications_benefit_body"
        case onboardingNotificationsLater = "onboarding_notifications_later"
    }

    private static func localized(_ key: Key) -> String {
        SalusLocalization.string(key.rawValue, bundle: .module)
    }

    /// Substitutes the single argument, in the device's locale.
    ///
    /// The locale is the current one rather than `nil` because that is what Android does:
    /// `Resources.getString(int, Object...)` formats with the configuration's locale.
    private static func formatted(_ key: Key, _ argument: CVarArg) -> String {
        String(format: localized(key), locale: .current, argument)
    }

    /// Substitutes the two arguments, in the device's locale.
    private static func formatted(_ key: Key, _ arg1: CVarArg, _ arg2: CVarArg) -> String {
        String(format: localized(key), locale: .current, arg1, arg2)
    }
}
