// The twin of `feature/onboarding/src/main/res/values/strings.xml` (Turkish, the source
// language) and `feature/onboarding/src/main/res/values-en/strings.xml` — every key
// `:feature:onboarding` owns, name and text verbatim, resolved against this package's own
// bundle exactly as `R.string` resolves against `:feature:onboarding`. The keys below are in the
// Android file's own order, which is the order the flow reads them in.
//
// NO KEY IS DROPPED: all 42 Android keys are here. The M15/M16 flow change cut the catalog from
// 46 to 42 — 24 keys of the eight single-question steps went (their titles, bodies and the four
// notification-step strings, plus `onboarding_progress` / `onboarding_step_counter` /
// the three `onboarding_section_*`), 20 M15 keys arrived, and eight kept their name while their
// value changed to the M15 wording (five of those eight already carried it on this side).
//
// `onboarding_back` ("Geri" / "Back") was briefly left out on the divergence-(d) precedent — the
// shell's single `NavigationStack` draws the back button for every pushed destination, so
// `reminder_health_back` (iOS-M3) and `settings_back` / `profile_back` (iOS-M8 settings) all went
// unported. **Controller ruling H-8 (iOS-M8) reversed that for this one key**: divergence (d)
// holds for a *pushed* screen and the onboarding flow is not one. The gate is an overlay with no
// navigation container, so `OnboardingHeader` draws the only hand-made back button in the app, and
// it is the only back button in the tree that needs a spoken label of its own.
//
// `onboarding_privacy_body` is this package's OWN copy of the About privacy statement, not a
// reach into `SettingsStrings`: `:feature:settings` is another module on both platforms, and
// Android copied the text into `:feature:onboarding` rather than depending across features
// (`values/strings.xml:11`). The two are expected to read alike and are maintained together.
//
// PLACEHOLDER MAPPING, the one place the port is not byte-for-byte. One key carries two
// integer arguments:
//
//   Android          Swift            Key                     Why
//   -----------------------------------------------------------------------------------------
//   %1$d, %2$d       %1$lld, %2$lld   onboarding_step_of      Swift's `Int` is 64-bit; `%d` is
//                                                             the C `int` (32-bit). The sentence
//                                                             around the specifier never changes.
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
    // MARK: - Chrome

    /// The header back button's accessibility label — the one back button in the port that draws
    /// itself, so the one that carries this key (ruling H-8).
    public static var onboardingBack: String { localized(.onboardingBack) }

    // MARK: - Page 1 — Welcome

    public static var onboardingWelcomeTitle: String { localized(.onboardingWelcomeTitle) }
    public static var onboardingWelcomeBody: String { localized(.onboardingWelcomeBody) }
    public static var onboardingTrustLocal: String { localized(.onboardingTrustLocal) }
    public static var onboardingTrustNoAccount: String { localized(.onboardingTrustNoAccount) }
    public static var onboardingTrustNoAds: String { localized(.onboardingTrustNoAds) }
    public static var onboardingStart: String { localized(.onboardingStart) }
    public static var onboardingPrivacyLink: String { localized(.onboardingPrivacyLink) }
    public static var onboardingPrivacyTitle: String { localized(.onboardingPrivacyTitle) }
    public static var onboardingPrivacyBody: String { localized(.onboardingPrivacyBody) }

    // MARK: - Page 2 — Personal details

    public static var onboardingPersonalTitle: String { localized(.onboardingPersonalTitle) }
    public static var onboardingPersonalBody: String { localized(.onboardingPersonalBody) }
    public static var onboardingNameLabel: String { localized(.onboardingNameLabel) }
    public static var onboardingNamePlaceholder: String { localized(.onboardingNamePlaceholder) }
    public static var onboardingSexLabel: String { localized(.onboardingSexLabel) }
    public static var onboardingSexFemale: String { localized(.onboardingSexFemale) }
    public static var onboardingSexMale: String { localized(.onboardingSexMale) }
    public static var onboardingSexOther: String { localized(.onboardingSexOther) }
    public static var onboardingCycleNote: String { localized(.onboardingCycleNote) }
    public static var onboardingBirthLabel: String { localized(.onboardingBirthLabel) }
    public static var onboardingBirthSelect: String { localized(.onboardingBirthSelect) }
    public static var onboardingAgeCaption: String { localized(.onboardingAgeCaption) }
    public static var onboardingHeightLabel: String { localized(.onboardingHeightLabel) }
    public static var onboardingHeightPlaceholder: String { localized(.onboardingHeightPlaceholder) }
    public static var onboardingHeightInvalid: String { localized(.onboardingHeightInvalid) }
    public static var onboardingWeightLabel: String { localized(.onboardingWeightLabel) }
    public static var onboardingWeightPlaceholder: String { localized(.onboardingWeightPlaceholder) }
    public static var onboardingWeightInvalid: String { localized(.onboardingWeightInvalid) }
    public static var onboardingNext: String { localized(.onboardingNext) }
    public static var onboardingSkip: String { localized(.onboardingSkip) }

    // MARK: - Page 3 — Health notes and permissions

    public static var onboardingHealthTitle: String { localized(.onboardingHealthTitle) }
    public static var onboardingHealthBody: String { localized(.onboardingHealthBody) }
    public static var onboardingNotesLabel: String { localized(.onboardingNotesLabel) }
    public static var onboardingNotesPlaceholder: String { localized(.onboardingNotesPlaceholder) }
    public static var onboardingOnlyDevice: String { localized(.onboardingOnlyDevice) }
    public static var onboardingNotesPrivacyBody: String { localized(.onboardingNotesPrivacyBody) }
    public static var onboardingRemindersTitle: String { localized(.onboardingRemindersTitle) }
    public static var onboardingRemindersSubtitle: String { localized(.onboardingRemindersSubtitle) }
    public static var onboardingFinish: String { localized(.onboardingFinish) }
    public static var onboardingLater: String { localized(.onboardingLater) }
    public static var onboardingLaterCaption: String { localized(.onboardingLaterCaption) }

    // MARK: - Formatted strings

    /// `onboarding_step_of` — "ADIM %1$lld / %2$lld" / "STEP %1$lld / %2$lld".
    public static func onboardingStepOf(_ step: Int, _ total: Int) -> String {
        formatted(.onboardingStepOf, step, total)
    }

    // MARK: - Keys

    /// The catalog keys, named once, in the Android file's order. Internal so the parity test can
    /// prove every accessor asks for a key the catalog really carries — a typo here would
    /// otherwise ship the key as the label.
    enum Key: String, CaseIterable {
        case onboardingBack = "onboarding_back"
        case onboardingStepOf = "onboarding_step_of"
        case onboardingWelcomeTitle = "onboarding_welcome_title"
        case onboardingWelcomeBody = "onboarding_welcome_body"
        case onboardingTrustLocal = "onboarding_trust_local"
        case onboardingTrustNoAccount = "onboarding_trust_no_account"
        case onboardingTrustNoAds = "onboarding_trust_no_ads"
        case onboardingStart = "onboarding_start"
        case onboardingPrivacyLink = "onboarding_privacy_link"
        case onboardingPrivacyTitle = "onboarding_privacy_title"
        case onboardingPrivacyBody = "onboarding_privacy_body"
        case onboardingPersonalTitle = "onboarding_personal_title"
        case onboardingPersonalBody = "onboarding_personal_body"
        case onboardingNameLabel = "onboarding_name_label"
        case onboardingNamePlaceholder = "onboarding_name_placeholder"
        case onboardingSexLabel = "onboarding_sex_label"
        case onboardingSexFemale = "onboarding_sex_female"
        case onboardingSexMale = "onboarding_sex_male"
        case onboardingSexOther = "onboarding_sex_other"
        case onboardingCycleNote = "onboarding_cycle_note"
        case onboardingBirthLabel = "onboarding_birth_label"
        case onboardingBirthSelect = "onboarding_birth_select"
        case onboardingAgeCaption = "onboarding_age_caption"
        case onboardingHeightLabel = "onboarding_height_label"
        case onboardingHeightPlaceholder = "onboarding_height_placeholder"
        case onboardingHeightInvalid = "onboarding_height_invalid"
        case onboardingWeightLabel = "onboarding_weight_label"
        case onboardingWeightPlaceholder = "onboarding_weight_placeholder"
        case onboardingWeightInvalid = "onboarding_weight_invalid"
        case onboardingNext = "onboarding_next"
        case onboardingSkip = "onboarding_skip"
        case onboardingHealthTitle = "onboarding_health_title"
        case onboardingHealthBody = "onboarding_health_body"
        case onboardingNotesLabel = "onboarding_notes_label"
        case onboardingNotesPlaceholder = "onboarding_notes_placeholder"
        case onboardingOnlyDevice = "onboarding_only_device"
        case onboardingNotesPrivacyBody = "onboarding_notes_privacy_body"
        case onboardingRemindersTitle = "onboarding_reminders_title"
        case onboardingRemindersSubtitle = "onboarding_reminders_subtitle"
        case onboardingFinish = "onboarding_finish"
        case onboardingLater = "onboarding_later"
        case onboardingLaterCaption = "onboarding_later_caption"
    }

    private static func localized(_ key: Key) -> String {
        SalusLocalization.string(key.rawValue, bundle: .module)
    }

    /// Substitutes the two arguments, in the device's locale.
    ///
    /// The locale is the current one rather than `nil` because that is what Android does:
    /// `Resources.getString(int, Object...)` formats with the configuration's locale.
    private static func formatted(_ key: Key, _ arg1: CVarArg, _ arg2: CVarArg) -> String {
        String(format: localized(key), locale: .current, arg1, arg2)
    }
}
