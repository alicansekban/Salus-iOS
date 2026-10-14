// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/sheet/
// GoalSheet.kt`.
//
// Names a savings goal and sets its target. It opens at the goal being edited, or empty for a first
// or a next goal; an editing sheet keeps what was saved toward the goal (contract §8.17, parity
// D-M17-ae) and says so in a note, while a new goal needs none. The amount is typed in whole units
// of the plan's currency and handed to `onSave` in minor units. "Kaydet" is off until both fields
// are valid and while a write is in flight; a swipe away writes nothing.
//
// Compose → SwiftUI: `SalusTextField(keyboardOptions = Decimal)` → `SalusTextField(keyboard:
// .decimal)`; `rememberSaveable` → `@State`; `SalusInfoNote(tone = Neutral)` → the same, with its
// icon named, since an SF Symbol has no default.

import SalusDesignSystem
import SalusUI
import SwiftUI

/// The longest name a goal may have.
let goalTitleMax = 40

/// `amountText` as a target in minor units, or `nil` when it is not an amount above zero.
func goalTargetMinor(amountText: String, fractionDigits: Int) -> Int64? {
    parseMinorUnits(amountText, fractionDigits: fractionDigits).flatMap { $0 > 0 ? $0 : nil }
}

func isGoalFormValid(title: String, amountText: String, fractionDigits: Int) -> Bool {
    !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && goalTargetMinor(amountText: amountText, fractionDigits: fractionDigits) != nil
}

func limitGoalTitle(_ title: String) -> String {
    String(title.prefix(goalTitleMax))
}

private enum GoalSheetSymbols {
    static let note = "info.circle"
}

/// The body of the goal sheet, with its own state.
struct GoalSheet: View {
    let currencyCode: String
    let editing: Bool
    let writing: Bool
    let onSave: (String, Int64) -> Void

    @State private var title: String
    @State private var amount: String

    init(
        currencyCode: String,
        initialTitle: String,
        initialTargetMinor: Int64?,
        editing: Bool,
        writing: Bool,
        onSave: @escaping (String, Int64) -> Void
    ) {
        self.currencyCode = currencyCode
        self.editing = editing
        self.writing = writing
        self.onSave = onSave
        _title = State(initialValue: limitGoalTitle(initialTitle))
        _amount = State(
            initialValue: initialTargetMinor.map {
                plainAmount(minor: $0, fractionDigits: fractionDigits(ofCurrency: currencyCode))
            } ?? ""
        )
    }

    var body: some View {
        GoalSheetContent(
            title: $title,
            amountText: $amount,
            currencyCode: currencyCode,
            editing: editing,
            writing: writing,
            onSave: {
                let target = goalTargetMinor(
                    amountText: amount,
                    fractionDigits: fractionDigits(ofCurrency: currencyCode)
                )
                if let target {
                    onSave(title.trimmingCharacters(in: .whitespacesAndNewlines), target)
                }
            }
        )
        // The name is held to its limit as it is typed, not when it is saved.
        .onChange(of: title) { _, new in
            let limited = limitGoalTitle(new)
            if limited != new {
                title = limited
            }
        }
        .interactiveDismissDisabled(writing)
    }
}

/// The sheet's body without its state, so a preview can draw every case.
struct GoalSheetContent: View {
    @Binding var title: String
    @Binding var amountText: String
    let currencyCode: String
    let editing: Bool
    let writing: Bool
    let onSave: () -> Void

    @Environment(\.locale) private var locale
    @Environment(\.salusTheme) private var theme

    var body: some View {
        let digits = fractionDigits(ofCurrency: currencyCode)
        // An empty field is not yet wrong; only text that cannot be a target is.
        let amountInvalid = !amountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && goalTargetMinor(amountText: amountText, fractionDigits: digits) == nil

        VStack(alignment: .leading, spacing: SalusSpacing.md) {
            SalusTextField(
                text: $title,
                label: SmokingStrings.goalSheetNameLabel,
                placeholder: SmokingStrings.goalSheetNamePlaceholder,
                capitalization: .sentences
            )
            SalusTextField(
                text: $amountText,
                label: SmokingStrings.goalSheetAmountLabel,
                placeholder: "0",
                suffix: currencySymbol(of: currencyCode, locale: locale),
                isError: amountInvalid,
                supportingText: amountInvalid ? SmokingStrings.goalSheetAmountError : nil,
                keyboard: .decimal
            )
            if editing {
                SalusInfoNote(
                    text: SmokingStrings.goalSheetKeepNote,
                    systemImage: GoalSheetSymbols.note,
                    tone: .neutral
                )
            }
            SalusButton(
                SmokingStrings.goalSheetSave,
                accent: theme.extendedColors.smoking,
                enabled: !writing && isGoalFormValid(title: title, amountText: amountText, fractionDigits: digits),
                action: onSave
            )
        }
        .padding(.horizontal, SalusSpacing.lg)
        .padding(.bottom, SalusSpacing.xl)
    }
}
