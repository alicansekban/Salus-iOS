// The twin of `feature/paywall/src/main/res/values/strings.xml` (Turkish, the source language) and
// `feature/paywall/src/main/res/values-en/strings.xml` — all 30 keys `:feature:paywall` owns, name
// and text verbatim, resolved against this package's own bundle exactly as `R.string` resolves
// against `:feature:paywall`.
//
// PLACEHOLDER MAPPING, the one place the port is not byte-for-byte. Android's specifier is Java's;
// one key carries it, rewritten to the Swift spelling of the same argument:
//
//   Android      Swift        Key                          Why
//   ---------------------------------------------------------------------------------------------
//   %1$s         %1$@         paywall_monthly_equivalent   `%s` under `String(format:)` reads a C
//                                                          string pointer. Handed a Swift `String`
//                                                          it prints garbage or crashes; `%@` is
//                                                          the object form.
//
// The sentence around the specifier is unchanged, and `PaywallStringsTests` pins the rendered text
// in both languages so the mapping cannot drift into a reworded string.
//
// STORE-NAME DIVERGENCE (ruling 3): `paywall_renewal_note` is platform-mapped on iOS. Android says
// "Google Play"; iOS says "App Store". This is the only key whose text differs from the Android
// XML, and the divergence is recorded in the task report.
//
// TOOLCHAIN NOTE, and it costs an hour to rediscover: a `.xcstrings` catalog is compiled into
// `.lproj/Localizable.strings` by **Xcode's** build system only. Command-line `swift build` /
// `swift test` copies the catalog into the resource bundle verbatim, so a lookup under
// `swift test` finds no table and `String(localized:)` returns the key. The real app build
// (`scripts/build-app.sh`, xcodebuild) does compile it, which is where the translations appear.
// That is why the tests assert against the FILE and never against a resolved string; the
// end-to-end check is the simulator run.

import Foundation
import SalusPremium

/// The strings `:feature:paywall` owns.
public enum PaywallStrings {
    // MARK: - Headlines

    public static var title: String { localized(.title) }
    public static var titleThemes: String { localized(.titleThemes) }
    public static var titleTrends: String { localized(.titleTrends) }
    public static var titleAiSummary: String { localized(.titleAiSummary) }
    public static var titleDoctorReport: String { localized(.titleDoctorReport) }
    public static var titleBackup: String { localized(.titleBackup) }
    public static var subtitle: String { localized(.subtitle) }

    // MARK: - Feature bullets

    public static var featureAiSummary: String { localized(.featureAiSummary) }
    public static var featureDoctorReport: String { localized(.featureDoctorReport) }
    public static var featureTrends: String { localized(.featureTrends) }
    public static var featureBackup: String { localized(.featureBackup) }
    public static var featureThemes: String { localized(.featureThemes) }

    // MARK: - Plans

    public static var planMonthly: String { localized(.planMonthly) }
    public static var planSixMonth: String { localized(.planSixMonth) }
    public static var planAnnual: String { localized(.planAnnual) }
    public static var badgeBestValue: String { localized(.badgeBestValue) }

    // MARK: - Actions

    public static var ctaTrial: String { localized(.ctaTrial) }
    public static var ctaSubscribe: String { localized(.ctaSubscribe) }
    public static var retry: String { localized(.retry) }
    public static var restore: String { localized(.restore) }
    public static var close: String { localized(.close) }

    // MARK: - Errors

    public static var errorOffering: String { localized(.errorOffering) }
    public static var errorPurchase: String { localized(.errorPurchase) }
    public static var errorRestore: String { localized(.errorRestore) }

    // MARK: - Legal

    public static var renewalNote: String { localized(.renewalNote) }
    public static var terms: String { localized(.terms) }
    public static var privacy: String { localized(.privacy) }
    public static var termsURL: String { localized(.termsURL) }
    public static var privacyURL: String { localized(.privacyURL) }

    // MARK: - Formatted strings

    /// `paywall_monthly_equivalent` — "Ayda %1$@" / "%1$@ per month".
    public static func monthlyEquivalent(_ formatted: String) -> String {
        Self.formatted(.monthlyEquivalent, formatted)
    }

    // MARK: - Headline by source

    /// The headline key for the paywall's opening source. `.onboarding` and `.settings` share the
    /// generic title; every other source names the feature it unlocks. Ported 1:1 from
    /// `PaywallController.kt`'s headline selection.
    public static func headlineKey(for source: PaywallSource) -> String {
        switch source {
        case .onboarding, .settings: Key.title.rawValue
        case .themes: Key.titleThemes.rawValue
        case .trends: Key.titleTrends.rawValue
        case .aiSummary: Key.titleAiSummary.rawValue
        case .doctorReport: Key.titleDoctorReport.rawValue
        case .backup: Key.titleBackup.rawValue
        }
    }

    // MARK: - Keys

    /// The catalog keys, named once. Internal so the parity test can prove every accessor asks for
    /// a key the catalog really carries — a typo here would otherwise ship the key as the label.
    enum Key: String, CaseIterable {
        case title = "paywall_title"
        case titleThemes = "paywall_title_themes"
        case titleTrends = "paywall_title_trends"
        case titleAiSummary = "paywall_title_ai_summary"
        case titleDoctorReport = "paywall_title_doctor_report"
        case titleBackup = "paywall_title_backup"
        case subtitle = "paywall_subtitle"
        case featureAiSummary = "paywall_feature_ai_summary"
        case featureDoctorReport = "paywall_feature_doctor_report"
        case featureTrends = "paywall_feature_trends"
        case featureBackup = "paywall_feature_backup"
        case featureThemes = "paywall_feature_themes"
        case planMonthly = "paywall_plan_monthly"
        case planSixMonth = "paywall_plan_six_month"
        case planAnnual = "paywall_plan_annual"
        case badgeBestValue = "paywall_badge_best_value"
        case monthlyEquivalent = "paywall_monthly_equivalent"
        case ctaTrial = "paywall_cta_trial"
        case ctaSubscribe = "paywall_cta_subscribe"
        case retry = "paywall_retry"
        case restore = "paywall_restore"
        case close = "paywall_close"
        case errorOffering = "paywall_error_offering"
        case errorPurchase = "paywall_error_purchase"
        case errorRestore = "paywall_error_restore"
        case renewalNote = "paywall_renewal_note"
        case terms = "paywall_terms"
        case privacy = "paywall_privacy"
        case termsURL = "paywall_terms_url"
        case privacyURL = "paywall_privacy_url"
    }

    private static func localized(_ key: Key) -> String {
        String(localized: String.LocalizationValue(key.rawValue), bundle: .module)
    }

    /// Substitutes the single argument, in the device's locale.
    ///
    /// The locale is the current one rather than `nil` because that is what Android does:
    /// `Resources.getString(int, Object...)` formats with the configuration's locale, so a grouped
    /// number reads the same on both platforms.
    private static func formatted(_ key: Key, _ argument: CVarArg) -> String {
        String(format: localized(key), locale: .current, argument)
    }
}
