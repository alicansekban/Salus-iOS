# M8 Research Inventory — The `:feature:settings` Module (Android source of truth → iOS current state)

Research for the Salus iOS M8 (settings hub) milestone plan. Companion to
`2026-08-30-m8-applock-onboarding-inventory.md` (which covers AppLockManager, secure screen, and
onboarding). Every section cites the Android file the iOS port must reproduce, plus the iOS
scaffolding that already exists.

---

## §1 More (the settings hub)

### Files
- `salus-android/feature/settings/src/main/kotlin/com/alicansekban/salus/feature/settings/ui/more/MoreScreen.kt` (590 lines)
- `.../ui/more/MoreUiState.kt` (100 lines)
- `.../ui/more/MoreViewModel.kt` (157 lines)

### Types

**`MoreRoute`** (stateful, MoreScreen.kt:82):
```kotlin
@Composable fun MoreRoute(
    onOpenCycle: () -> Unit,           // shell callback — CycleKey belongs to :feature:cycle
    onOpenDoctorReport: () -> Unit,   // shell callback — DoctorReportKey belongs to :feature:aihealth
    onOpenTrends: () -> Unit,         // shell callback — TrendsKey belongs to :feature:trends
    viewModel: MoreViewModel = koinViewModel(),
)
```
Route-only responsibilities (not in the ViewModel): BiometricPrompt before enabling app lock
(`authenticate(activity, title) { viewModel.onEvent(event) }`, lines 452–472, `BIOMETRIC_WEAK or
DEVICE_CREDENTIAL`); reading `versionName` from the package manager (lines 120–124); opening system
notification settings via `Settings.ACTION_APP_NOTIFICATION_SETTINGS` (lines 144–149); collecting
`effects` and running `OpenUrl` via `ACTION_VIEW` (runCatching).

**`MoreScreen`** (stateless, MoreScreen.kt:154): parameters
`state: MoreUiState, versionName: String, appLockAvailable: Boolean, onEvent: (MoreEvent) -> Unit,
onOpenCycle, onOpenReminderHealth, onOpenAbout, onOpenProfile, onOpenNotificationSettings` — all
`() -> Unit`. Uses `SalusScreenHeader` (tab root, no TopAppBar), private `MoreCard`, `MoreToggleCard`,
`SectionLabel`, `SelectionDialog` (radio-list AlertDialog, one shared Cancel button) and
`SelectionOption(label, isSelected, onSelect)`.

**`MoreDialog`** enum (MoreUiState.kt:9): `Theme`, `ColorTheme`, `Language`.

**`MoreUiState`** (MoreUiState.kt:19), all fields with defaults:
| Field | Type | Default |
|---|---|---|
| `isLoading` | Boolean | `true` |
| `profileName` | String | `""` |
| `showCycle` | Boolean | `false` |
| `themeMode` | ThemeMode | `SYSTEM` |
| `premiumTheme` | PremiumTheme | `CLASSIC` (stored pick, shown even while free) |
| `language` | AppLanguage | `SYSTEM` |
| `premiumStatus` | PremiumStatus | `FREE` |
| `appLockEnabled` | Boolean | `false` |
| `secureScreenEnabled` | Boolean | `false` |
| `activeDialog` | MoreDialog? | `null` |

**`MoreEvent`** sealed interface (MoreUiState.kt:35), verbatim:
`DialogRequested(dialog: MoreDialog)` · `DialogDismissed` · `SelectTheme(mode: ThemeMode)` ·
`ColorThemeSelected(theme: PremiumTheme)` · `SelectLanguage(language: AppLanguage)` ·
`SetAppLock(enabled: Boolean)` (sent only after successful auth when enabling) ·
`SetSecureScreen(enabled: Boolean)` · `PremiumClicked` · `DoctorReportClicked` · `TrendsClicked`.

**`MoreEffect`** sealed interface (MoreUiState.kt:76): `OpenUrl(url: String)` · `OpenDoctorReport` ·
`OpenTrends`. Channel is `Channel.BUFFERED` (not conflated) so an off-screen effect is still
delivered.

**`MoreViewModel`** (MoreViewModel.kt:26) constructor:
```kotlin
class MoreViewModel(
    profileRepository: ProfileRepository,
    private val premiumRepository: PremiumRepository,
    private val preferences: SettingsPreferences,
    private val localeController: AppLocaleController,
    private val paywallController: PaywallController,
) : ViewModel()
```
- `language = MutableStateFlow(localeController.current())` — read once, tracked (not observed).
- `state` = 5-flow `combine` (profile, themeMode, appLock, secureScreen, + `SecondaryState`
  bundling language/activeDialog/premiumStatus/premiumTheme — combine's typed overloads stop at 5),
  `stateIn(WhileSubscribed(5_000), MoreUiState())`.
- Event handling gates (all read `premiumRepository.status.value`, not `state`):
  - `ColorThemeSelected`: entitled → persist + close; free → close + `paywallController.show(PaywallSource.THEMES)` — nothing written.
  - `PremiumClicked`: entitled → effect `OpenUrl(PLAY_SUBSCRIPTIONS_URL)`; free → `show(PaywallSource.SETTINGS)`.
  - `DoctorReportClicked`: entitled → `OpenDoctorReport`; free → `show(PaywallSource.DOCTOR_REPORT)`.
  - `TrendsClicked`: **never gated** — the screen shows its own lock → `OpenTrends`.
- **Sex-gate:** `showCycle = profile != null && profile.sex != Sex.MALE` — a profile with a skipped
  sex question (`null`) **keeps** the row; only explicit MALE hides it.
- **Constant:** `private const val PLAY_SUBSCRIPTIONS_URL = "https://play.google.com/store/account/subscriptions"`
  (MoreViewModel.kt:149). iOS equivalent for M9: App Store subscription management
  (`https://apps.apple.com/account/subscriptions` — platform-mapped, like the spec's other store
  URLs; final value is an M9 decision, not M8).

### Settings rows, in draw order (MoreScreen.kt:180–313)
| # | Row | Icon | Type | Destination / action | Keys |
|---|---|---|---|---|---|
| 1 | Profile | `Person` | MoreCard | `onOpenProfile` → `ProfileKey` | `more_profile`, subtitle = `profileName` or `more_profile_incomplete` if blank |
| 2 | Salus Premium | `WorkspacePremium` | MoreCard | `PremiumClicked` event (VM gates) | `settings_premium`, subtitle `settings_premium_active` if entitled else `settings_premium_promo` |
| 3 | Doctor Report (PDF) | `Description` | MoreCard | `DoctorReportClicked` event (VM gates) | `settings_doctor_report`, `settings_doctor_report_desc` |
| 4 | Trends | `Insights` | MoreCard | `TrendsClicked` event (never gated) | `more_trends`, `more_trends_subtitle` |
| — | *Section:* Tracking | | SectionLabel | only `if (state.showCycle)` | `more_section_tracking` |
| 5 | Cycle tracking | `WaterDrop` (accentTint = cycle color) | MoreCard | `onOpenCycle` shell callback | `more_cycle`, `more_cycle_subtitle` |
| — | *Section:* Appearance | | SectionLabel | | `settings_section_appearance` |
| 6 | Theme | `Palette` | MoreCard | `DialogRequested(Theme)` radio dialog | `settings_theme`, subtitle = current `theme_*` |
| 7 | Color theme | `ColorLens` | MoreCard | `DialogRequested(ColorTheme)` | `settings_color_theme`, subtitle = **effective** theme (lapsed subscriber sees Classic) via `effectivePremiumTheme(premiumStatus, premiumTheme)` |
| 8 | Language | `Language` | MoreCard | `DialogRequested(Language)` | `settings_language`, subtitle = current `language_*` |
| — | *Section:* Security | | SectionLabel | | `settings_section_security` |
| 9 | App lock | `Lock` | **MoreToggleCard** (Switch) | `SetAppLock`; disabled+subtitle swap when no biometric available; enable passes through BiometricPrompt first | `settings_app_lock`, `settings_app_lock_desc` / `settings_app_lock_unavailable`, prompt title `settings_app_lock_confirm_title` |
| 10 | Block screenshots | `Screenshot` | **MoreToggleCard** | `SetSecureScreen` | `settings_secure_screen`, `settings_secure_screen_desc` |
| — | *Section:* Notifications | | SectionLabel | | `settings_section_notifications` |
| 11 | Notification settings | `Notifications` | MoreCard | system deep link (`ACTION_APP_NOTIFICATION_SETTINGS`) | `settings_notifications`, `settings_notifications_desc` |
| 12 | Reminders | `Alarm` | MoreCard | `onOpenReminderHealth` → `ReminderHealthKey` | `settings_reminders`, `settings_reminders_desc` |
| — | *Section:* App | | SectionLabel | | `settings_section_app` |
| 13 | About the app | `Info` | MoreCard | `onOpenAbout` → `AboutKey` | `settings_about`, `settings_about_desc` |
| — | Version footer | | center-aligned `bodySmall` Text | only when `versionName` non-empty | `about_version` (format arg) |

Dialogs: Theme → all `ThemeMode.entries`; ColorTheme → **all** `PremiumTheme.entries` (free users
see the full list; the gate runs on tap); Language → all `AppLanguage.entries`. Each option applies
immediately and closes. Confirm button of every dialog: `settings_cancel`.

**Answers to the specific questions:** Yes — app lock toggle (row 9), secure screen toggle
(row 10), theme selection (row 6), premium theme (row 7) all exist as rows. The sex-gate for the
cycle row is `profile != null && profile.sex != Sex.MALE` in the ViewModel, plus the whole
Tracking section (label included) is hidden with it. The version string is a footer on More
itself (`about_version` = "Version %1$s" / "Sürüm %1$s"); the About screen deliberately shows
**no** version (single-home rule, AboutScreen.kt:33–34 comment).

### Platform adaptations the plan must decide
- BiometricPrompt → `LAContext`/`.deviceOwnerAuthentication` (`evaluatePolicy`); `appLockAvailable`
  = policy can evaluate.
- `ACTION_APP_NOTIFICATION_SETTINGS` → `UIApplication.openSettingsURL`.
- `PLAY_SUBSCRIPTIONS_URL` → App Store equivalent (row is inert until M9 anyway; see §8).
- Effects channel → `pendingEffect`/`consumeEffect()` @Observable pattern already proven in
  `ReminderHealthViewModel.swift`.

---

## §2 Profile

### Files
- `.../ui/profile/ProfileScreen.kt` (243 lines), `ProfileUiState.kt` (74 lines), `ProfileViewModel.kt` (112 lines)

### Types

**`ProfileRoute(viewModel = koinViewModel())`** — collects state, wires `navigator::pop` as back.
**`ProfileScreen(state, onEvent, onBack)`** stateless; TopAppBar with back (contentDescription
`profile_back`) and a `TextButton` "Save" disabled while `isLoading || isSaving || showInvalidHeight`.

**`ProfileUiState`** (ProfileUiState.kt:11):
| Field | Type | Default |
|---|---|---|
| `isLoading` | Boolean | `true` |
| `name` | String | `""` |
| `sex` | Sex? | `null` (pending value) |
| `birthDateEpochDay` | Int? | `null` |
| `heightText` | String | `""` |
| `healthNotes` | String | `""` |
| `storedSex` | Sex? | `null` (value on disk, for change detection) |
| `isSaving` | Boolean | `false` |
| `showSexChangeConfirm` | Boolean | `false` |

Computed properties:
- `showInvalidHeight` = `heightText.isNotBlank() && MeasurementInput.parseHeightCm(heightText) == null` (blank is fine — optional field).
- `cycleVisibilityChange: CycleVisibilityChange?` — compares `showsCycle()` of stored vs pending,
  where `showsCycle() = this != Sex.MALE` (null counts as showing). Returns `null` if unchanged,
  `Appears` if the row appears, `Disappears` if it vanishes. (Raw-value compare would miss
  `null → MALE` and nag on `FEMALE → OTHER`.)

**`CycleVisibilityChange`** enum: `Appears`, `Disappears`.

**`ProfileEvent`** sealed interface: `NameChanged(text: String)` · `SexSelected(sex: Sex)` ·
`BirthDateSelected(epochDay: Int)` · `HeightChanged(text: String)` ·
`HealthNotesChanged(text: String)` · `SaveClicked` · `SexChangeConfirmed` · `SexChangeDismissed`.
**No ProfileEffect** — closing after save is a `Navigator.pop()` from the ViewModel.

**`ProfileViewModel(profileRepository, navigator)`**: loads **once** in `init` via
`getProfile()` (not `observeProfile`). Events are plain `_state.update` copies except:
- `SaveClicked`: return early if `showInvalidHeight || isSaving`; if
  `cycleVisibilityChange == Disappears` → set `showSexChangeConfirm = true` (no write); else `save()`.
- `SexChangeConfirmed`: clear dialog + `save()`.
- `SexChangeDismissed`: clear dialog **and restore `sex = storedSex`** (inline warning must vanish).
- `save()`: sets `isSaving`, copies the **existing row** (`id`, `isDefault` must survive — every
  other table hangs off `profile_id`); `displayName = name.trim()`,
  `birthDate = epochDay?.let(LocalDate.fromEpochDays)`,
  `heightCm = MeasurementInput.parseHeightCm(heightText)` (blank → null),
  `healthNotes = trimmed.takeIf { isNotEmpty() }`; then `navigator.pop()`.
- `emptyProfile()` guard for corrupted installs: `Profile(id = ProfileRepository.DEFAULT_PROFILE_ID,
  displayName = "", birthDate = null, sex = null, heightCm = null, healthNotes = null, isDefault = true)`.
- `formatHeight(cm)`: prints `"165"` not `"165.0"` (`if (cm % 1.0 == 0.0) toLong else toString`).

### Form fields, in order (mirrors onboarding exactly)
1. Name — `SalusPillTextField`, words capitalization, no autocorrect, `ImeAction.Next`,
   autofill `ContentType.PersonFullName`, placeholder `profile_name_placeholder`.
2. Sex — three `SalusOptionRow`s (`Sex.entries`), icons Female/Male/Transgender, accents:
   FEMALE → cycle accent, MALE → vitals accent, OTHER → null. Below them, when
   `cycleVisibilityChange != null`, an inline `bodySmall` warning (`profile_sex_cycle_appears` /
   `profile_sex_cycle_disappears`).
3. Birth date — `SalusDateField(dateEpochDay, onDateSelected, placeholder)`.
4. Height — `SalusPillTextField`, suffix `"cm"`, decimal keyboard, `isError = showInvalidHeight`,
   supporting text `profile_height_invalid` when invalid.
5. Health notes — `SalusPillTextField`, **multi-line** (`singleLine = false`), sentences
   capitalization, **no imeAction** (would steal the newline key), placeholder
   `profile_health_notes_placeholder`.

Sex-change confirm dialog (`SalusConfirmDialog`): title `profile_sex_confirm_title`, body
`profile_sex_confirm_body`, confirm `profile_sex_confirm_ok`, dismiss `profile_sex_confirm_cancel`.

**Answer to "how does Profile work":** yes, full name editing (plus sex, birth date, height,
health notes — the same five onboarding fields, same order). Weight is deliberately absent (vitals
time series, not a profile attribute, per m10-plan).

### iOS dependency gaps for Profile
- `SalusPillTextField` — **does not exist** in `SalusUI` (has `SalusPillButton` only). Features
  today use plain `TextField` (e.g. `FeatureVitals` editors). Plan must add it or use TextField.
- `SalusOptionRow` — **does not exist** in `SalusUI`.
- `SalusListItemChevron` — **does not exist** in `SalusUI` (MoreScreen rows use it).
- `MeasurementInput.parseHeightCm` — **does not exist** on iOS; port from
  `core/common/.../MeasurementInput.kt` with `MIN_HEIGHT_CM = 50.0`, `MAX_HEIGHT_CM = 250.0`
  (constants in `profile_height_invalid` copy: "between 50 and 250 cm"). Port into `SalusCommon`
  (twin of `:core:common`) with its table tests.
- `Profile` model, `Sex` enum, `LocalDate`, `ProfileRepository` (async-throwing variants) already
  exist in `SalusModel`/`SalusProfile`; `DEFAULT_PROFILE_ID` reached via `SalusProfile`.

---

## §3 About

**File:** `.../ui/about/AboutScreen.kt` (80 lines).

**`AboutRoute()`** — injects `Navigator`, passes `navigator::pop`.
**`AboutScreen(onBack: () -> Unit)`** — TopAppBar (back contentDescription uses `settings_back`
— **not** an `about_*` key), then a scroll column with hardcoded `16.dp`/`12.dp`/`8.dp` paddings
(not SalusSpacing — a fidelity note; iOS should use tokens):
1. `about_app_name` ("Salus") — `headlineMedium`, primary color.
2. `about_description` — `bodyMedium`.
3. `Card` with `about_privacy_title` (`titleMedium`) + `about_privacy_body` (`bodyMedium`).

**No version display** (single home for the number is the More footer — comment cites
m9-plan item 1). No ViewModel, no state, no events.

---

## §4 Navigation

**File:** `.../navigation/SettingsNavigation.kt` (51 lines).

NavKeys (all `@Serializable data object : NavKey`, no params):
- `MoreKey` — bottom-bar tab root.
- `ProfileKey` — pushed (`SalusTransitions.push`).
- `AboutKey` — pushed.
- `ReminderHealthKey` — pushed.

```kotlin
fun EntryProviderScope<NavKey>.settingsEntries(
    onOpenCycle: () -> Unit,
    onOpenDoctorReport: () -> Unit,
    onOpenTrends: () -> Unit,
)
```
The three callbacks are the cross-feature ones (Cycle → `:feature:cycle`, doctor report →
`:feature:aihealth`'s `DoctorReportKey`, trends → `:feature:trends`'s `TrendsKey`); everything
else goes through the shared `Navigator` inside the feature.

iOS current state: `SettingsNavigation.swift` has only `ReminderHealthKey` and
`settingsDestinations()` registering it. **Owed:** `MoreKey` (tab root — likely no key needed; the
More tab root is the `NavigationStack` root like other tabs), `ProfileKey`, `AboutKey`, and shell
callbacks for cycle (exists), doctor report, trends. Note `PlaceholderScreen` (App) already carries
`onOpenCycle`/`onOpenReminderHealth` rows and `RootView.swift:202` has `TODO(M8)` for the hub.

---

## §5 Preferences / locale / DI

**`SettingsPreferences`** (domain interface, SettingsPreferences.kt:7) — pure Kotlin, no Android:
```kotlin
interface SettingsPreferences {
    val themeMode: Flow<ThemeMode>
    val appLockEnabled: Flow<Boolean>
    val secureScreenEnabled: Flow<Boolean>
    val premiumTheme: Flow<PremiumTheme>   // stored even while not entitled
    suspend fun setThemeMode(mode: ThemeMode)
    suspend fun setAppLockEnabled(enabled: Boolean)
    suspend fun setSecureScreenEnabled(enabled: Boolean)
    suspend fun setPremiumTheme(theme: PremiumTheme)
}
```

**`SettingsPreferencesImpl(dataSource: SalusPreferencesDataSource)`** — each flow is
`dataSource.userSettings.map { it.<field> }`; each setter delegates 1:1. iOS twin:
`SalusSettings`' `SalusPreferencesDataSource` already exposes `userSettings: AsyncStream<UserSettings>`
and all four setters — **the impl port is a thin adapter**, or the feature can consume the data
source through a narrowed protocol like `FeatureHome` did.

**`AppLanguage`** enum (AppLocaleController.kt:3): `SYSTEM`, `TURKISH`, `ENGLISH`.

**`AppLocaleController`** interface: `fun current(): AppLanguage`, `fun apply(language: AppLanguage)`.

**`AppCompatLocaleController`** (data): `current()` reads `AppCompatDelegate.getApplicationLocales()`
(empty → SYSTEM, `"tr"` → TURKISH, else ENGLISH); `apply` sets a `LocaleListCompat` ("tr"/"en"/empty).
**iOS has no equivalent anywhere** (no `AppLanguage`, no locale controller; greps find nothing).
The ios-v1-plan puts "localization — String Catalogs for all 511 keys" in M8, so the in-app
language picker machinery is M8 scope; the natural twin is a UserDefaults "override bundle locale"
approach. **This is a plan-level design decision** — recorded here as owed.

**`SettingsModule`** (di/SettingsModule.kt:13):
```kotlin
val settingsModule = module {
    single<SettingsPreferences> { SettingsPreferencesImpl(get()) }
    single<AppLocaleController> { AppCompatLocaleController() }
    viewModelOf(::MoreViewModel)
    viewModelOf(::ReminderHealthViewModel)
    viewModelOf(::ProfileViewModel)
}
```
iOS twin `SettingsModule.swift` currently holds only `makeReminderHealthViewModel: @MainActor () ->
ReminderHealthViewModel`; `makeSettingsModule(reminderEnvironment:reminderAuthorization:reminderSyncState:clock:alarmKitSupported:)`
builds it. **Owed:** `makeMoreViewModel` + `makeProfileViewModel` closures, and the preferences /
locale-controller inputs threaded in from `AppCompositionRoot` (which already owns
`SalusPreferencesDataSource` and `ProfileRepository`).

---

## §6 Strings inventory

Android `values/strings.xml` (TR, source) and `values-en/strings.xml` (EN) each hold **91 keys**;
the iOS `Localizable.xcstrings` currently carries **15** (reminder-health set, incl. 5 iOS-only:
`reminder_health_background_refresh_*` ×3, `reminder_health_last_sync`, `reminder_health_never_synced`;
dropped Android keys: `reminder_health_exact_*` ×3, `reminder_health_battery_*` ×3,
`reminder_health_back`). **74 non-reminder-health keys are owed**, all with TR+EN pairs below.

Two back keys (`settings_back`, `profile_back`) exist only as TopAppBar contentDescriptions —
per the `reminder_health_back` precedent (shell draws the back button), **likely dropped on iOS**;
flag for the plan. Effective owed-with-drop: 72 new keys → catalog grows to 87.

### More + dialogs (44)
| Key | TR | EN |
|---|---|---|
| `more_title` | Daha Fazla | More |
| `more_profile` | Profil | Profile |
| `more_profile_incomplete` | Profilini tamamla | Complete your profile |
| `settings_premium` | Salus Premium | Salus Premium |
| `settings_premium_active` | Premium üyesin | You are a Premium member |
| `settings_premium_promo` | AI özetleri, gelişmiş trendler ve daha fazlası | AI summaries, advanced trends and more |
| `settings_doctor_report` | Doktor Raporu (PDF) | Doctor report (PDF) |
| `settings_doctor_report_desc` | Kayıtlarını PDF olarak dışa aktar ve paylaş | Export your records as a PDF and share them |
| `more_trends` | Analizler | Trends |
| `more_trends_subtitle` | Kayıtlarındaki örüntüler ve dönem karşılaştırmaları | Patterns in your records and period comparisons |
| `more_section_tracking` | Takip | Tracking |
| `more_cycle` | Regl Takibi | Cycle tracking |
| `more_cycle_subtitle` | Takvim, tahminler ve belirtiler | Calendar, predictions and symptoms |
| `settings_section_appearance` | Görünüm | Appearance |
| `settings_theme` | Tema | Theme |
| `theme_title` | Tema | Theme |
| `theme_system` | Sistem varsayılanı | System default |
| `theme_light` | Açık | Light |
| `theme_dark` | Koyu | Dark |
| `settings_color_theme` | Renk teması | Color theme |
| `color_theme_classic` | Klasik | Classic |
| `color_theme_ocean` | Okyanus | Ocean |
| `color_theme_sunset` | Gün batımı | Sunset |
| `color_theme_forest` | Orman | Forest |
| `settings_language` | Dil | Language |
| `language_title` | Dil | Language |
| `language_system` | Sistem dili | System language |
| `language_turkish` | Türkçe | Türkçe |
| `language_english` | English | English |
| `settings_section_security` | Güvenlik | Security |
| `settings_app_lock` | Uygulama kilidi | App lock |
| `settings_app_lock_desc` | 30 sn arka planda kaldıktan sonra biyometri veya cihaz kilidi iste | Require biometrics or device credential after 30 s in the background |
| `settings_app_lock_unavailable` | Bu cihazda ekran kilidi tanımlı değil | No screen lock is set up on this device |
| `settings_app_lock_confirm_title` | Uygulama kilidini etkinleştir | Enable app lock |
| `settings_secure_screen` | Ekran görüntüsünü engelle | Block screenshots |
| `settings_secure_screen_desc` | Ekran görüntülerini ve son uygulamalar önizlemesini gizler | Hides screenshots and the recents preview |
| `settings_section_notifications` | Bildirimler | Notifications |
| `settings_notifications` | Bildirim ayarları | Notification settings |
| `settings_notifications_desc` | Kanal, ses ve titreşimi sistem ayarlarından yönet | Manage channels, sound and vibration in system settings |
| `settings_reminders` | Hatırlatıcılar | Reminders |
| `settings_reminders_desc` | Hatırlatıcıların çalışma durumunu incele | Review how reminders are running |
| `settings_section_app` | Uygulama | App |
| `settings_about` | Uygulama hakkında | About the app |
| `settings_about_desc` | Sürüm ve uygulama bilgileri | Version and app info |

### About (5, incl. the shared version line)
| Key | TR | EN |
|---|---|---|
| `about_title` | Uygulama hakkında | About the app |
| `about_app_name` | Salus | Salus |
| `about_version` | Sürüm %1$s | Version %1$s |
| `about_description` | Salus; randevularınızı, ilaçlarınızı, döngünüzü ve sağlık ölçümlerinizi tek bir yerden takip etmenize yardımcı olan cihaz öncelikli bir sağlık asistanıdır. | Salus is a device-first health companion that helps you track your appointments, medications, cycle, and health measurements in one place. |
| `about_privacy_title` | Gizlilik | Privacy |
| `about_privacy_body` | Sağlık kayıtlarınız yalnızca cihazınızda saklanır ve cihazınızdan asla çıkmaz. Hesap yoktur, analitik yoktur, veri toplanmaz. Salus ağı yalnızca iki şey için kullanır: aboneliğinizi doğrulamak (Google Play ve abonelik altyapımız RevenueCat) ve — kullanırsanız — AI özellikleri. AI özelliklerine yalnızca anonim istatistik özetleri gönderilir; sağlık kayıtlarınız asla gönderilmez. | Your health records are stored only on your device and never leave it. No accounts, no analytics, no data collection. Salus uses the network for two things: verifying your subscription (Google Play and our subscription provider, RevenueCat) and — if you use them — the AI features. The AI features only ever receive anonymous statistical summaries; your health records are never sent. |

(`about_privacy_body` mentions Google Play/RevenueCat — iOS copy decision needed: keep verbatim
per the TR+EN parity rule, or follow the App Store naming as a recorded divergence. The
`about_description` sentence is platform-neutral.)

### Profile (22)
| Key | TR | EN |
|---|---|---|
| `profile_title` | Profil | Profile |
| `profile_back` | Geri | Back |
| `profile_save` | Kaydet | Save |
| `profile_name` | Ad | Name |
| `profile_name_placeholder` | Örn: Ayşe | e.g. Ayşe |
| `profile_sex` | Cinsiyet | Sex |
| `profile_sex_female` | Kadın | Female |
| `profile_sex_male` | Erkek | Male |
| `profile_sex_other` | Diğer | Other |
| `profile_sex_cycle_appears` | Regl Takibi, Daha Fazla sekmesine eklenir. Daha önce kaydettiğin regl verilerin olduğu gibi durur. | Cycle tracking is added to the More tab. Any cycle data you recorded before is still there. |
| `profile_sex_cycle_disappears` | Regl Takibi, Daha Fazla sekmesinden kaldırılır. Kayıtlı regl verilerin silinmez; seçimi geri aldığında geri gelir. | Cycle tracking is removed from the More tab. Your recorded cycle data is not deleted and comes back if you change this again. |
| `profile_sex_confirm_title` | Regl Takibi kaldırılsın mı? | Remove Cycle tracking? |
| `profile_sex_confirm_body` | Bu seçimle Regl Takibi, Daha Fazla sekmesinden kaldırılır. Kayıtlı regl verilerin silinmez; seçimi geri aldığında geri gelir. | This removes Cycle tracking from the More tab. Your recorded cycle data is not deleted and comes back if you change this again. |
| `profile_sex_confirm_ok` | Kaydet | Save |
| `profile_sex_confirm_cancel` | Vazgeç | Cancel |
| `profile_birth_date` | Doğum Tarihi | Date of birth |
| `profile_birth_date_select` | Tarih seçin | Pick a date |
| `profile_height` | Boy | Height |
| `profile_height_placeholder` | Örn: 170 | e.g. 170 |
| `profile_height_invalid` | 50 ile 250 cm arasında bir değer girin. | Enter a value between 50 and 250 cm. |
| `profile_health_notes` | Sağlık Notları | Health notes |
| `profile_health_notes_placeholder` | Kronik hastalıklar, alerjiler, kullandığın ilaçlar… | Chronic conditions, allergies, medications you take… |

### Shared / misc (3)
| Key | TR | EN | Used by |
|---|---|---|---|
| `settings_cancel` | Vazgeç | Cancel | all three selection dialogs on More |
| `settings_back` | Geri | Back | About TopAppBar contentDescription |
| `more_profile` / `more_profile_incomplete` | (in More table above) | | Profile row subtitle |

**Placeholder mapping rule** (per CLAUDE.md): `%1$s` → `%1$@` (`about_version` is the only
formatted key owed). String tests: extend `SettingsStringsTests` (currently pins "exactly the 15
keys") with the new key-set literal + parity + value tables, same shape.

---

## §7 Tests owed (verbatim backtick names)

### MoreViewModelTest.kt — 20 tests
Fakes: `FakeProfileRepository` (MutableStateFlow-backed), `FakePremiumRepository` (status flow +
refreshCount), `FakeSettingsPreferences` (MutableStateFlow per preference), `FakeLocaleController`
(language + appliedCount), real `PaywallController()`. Helper `hotViewModel()` keeps a live
collector so `state.value` is current.

Cycle visibility:
1. `cycle is hidden while the profile has not loaded` — initial state: isLoading, !showCycle.
2. `cycle is shown for female, other and unspecified profiles` — FEMALE/OTHER/null all show.
3. `cycle is hidden for a male profile`.
4. `changing sex updates visibility without recreating the view model` — flow re-emits on profile change.

Settings (merged from former Settings screen):
5. `state carries the stored preferences` — theme/language/appLock/secureScreen all reach state.
6. `selecting a theme persists it and closes the dialog`.
7. `selecting a language applies the locale and closes the dialog` — locale.apply called once.
8. `dismissing a dialog leaves the setting untouched`.
9. `security toggles persist` — SetAppLock(true) + SetSecureScreen(true).

Premium:
10. `state follows the entitlement` — FREE → GRACE_PERIOD transition lands in state.
11. `a free user tapping premium opens the paywall from the settings source` — PaywallSource.SETTINGS, no effects.
12. `an entitled user tapping premium is sent to subscription management` — OpenUrl(play subscriptions URL), no paywall.
13. `a grace period user tapping premium is sent to subscription management` — still entitled.

Doctor report:
14. `a free user tapping the doctor report gets the paywall and never the screen` — PaywallSource.DOCTOR_REPORT.
15. `an entitled user tapping the doctor report opens it` — OpenDoctorReport effect.
16. `a grace period user reaches the doctor report`.

Colour themes:
17. `state carries the stored colour theme`.
18. `a premium user's colour theme is persisted and the dialog closes`.
19. `a grace period user may still change the colour theme`.
20. `a free user's pick opens the paywall and is not persisted` — THEMES paywall, stored stays CLASSIC, dialog closes.

**iOS blocker:** tests 10–20 need `PremiumStatus`/`PaywallController`/`PaywallSource` ports. iOS
has **none** (premium is M9; `SalusPremium` is a namespace, `FeaturePaywall` is an M0 placeholder).
The `FeatureHome` precedent (divergence (d)): a narrow protocol (`HomePremiumStatus.isPremium:
AsyncStream<Bool>`) + `FreeOnlyPremiumStatus` stand-in, with tests for gated paths landing in M9.
Options for the plan: (a) same stand-in pattern here (`FreeOnly` answers false → all paywall
branches testable, management branches deferred), or (b) port the three-state enum + controller
now. Note More needs more than Home's boolean: it distinguishes paywall vs OpenUrl vs
OpenDoctorReport, and state carries `premiumStatus` for the row subtitle + effective theme.

### ProfileViewModelTest.kt — 8 tests
Fakes: `FakeProfileRepository(initial)` (saved list), `FakeNavigator` (commandLog of
`NavCommand.Pop`/`Navigate`). Stored profile: id "default", "Ayşe", 1990-05-17, FEMALE, 165.0,
"Penicillin allergy", isDefault true.

1. `loads the stored profile into the form` — all five fields + storedSex; height formatted "165".
2. `blank optional fields save as null and the stored id is kept` — trims name, nulls height/notes, id/isDefault survive, pops once.
3. `an out-of-range height blocks the save` — "300" → showInvalidHeight, nothing saved, no pop.
4. `female to male asks for confirmation before writing` — Disappears detected, confirm dialog, nothing saved until SexChangeConfirmed, then pop.
5. `a skipped sex set to male also asks for confirmation` — null → MALE counts as Disappears.
6. `female to other keeps the cycle row and needs no confirmation` — cycleVisibilityChange nil, saves immediately.
7. `male back to female brings the row back without a dialog` — Appears, saves immediately.
8. `cancelling the dialog restores the stored sex and writes nothing` — sex back to FEMALE, warning gone, no save, no pop.

iOS has all supporting types for these (`Profile`, `Sex`, `ProfileRepository` protocol,
`Navigator`/`NavCommand`); only `MeasurementInput.parseHeightCm` must land first (test 3 depends
on it).

### ReminderHealthViewModelTest.kt — already ported
Android's 5 tests are covered (and extended to 11) by
`Tests/FeatureSettingsTests/ReminderHealthViewModelTests.swift` (Swift Testing `@Test` names mirror
the backtick names, plus iOS-only AlarmKit/background-refresh/last-sync cases). Nothing owed.

---

## §8 iOS current state (FeatureSettings package)

**Ported (M4/M6):**
- `ui/reminderhealth/` — `ReminderHealthScreen.swift` (Route/Screen split, effects via
  `pendingEffect`/`consumeEffect()`, scenePhase refresh), `ReminderHealthViewModel.swift`,
  `ReminderHealthUiState.swift` (iOS-shaped rows: AlarmKit instead of exact alarms,
  background refresh instead of battery optimization, `lastSyncAt`+`timeZone` extra),
  `ReminderHealthLastSync.swift`.
- `SettingsStrings.swift` — 15 reminder-health keys only.
- `navigation/SettingsNavigation.swift` — `ReminderHealthKey` + `settingsDestinations()`.
- `SettingsModule.swift` — `SettingsModule { makeReminderHealthViewModel }`,
  `makeSettingsModule(reminderEnvironment:reminderAuthorization:reminderSyncState:clock:alarmKitSupported:)`,
  `@Entry var settingsModule`.
- Tests: `ReminderHealthViewModelTests` (11), `ReminderHealthLastSyncTests`, `SettingsStringsTests`
  (pins "exactly the 15 keys" — must grow), `FakeReminderEnvironment`, `WaitUntil`.
- `Package.swift` already declares dependencies the hub needs: SalusDesignSystem, SalusUI,
  SalusCommon, SalusModel, SalusNavigation, SalusReminder, **SalusSettings, SalusProfile,
  SalusPremium** (added ahead, unused so far).

**Owed (everything else):**
- `ui/more/` — MoreRoute/MoreScreen, MoreUiState (MoreDialog/MoreEvent/MoreEffect), MoreViewModel.
- `ui/profile/` — ProfileRoute/ProfileScreen, ProfileUiState (CycleVisibilityChange/ProfileEvent),
  ProfileViewModel.
- `ui/about/` — AboutRoute/AboutScreen (static, no VM).
- `domain/` — `SettingsPreferences` protocol + impl over `SalusPreferencesDataSource`;
  `AppLanguage` + `AppLocaleController` (iOS locale mechanism = M8 design decision).
- Navigation keys: ProfileKey, AboutKey; MoreKey tab-root wiring in the shell.
- 74 strings (§6) + `SettingsStrings` accessors + parity-test updates.
- 28 ViewModel tests (§7) + any state-computed tests.
- Shell: replace `PlaceholderScreen` for `.more` with `MoreRoute`; delete `PlaceholderScreen`
  entirely (its own TODOs say so).

**TODO(M8) markers found (4 locations):**
1. `Sources/FeatureSettings/SettingsModule.swift:11` — "TODO(M8): the settings hub's own ViewModel
   and the preferences it reads."
2. `Sources/FeatureSettings/navigation/SettingsNavigation.swift:18-19` — "TODO(M8): the settings
   hub itself, plus the keys its rows push."
3. `App/RootView.swift:202` — "TODO(M8): the settings hub replaces this placeholder."
4. `App/PlaceholderScreen.swift:20,30` — "TODO(M8): delete this along with the whole view" (×2).

**Cross-feature rows at M8 time:** doctor report (`FeatureAIHealth` — M0 placeholder), trends
(`FeatureTrends` — M0 placeholder), premium/paywall (`FeaturePaywall` — M0 placeholder; `SalusPremium`
is a namespace). More's row 2/3/4 and their gates need stand-ins until M9/M10/M11 — the
`FreeOnlyPremiumStatus` divergence-(d) pattern is the established shape; doctor-report and trends
callbacks can be shell closures that no-op or get wired in their own milestones (mirroring how the
placeholder already routes cycle and reminder health today).

**Other infra notes:**
- `UserSettings` on iOS already carries `appLockEnabled` (Keychain-backed) and
  `secureScreenEnabled` (the §6.2 masking toggle — wording divergence already recorded in the
  model: always-on switcher blur + masking toggle; `settings_secure_screen_desc` copy above says
  "hides screenshots and the recents preview" — the §6.2 ruling governs if the strings diverge).
- `SalusTheme.resolve` takes the **effective** palette; `SalusDesignSystem` already implements the
  `effectivePremiumTheme` twin (lapsed subscriber → classic accents) — More's color-theme row
  subtitle should use the same resolved value the shell draws.
- Version footer: read from bundle (`CFBundleShortVersionString`) in the Route, twin of the
  packageManager read.
- App lock availability/enabling prompt lives in the Route on iOS too (LAContext), keeping the
  ViewModel testable — same split as Android.

---

## §9 Constants recap
| Constant | Value | Source |
|---|---|---|
| `PLAY_SUBSCRIPTIONS_URL` | `https://play.google.com/store/account/subscriptions` | MoreViewModel.kt:149 (iOS: App Store equivalent, M9) |
| `MIN_HEIGHT_CM` | 50.0 | MeasurementInput.kt:13 |
| `MAX_HEIGHT_CM` | 250.0 | MeasurementInput.kt:14 |
| App-lock re-lock timeout | 30 s (fixed, no UI option) | AppLockManager (companion doc) |
| `stateIn` timeout | 5_000 ms | MoreViewModel.kt:76 |
| Effects channel | `Channel.BUFFERED` | MoreViewModel.kt:41 |