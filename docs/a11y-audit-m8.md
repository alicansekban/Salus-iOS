# iOS-M8 accessibility audit — the VoiceOver + Dynamic Type pass

The Task 14 worksheet. A per-surface walk of every M8 screen plus a sweep of the six existing
surfaces, against two rules: **VoiceOver** (every control labelled, decoratives hidden, focus order
follows draw order) and **Dynamic Type at AX5 with Turkish strings** (the longest TR value drives
layout, no fixed height or fixed line count that clips what Android wraps).

The executor's half is **code only** — label/trait/hiding declarations, verified by build, lint and
the existing tests. The rotor walk, the focus-order check and the AX5-TR layout inspection are the
user's, written as `scripts/m8-manual-qa.md` §6 rows and never run here.

A **FIXED** row has a code change in this commit. A **DEFERRED** row is a finding on an existing
surface or a structural/layout rework that this milestone deliberately leaves alone, with a note
saying why and where it belongs.

---

## M8 screens

### More hub + the three selection dialogs (`ui/more/`)

| # | Finding | Verdict | Where |
|---|---------|---------|-------|
| M-1 | The `MoreToggleCard`'s `Switch` is announced as an unnamed "switch": `Toggle("", …)`. The whole card is the tappable affordance (the `Switch`'s own `onCheckedChange` is wired through the card's tap), and the row's text is what it toggles. | **FIXED** — `.accessibilityLabel(title)` on the `Toggle`. The card's `title` is already the row's spoken text, so VoiceOver reads the toggle as "Uygulama kilidi" / "Güvenli ekran" rather than an empty control. Android's `Switch` reads the enclosing card's semantics the same way (`MoreScreen.kt:409-449`). | `MoreScreenComponents.swift:84-95` |
| M-2 | The app-lock `Toggle` is **disabled** when `LAContext` cannot evaluate `.deviceOwnerAuthentication` (`appLockAvailable`). A disabled switch is correctly announced as such by VoiceOver, but no row text explains why. | **DEFERRED** — the Kotlin shows the same disabled switch with no explanatory string (`MoreScreen.kt:258-279`). Adding copy needs a new catalog key; not this task. | `MoreScreen.swift` |
| M-3 | All `Text` through `SalusSectionHeader` / `SalusScreenHeader` / `SalusPillButton` / `MoreSelectionDialog` already uses `Text(verbatim:)`; the shared components themselves did not. | **FIXED (shared)** — see S-1. | shared |
| M-4 | The three sheet dialogs' `SalusOptionRow`s already carry `.isSelected` / `.isButton` traits and hidden icon/indicator (`SalusOptionRow.swift`), and the `footnote` already resolves verbatim. | No finding | — |

### Profile (`ui/profile/`)

| # | Finding | Verdict | Where |
|---|---------|---------|-------|
| P-1 | The three sex `SalusOptionRow`s carry the radio role + selectable trait; `SalusIconBadge` and the chevron are decorative-hidden. The toolbar Save button is a real `Button` (`profileSave`), the name/height/notes fields are `SalusPillTextField` (a real text field), the date field is `SalusDateField` with an a11y title. | No finding | `ProfileScreen.swift` |
| P-2 | The inline `Text` `change.inlineMessage` (`profileSexCycleAppears`/`profileSexCycleDisappears`) is already `Text(verbatim:)`. | No finding | `ProfileScreen.swift:189` |

### About (`ui/about/`)

| # | Finding | Verdict | Where |
|---|---------|---------|-------|
| A-1 | `about_privacy_body` (the longest TR value on the screen) wraps in a `SalusCard` with no fixed height and no `lineLimit`, exactly as Android's `Text` wraps. | No finding (verified) | `AboutScreen.swift:70` |

### Onboarding ×8 steps (already wired by T8 — checked for the T14 bar, not re-done)

| # | Finding | Verdict | Where |
|---|---------|---------|-------|
| O-1 | The counter badge is `.accessibilityHidden(true)` (T8); the progress bar carries `onboarding_progress`; the back button carries `onboarding_back` (H-8). | Already shipped | `OnboardingHeader.swift` |
| O-2 | The hero cluster (Welcome/Notifications pictures) is `.accessibilityHidden(true)`, exactly the M7 sparkline precedent. | Already shipped | `OnboardingHero.swift` |
| O-3 | Steps 2,5,6,7,8 all carry `.lineLimit(nil)` on their title/body/benefit texts; `onboarding_notifications_body` (the longest TR value) wraps with no fixed height. | No finding (verified) | `OnboardingStepContent.swift` |
| O-4 | The step-title texts in the header carry `.lineLimit(nil)`, so a long localized section title cannot clip. | Already shipped | `OnboardingHeader.swift:82` |

### App lock (`App/Lock/`)

| # | Finding | Verdict | Where |
|---|---------|---------|-------|
| L-1 | The screen's title (`AppLockScreen` `appLockLockedTitle`) is the first thing VoiceOver reads on the gate — the gate announces itself. The Unlock button is a real `SalusPillButton`. The badge is `SalusIconBadge` (hidden by the component). | No finding (verified) | `AppLockScreen.swift` |
| L-2 | The title uses `.multilineTextAlignment(.center)` and no `lineLimit`, so a long TR lock title wraps. | No finding (verified) | `AppLockScreen.swift:60` |

### Secure screen (`App/PrivacyOverlay.swift`)

| # | Finding | Verdict | Where |
|---|---------|---------|-------|
| S-0 | The curtain is one combined element (`.accessibilityElement(children: .combine)`), read as the app name. The `SecureScreenMask`'s full-screen `UITextField` has `isAccessibilityElement = false` so it never takes VoiceOver focus (the C-1 fix comment documents it). | Already shipped | `PrivacyOverlay.swift` |
| S-1 | **Shared-component `Text(_:)` on resolved strings.** `SalusSectionHeader`, `SalusScreenHeader`, `SalusPillButton`, `SalusConfirmDialog` and `SalusSnackbarHost` all passed their `String` parameter to `Text(_:)`, which reads it back as a `LocalizedStringKey` against the **main** bundle and can silently render the key instead of the value. This affects every M8 screen (More/Profile/About use `SalusSectionHeader` + `SalusScreenHeader` + `SalusPillButton`, and the app-lock uses `SalusPillButton`). | **FIXED** — all five now use `Text(verbatim:)`, with a comment citing the M7 `c726e22` finding. | `SalusScreenHeader.swift`, `SalusSectionHeader.swift`, `SalusPillButton.swift`, `SalusConfirmDialog.swift`, `SalusSnackbarHost.swift` |

---

## Existing-surface sweep (the six surfaces)

Every surface is listed; "no finding" rows are still an audit result.

### Home (`FeatureHome`)

| # | Finding | Verdict | Where |
|---|---------|---------|-------|
| H-1 | The sparkline is `.accessibilityHidden(true)` (inside `SalusSparkline`); tap-cards combine into a button with a default action. | Already shipped | `SalusSparkline.swift`, `HomeScreen.swift` |
| H-2 | `HomeHeader`'s greeting (`HomeStrings.greeting(_:)`) renders through `Text(_:)`. | **DEFERRED** — pre-existing on an M6 surface; `HomeStrings.greeting` resolves a localized format string and the M7 record already accepted the verbatim sweep as out of scope for M8 (the `Text(verbatim:)` rule applies to lines this task touches). Flagged for the whole-branch verbatim sweep. | `HomeHeader.swift:36` |

### Vitals (`FeatureVitals`: list + 3 editors)

| # | Finding | Verdict | Where |
|---|---------|---------|-------|
| V-1 | List rows combine into a button with default action; the row headline/date/supporting/note texts render `Text(verbatim:)` (the M7 fix already landed here). | Already shipped | `VitalsListSections.swift` |
| V-2 | The `Picker` segment labels (`.tag`) are `Text` inside a `Picker` — correctly labelled by SwiftUI. | No finding | `VitalsScreen.swift`, `VitalsListSections.swift` |
| V-3 | The three editors' text rows (`entry.headline`, `entry.measuredAt.formatted…`) render via `Text(_:)` in `VitalsListSections`. | **DEFERRED** — pre-existing M2 surface; same verbatim-sweep bucket as H-2. | `VitalsListSections.swift:205,208` |

### Medications (`FeatureMedications`: list/detail/editor)

| # | Finding | Verdict | Where |
|---|---------|---------|-------|
| ME-1 | `MedicationCard` combines into a button with default action; the `recordedDoses`/reminder texts and detail rows render `Text(verbatim:)`. | Already shipped | `MedicationCard.swift` |
| ME-2 | `MedicationDetailSections` renders `medication.name`, `subtitle`, `when(item)`, `label`, `value` through `Text(_:)`. | **DEFERRED** — pre-existing M5 surface; same bucket. | `MedicationDetailSections.swift` |

### Appointments (`FeatureAppointments`: list/detail/editor)

| # | Finding | Verdict | Where |
|---|---------|---------|-------|
| AP-1 | List rows combine into a button with default action; detail/list decorative icons are `.accessibilityHidden(true)`. | Already shipped | `AppointmentsScreen.swift`, `AppointmentDetailScreen.swift` |
| AP-2 | Detail renders `appointment.title`, `appointment.startsAt.formatted…`, `healthNotes` via `Text(_:)`. | **DEFERRED** — pre-existing M4 surface; same bucket. | `AppointmentDetailScreen.swift` |

### Cycle (`FeatureCycle`: calendar/log)

| # | Finding | Verdict | Where |
|---|---------|---------|-------|
| C-1 | Calendar day cells carry an explicit `accessibilityLabel`; the summary row combines with a label; the disabled future-press decoration is hidden. | Already shipped | `CycleCalendarSections.swift` |
| C-2 | `CycleSummarySections`/detail render `predictionText`, `text` values, day numbers (`dayNumber(_:)`) via `Text(_:)`. | **DEFERRED** — pre-existing M6 surface; same bucket. | `CycleSummarySections.swift`, `CycleDayScreen.swift` |

### Reminder Health (`FeatureSettings` — reminder-health screens, in the M8 scope)

| # | Finding | Verdict | Where |
|---|---------|---------|-------|
| R-1 | The verdict line passes `reminderHealthAllOk`/`reminderHealthIntro` through `Text(_:)`. | **FIXED** — `Text(verbatim:)`. | `ReminderHealthScreen.swift:124` |
| R-2 | The honesty line passes `ReminderHealthLastSync.line(_:_:)` (a resolved formatted string) through `Text(_:)`. | **FIXED** — `Text(verbatim:)`. | `ReminderHealthScreen.swift:171` |
| R-3 | The health-card `title`/`description` and the fix button pass resolved strings through `Text(_:)`. | **FIXED** — `Text(verbatim:)` on all three. | `ReminderHealthScreen.swift:213,217,229` |

---

## Deferred rows, consolidated

The M8 record's deferred list. These are pre-existing `Text(_:)` on resolved strings across the six
M2–M6 surfaces (H-2, V-3, ME-2, AP-2, C-2), all same-bucket; they render the `Strings` enum values
that ARE the fallback `LocalizedStringKey` for Turkish/English, so the visible defect only appears on
a device set to a **third** locale, and fixing them is a mechanical verbatim sweep across files this
milestone does not otherwise touch. They belong to a whole-branch sweep (M16's record keeps the
verbatim rule; these are the rows it will pick up).

**Deferred by design, not forgotten:**

| Row | Why deferred |
|-----|--------------|
| M-2 app-lock disabled-switch copy | Needs a new catalog key; Android has none. |
| H-2, V-3, ME-2, AP-2, C-2 verbatim sweep | Pre-existing surfaces; mechanical, same-class, cross-milestone. |

## What the executor did NOT check

The rotor walk, the focus-order check and the AX5-with-Turkish layout inspection are **the user's**
(standing ruling: executors run zero simulator work). They are written as `scripts/m8-manual-qa.md`
§6 rows and listed there. Every row in §6 is **NOT RUN**.
