# App Store listing — Salus iOS

Twin of `salus-android/docs/play/store-listing.md`. Same feature set, same banned-claims rule
(never "adherence", "compliance", "planned doses", "target range" — say **"recorded doses"** /
**"kaydedilen doz"**), same premium list as the paywall (`PaywallStringsTests` pins it). Only the
store-specific wording differs: "App Store" instead of "Google Play", subscriptions tied to the
Apple ID (S-3), and App Store Connect's field limits.

Primary language in App Store Connect: **Turkish** (S-4). Add **English (U.S.)** as a
localization.

## Field limits (App Store Connect)

| Field | Limit | Notes |
|---|---|---|
| Name | 30 | shown on the product page and search |
| Subtitle | 30 | one line under the name |
| Promotional text | 170 | editable without a new build |
| Description | 4000 | no HTML, plain line breaks |
| Keywords | 100 | comma-separated, no spaces after commas, do not repeat the name |
| What's New | 4000 | per version |
| Support URL | required | |
| Marketing URL | optional | |
| Privacy Policy URL | required | the Google Sites pages already exist |

---

## Türkçe (tr)

**Name**

```
Salus: Sağlık Takibi
```

**Subtitle**

```
Tansiyon, şeker, ilaç, randevu
```

**Promotional text**

```
Tansiyon, kan şekeri, kilo, ilaç ve randevularınızı tek yerden takip edin. Tüm kayıtlarınız cihazınızda kalır; hesap yok, reklam yok.
```

**Keywords**

```
tansiyon,kan şekeri,ilaç hatırlatıcı,sağlık günlüğü,randevu,kilo takibi,regl,doktor raporu,gizlilik
```

**Description**

```
Salus, sağlığınızı tek bir yerden takip etmenizi sağlayan, gizlilik odaklı bir sağlık günlüğüdür. Tüm sağlık kayıtlarınız yalnızca kendi cihazınızda saklanır — buluta gönderilmez, üçüncü taraflarla paylaşılmaz, reklam için kullanılmaz.

ÖLÇÜMLERİNİZİ KAYDEDİN
• Tansiyon (büyük/küçük tansiyon, nabız)
• Kan şekeri (açlık, tokluk)
• Kilo takibi
Kayıtlarınızı geçmişe dönük görüntüleyin, değişimi izleyin.

İLAÇLARINIZI UNUTMAYIN
• İlaçlarınızı doz ve kullanım saatleriyle kaydedin
• Doz saatinde tam ekran alarm alın (iOS 26 ve sonrası), önceki sürümlerde zaman duyarlı bildirim
• Kullanım geçmişinizi görün

RANDEVULARINIZI YÖNETİN
• Doktor ve muayene randevularınızı ekleyin
• Randevu öncesi bildirim alın
• Notlarınızı randevuyla birlikte saklayın

DÖNGÜ TAKİBİ
• Regl döngünüzü kaydedin ve takip edin
• Döngü geçmişinizi görüntüleyin

GİZLİLİK ÖNCE GELİR
• Tüm kayıtlarınız cihazınızda: Salus'un kendi sunucusu yoktur
• Sağlık takibinin tamamı internet bağlantısı olmadan çalışır
• Face ID / Touch ID veya PIN uygulama kilidiyle kayıtlarınızı koruyun
• Reklam yok, davranış takibi yok, veri satışı yok

SALUS PREMIUM
İsteğe bağlı Salus Premium aboneliğiyle kayıtlarınızdan daha fazlasını çıkarırsınız:
• Yapay zekâ destekli sağlık özeti — seçtiğiniz haftalık ya da aylık dönemi sade bir dille özetler
• Doktor raporu (PDF) — dönemin tansiyon, kan şekeri ve kilo kayıtlarını, kaydedilen dozların alınma oranını ve yeterli veri varsa yapay zekâ değerlendirmesini tek bir dosyada toplar; dilediğiniz gibi paylaşırsınız
• Gelişmiş trend analizleri — kayıtlarınızın gün içi dağılımı, metriklerinizin bir arada seyri, kaydedilen dozların alınma oranı ve her metriğin önceki döneme göre değişimi
• Premium renk temaları
• Yol haritamızdaki yeni premium özelliklere ilk erişim

Yapay zekâ özellikleri nasıl çalışır: özet ve rapor hazırlanırken modele yalnızca dönemin toplulaştırılmış sayıları gönderilir — ölçüm adedi, ortalama, en düşük ve en yüksek değer, değişim yönü, kaydedilen ve alındı işaretlenen doz sayısı. Adınız, doğum tarihiniz, notlarınız ve tek tek kayıtlarınız hiçbir zaman gönderilmez. PDF cihazınızda oluşturulur ve yalnızca sizin paylaştığınız yere gider. Yapay zekâ üretimi günde 5 istekle sınırlıdır; yapay zekâ özetini bir kez ücretsiz deneyebilirsiniz.

Çekirdek sağlık takibi özellikleri her zaman ücretsizdir. Abonelikler aylık, 6 aylık ve yıllık planlarla sunulur; 6 aylık ve yıllık planlarda 7 günlük ücretsiz deneme vardır. Ödeme Apple Kimliğinize bağlı App Store hesabınızdan alınır; abonelik satın alındığı mağazaya bağlıdır ve Android'e taşınmaz. Aboneliğinizi dilediğiniz zaman App Store hesap ayarlarınızdan iptal edebilirsiniz.

ÖNEMLİ NOT
Salus bilgilendirme amaçlıdır; tıbbi tavsiye, teşhis veya tedavi yerine geçmez. Yapay zekâ özetleri ve doktor raporu da yalnızca bilgilendirme amaçlıdır. Sağlığınızla ilgili kararlar için her zaman bir sağlık profesyoneline danışın.

Gizlilik politikası: https://sites.google.com/view/salus-privacy-policy-tr/home
Kullanım koşulları: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
İletişim: alicansekban@hotmail.com
```

**What's New (1.0.0)**

```
İlk sürüm. Tansiyon, kan şekeri ve kilo takibi; doz saatinde tam ekran ilaç alarmı; randevu hatırlatıcıları; döngü takibi; Face ID / Touch ID veya PIN kilit. Tüm kayıtlar cihazınızda kalır. İsteğe bağlı Salus Premium: yapay zekâ sağlık özeti, PDF doktor raporu, gelişmiş trendler, premium temalar.
```

---

## English (en-US)

**Name**

```
Salus: Health Tracker
```

**Subtitle**

```
Blood pressure, glucose & meds
```

**Promotional text**

```
Track blood pressure, glucose, weight, medications and appointments in one place. Everything stays on your device — no account, no ads.
```

**Keywords**

```
blood pressure,glucose,medication reminder,health journal,appointments,weight,period,doctor report
```

**Description**

```
Salus is a privacy-first health journal that lets you track your health in one place. All of your health records are stored only on your own device — never uploaded to a cloud, never shared with third parties, never used for ads.

LOG YOUR MEASUREMENTS
• Blood pressure (systolic/diastolic, pulse)
• Blood glucose (fasting, post-meal)
• Weight tracking
Browse your history and watch how your values change.

NEVER MISS A MEDICATION
• Save your medications with dose and schedule
• Get a full-screen alarm at dose time (iOS 26 and later), a time-sensitive notification on earlier versions
• Review your intake history

MANAGE YOUR APPOINTMENTS
• Add doctor visits and check-ups
• Get notified before each appointment
• Keep your notes together with the appointment

CYCLE TRACKING
• Log and follow your menstrual cycle
• View your cycle history

PRIVACY COMES FIRST
• Every record stays on your device: Salus has no servers of its own
• All of the health tracking works with no internet connection
• Protect your records with Face ID / Touch ID or a PIN app lock
• No ads, no behavioral tracking, no data selling

SALUS PREMIUM
An optional Salus Premium subscription gets you more out of your records:
• AI-powered health summary — puts the week or month you pick into plain language
• Doctor report (PDF) — collects the period's blood pressure, glucose and weight records, the share of recorded doses that were marked as taken, and an AI assessment when there is enough data, all in one file you can share however you like
• Advanced trend analyses — the time-of-day spread of your records, your metrics side by side, the share of recorded doses that were marked as taken, and how each metric changed from the previous period
• Premium color themes
• First access to the new premium features on our roadmap

How the AI features work: when a summary or a report is prepared, only the period's aggregated numbers are sent to the model — how many readings there are, the average, the lowest and highest value, the direction of change, and how many doses were recorded and marked as taken. Your name, birth date, notes and individual records are never sent. The PDF is created on your device and goes only where you share it. AI generation is limited to 5 requests per day, and you can try the AI summary once for free.

Core health-tracking features are free and always will be. Subscriptions are available as monthly, 6-month and yearly plans; the 6-month and yearly plans include a 7-day free trial. Payment is charged to the App Store account tied to your Apple ID; a subscription belongs to the store it was bought in and does not transfer to Android. You can cancel anytime in your App Store account settings.

IMPORTANT
Salus is for informational purposes only and is not a substitute for medical advice, diagnosis or treatment. The AI summaries and the doctor report are for information only as well. Always consult a healthcare professional for decisions about your health.

Privacy policy: https://sites.google.com/view/salus-privacy-policy-en/home
Terms of use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Contact: alicansekban@hotmail.com
```

**What's New (1.0.0)**

```
First release. Blood pressure, glucose and weight tracking; a full-screen alarm at dose time; appointment reminders; cycle tracking; Face ID / Touch ID or PIN lock. Every record stays on your device. Optional Salus Premium: AI health summary, PDF doctor report, advanced trends, premium themes.
```

---

## Other App Store Connect fields

| Field | Value |
|---|---|
| Primary category | Health & Fitness |
| Secondary category | Medical |
| Age rating | 4+. In the questionnaire: "Medical or Treatment Information" → **None** (Salus logs the user's own readings and gives no treatment advice; every AI output carries the disclaimer); unrestricted web access, gambling, contests, mature themes → No. If App Store Connect's current questionnaire forces "Infrequent/Mild" for health topics, accept the 12+ it computes rather than misanswer. |
| Support URL | https://sites.google.com/view/salus-privacy-policy-tr/home (until a support page exists) |
| Privacy policy URL | tr: https://sites.google.com/view/salus-privacy-policy-tr/home · en: https://sites.google.com/view/salus-privacy-policy-en/home |
| License agreement (EULA) | Apple's standard EULA — leave the custom EULA field empty; the description links https://www.apple.com/legal/internet-services/itunes/dev/stdeula/ (a Terms of Use link is mandatory for auto-renewable subscriptions, guideline 3.1.2). Replace with our own page if `salus-android/docs/legal/terms.html` is ever published. |
| Copyright | © 2026 Alican Şekban |
| Content rights | does not contain third-party content |
| Sign-in required for review | No — no accounts |
| App uses IDFA | No |
| Encryption export declaration | `ITSAppUsesNonExemptEncryption = false` in Info.plist (HTTPS only, exempt) |

### Privacy nutrition labels (S-17)

| Data type | Collected? | Linked to user | Used for tracking | Purpose |
|---|---|---|---|---|
| Health & Fitness → Health | **Yes** — aggregated statistics sent to Firebase AI Logic (Gemini) only when the user requests a summary or report | No | No | App Functionality |
| Purchases → Purchase History | Yes — RevenueCat receipt validation | No (anonymous RevenueCat app user ID) | No | App Functionality |
| Identifiers → Device ID | Yes — RevenueCat anonymous ID, Firebase App Check attestation | No | No | App Functionality |
| Everything else (contacts, location, usage data, diagnostics, name, DOB) | Not collected | | | |

Data is **not** used for tracking; no third-party advertising SDK is present.
"Transient" applies to the health statistics: they are processed for the response and not stored
server-side by us (Google's Gemini API terms govern their retention — say so in the privacy policy).

### App Review notes

```
Salus stores all health data on the device (GRDB/SQLite) and has no backend. Network is used
only for (1) RevenueCat subscription validation and (2) the optional AI summary / doctor report,
which sends aggregated statistics (counts, averages, min/max) to Firebase AI Logic — never
individual records or identity.

No account is needed. To test Premium, use the sandbox tester below or the "Restore" flow.
Sandbox tester: <create in App Store Connect → Users and Access → Sandbox Testers>
The AI summary can be tried once for free without a subscription: Home → AI summary card.
Medication alarms use AlarmKit on iOS 26+ (permission prompt on first medication with a
reminder); on iOS 17–25 they are time-sensitive notifications.
```

### Screenshots

Required: **6.9" display** (iPhone 16 Pro Max / 17 Pro Max, 1320×2868 portrait), 3–10 images.
Optional but recommended: 6.5" (1284×2778) for older devices; iPad not needed
(`TARGETED_DEVICE_FAMILY = 1`).

Final set (2026-09-04): `~/Desktop/salus-store-görseller/ios/01-home.png … 08-more.png`,
1320×2868 PNG, no alpha, in-app language Turkish, same order as the Play set: 01 home ·
02 dose alarm · 03 medications · 04 vitals · 05 appointments · 06 AI summary · 07 doctor report ·
08 more. Upload all eight to the 6.9" slot of the **tr** localization; en-US can reuse the same
files (App Store Connect offers "use the primary localization's screenshots"). 02, 06 and 07 were
upscaled from 738×1600 device JPEGs and are slightly soft; re-export from the iPhone at native
1290×2796 and re-run the framing script if a crisper set is wanted.

### App icon

1024×1024 PNG, sRGB, **no alpha**, no rounded corners (iOS masks it). Same artwork as the Android
adaptive icon foreground on the Android `ic_launcher_background` colour. Goes into
`App/Assets.xcassets/AppIcon.appiconset` with `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`
in `project.yml`.

## Checklist before the first TestFlight upload

- [x] App icon + asset catalog + `project.yml` setting, `xcodegen generate`, CI green
- [x] `App/PrivacyInfo.xcprivacy` (UserDefaults `CA92.1`, file timestamp `C617.1`; tracking `false`; collected data types matching the table above)
      — `CA92.1` is ours; `C617.1` is declared because `attributesOfItemAtPath:error:` reaches
      the linked binary from RevenueCat, whose own manifest declares only `UserDefaults`. Disk
      space, boot time and active keyboards are deliberately absent: nothing in our sources or
      in the built binary names them.
- [x] `ITSAppUsesNonExemptEncryption = false`
- [x] `MARKETING_VERSION 1.0.0`, `CURRENT_PROJECT_VERSION 1`
- [x] `about_privacy_body` says "App Store" on iOS (both locales)
- [x] Database file `isExcludedFromBackup = true` verified (S-10) — it was **not** set; added in
      `SalusDatabase.excludeFromBackup(at:)`, called from `AppCompositionRoot.openDatabase`, with
      the report cache directory covered too and four tests pinning the resource value
- [x] Product IDs in App Store Connect match the RevenueCat offering — verified 2026-09-02: group `Premium_Plan`, `com.alicansekban.salus.monthly` / `.six_month` / `.annual`; `docs/revenuecat-ios-setup.md` corrected
      — needs the dashboard, so it stays open. Both docs now carry the conflict as a warning
      block; no Swift source names a product ID, so only the docs are wrong.
- [x] Production RevenueCat key (`appl_…`) in `Secrets.local.xcconfig`; Release build verified
      2026-09-04 (key lands in the built Info.plist)
- [x] Firebase App Check: DeviceCheck registered for the iOS app (2026-09-04)
- [x] Post-onboarding intro paywall removed (`a19d5a0`, ledger S-25) — the paywall opens only from
      Settings and gated premium features
- [x] Screenshots framed (eight, 6.9", see above)

## App Store Connect order (2026-09-04)

1. **Xcode → Product → Archive** on `main` (Release, 1.0.0 build 1) → Distribute → App Store
   Connect → Upload. Bump `CURRENT_PROJECT_VERSION` in `project.yml` before every later upload.
2. **App Store Connect → App Information**: name, subtitle (tr, then en-US), primary category,
   secondary category, Apple's standard EULA, privacy policy URLs, content rights.
3. **App Privacy** (nutrition labels): the three rows in the table above, "not linked", "not used
   for tracking", App Functionality. Everything else "not collected".
4. **Age rating** questionnaire as in the table.
5. **Subscriptions → Premium_Plan**: the three products must be "Ready to Submit" and attached to
   the first version, with localized display names and the 7-day introductory offer on
   `.six_month` and `.annual`; App Review can only see them if they are attached.
6. **Version 1.0.0**: description, keywords, promotional text, What's New, support URL, the eight
   screenshots, review notes + a sandbox tester's credentials, "Sign-in required: No", export
   compliance answered by the plist.
7. **TestFlight** first: install the build on the iPhone, run `scripts/premium-sandbox-qa.md`
   with a sandbox tester (simulator cannot: "No active account"), check the AI summary from the
   TestFlight build (App Check DeviceCheck path), check alarms and notifications.
8. Submit for review; select "Release manually" so the two stores can go live together.

- [ ] `scripts/premium-sandbox-qa.md` run on a device with a sandbox tester (TestFlight build)
- [ ] Copy this file's fields into App Store Connect (tr primary, en-US)
- [ ] Nutrition labels + age rating + review notes filled in
- [ ] Screenshots uploaded (6.9")
- [ ] Subscriptions attached to version 1.0.0
