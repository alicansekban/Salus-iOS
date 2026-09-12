// Ported from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// ui/editor/VitalsEditorChrome.kt` — the frame the three vitals editors share, plus the three text
// helpers their steppers read and write through (`:87-103`).
//
// It replaces `VitalsEditorField.swift`, the hand-drawn `OutlinedTextField` stand-in the M2 editors
// used: M15 types every number through `SalusStepperField` and every free text through
// `SalusTextField`, so there is nothing left for a bespoke field to do.
//
// Compose → SwiftUI, and the two places the frame is not literally Kotlin's:
//   `SalusTopBar.Pushed(title:subtitle:actions:)` → `.navigationTitle` + `.navigationBarTitleDisplayMode(.inline)`
//                                                   plus a trailing `ToolbarItem` "Kaydet" button
//                                                   tinted `primary` (spec §2.2). The subtitle
//                                                   Android draws under the pushed title moves into
//                                                   the content's first row, which is the same §2.2
//                                                   rule; `onBack` has no twin at all, because the
//                                                   stack already draws the back button that pops
//                                                   the very `NavigationPath` `Navigator.pop()`
//                                                   mutates.
//   `Column(verticalScroll)` + bottom `SalusButton` → `ScrollView` + a `SalusButton` pinned under
//                                                   it, in the same order.
//
// Each editor is type-specific. The type is chosen on the list, before the editor is pushed, and
// never changes inside it: switching type mid-form can only be expressed as a pop and a push, which
// animates as if a new screen were being opened every time the user taps a segment
// (`VitalsEditorChrome.kt:30-34`).

import Foundation
import SalusDesignSystem
import SalusUI
import SwiftUI

/// The frame the three vitals editors share (`VitalsEditorChrome.kt:38-85`): the scrolling body,
/// the subtitle that heads it, the tip that closes it and the two ways to save.
///
/// Only the fields differ between the three screens, so only the fields live in `content`.
struct VitalsEditorChrome<Content: View>: View {
    let isEdit: Bool
    let saveEnabled: Bool
    let onSave: () -> Void
    @ViewBuilder let content: Content

    @Environment(\.salusTheme) private var theme

    var body: some View {
        // No `Scaffold` twin and no inset modifier: the app shell owns the one navigation stack
        // and its insets (`VitalsEditorChrome.kt:35-37`).
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: SalusSpacing.lg) {
                    // Android draws this under the pushed title; §2.2 moves a pushed screen's
                    // subtitle into the content's first row.
                    Text(verbatim: VitalsStrings.editorSubtitle)
                        .font(SalusTypography.bodyMedium.font)
                        .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    content

                    SalusInfoNote(text: VitalsStrings.editorTip, systemImage: "lightbulb")
                }
                .padding(.horizontal, SalusSpacing.lg)
                .padding(.vertical, SalusSpacing.lg)
            }
            // A `ScrollView` is transparent, so the token ground shows through from the outer
            // container — the shape `MedicationEditorScreen` carries.
            .scrollDismissesKeyboard(.interactively)

            // `SalusButton(vitals_save_measurement, accent = salusColors.vitals)`
            // (`VitalsEditorChrome.kt:75-83`) — the screen's single emphasised action, which is
            // why the bar action above it is a plain text button on both platforms.
            SalusButton(
                VitalsStrings.saveMeasurement,
                accent: theme.extendedColors.vitals,
                enabled: saveEnabled,
                action: onSave
            )
            .padding(SalusSpacing.lg)
        }
        .salusDismissesKeyboardOnTap()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colorScheme.background)
        .navigationTitle(
            Text(verbatim: isEdit ? VitalsStrings.editorTitleEdit : VitalsStrings.editorTitleNew)
        )
        .toolbar {
            // `.primaryAction`, not `.topBarTrailing`: spec §2.2 names the trailing slot by its
            // iOS spelling, but `ToolbarItemPlacement.topBarTrailing` is iOS-only API and every
            // feature package also builds for the macOS test host. `.primaryAction` resolves to
            // exactly that slot on iOS, compiles on both, and is what every other pushed screen in
            // this tree uses (`MedicationDetailScreen.swift:19-24`).
            ToolbarItem(placement: .primaryAction) {
                // `TextButton(onClick = onSave, enabled = saveEnabled)`
                // (`VitalsEditorChrome.kt:56-61`) — a plain `Button`, the §2.2 rule for every
                // pushed screen's trailing text action. The `primary` tint is inherited: the
                // shell tints the whole `TabView` (`RootView.swift`), so a per-site `.tint` is a
                // second place the same colour could drift.
                Button(action: onSave) {
                    Text(verbatim: VitalsStrings.save)
                }
                .disabled(!saveEnabled)
            }
        }
        // LAST in the chain, and `#if os(iOS)` because the modifier is iOS-only API while every
        // feature package also builds for the macOS test host (CLAUDE.md's `.macOS(.v14)`
        // concession). Last because SwiftFormat indents whatever follows an `#endif` one level
        // deeper, which reads as if those modifiers were inside the guard.
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Stepper text

/// Reads an editor's text back as a number for its stepper (`VitalsEditorChrome.kt:87-93`).
///
/// The steppers never own the value — they read and write the same text state the ViewModels
/// already validate — so an empty or half-typed field simply starts the stepper at `fallback`.
func stepperValue(of text: String, fallback: Double) -> Double {
    Double(text.replacingOccurrences(of: ",", with: ".")) ?? fallback
}

/// Writes a stepper's value back in the canonical form the ViewModels parse: a dot decimal
/// separator regardless of the display locale, rounded so 0.1 steps cannot accumulate float noise
/// into the saved string (`VitalsEditorChrome.kt:95-100`).
func editorDecimalText(_ value: Double) -> String {
    String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), value)
}

/// The whole-number counterpart of ``editorDecimalText(_:)``, for mmHg, bpm and mg/dL
/// (`VitalsEditorChrome.kt:102-103`).
func editorWholeText(_ value: Double) -> String {
    String(Int(value.rounded()))
}

/// The value one − or + tap lands on, clamped into `range` on the way
/// (`SalusStepperField.kt:53-54` bounds the Compose component itself; the iOS twin owns no
/// arithmetic, so every caller applies the step and the bounds — the caller contract
/// `SalusStepperField.swift` writes down).
func nudgedStepperValue(
    from text: String,
    fallback: Double,
    by step: Double,
    in range: ClosedRange<Double>
) -> Double {
    let current = stepperValue(of: text, fallback: fallback)
    return min(range.upperBound, max(range.lowerBound, current + step))
}

/// The answer a caller owes every `onValueChange`: the typed number, clamped into `range`
/// (`SalusStepperField.swift`, "answer it by accepting or clamping and re-emitting"). Text the
/// parser cannot read is not a proposal at all and is handed straight back, which is how a cleared
/// field stays cleared.
func clampedStepperText(_ text: String, in range: ClosedRange<Double>) -> Double? {
    guard let typed = Double(text.replacingOccurrences(of: ",", with: ".")) else { return nil }
    return min(range.upperBound, max(range.lowerBound, typed))
}
