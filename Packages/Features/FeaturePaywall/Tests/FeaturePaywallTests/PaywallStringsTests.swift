import Foundation
import SalusPremium
import SalusTesting
import Testing

@testable import FeaturePaywall

/// The twin of Android's `feature/paywall/src/main/res/values/strings.xml` (`tr`, the source
/// language) and `values-en/strings.xml`, and the drift detector between them: all 30 keys and
/// both of their translations are pinned here, copied from the XML.
///
/// The catalog is read off disk rather than through `Bundle.module`. Android's own parity checks
/// read the XML for the first reason: `String(localized:)` answers for ONE locale — the host's —
/// so it can never prove that both locales carry a key. The second is the toolchain note in
/// `PaywallStrings.swift`: command-line `swift test` does not compile a `.xcstrings` at all, so a
/// resolved string here would only ever be the key back. The end-to-end check is the simulator
/// run.
///
/// The parity mechanics — loading, the key-set pin, the locale check — live in
/// `SalusTesting.StringCatalogParity`, so this suite is only this feature's application of them
/// plus the half no shared helper can own: the Android-verbatim values.
///
/// The banned-health-claims scan is deliberately NOT here. It runs repository-wide from
/// `SalusTestingTests.BannedHealthClaimsTests`, over every `.xcstrings` under `Packages/`, so the
/// next feature's catalog is covered without remembering to copy a test.
@Suite("FeaturePaywall strings")
struct PaywallStringsTests {
    /// Every key `:feature:paywall` owns, with both translations, copied from the XML. A new key
    /// there means a new row here, in the same commit — that is the whole job of this table.
    ///
    /// `paywall_renewal_note` carries the iOS store-name divergence (ruling 3): "App Store" where
    /// Android says "Google Play". Every other value is Android-verbatim.
    static let samples: [PaywallStringSample] = [
        PaywallStringSample(
            key: "paywall_title",
            turkish: "Salus Premium",
            english: "Salus Premium"
        ),
        PaywallStringSample(
            key: "paywall_title_themes",
            turkish: "Premium temalara eriş",
            english: "Unlock premium themes"
        ),
        PaywallStringSample(
            key: "paywall_title_trends",
            turkish: "Gelişmiş trendlere eriş",
            english: "Unlock advanced trends"
        ),
        PaywallStringSample(
            key: "paywall_title_ai_summary",
            turkish: "AI sağlık özetine eriş",
            english: "Unlock AI health summaries"
        ),
        PaywallStringSample(
            key: "paywall_title_doctor_report",
            turkish: "AI doktor raporuna eriş",
            english: "Unlock the AI doctor report"
        ),
        PaywallStringSample(
            key: "paywall_title_backup",
            turkish: "Şifreli yedeğe eriş",
            english: "Unlock encrypted backup"
        ),
        PaywallStringSample(
            key: "paywall_subtitle",
            turkish: "Sağlık verilerini analiz eden ve seninle birlikte büyüyen tüm özellikler tek abonelikte.",
            english: "Every feature that analyses and grows with your health data, in one subscription."
        ),
        PaywallStringSample(
            key: "paywall_feature_ai_summary",
            turkish: "Yapay zekâ destekli sağlık özetleri",
            english: "AI-powered health summaries"
        ),
        PaywallStringSample(
            key: "paywall_feature_doctor_report",
            turkish: "Doktoruna götürebileceğin PDF rapor",
            english: "A PDF report to take to your doctor"
        ),
        PaywallStringSample(
            key: "paywall_feature_trends",
            turkish: "Sabah-akşam dağılımı, çoklu metrik ve doz-ölçüm analizi",
            english: "Time-of-day breakdown, multi-metric overlay and dose-vs-measurement analysis"
        ),
        PaywallStringSample(
            key: "paywall_feature_backup",
            turkish: "Şifreli yedekleme ve geri yükleme",
            english: "Encrypted backup and restore"
        ),
        PaywallStringSample(
            key: "paywall_feature_themes",
            turkish: "Premium temalar",
            english: "Premium themes"
        ),
        PaywallStringSample(
            key: "paywall_plan_monthly",
            turkish: "Aylık",
            english: "Monthly"
        ),
        PaywallStringSample(
            key: "paywall_plan_six_month",
            turkish: "6 aylık",
            english: "6 months"
        ),
        PaywallStringSample(
            key: "paywall_plan_annual",
            turkish: "Yıllık",
            english: "Yearly"
        ),
        PaywallStringSample(
            key: "paywall_badge_best_value",
            turkish: "En avantajlı",
            english: "Best value"
        ),
        PaywallStringSample(
            key: "paywall_monthly_equivalent",
            turkish: "Ayda %1$@",
            english: "%1$@ per month"
        ),
        PaywallStringSample(
            key: "paywall_cta_trial",
            turkish: "7 gün ücretsiz dene",
            english: "Start 7-day free trial"
        ),
        PaywallStringSample(
            key: "paywall_cta_subscribe",
            turkish: "Abone ol",
            english: "Subscribe"
        ),
        PaywallStringSample(
            key: "paywall_retry",
            turkish: "Tekrar dene",
            english: "Try again"
        ),
        PaywallStringSample(
            key: "paywall_restore",
            turkish: "Satın almaları geri yükle",
            english: "Restore purchases"
        ),
        PaywallStringSample(
            key: "paywall_close",
            turkish: "Kapat",
            english: "Close"
        ),
        PaywallStringSample(
            key: "paywall_error_offering",
            turkish: "Planlar şu an yüklenemedi. Bağlantını kontrol edip tekrar dene.",
            english: "Plans could not be loaded right now. Check your connection and try again."
        ),
        PaywallStringSample(
            key: "paywall_error_purchase",
            turkish: "Satın alma tamamlanamadı. Lütfen tekrar dene.",
            english: "The purchase could not be completed. Please try again."
        ),
        PaywallStringSample(
            key: "paywall_error_restore",
            turkish: "Mağazaya ulaşılamadı ya da bu hesapta bir abonelik bulunamadı.",
            english: "The store could not be reached, or no subscription was found on this account."
        ),
        PaywallStringSample(
            key: "paywall_renewal_note",
            turkish: "Abonelik, iptal edilmediği sürece dönem sonunda otomatik yenilenir. "
                + "Dilediğin zaman App Store üzerinden iptal edebilirsin.",
            english: "The subscription renews automatically at the end of each period unless "
                + "cancelled. You can cancel any time in the App Store."
        ),
        PaywallStringSample(
            key: "paywall_terms",
            turkish: "Abonelik şartları",
            english: "Subscription terms"
        ),
        PaywallStringSample(
            key: "paywall_privacy",
            turkish: "Gizlilik politikası",
            english: "Privacy policy"
        ),
        PaywallStringSample(
            key: "paywall_terms_url",
            turkish: "https://sites.google.com/view/salus-subscription-terms-tr/home",
            english: "https://sites.google.com/view/salus-subscription-terms-en/home"
        ),
        PaywallStringSample(
            key: "paywall_privacy_url",
            turkish: "https://sites.google.com/view/salus-privacy-policy-tr/home",
            english: "https://sites.google.com/view/salus-privacy-policy-en/home"
        )
    ]

    static let expectedKeys = Set(samples.map(\.key))

    @Test("the catalog holds exactly the 30 keys :feature:paywall owns")
    func catalogHoldsExactlyTheThirtyKeys() throws {
        // Pinned as a number as well as a set: a row deleted from the table together with its key
        // from the catalog would otherwise agree with itself and pass.
        #expect(Self.samples.count == 30)

        try StringCatalogParity.assertKeys(of: Self.loadCatalog(), are: Self.expectedKeys)
    }

    @Test("Turkish is the source language and every key has both tr and en (spec 6.4)")
    func everyKeyHasBothLocales() throws {
        let catalog = try Self.loadCatalog()

        try StringCatalogParity.assertSourceLanguage(of: catalog)
        try StringCatalogParity.assertEveryKeyIsLocalized(in: catalog)
    }

    @Test(
        "the values are Android-verbatim (feature/paywall/res/values*/strings.xml)",
        arguments: samples
    )
    func valuesAreAndroidVerbatim(sample: PaywallStringSample) throws {
        let catalog = try Self.loadCatalog()

        #expect(catalog.value(of: sample.key, in: "tr") == sample.turkish)
        #expect(catalog.value(of: sample.key, in: "en") == sample.english)
    }

    @Test("every accessor asks for a key the catalog carries")
    func everyAccessorAsksForAKeyTheCatalogCarries() throws {
        let catalog = try Self.loadCatalog()

        // A typo in one of `PaywallStrings.Key`'s raw values does not fail to compile — it ships
        // the key itself as the label. This is the check that catches it.
        #expect(Set(PaywallStrings.Key.allCases.map(\.rawValue)) == catalog.keys)
    }

    @Test("the format key carries a Swift specifier and renders the Android sentence")
    func formatKeyRendersTheAndroidSentence() throws {
        let catalog = try Self.loadCatalog()

        // Android's `%1$s` is a Java specifier. `%s` reads a C string pointer under
        // `String(format:)`, so the catalog carries `%1$@` instead — see the mapping table in
        // `PaywallStrings.swift`. The sentence around it is unchanged, and these are the
        // assertions that say so.
        try #expect(Self.render("paywall_monthly_equivalent", "tr", "₺49,99") == "Ayda ₺49,99")
        try #expect(Self.render("paywall_monthly_equivalent", "en", "$4.99") == "$4.99 per month")

        try #expect(#require(catalog.value(of: "paywall_monthly_equivalent", in: "tr")).contains("%1$@"))
        try #expect(#require(catalog.value(of: "paywall_monthly_equivalent", in: "en")).contains("%1$@"))
    }

    @Test("the headline key maps each PaywallSource to the feature it unlocks")
    func headlineKeyMapsEachSource() {
        #expect(PaywallStrings.headlineKey(for: .onboarding) == "paywall_title")
        #expect(PaywallStrings.headlineKey(for: .settings) == "paywall_title")
        #expect(PaywallStrings.headlineKey(for: .themes) == "paywall_title_themes")
        #expect(PaywallStrings.headlineKey(for: .trends) == "paywall_title_trends")
        #expect(PaywallStrings.headlineKey(for: .aiSummary) == "paywall_title_ai_summary")
        #expect(PaywallStrings.headlineKey(for: .doctorReport) == "paywall_title_doctor_report")
        #expect(PaywallStrings.headlineKey(for: .backup) == "paywall_title_backup")
    }

    /// One catalog value with its single argument substituted, formatted locale-independently so
    /// the expected sentence does not depend on where the test ran.
    static func render(_ key: String, _ locale: String, _ argument: CVarArg) throws -> String {
        let format = try #require(loadCatalog().value(of: key, in: locale))
        return String(format: format, locale: nil, argument)
    }

    /// The catalog file itself, read from the package tree relative to this test.
    static func loadCatalog() throws -> StringCatalog {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // FeaturePaywallTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // FeaturePaywall
        return try StringCatalogParity.load(
            at: packageRoot.appendingPathComponent("Sources/FeaturePaywall/Resources/Localizable.xcstrings")
        )
    }
}

/// One row of the ported string table: a key and the two translations Android ships for it.
///
/// Flat rather than nested in the suite so it can be a `@Test(arguments:)` table, which requires
/// a `Sendable` element type.
struct PaywallStringSample: Sendable {
    let key: String
    let turkish: String
    let english: String
}
