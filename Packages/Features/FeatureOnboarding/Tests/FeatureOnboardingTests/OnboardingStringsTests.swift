import Foundation
import SalusTesting
import Testing

@testable import FeatureOnboarding

/// The twin of Android's `feature/onboarding/src/main/res/values/strings.xml` (`tr`, the source
/// language) and `values-en/strings.xml`, and the drift detector between the two locales: all
/// keys and both of their translations are pinned here, in the Android file's own order.
///
/// The M15/M16 flow change is what makes this table 42 rows rather than 46: the eight
/// single-question steps took 24 keys with them, 20 M15 keys arrived, and eight kept their name
/// while their value changed.
///
/// `onboarding_back` **is** here, and it is the one key divergence (d) does not reach: that
/// precedent (`reminder_health_back`, `settings_back`, `profile_back`) drops a back label because
/// the shell's single `NavigationStack` draws the button. The onboarding gate is an overlay with no
/// navigation container, so `OnboardingHeader` draws its own — controller ruling H-8 (iOS-M8)
/// restored the key for it.
///
/// `onboarding_privacy_body` is this package's own copy of the About privacy statement, exactly as
/// Android copied it into `:feature:onboarding` rather than depending on `:feature:settings`.
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
        #expect(Self.samples.count == 42)

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

    @Test("the format key carries the Swift specifiers and renders its sentence")
    func theFormatKeyRendersItsSentence() throws {
        let catalog = try Self.loadCatalog()

        // Java's `%1$d` reads a 32-bit C `int` under `String(format:)`; `%1$lld` is the 64-bit
        // form — see the mapping table in `OnboardingStrings.swift`.
        for locale in ["tr", "en"] {
            try #expect(#require(catalog.value(of: "onboarding_step_of", in: locale)).contains("%1$lld"))
            try #expect(#require(catalog.value(of: "onboarding_step_of", in: locale)).contains("%2$lld"))
        }

        try #expect(Self.render("onboarding_step_of", "tr", 2, 3) == "ADIM 2 / 3")
        try #expect(Self.render("onboarding_step_of", "en", 2, 3) == "STEP 2 / 3")
    }

    /// The overlines the M15 pages draw are upper-case **in the resource**, never
    /// `uppercased()` at run time: Turkish's dotted/dotless I makes a run-time fold
    /// locale-dependent, and "İSTEĞE BAĞLI" is exactly the string a Turkish-locale fold would get
    /// wrong from a lower-case source.
    @Test("the overlines are stored upper-case rather than folded at run time")
    func theOverlinesAreStoredUpperCase() throws {
        let catalog = try Self.loadCatalog()
        // `onboarding_step_of` belongs to the same group but is not in this list: it carries
        // `%1$lld`, which a fold would turn into `%1$LLD`. Its own upper-case wording is pinned by
        // ``theFormatKeyRendersItsSentence()`` ("ADIM 2 / 3" / "STEP 2 / 3").
        let overlines = [
            "onboarding_name_label",
            "onboarding_sex_label",
            "onboarding_birth_label",
            "onboarding_height_label",
            "onboarding_weight_label",
            "onboarding_notes_label"
        ]

        for key in overlines {
            let turkish = try #require(catalog.value(of: key, in: "tr"))
            #expect(turkish == turkish.uppercased(with: Locale(identifier: "tr")), "tr \(key)")
        }
    }

    /// The trust chips state what the app does **not** do, and they do it without claiming
    /// encryption the app does not perform: the ground truth is "on your device", not
    /// "end-to-end encrypted". Pinned because it is the kind of line a later copy pass rewrites
    /// into a security claim.
    @Test("the trust chips claim locality, not cryptography")
    func theTrustChipsClaimLocalityNotCryptography() throws {
        let catalog = try Self.loadCatalog()
        let chips = ["onboarding_trust_local", "onboarding_trust_no_account", "onboarding_trust_no_ads"]

        #expect(catalog.value(of: "onboarding_trust_local", in: "tr") == "Yalnızca cihazınızda")
        #expect(catalog.value(of: "onboarding_trust_no_account", in: "tr") == "Hesap gerektirmez")
        #expect(catalog.value(of: "onboarding_trust_no_ads", in: "tr") == "Reklamsız")

        for key in chips {
            for locale in ["tr", "en"] {
                // Folded in the Turkish locale on purpose: a run-time `lowercased()` is exactly
                // the operation this test exists to keep out of the views.
                let value = try #require(catalog.value(of: key, in: locale))
                    .lowercased(with: Locale(identifier: "tr"))
                #expect(value.contains("şifre") == false, "\(key) (\(locale))")
                #expect(value.contains("encrypt") == false, "\(key) (\(locale))")
            }
        }
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

/// Every key `:feature:onboarding` owns today, with both translations, in the Android file's
/// own order. A new key means a new row here, in the same commit — that is the whole job of
/// this table.
///
/// Held in a dedicated file-private enum so the row table does not blow the suite's own body
/// past the `type_body_length` gate.
private enum OnboardingSamples {
    static let all: [OnboardingStringSample] = [
        OnboardingStringSample(key: "onboarding_back", turkish: "Geri", english: "Back"),
        OnboardingStringSample(
            key: "onboarding_step_of",
            turkish: "ADIM %1$lld / %2$lld",
            english: "STEP %1$lld / %2$lld"
        ),
        OnboardingStringSample(
            key: "onboarding_welcome_title",
            turkish: "Salus'a Hoş Geldiniz",
            english: "Welcome to Salus"
        ),
        OnboardingStringSample(
            key: "onboarding_welcome_body",
            turkish: "Sağlığınızı güvenle ve huzurla takip edebileceğiniz, gizliliğinizi merkeze alan kişisel "
                + "alanınıza adım atın.",
            english: "Step into a personal space built around your privacy, where you can follow your health "
                + "calmly and with confidence."
        ),
        OnboardingStringSample(
            key: "onboarding_trust_local",
            turkish: "Yalnızca cihazınızda",
            english: "On your device only"
        ),
        OnboardingStringSample(
            key: "onboarding_trust_no_account",
            turkish: "Hesap gerektirmez",
            english: "No account needed"
        ),
        OnboardingStringSample(key: "onboarding_trust_no_ads", turkish: "Reklamsız", english: "No ads"),
        OnboardingStringSample(key: "onboarding_start", turkish: "Başla", english: "Get started"),
        OnboardingStringSample(
            key: "onboarding_privacy_link",
            turkish: "Gizlilik ve Güvenlik İlkelerimiz",
            english: "Our privacy and security principles"
        ),
        OnboardingStringSample(
            key: "onboarding_privacy_title",
            turkish: "Gizlilik ve Güvenlik",
            english: "Privacy and security"
        ),
        OnboardingStringSample(
            key: "onboarding_privacy_body",
            turkish: "Girdiğiniz sağlık verileri yalnızca bu cihazdaki veritabanında saklanır. Hesap açmanız gerekmez; "
                + "kayıt, giriş ya da profil eşleştirmesi yoktur. Kullanımınızı izleyen bir analiz aracı veya reklam "
                + "ağı kullanmıyoruz. Sağlık kayıtlarınız telefonunuzdan çıkmaz; ağ yalnızca aboneliğinizi "
                + "doğrulamak ve — kullanırsanız — yapay zekâ özellikleri için, anonim istatistik özetleriyle "
                + "kullanılır. Hatırlatıcılar cihazınızın kendi bildirimleriyle, yerel olarak çalışır.",
            english: "The health data you enter is stored in a database on this device only. You do not need an "
                + "account; there is no sign-up, no sign-in and no profile matching. We use no analytics tool and no "
                + "ad network to watch how you use the app. Your health records never leave your phone; the network "
                + "is used only to verify your subscription and — if you use them — for the AI features, which "
                + "receive anonymous statistical summaries. Reminders run locally, through your device's own "
                + "notifications."
        ),
        OnboardingStringSample(
            key: "onboarding_personal_title",
            turkish: "Sizi Tanıyalım",
            english: "Let us get to know you"
        ),
        OnboardingStringSample(
            key: "onboarding_personal_body",
            turkish: "Bu bilgiler ölçümlerinizi yorumlamak ve size uygun bölümleri açmak için kullanılır. Hepsi "
                + "cihazınızda kalır.",
            english: "These details put your measurements in context and open the sections that apply to you. All of "
                + "them stay on your device."
        ),
        OnboardingStringSample(
            key: "onboarding_name_label",
            turkish: "HİTAP ŞEKLİ / ADINIZ",
            english: "PREFERRED NAME"
        ),
        OnboardingStringSample(key: "onboarding_name_placeholder", turkish: "Örn: Ayşe", english: "e.g. Ayşe"),
        OnboardingStringSample(key: "onboarding_sex_label", turkish: "BİYOLOJİK CİNSİYET", english: "BIOLOGICAL SEX"),
        OnboardingStringSample(key: "onboarding_sex_female", turkish: "Kadın", english: "Female"),
        OnboardingStringSample(key: "onboarding_sex_male", turkish: "Erkek", english: "Male"),
        OnboardingStringSample(key: "onboarding_sex_other", turkish: "Diğer", english: "Other"),
        OnboardingStringSample(
            key: "onboarding_cycle_note",
            turkish: "Regl ve döngü takibi uygulamada sizin için otomatik olarak aktifleşir",
            english: "Period and cycle tracking is turned on for you automatically"
        ),
        OnboardingStringSample(key: "onboarding_birth_label", turkish: "DOĞUM TARİHİ", english: "DATE OF BIRTH"),
        OnboardingStringSample(key: "onboarding_birth_select", turkish: "Tarih seçin", english: "Pick a date"),
        OnboardingStringSample(
            key: "onboarding_age_caption",
            turkish: "Yaş dinamik hesaplanır",
            english: "Your age is calculated from this date"
        ),
        OnboardingStringSample(key: "onboarding_height_label", turkish: "BOY", english: "HEIGHT"),
        OnboardingStringSample(key: "onboarding_height_placeholder", turkish: "Örn: 170", english: "e.g. 170"),
        OnboardingStringSample(
            key: "onboarding_height_invalid",
            turkish: "50 ile 250 cm arasında bir değer girin.",
            english: "Enter a value between 50 and 250 cm."
        ),
        OnboardingStringSample(key: "onboarding_weight_label", turkish: "KİLO", english: "WEIGHT"),
        OnboardingStringSample(key: "onboarding_weight_placeholder", turkish: "Örn: 70", english: "e.g. 70"),
        OnboardingStringSample(
            key: "onboarding_weight_invalid",
            turkish: "20 ile 400 kg arasında bir değer girin.",
            english: "Enter a value between 20 and 400 kg."
        ),
        OnboardingStringSample(key: "onboarding_next", turkish: "Devam Et", english: "Continue"),
        OnboardingStringSample(key: "onboarding_skip", turkish: "Şimdilik Atla", english: "Skip for now"),
        OnboardingStringSample(
            key: "onboarding_health_title",
            turkish: "Son Birkaç Detay",
            english: "A few last details"
        ),
        OnboardingStringSample(
            key: "onboarding_health_body",
            turkish: "Doktorunuzun bilmesini istediğiniz notları ekleyin ve hatırlatıcıları açın. İkisini de sonradan "
                + "değiştirebilirsiniz.",
            english: "Add anything you want your doctor to know and turn on reminders. You can change both later."
        ),
        OnboardingStringSample(
            key: "onboarding_notes_label",
            turkish: "SAĞLIK NOTLARI & ALERJİLER (İSTEĞE BAĞLI)",
            english: "HEALTH NOTES & ALLERGIES (OPTIONAL)"
        ),
        OnboardingStringSample(
            key: "onboarding_notes_placeholder",
            turkish: "Örn: 2018'de hafif bir diz sakatlığı geçirdim. Bazen egzersiz sonrası ağrı yapıyor. Penisilin "
                + "alerjim var.",
            english: "e.g. I hurt my knee slightly in 2018. It aches after exercise. I am allergic to penicillin."
        ),
        OnboardingStringSample(
            key: "onboarding_only_device",
            turkish: "Yalnızca bu cihazda",
            english: "On this device only"
        ),
        OnboardingStringSample(
            key: "onboarding_notes_privacy_body",
            turkish: "Sağlık notlarınız yalnızca bu cihazda saklanır; sağlık kayıtlarınız hiçbir sunucuya gönderilmez "
                + "ve üçüncü taraflarla paylaşılmaz. Salus ağı yalnızca aboneliğinizi doğrulamak için ve — "
                + "kullanırsanız — AI özellikleri için kullanır; AI özelliklerine yalnızca anonim istatistik "
                + "özetleri gönderilir.",
            english: "Your health notes are stored on this device only; your health records are never sent to a server "
                + "and never shared with third parties. Salus uses the network only to verify your subscription and "
                + "— if you use them — for the AI features, which only ever receive anonymous statistical summaries."
        ),
        OnboardingStringSample(
            key: "onboarding_reminders_title",
            turkish: "Zamanında Hatırlatıcılar",
            english: "On-time reminders"
        ),
        OnboardingStringSample(
            key: "onboarding_reminders_subtitle",
            turkish: "İlaç ve randevu saatlerinizde bildirim alın",
            english: "Get a notification at your medication and appointment times"
        ),
        OnboardingStringSample(
            key: "onboarding_finish",
            turkish: "Kurulumu Tamamla ve Başla",
            english: "Finish setup and start"
        ),
        OnboardingStringSample(key: "onboarding_later", turkish: "Daha Sonra Ayarla", english: "Set up later"),
        OnboardingStringSample(
            key: "onboarding_later_caption",
            turkish: "Dilediğiniz zaman Daha Fazla > Ayarlar bölümünden tercihlerinizi güncelleyebilirsiniz",
            english: "You can update your preferences any time under More > Settings"
        )
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
