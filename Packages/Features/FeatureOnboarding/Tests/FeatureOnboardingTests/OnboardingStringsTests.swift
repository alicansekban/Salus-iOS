import Foundation
import SalusTesting
import Testing

@testable import FeatureOnboarding

/// The twin of Android's `feature/onboarding/src/main/res/values/strings.xml` (`tr`, the source
/// language) and `values-en/strings.xml`, and the drift detector between the two locales: all
/// keys and both of their translations are pinned here.
///
/// `onboarding_back` is deliberately not here (see `OnboardingStrings.swift`'s header): the
/// shell's single `NavigationStack` draws the back button, so no screen in this port declares
/// one. It is a recorded divergence (d), not a silent drop — the same precedent that dropped
/// `reminder_health_back` (iOS-M3) and `settings_back` / `profile_back` (iOS-M8 settings).
///
/// The catalog is read off disk rather than through `Bundle.module`, for the two reasons
/// `VitalsStringsTests` records: `String(localized:)` answers for ONE locale, so it can never
/// prove both carry a key, and command-line `swift test` does not compile a `.xcstrings` at all.
///
/// The banned-health-claims scan is deliberately NOT here. It runs repository-wide from
/// `SalusTestingTests.BannedHealthClaimsTests`, over every `.xcstrings` under `Packages/`.
@Suite("FeatureOnboarding strings")
struct OnboardingStringsTests {
    static let samples = OnboardingSamples.all
    static let expectedKeys = Set(samples.map(\.key))

    @Test("the catalog holds exactly the keys :feature:onboarding owns")
    func catalogHoldsExactlyTheKeys() throws {
        // Pinned as a number as well as a set: a row deleted from the table together with its key
        // from the catalog would otherwise agree with itself and pass.
        #expect(Self.samples.count == 45)

        try StringCatalogParity.assertKeys(of: Self.loadCatalog(), are: Self.expectedKeys)
    }

    @Test("Turkish is the source language and every key has both tr and en (spec 6.4)")
    func everyKeyHasBothLocales() throws {
        let catalog = try Self.loadCatalog()

        try StringCatalogParity.assertSourceLanguage(of: catalog)
        try StringCatalogParity.assertEveryKeyIsLocalized(in: catalog)
    }

    @Test(
        "the values match the ported table (feature/onboarding/res/values*/strings.xml)",
        arguments: samples
    )
    func valuesMatchThePortedTable(sample: OnboardingStringSample) throws {
        let catalog = try Self.loadCatalog()

        #expect(catalog.value(of: sample.key, in: "tr") == sample.turkish)
        #expect(catalog.value(of: sample.key, in: "en") == sample.english)
    }

    @Test("every accessor asks for a key the catalog carries")
    func everyAccessorAsksForAKeyTheCatalogCarries() throws {
        let catalog = try Self.loadCatalog()

        // A typo in one of `OnboardingStrings.Key`'s raw values does not fail to compile — it ships
        // the key itself as the label. This is the check that catches it.
        #expect(Set(OnboardingStrings.Key.allCases.map(\.rawValue)) == catalog.keys)
    }

    @Test("the format keys carry the Swift specifier and render their sentence")
    func theFormatKeyRendersItsSentence() throws {
        let catalog = try Self.loadCatalog()

        // Java's `%1$d` reads a 32-bit C `int` under `String(format:)`; `%1$lld` is the 64-bit
        // form — see the mapping table in `OnboardingStrings.swift`.
        try #expect(#require(catalog.value(of: "onboarding_progress", in: "tr")).contains("%1$lld"))
        try #expect(#require(catalog.value(of: "onboarding_progress", in: "en")).contains("%1$lld"))
        try #expect(#require(catalog.value(of: "onboarding_progress", in: "tr")).contains("%2$lld"))
        try #expect(#require(catalog.value(of: "onboarding_progress", in: "en")).contains("%2$lld"))
        try #expect(#require(catalog.value(of: "onboarding_step_counter", in: "tr")).contains("%1$lld"))
        try #expect(#require(catalog.value(of: "onboarding_step_counter", in: "en")).contains("%1$lld"))
        try #expect(#require(catalog.value(of: "onboarding_step_counter", in: "tr")).contains("%2$lld"))
        try #expect(#require(catalog.value(of: "onboarding_step_counter", in: "en")).contains("%2$lld"))

        try #expect(Self.render("onboarding_progress", "tr", 2, 7) == "Adım 2 / 7")
        try #expect(Self.render("onboarding_progress", "en", 2, 7) == "Step 2 of 7")
        try #expect(Self.render("onboarding_step_counter", "tr", 2, 7) == "2/7")
        try #expect(Self.render("onboarding_step_counter", "en", 2, 7) == "2/7")
    }

    /// One catalog value with its two arguments substituted, formatted locale-independently so
    /// the expected sentence does not depend on where the test ran.
    static func render(_ key: String, _ locale: String, _ arg1: CVarArg, _ arg2: CVarArg) throws -> String {
        let format = try #require(loadCatalog().value(of: key, in: locale))
        return String(format: format, locale: nil, arg1, arg2)
    }

    /// The catalog file itself, read from the package tree relative to this test.
    static func loadCatalog() throws -> StringCatalog {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // FeatureOnboardingTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // FeatureOnboarding
        return try StringCatalogParity.load(
            at: packageRoot.appendingPathComponent("Sources/FeatureOnboarding/Resources/Localizable.xcstrings")
        )
    }
}

/// Every key `:feature:onboarding` owns today, with both translations. A new key means a new row
/// here, in the same commit — that is the whole job of this table.
///
/// Held in a dedicated file-private enum so the row table does not blow the suite's own body
/// past the `type_body_length` gate.
private enum OnboardingSamples {
    static let all: [OnboardingStringSample] = [
        OnboardingStringSample(key: "onboarding_skip", turkish: "Şimdilik Atla", english: "Skip for now"),
        OnboardingStringSample(key: "onboarding_start", turkish: "Başla", english: "Get started"),
        OnboardingStringSample(key: "onboarding_next", turkish: "Devam Et", english: "Continue"),
        OnboardingStringSample(key: "onboarding_finish", turkish: "Bitir", english: "Finish"),
        OnboardingStringSample(key: "onboarding_allow_notifications", turkish: "İzin Ver", english: "Allow"),
        OnboardingStringSample(
            key: "onboarding_progress",
            turkish: "Adım %1$lld / %2$lld",
            english: "Step %1$lld of %2$lld"
        ),
        OnboardingStringSample(
            key: "onboarding_step_counter",
            turkish: "%1$lld/%2$lld",
            english: "%1$lld/%2$lld"
        ),
        OnboardingStringSample(
            key: "onboarding_section_personal",
            turkish: "Kişisel Bilgiler",
            english: "Personal Details"
        ),
        OnboardingStringSample(key: "onboarding_section_notes", turkish: "Sağlık Notları", english: "Health Notes"),
        OnboardingStringSample(
            key: "onboarding_section_privacy",
            turkish: "Gizlilik Tercihleri",
            english: "Privacy Preferences"
        ),
        OnboardingStringSample(
            key: "onboarding_welcome_title",
            turkish: "Salus'a Hoş Geldiniz",
            english: "Welcome to Salus"
        ),
        OnboardingStringSample(
            key: "onboarding_welcome_body",
            turkish: "Sağlığınızı güvenle ve huzurla takip edebileceğiniz, gizliliğinizi merkeze "
                + "alan kişisel alanınıza adım atın.",
            english: "Step into a personal space built around your privacy, where you can follow "
                + "your health calmly and with confidence."
        ),
        OnboardingStringSample(key: "onboarding_name_title", turkish: "Adınız Nedir?", english: "What is your name?"),
        OnboardingStringSample(
            key: "onboarding_name_body",
            turkish: "Size nasıl hitap etmemizi istersiniz?",
            english: "How would you like us to address you?"
        ),
        OnboardingStringSample(key: "onboarding_name_label", turkish: "Ad", english: "Name"),
        OnboardingStringSample(key: "onboarding_name_placeholder", turkish: "Örn: Ayşe", english: "e.g. Ayşe"),
        OnboardingStringSample(
            key: "onboarding_sex_title",
            turkish: "Cinsiyetinizi Seçin",
            english: "Select your sex"
        ),
        OnboardingStringSample(
            key: "onboarding_sex_body",
            turkish: "Size en uygun sağlık deneyimini ve döngü takibini sunabilmemiz için bu bilgiye "
                + "ihtiyacımız var. Verileriniz yalnızca bu cihazda saklanır.",
            english: "We need this to tailor your health experience and cycle tracking. "
                + "Your data is stored on this device only."
        ),
        OnboardingStringSample(key: "onboarding_sex_female", turkish: "Kadın", english: "Female"),
        OnboardingStringSample(key: "onboarding_sex_male", turkish: "Erkek", english: "Male"),
        OnboardingStringSample(key: "onboarding_sex_other", turkish: "Diğer", english: "Other"),
        OnboardingStringSample(
            key: "onboarding_birth_title",
            turkish: "Doğum Tarihiniz",
            english: "Your date of birth"
        ),
        OnboardingStringSample(
            key: "onboarding_birth_body",
            turkish: "Yaşınız bu tarihten hesaplanır; ayrıca saklanmaz.",
            english: "Your age is derived from this date, never stored separately."
        ),
        OnboardingStringSample(key: "onboarding_birth_select", turkish: "Tarih seçin", english: "Pick a date"),
        OnboardingStringSample(
            key: "onboarding_height_title",
            turkish: "Boyunuz Kaç cm?",
            english: "How tall are you?"
        ),
        OnboardingStringSample(
            key: "onboarding_height_body",
            turkish: "Ölçümlerinizi yorumlarken kullanılır.",
            english: "Used when putting your measurements in context."
        ),
        OnboardingStringSample(key: "onboarding_height_label", turkish: "Boy", english: "Height"),
        OnboardingStringSample(key: "onboarding_height_placeholder", turkish: "Örn: 170", english: "e.g. 170"),
        OnboardingStringSample(
            key: "onboarding_height_invalid",
            turkish: "50 ile 250 cm arasında bir değer girin.",
            english: "Enter a value between 50 and 250 cm."
        ),
        OnboardingStringSample(
            key: "onboarding_weight_title",
            turkish: "Kilonuz Kaç kg?",
            english: "What do you weigh?"
        ),
        OnboardingStringSample(
            key: "onboarding_weight_body",
            turkish: "İlk ölçümünüz olarak kaydedilir ve kilo grafiğinizin başlangıcı olur.",
            english: "Saved as your first measurement, so your weight chart starts today."
        ),
        OnboardingStringSample(key: "onboarding_weight_label", turkish: "Kilo", english: "Weight"),
        OnboardingStringSample(key: "onboarding_weight_placeholder", turkish: "Örn: 70", english: "e.g. 70"),
        OnboardingStringSample(
            key: "onboarding_weight_invalid",
            turkish: "20 ile 400 kg arasında bir değer girin.",
            english: "Enter a value between 20 and 400 kg."
        ),
        OnboardingStringSample(
            key: "onboarding_notes_title",
            turkish: "Ek Sağlık Notları",
            english: "Extra health notes"
        ),
        OnboardingStringSample(
            key: "onboarding_notes_body",
            turkish: "Doktorunuzun bilmesini istediğiniz geçmiş rahatsızlıklar, alerjiler veya genel "
                + "sağlık durumunuzla ilgili özel notlarınızı buraya ekleyebilirsiniz.",
            english: "Add past conditions, allergies or anything else about your health that "
                + "you want your doctor to know."
        ),
        OnboardingStringSample(key: "onboarding_notes_label", turkish: "Notlar", english: "Notes"),
        OnboardingStringSample(
            key: "onboarding_notes_placeholder",
            turkish: "Örn: 2018'de hafif bir diz sakatlığı geçirdim. Bazen egzersiz sonrası ağrı "
                + "yapıyor. Penisilin alerjim var.",
            english: "e.g. I hurt my knee slightly in 2018. It aches after exercise. "
                + "I am allergic to penicillin."
        ),
        OnboardingStringSample(
            key: "onboarding_notes_private",
            turkish: "Yalnızca bu cihazda",
            english: "On this device only"
        ),
        OnboardingStringSample(
            key: "onboarding_notes_privacy_body",
            turkish: "Sağlık notlarınız yalnızca bu cihazda saklanır; sağlık kayıtlarınız hiçbir "
                + "sunucuya gönderilmez ve üçüncü taraflarla paylaşılmaz. Salus ağı yalnızca "
                + "aboneliğinizi doğrulamak için ve — kullanırsanız — AI özellikleri için kullanır; "
                + "AI özelliklerine yalnızca anonim istatistik özetleri gönderilir.",
            english: "Your health notes are stored on this device only; your health records are "
                + "never sent to a server and never shared with third parties. Salus uses the "
                + "network only to verify your subscription and — if you use them — for the AI "
                + "features, which only ever receive anonymous statistical summaries."
        ),
        OnboardingStringSample(
            key: "onboarding_notifications_title",
            turkish: "Bildirim İzinleri",
            english: "Notification permission"
        ),
        OnboardingStringSample(
            key: "onboarding_notifications_body",
            turkish: "İlaçlarınızı ve sağlık kontrollerinizi unutmamanız için size nazik "
                + "hatırlatıcılar gönderelim. İzin vermezseniz uygulama çalışmaya devam eder; "
                + "izni sonradan Daha Fazla › Hatırlatıcılar bölümünden verebilirsiniz.",
            english: "Let us send you gentle reminders so you do not forget your medications "
                + "and health check-ups. If you decline, the app keeps working — you can grant "
                + "it later under More › Reminders."
        ),
        OnboardingStringSample(
            key: "onboarding_notifications_benefit_title",
            turkish: "Zamanında Hatırlatma",
            english: "On-time reminders"
        ),
        OnboardingStringSample(
            key: "onboarding_notifications_benefit_body",
            turkish: "Asla bir dozu kaçırmayın.",
            english: "Never miss a dose."
        ),
        OnboardingStringSample(key: "onboarding_notifications_later", turkish: "Daha Sonra", english: "Later")
    ]
}

/// One row of the ported string table: a key and the two translations the app ships for it.
///
/// Flat rather than nested in the suite so it can be a `@Test(arguments:)` table, which requires
/// a `Sendable` element type.
struct OnboardingStringSample: Sendable {
    let key: String
    let turkish: String
    let english: String
}
