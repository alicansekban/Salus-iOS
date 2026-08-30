# M8 Research Inventory — App Lock, Secure Screen, Onboarding (Android source of truth → iOS current state)

Research for the Salus iOS M8 (settings) milestone plan. Every section cites the Android file and
line the iOS port must reproduce, plus the iOS scaffolding that already exists.

---

## §1 AppLockManager (Android)

**File:** `salus-android/app/src/main/kotlin/com/alicansekban/salus/lock/AppLockManager.kt` (52 lines)

### State machine

```kotlin
class AppLockManager(
    appLockEnabled: Flow<Boolean>,      // from SalusPreferencesDataSource.userSettings.map { it.appLockEnabled } (distinctUntilChanged applied in DI)
    private val clock: SalusClock,
) : DefaultLifecycleObserver
```

- Private state: `unlockedThisSession: MutableStateFlow<Boolean>` (starts `false` — a cold start
  begins locked when the setting is on), `backgroundedAtMs: Long?` (starts `null`).
- `val isLocked: Flow<Boolean> = combine(appLockEnabled, unlockedThisSession) { enabled, unlocked -> enabled && !unlocked }`
- Registered on **ProcessLifecycleOwner** in `SalusApplication.onCreate` (`SalusApplication.kt:51`):
  "App lock watches the whole process, not a single activity: switching activities or configuration
  changes must not count as 'leaving the app'."
- Singleton in Koin `appModule` (`di/AppModules.kt:45-52`):
  `AppLockManager(appLockEnabled = get<SalusPreferencesDataSource>().userSettings.map { it.appLockEnabled }.distinctUntilChanged(), clock = get())`

### Timeout semantics — re-lock is a background-duration grace, not foreground

- `onStop(owner)`: `backgroundedAtMs = clock.now().toEpochMilliseconds()`
- `onStart(owner)`: if `backgroundedAt == null || now - backgroundedAt > LOCK_TIMEOUT` →
  `unlockedThisSession.value = false` (re-lock). So: **re-lock 30 s after backgrounding**, evaluated
  on return to foreground. A cold start (`backgroundedAt == null`) also locks.
- `fun unlock()` sets `unlockedThisSession.value = true`.
- Disabling the setting while locked unlocks immediately (isLocked is derived from
  `enabled && !unlocked`).

### Timeout constant

```kotlin
companion object {
    /** Fixed by product decision — no UI option. */
    val LOCK_TIMEOUT = 30.seconds
}
```

### Biometric prompt flow

`MainActivity.showUnlockPrompt(onSuccess: () -> Unit)` (`MainActivity.kt:118-134`):

- `BiometricPrompt(this, ContextCompat.getMainExecutor(this), callback)` — requires
  FragmentActivity, which is why `MainActivity : AppCompatActivity` (comment at
  `MainActivity.kt:36-38`; also needed for per-app locales below API 33).
- Callback: only `onAuthenticationSucceeded` is overridden → calls `onSuccess()`.
- `PromptInfo.Builder().setTitle(getString(R.string.app_lock_prompt_title))`
  `.setAllowedAuthenticators(BIOMETRIC_WEAK or DEVICE_CREDENTIAL).build()` — **biometrics weak OR
  device credential (PIN/pattern/password) is the passcode fallback**; the system renders the
  credential UI itself.
- **On failure/cancel:** nothing happens — no callback, no retry loop. The gate stays up; the
  `AppLockScreen`'s Unlock button is the retry.

### Storage (Android side)

`core/datastore` `SalusPreferencesDataSource`:
- `KEY_APP_LOCK_ENABLED = booleanPreferencesKey("app_lock_enabled")`, read `?: false`.
- `suspend fun setAppLockEnabled(enabled: Boolean)` — plain DataStore (not Keychain; the Keychain
  split is an iOS-only spec decision, see §9).
- Model field: `UserSettings.appLockEnabled: Boolean = false` (`core/model/Settings.kt:19`).

### Settings UI entry (Android, for parity)

`feature/settings/.../more/MoreScreen.kt:258-279` — "Security" section with two `MoreToggleCard`s:
- App lock (`settings_app_lock` / `settings_app_lock_desc` / `settings_app_lock_unavailable`).
  `appLockAvailable = activity is FragmentActivity && BiometricManager.canAuthenticate(BIOMETRIC_WEAK or DEVICE_CREDENTIAL) == BIOMETRIC_SUCCESS`
  (`MoreScreen.kt:94-98`). Toggle disabled when unavailable.
- **Enabling requires re-auth:** `MoreRoute` intercepts `MoreEvent.SetAppLock(enabled=true)` and
  runs `authenticate(activity, appLockPromptTitle) { viewModel.onEvent(event) }`
  (`MoreScreen.kt:130-137`, `authenticate` at `MoreScreen.kt:452-472` — same BiometricPrompt shape
  as MainActivity's). Disabling needs no confirmation.
- `MoreViewModel.onEvent(SetAppLock)` → `preferences.setAppLockEnabled(event.enabled)` (`MoreViewModel.kt:112-114`).
- Block screenshots toggle (`settings_secure_screen` / `settings_secure_screen_desc`).

---

## §2 AppLockScreen (Android)

**File:** `salus-android/app/src/main/kotlin/com/alicansekban/salus/lock/AppLockScreen.kt` (68 lines)

```kotlin
@Composable
internal fun AppLockScreen(onUnlockRequest: () -> Unit) {
    LaunchedEffect(Unit) { onUnlockRequest() }   // fires the prompt automatically on entry
    ...
}
```

- Full-screen `Surface` (background color), centred `Column`:
  - `SalusIconBadge(icon = Icons.Outlined.Lock, size = LargeSize, iconSize = LargeIconSize)`
  - `Spacer(SalusSpacing.lg)`
  - `Text(stringResource(R.string.app_lock_locked_title), style = MaterialTheme.typography.titleLarge)`
  - `Spacer(SalusSpacing.xl)`
  - `SalusPillButton(text = stringResource(R.string.app_lock_unlock), onClick = onUnlockRequest)`
- **Retry affordance:** just the lock icon + title + Unlock button — the button re-fires the
  prompt after a cancel/failure. Nothing else on screen. No back handling (it's an overlay above
  the nav root, so the back stack and pending deep links survive the lock).
- `@PreviewLightDark private fun AppLockScreenPreview()`.

### Strings (app module, `app/src/main/res/values/strings.xml:11-13`)

| Key | TR (default) | EN (`values-en`) |
|---|---|---|
| `app_lock_locked_title` | Salus kilitli | Salus is locked |
| `app_lock_unlock` | Kilidi aç | Unlock |
| `app_lock_prompt_title` | Salus kilidini aç | Unlock Salus |

Settings-feature lock strings (`feature/settings/src/main/res/values{,-en}/strings.xml:21-26`):

| Key | TR | EN |
|---|---|---|
| `settings_app_lock` | Uygulama kilidi | App lock |
| `settings_app_lock_desc` | 30 sn arka planda kaldıktan sonra biyometri veya cihaz kilidi iste | Require biometrics or device credential after 30 s in the background |
| `settings_app_lock_unavailable` | Bu cihazda ekran kilidi tanımlı değil | No screen lock is set up on this device |
| `settings_app_lock_confirm_title` | Uygulama kilidini etkinleştir | Enable app lock |
| `settings_secure_screen` | Ekran görüntüsünü engelle | Block screenshots |
| `settings_secure_screen_desc` | Ekran görüntülerini ve son uygulamalar önizlemesini gizler | Hides screenshots and the recents preview |
| `settings_section_security` (section label, MoreScreen.kt:258) | *(check settings strings.xml for TR value)* | *(check)* |

---

## §3 MainActivity gates + lifecycle wiring (Android)

**File:** `salus-android/app/src/main/kotlin/com/alicansekban/salus/MainActivity.kt` (135 lines)

### Onboarding gate — splash-held null until DataStore answers

- `private val onboardingCompleted = MutableStateFlow<Boolean?>(null)` — "Null until DataStore has
  answered; the splash stays up so Home never flashes."
- `onCreate`: `installSplashScreen().setKeepOnScreenCondition { onboardingCompleted.value == null }`,
  then `lifecycleScope.launch { preferencesDataSource.userSettings.map { it.onboardingCompleted }.collect { onboardingCompleted.value = it } }`

### Gate order (setContent, `MainActivity.kt:94-107`)

```kotlin
SalusTheme(darkTheme, premiumTheme) {
    SalusApp()                          // the nav shell — always composed
    // Overlays, not destinations: the back stack and pending notification deep
    // links stay intact behind the gates. Onboarding sits outermost — a first
    // launch has nothing to lock.
    if (isLocked) { AppLockScreen(onUnlockRequest = { showUnlockPrompt(appLockManager::unlock) }) }
    if (onboardingDone == false) { OnboardingRoute() }
}
```

- **Order of overlays in the composition: lock first (inner), onboarding outermost.** Onboarding
  renders *above* the lock because "a first launch has nothing to lock" — a fresh install has
  `app_lock_enabled=false` so the lock never shows, and the visual order guarantees onboarding
  covers everything.
- `isLocked` collected with `initialValue = false` (no splash hold for lock; the lock only appears
  on re-lock transitions).
- `onboardingDone == false` (three-state: `null` = still loading → onboarding not shown, splash holds).

### Lifecycle

- `onStop()` (`MainActivity.kt:111-116`): `pendingDeletes.commitAll()` — undo windows don't survive
  backgrounding. (AppLockManager's own onStop is on the process lifecycle, via
  SalusApplication — see §1.)
- Theme/secure/premium collected via `remember(preferences) { ... }.collectAsStateWithLifecycle`.

### Biometric prompt

See §1 "Biometric prompt flow" — `showUnlockPrompt` is private in MainActivity, title
`app_lock_prompt_title`, `BIOMETRIC_WEAK or DEVICE_CREDENTIAL`.

---

## §4 Secure screen implementation (Android)

- `MainActivity.kt:65-74`:
  ```kotlin
  val secureScreen by remember(preferences) { preferences.userSettings.map { it.secureScreenEnabled } }
      .collectAsStateWithLifecycle(initialValue = false)
  LaunchedEffect(secureScreen) {
      if (secureScreen) window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
      else window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
  }
  ```
- `UserSettings.secureScreenEnabled: Boolean = false` (`core/model/Settings.kt:21`): "Sets
  FLAG_SECURE: blocks screenshots and hides the recents preview."
- Storage: `KEY_SECURE_SCREEN_ENABLED = booleanPreferencesKey("secure_screen_enabled")`,
  `setSecureScreenEnabled(enabled: Boolean)` in `SalusPreferencesDataSource`.
- No other secure-related code in the app module (no secure text field / no UIScreen.isCaptured on
  Android — that concept is iOS-only, spec §6.2).

---

## §5 Onboarding feature (Android)

**Module:** `salus-android/feature/onboarding/` — files: `ui/OnboardingScreen.kt` (306 l),
`ui/OnboardingUiState.kt` (122 l), `ui/OnboardingViewModel.kt` (130 l), `ui/OnboardingStepContent.kt`
(366 l), `ui/OnboardingHeader.kt` (130 l), `ui/OnboardingHero.kt` (163 l),
`domain/OnboardingPreferences.kt` (9 l), `data/OnboardingPreferencesImpl.kt` (13 l),
`di/OnboardingModule.kt` (23 l).

### Steps (8 total, one dropped below API 33 → 7 counting steps)

```kotlin
enum class OnboardingStep { Welcome, Name, Sex, BirthDate, Height, Weight, HealthNotes, Notifications }
enum class OnboardingSection { PersonalDetails, HealthNotes, Privacy }
```

Section mapping (private `OnboardingStep.section: OnboardingSection?`):
- `Welcome → null` (no header at all — "the cover, not a question")
- `Name, Sex, BirthDate, Height, Weight → PersonalDetails`
- `HealthNotes → HealthNotes`
- `Notifications → Privacy`

Steps list is filtered: `OnboardingStep.entries.filter { it != Notifications || includeNotificationStep }`
— the Notifications step is dropped below API 33 (`includeNotificationStep = Build.VERSION.SDK_INT >= TIRAMISU`,
from `OnboardingModule.kt:20`). iOS always has the notification-permission concept, so the step stays.

### UiState (`OnboardingUiState.kt:47-101`)

```kotlin
data class OnboardingUiState(
    val steps: ImmutableList<OnboardingStep> = persistentListOf(OnboardingStep.Welcome),
    val stepIndex: Int = 0,
    val name: String = "",
    val sex: Sex? = null,
    val birthDateEpochDay: Int? = null,
    val heightText: String = "",
    val weightText: String = "",
    val healthNotes: String = "",
    val isSaving: Boolean = false,
)
```

Derived (all tested — see §8):
- `step: OnboardingStep get() = steps.getOrElse(stepIndex) { Welcome }`
- `isLastStep: Boolean get() = stepIndex >= steps.lastIndex`
- `section: OnboardingSection?` (see mapping above)
- `stepCount: Int` — steps excluding Welcome ("How many steps actually ask the user something")
- `stepNumber: Int` — 1-based among collecting steps; 0 on Welcome
- `progress: Float` — `stepNumber / stepCount` (overall, never per-section)
- `canGoBack: Boolean` — `stepIndex > 0` ("Step 1 has nothing behind it: the flow can be stepped
  through, never escaped")
- `isSkippable: Boolean` — `step != Welcome && step != Sex` (Sex is the one hard gate)
- `showInvalidHeight / showInvalidWeight: Boolean` — non-blank text that fails
  `MeasurementInput.parseHeightCm / parseWeightKg` (valid ranges: height 50–250 cm, weight 20–400 kg)
- `canContinue: Boolean` — `!isSaving && when (step) { Sex -> sex != null; Height -> !showInvalidHeight; Weight -> !showInvalidWeight; else -> true }`

### Events (`OnboardingUiState.kt:103-121`)

```kotlin
sealed interface OnboardingEvent {
    data object NextClicked
    data object BackClicked
    data object SkipClicked          // clears whatever the current step collects and moves on
    data class NameChanged(val value: String)
    data class SexSelected(val sex: Sex)
    data class BirthDateSelected(val epochDay: Int)
    data class HeightChanged(val value: String)
    data class WeightChanged(val value: String)
    data class HealthNotesChanged(val value: String)
}
```

No Effect type — the flow ends by writing the completion flag, not by emitting navigation.

### ViewModel (`OnboardingViewModel.kt`)

```kotlin
class OnboardingViewModel(
    private val profileRepository: ProfileRepository,
    private val vitalsQuickEntry: VitalsQuickEntry,
    private val preferences: OnboardingPreferences,
    private val clock: SalusClock,
    includeNotificationStep: Boolean,
) : ViewModel()
```

- `onEvent(NextClicked) → advance()`: blocked if `!canContinue`; last step → `finish()`, else
  `stepIndex + 1`.
- `onEvent(BackClicked)`: `stepIndex = (stepIndex - 1).coerceAtLeast(0)`.
- `onEvent(SkipClicked)`: `clearCurrentStep()` then `advance()`. `clearCurrentStep` clears
  name/birthDateEpochDay/heightText/weightText/healthNotes (Welcome, Sex, Notifications unchanged).
- `finish()` (private): guards `isSaving`, sets it, then in `viewModelScope.launch`:
  1. **Profile write first, completion flag last** — "so a process death midway replays the flow
     instead of stranding a half-filled profile behind a closed gate":
     `profileRepository.saveProfile((existing ?: emptyProfile()).copy(displayName = name.trim(), sex, birthDate = epochDay → LocalDate.fromEpochDays, heightCm = parseHeightCm(heightText), healthNotes = trimmed.takeIf { it.isNotEmpty() }))`
  2. **Weight is a measurement, not a profile attribute:** `vitalsQuickEntry.recordWeight(kilograms, epochMs = clock.now().toEpochMilliseconds(), timeZoneId = clock.timeZone().id)` —
     "it lands in the vitals history so the weight chart starts from day one."
  3. `preferences.setCompleted()`.
- `emptyProfile()` guards a corrupted install: `Profile(id = SalusDatabase.DEFAULT_PROFILE_ID, ...,
  isDefault = true)`. (The row is seeded on database creation.)

### Preferences port

- `domain/OnboardingPreferences.kt`: `interface OnboardingPreferences { suspend fun setCompleted() }`
  ("Narrowing it to an interface … keeps the ViewModel testable without a real DataStore").
- `data/OnboardingPreferencesImpl.kt`: `dataSource.setOnboardingCompleted(true)` → DataStore key
  `KEY_ONBOARDING_COMPLETED = booleanPreferencesKey("onboarding_completed")` (defaults `false`).
- DI (`OnboardingModule.kt`): `single<OnboardingPreferences> { OnboardingPreferencesImpl(get()) }`
  + `viewModel { OnboardingViewModel(...) }`.

### Route wiring (`OnboardingScreen.kt:41-66`)

- `OnboardingRoute(viewModel = koinViewModel())` collects state.
- `BackHandler { if (state.canGoBack) viewModel.onEvent(OnboardingEvent.BackClicked) }` — "The
  flow can be stepped through but not escaped: back on the first step does nothing."
- Notification permission: `rememberLauncherForActivityResult(RequestPermission())` — result
  (grant **or** denial — "Denial is not a dead end — Reminder health stays the place to fix it
  later") always → `NextClicked`. On < API 33 → straight `NextClicked`.
- Full-screen gate: applies its own insets (`safeDrawingPadding + imePadding`) — "It is the app's
  only other inset owner" besides the shell.

### UI structure (per step)

- `OnboardingHeader` (all steps except Welcome): back IconButton, centred section title
  (`titleLarge`) over a `LinearProgressIndicator` (128×4 dp, clipped CircleShape, progress content
  description `onboarding_progress`), and a circular counter badge (32 dp, primary bg, onPrimary
  `onboarding_step_counter`, cleared from a11y semantics — "the bar next to it already announces
  the position").
- Footer: full-width `SalusPillButton` — label per step: Welcome → `onboarding_start`, Notifications
  → `onboarding_allow_notifications`, last step → `onboarding_finish`, else `onboarding_next`;
  enabled = `canContinue`; trailing icon: Notifications → `Icons.Filled.CheckCircle`, else
  `AutoMirrored.Filled.ArrowForward` ("Granting a permission is an act of consent, not another
  step; it gets a tick, not an arrow"). Below it, if `isSkippable`, a `TextButton` skip
  (`onboarding_skip`, or `onboarding_notifications_later` on Notifications), disabled while saving.
- Step bodies (`OnboardingStepContent.kt`):
  - **Welcome:** `CenteredStep(hero = OnboardingHeroVariant.Welcome, onboarding_welcome_title/body)`
  - **Name:** `CenteredStep` + `SalusPillTextField` (placeholder `onboarding_name_placeholder`,
    Words capitalization, autoCorrect off, ImeAction.Done, autofill `ContentType.PersonFullName`)
  - **Sex:** `LeadingStep` (icon `Icons.Outlined.Wc`) + one `SalusOptionRow` per `Sex.entries`
    (FEMALE → cycle accent + `Icons.Outlined.Female`, MALE → vitals accent + Male icon, OTHER →
    default accent + Transgender icon)
  - **BirthDate:** `CenteredStep` (icon Cake) + `SalusDateField` (placeholder `onboarding_birth_select`)
  - **Height:** `CenteredStep` (icon Height) + `MeasureField` (suffix "cm", error `onboarding_height_invalid`)
  - **Weight:** `CenteredStep` (icon MonitorWeight) + `MeasureField` (suffix "kg", error `onboarding_weight_invalid`)
  - **HealthNotes:** `CenteredStep` (icon EditNote) + `HealthNotesField` (240 dp tall Surface,
    `BasicTextField` with sentences capitalization, placeholder `onboarding_notes_placeholder`,
    `SalusStatusChip(onboarding_notes_private, Success, Icons.Filled.Lock)` at the bottom) + a
    `SalusCard` with Shield icon + `onboarding_notes_privacy_body` ("The chip states where the text
    ends up")
  - **Notifications:** `CenteredStep(hero = NotificationsVariant)` + `SalusCard` +
    `SalusListItem(icon = Verified, onboarding_notifications_benefit_title/body)`
- `OnboardingHero` (`OnboardingHero.kt`): decorative clusters, cleared from a11y —
  Welcome (rounded-square shield + inner circle + Shield icon) and Notifications (primary circle
  with Medication icon + satellite bell badge (tertiary) + heart badge (vitals accent)).
- 7 previews in `OnboardingScreen.kt` (one per step) + header/hero previews.

### Profile-name step

Yes — step 2 (`Name`), skippable (skipping blanks it), saved as `displayName` trimmed.

---

## §6 Onboarding strings (Android, `feature/onboarding/src/main/res/values/strings.xml` TR default + `values-en/`)

| Key | TR | EN |
|---|---|---|
| `onboarding_back` | Geri | Back |
| `onboarding_skip` | Şimdilik Atla | Skip for now |
| `onboarding_start` | Başla | Get started |
| `onboarding_next` | Devam Et | Continue |
| `onboarding_finish` | Bitir | Finish |
| `onboarding_allow_notifications` | İzin Ver | Allow |
| `onboarding_progress` | Adım %1$d / %2$d | Step %1$d of %2$d |
| `onboarding_step_counter` | %1$d/%2$d | %1$d/%2$d |
| `onboarding_section_personal` | Kişisel Bilgiler | Personal Details |
| `onboarding_section_notes` | Sağlık Notları | Health Notes |
| `onboarding_section_privacy` | Gizlilik Tercihleri | Privacy Preferences |
| `onboarding_welcome_title` | Salus'a Hoş Geldiniz | Welcome to Salus |
| `onboarding_welcome_body` | Sağlığınızı güvenle ve huzurla takip edebileceğiniz, gizliliğinizi merkeze alan kişisel alanınıza adım atın. | Step into a personal space built around your privacy, where you can follow your health calmly and with confidence. |
| `onboarding_name_title` | Adınız Nedir? | What is your name? |
| `onboarding_name_body` | Size nasıl hitap etmemizi istersiniz? | How would you like us to address you? |
| `onboarding_name_label` | Ad | Name |
| `onboarding_name_placeholder` | Örn: Ayşe | e.g. Ayşe |
| `onboarding_sex_title` | Cinsiyetinizi Seçin | Select your sex |
| `onboarding_sex_body` | Size en uygun sağlık deneyimini ve döngü takibini sunabilmemiz için bu bilgiye ihtiyacımız var. Verileriniz yalnızca bu cihazda saklanır. | We need this to tailor your health experience and cycle tracking. Your data is stored on this device only. |
| `onboarding_sex_female` | Kadın | Female |
| `onboarding_sex_male` | Erkek | Male |
| `onboarding_sex_other` | Diğer | Other |
| `onboarding_birth_title` | Doğum Tarihiniz | Your date of birth |
| `onboarding_birth_body` | Yaşınız bu tarihten hesaplanır; ayrıca saklanmaz. | Your age is derived from this date, never stored separately. |
| `onboarding_birth_select` | Tarih seçin | Pick a date |
| `onboarding_height_title` | Boyunuz Kaç cm? | How tall are you? |
| `onboarding_height_body` | Ölçümlerinizi yorumlarken kullanılır. | Used when putting your measurements in context. |
| `onboarding_height_label` | Boy | Height |
| `onboarding_height_placeholder` | Örn: 170 | e.g. 170 |
| `onboarding_height_invalid` | 50 ile 250 cm arasında bir değer girin. | Enter a value between 50 and 250 cm. |
| `onboarding_weight_title` | Kilonuz Kaç kg? | What do you weigh? |
| `onboarding_weight_body` | İlk ölçümünüz olarak kaydedilir ve kilo grafiğinizin başlangıcı olur. | Saved as your first measurement, so your weight chart starts today. |
| `onboarding_weight_label` | Kilo | Weight |
| `onboarding_weight_placeholder` | Örn: 70 | e.g. 70 |
| `onboarding_weight_invalid` | 20 ile 400 kg arasında bir değer girin. | Enter a value between 20 and 400 kg. |
| `onboarding_notes_title` | Ek Sağlık Notları | Extra health notes |
| `onboarding_notes_body` | Doktorunuzun bilmesini istediğiniz geçmiş rahatsızlıklar, alerjiler veya genel sağlık durumunuzla ilgili özel notlarınızı buraya ekleyebilirsiniz. | Add past conditions, allergies or anything else about your health that you want your doctor to know. |
| `onboarding_notes_label` | Notlar | Notes |
| `onboarding_notes_placeholder` | Örn: 2018'de hafif bir diz sakatlığı geçirdim. Bazen egzersiz sonrası ağrı yapıyor. Penisilin alerjim var. | e.g. I hurt my knee slightly in 2018. It aches after exercise. I am allergic to penicillin. |
| `onboarding_notes_private` | Yalnızca bu cihazda | On this device only |
| `onboarding_notes_privacy_body` | Sağlık notlarınız yalnızca bu cihazda saklanır; sağlık kayıtlarınız hiçbir sunucuya gönderilmez ve üçüncü taraflarla paylaşılmaz. Salus ağı yalnızca aboneliğinizi doğrulamak için ve — kullanırsanız — AI özellikleri için kullanır; AI özelliklerine yalnızca anonim istatistik özetleri gönderilir. | Your health notes are stored on this device only; your health records are never sent to a server and never shared with third parties. Salus uses the network only to verify your subscription and — if you use them — for the AI features, which only ever receive anonymous statistical summaries. |
| `onboarding_notifications_title` | Bildirim İzinleri | Notification permission |
| `onboarding_notifications_body` | İlaçlarınızı ve sağlık kontrollerinizi unutmamanız için size nazik hatırlatıcılar gönderelim. İzin vermezseniz uygulama çalışmaya devam eder; izni sonradan Daha Fazla › Hatırlatıcılar bölümünden verebilirsiniz. | Let us send you gentle reminders so you do not forget your medications and health check-ups. If you decline, the app keeps working — you can grant it later under More › Reminders. |
| `onboarding_notifications_benefit_title` | Zamanında Hatırlatma | On-time reminders |
| `onboarding_notifications_benefit_body` | Asla bir dozu kaçırmayın. | Never miss a dose. |
| `onboarding_notifications_later` | Daha Sonra | Later |

54 keys total. Placeholder conversion for iOS per CLAUDE.md: `%1$d` → `%1$lld`,
`%2$d` → `%2$lld` (`onboarding_progress`, `onboarding_step_counter`).

---

## §7 Lock strings (Android)

App module (`app/src/main/res/values{,-en}/strings.xml:11-13`) — see table in §2:
`app_lock_locked_title`, `app_lock_unlock`, `app_lock_prompt_title`.

Settings feature (see §2 table): `settings_app_lock`, `settings_app_lock_desc`,
`settings_app_lock_unavailable`, `settings_app_lock_confirm_title`, `settings_secure_screen`,
`settings_secure_screen_desc`, plus section label `settings_section_security`.

---

## §8 Tests owed (Android test inventory to port)

### `app/src/test/.../lock/AppLockManagerTest.kt` (7 tests, `@OptIn(ExperimentalTime::class)`)

Setup: `MutableClock : SalusClock` (advanceable), `owner: LifecycleOwner` (lifecycle throws — not
used), `enabled = MutableStateFlow(true)`, `manager = AppLockManager(appLockEnabled = enabled, clock = clock)`.

1. `cold start is locked when the setting is on` — onStart → isLocked true
2. `never locks while the setting is off` — enabled=false → onStart → isLocked false
3. `unlock clears the gate` — onStart, unlock → isLocked false
4. `short background stay keeps the session unlocked` — unlock, onStop, advance(LOCK_TIMEOUT − 1s),
   onStart → isLocked false
5. `exceeding the timeout in the background re-locks` — unlock, onStop, advance(LOCK_TIMEOUT + 1s),
   onStart → isLocked true
6. `disabling the setting while locked unlocks immediately` — locked, enabled=false → isLocked false

(7 listed in file: actually 6 @Test methods — count verified from the source: `cold start…`,
`never locks…`, `unlock clears…`, `short background…`, `exceeding the timeout…`, `disabling the
setting…`.)

### `feature/onboarding/src/test/.../OnboardingUiStateTest.kt` (6 tests)

1. `welcome has no section` — `stateAt(Welcome).section == null`
2. `every step maps to its section` — asserts the full step→section map (Name/Sex/BirthDate/
   Height/Weight → PersonalDetails, HealthNotes → HealthNotes, Notifications → Privacy)
3. `welcome is outside the counter` — stepNumber 0, progress 0
4. `the counter runs one to seven over the collecting steps` — Name: stepCount 7, stepNumber 1;
   Notifications: stepNumber 7, progress 1
5. `progress never goes backwards across the flow` — zipWithNext strictly increasing
6. `a shortened step list still counts to its own end` — 3-step flow (Welcome, Name, Sex) at
   index 2 → stepCount 2, stepNumber 2, progress 1

### `feature/onboarding/src/test/.../OnboardingViewModelTest.kt` (7 tests)

Fakes: `FakeProfileRepository` (MutableStateFlow<Profile?>, seeded "default-profile"),
`FakeVitalsQuickEntry` (records Triple<Double, Long, String>), `FakeOnboardingPreferences`
(completed flag), `FixedSalusClock(now = 1_750_000_000_000 ms, TimeZone "Europe/Istanbul")`,
`MainDispatcherRule`. Helper `goTo(target)` walks forward answering Sex when needed.

1. `the notification step is dropped below API 33` — includeNotificationStep=false excludes
   Notifications from steps; true includes it
2. `sex is the one hard gate` — at Sex: canContinue false + isSkippable false; NextClicked stays
   put; SexSelected(FEMALE) + Next → BirthDate
3. `back on the first step is a no-op` — BackClicked at index 0 → stepIndex 0, canGoBack false
4. `an unusable measurement blocks the step but a blank one does not` — HeightChanged("7") →
   showInvalidHeight + !canContinue; HeightChanged("") → canContinue
5. `skipping clears what the step collected` — NameChanged("Ada"), SkipClicked → name "" and
   step Sex
6. `finishing writes the profile, the first weight and the completion flag` — full happy walk
   (name "  Ada  " trimmed, FEMALE, birth 1990-06-15, height 170, weight "72,4" — Turkish comma,
   notes "Pollen allergy") → saved profile fields + `vitals.recorded.single() == (72.4, nowMs,
   "Europe/Istanbul")` + preferences.completed
7. `a skipped weight writes no measurement and blank notes stay null` — no vitals record,
   healthNotes null, completed true

### Settings-side tests touching lock (already ported to iOS — for reference)

`MoreViewModelTest.kt:182, 191, 246, 250-251`: loading appLockEnabled/secureScreenEnabled into
state, `SetAppLock(true)` → `preferences.appLockEnabled.value == true`.

---

## §9 iOS current state

### App entry flow — no gates exist yet

- `App/SalusApp.swift` (84 l): `@main`, builds `AppCompositionRoot` in `init`, `startReminderEngine()`,
  `WindowGroup { RootView().environment(compositionRoot) }` + `onChange(of: scenePhase)` —
  `.active → reminderDidBecomeActive()`, `.background → commitPendingDeletes()` (inside a
  `beginBackgroundTask`). **No splash-hold, no onboarding gate, no lock overlay.**
- `App/RootView.swift` (350 l): five-tab `TabView` shell. More tab root is `PlaceholderScreen`
  with `TODO(M8)`: "the settings hub replaces this placeholder. Until it lands the tab's root
  carries the two rows this and the last milestone need" (Reminder Health + cycle calendar).
  **No onboarding/lock overlays; theme observed from `root.preferences.userSettings`.**
- `App/PlaceholderScreen.swift`, `App/RootTab.swift` exist; no lock/onboarding views anywhere in `App/`.

### KeychainAppLockFlagStore — already shipped (iOS-M1)

`Packages/SalusSettings/Sources/SalusSettings/KeychainAppLockFlagStore.swift` (79 l):
- `public struct KeychainAppLockFlagStore: AppLockFlagStore`, `public static let service =
  "com.alicansekban.salus"`, `public init() {}`
- `read() -> Bool`: `SecItemCopyMatching` (kSecReturnData, kSecMatchLimitOne); absent item **or
  any failure reads as false** — "a lock that cannot be confirmed must not be claimed" (the Kotlin
  `?: false`). Value is one byte: `flag == 1`.
- `write(_ enabled: Bool)`: `SecItemUpdate` first, `SecItemAdd` only on `errSecItemNotFound`
  (add-or-update, no absent-flag window). Value `Data([enabled ? 1 : 0])`, accessibility
  `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, `kSecUseDataProtectionKeychain: true`.
- Item shape (persistence contract): class `kSecClassGenericPassword`, service
  `com.alicansekban.salus`, account `SettingsKeys.appLockEnabled` (= `"app_lock_enabled"`).
- **Not unit-tested on purpose** (entitlement-host problem); `InMemoryAppLockFlagStore` fake lives
  in `AppLockFlagStore.swift:30-50`.

`Packages/SalusSettings/Sources/SalusSettings/AppLockFlagStore.swift` (50 l):
- `public protocol AppLockFlagStore: Sendable { func read() -> Bool; func write(_ enabled: Bool) }`
  — synchronous, non-throwing ("they mirror `preferences[KEY_APP_LOCK_ENABLED]`, which cannot fail
  either. A Keychain that will not answer reads as 'locked off'").
- `InMemoryAppLockFlagStore` (NSLock-guarded, `init(enabled: Bool = false)`).

### Preferences wiring — already shipped

`Packages/SalusSettings/Sources/SalusSettings/SalusPreferencesDataSource.swift`:
- `public init(defaults: UserDefaults = .standard, appLockFlagStore: any AppLockFlagStore)`
- `setAppLockEnabled(_ enabled: Bool)` → `appLockFlagStore.write(enabled)` — **never lands in
  UserDefaults**; `setSecureScreenEnabled` / `setOnboardingCompleted` are normal UserDefaults
  writes under keys `secure_screen_enabled` / `onboarding_completed`.
- `read(from:appLockFlagStore:)` composes `UserSettings(appLockEnabled: appLockFlagStore.read(), …)`.
- `SettingsKeys`: `appLockEnabled = "app_lock_enabled"`, `secureScreenEnabled =
  "secure_screen_enabled"`, `onboardingCompleted = "onboarding_completed"` (all Android-verbatim).

`App/AppCompositionRoot.swift`: `appLockFlagStore = KeychainAppLockFlagStore()` at line 303, exposed
as `let appLockFlagStore: any AppLockFlagStore` (line 60) and injected into
`SalusPreferencesDataSource(defaults: .standard, appLockFlagStore:)` (line 312). Also:
- `vitalsQuickEntry` computed property (line 163) exists explicitly for "onboarding's current
  weight step (M6)" — the M8 onboarding `finish()` can use `root.vitalsQuickEntry`.
- `profileRepository`, `clock`, `preferences` all exposed on the root.

Pinning tests already present:
- `SalusPreferencesDataSourceTests.appLockFlagBypassesUserDefaults` (flag never in UserDefaults),
  `appLockFlagIsReadFromTheFlagStore`
- `SettingsKeysTests` pins `app_lock_enabled` etc.

### UserSettings model — already ported

`Packages/SalusModel/Sources/SalusModel/Settings.swift`: `UserSettings` with `appLockEnabled`,
`secureScreenEnabled` (doc comment: "On Android this sets `FLAG_SECURE`. On iOS it is the
*masking* toggle of spec §6.2 — the app-switcher blur is always on, and this adds screenshot
masking on top of it"), `onboardingCompleted`, all Kotlin defaults. `VocabularyTests.swift:153-154`
pin the false defaults.

### FeatureOnboarding package — skeleton only

`Packages/Features/FeatureOnboarding/`: `Package.swift` (deps per manifest; no Feature→Feature
edges), `FeatureOnboarding.swift` = `public enum FeatureOnboardingModule { public static let name =
"FeatureOnboarding" }` namespace placeholder, one placeholder test (`FeatureOnboardingModuleTests`).
No UiState/ViewModel/Screen/strings exist yet. `.build/` shows SalusProfile + SalusDesignSystem
already resolve as transitive deps.

### FeatureSettings package — Reminder Health only

`Packages/Features/FeatureSettings/Sources/FeatureSettings/`: `SettingsModule.swift`,
`SettingsStrings.swift`, `navigation/SettingsNavigation.swift`, `ui/reminderhealth/*`
(ViewModel/Screen/UiState/LastSync). **No More hub, no lock/secure toggles yet.** `RootView`'s
More tab still shows `PlaceholderScreen` with the M8 TODO.

### Info.plist / project.yml — nothing lock-related

`App/Info.plist`: BGTaskSchedulerPermittedIdentifiers, CFBundle*, NSAlarmKitUsageDescription,
scene manifest, UIBackgroundModes [fetch], UILaunchScreen (empty dict), portrait orientations.
**No NSFaceIDUsageDescription yet** — the iOS port will need it for the LocalAuthentication
biometric prompt (spec: biometrics come from the system, dependency allowlist stays at three).

### iOS-specific spec decisions already recorded (CLAUDE.md / code comments)

- **§6.2 secure screen:** "always-on app-switcher blur plus a *masking* toggle, never worded as an
  absolute screenshot block" — the blur (app switcher) is always on; `secure_screen_enabled` adds
  screenshot masking. Not a raw FLAG_SECURE port.
- **Keychain rule:** "The Keychain holds exactly one thing: `app_lock_enabled` … Never move a
  second setting there."
- **Persisted keys Android-verbatim** (13 listed, incl. `onboarding_completed`,
  `app_lock_enabled`, `secure_screen_enabled`).
- Placeholder conversion: `%1$s` → `%1$@`, `%1$d` → `%1$lld`.
- String catalogs: one `Localizable.xcstrings` per package + `StringCatalogParity` tests
  (tr source language, both locales present, key-set pinned from the Android XML).

### What M8 must build on iOS (gap list)

1. **AppLockManager twin** (state machine + 30 s background grace, injectable clock — the
   `AppLockManagerTest` table ports directly) — but the lock flag is read from
   `SalusPreferencesDataSource.userSettings` / `appLockFlagStore` rather than a DataStore flow.
2. **AppLockScreen twin** — icon badge + `app_lock_locked_title` + `app_lock_unlock` pill button,
   auto-prompt on entry, LocalAuthentication (`LAContext.evaluatePolicy(.deviceOwnerAuthentication`)
   ≈ BIOMETRIC_WEAK or DEVICE_CREDENTIAL) as the retry; strings to `App/Localizable.xcstrings`
   (app target already has one since iOS-M6).
3. **Onboarding gate + flow** — FeatureOnboarding UiState/ViewModel/Screen/Header/Hero/StepContent
   port (8 steps, Sex hard gate, skip-clears semantics, finish-writes-profile-then-flag), strings
   catalog with parity tests, `OnboardingUiStateTest`/`OnboardingViewModelTest` tables ported.
4. **Gate wiring in SalusApp/RootView** — splash-hold equivalent (`onboardingCompleted == nil`),
   overlay order (onboarding outermost, lock beneath), deep links preserved.
5. **Settings hub (More tab)** — replaces PlaceholderScreen; Security section with app-lock toggle
   (availability check + re-auth-to-enable via LocalAuthentication) and the §6.2 masking toggle.
6. **Secure screen (iOS shape)** — always-on app-switcher blur (scenePhase-based overlay /
   `UIScreen.isCaptured` handling is an implementation decision for the plan) + screenshot
   masking toggle backed by `secure_screen_enabled`.
7. **Info.plist**: add `NSFaceIDUsageDescription` for biometrics.