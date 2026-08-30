// The SwiftUI stand-in for the `OutlinedTextField` all three vitals editors reach for:
// `WeightEditorScreen.kt:96-113`, `BloodPressureEditorScreen.kt:174-196` (its private `NumberField`
// composable) and `GlucoseEditorScreen.kt:105-121`.
//
// Compose gets one field for the three because Material's `OutlinedTextField` already carries
// `label`, `suffix` and `isError` as slots. SwiftUI's `TextField` carries none of them, so each of
// the three editors had to draw the caption, the suffix and the error stroke by hand — and the
// three copies drifted: the weight editor had grown neither a caption nor a stroke, so the same
// `isError = state.showInvalidWeight` that reddens the Kotlin field's border reddened nothing here.
// One view, used three times, is what keeps them one behaviour.

import SalusDesignSystem
import SalusUI
import SwiftUI

/// A captioned text field with a trailing unit suffix and an error stroke — Material's
/// `OutlinedTextField(label:suffix:isError:)`, drawn by hand.
///
/// The **message** below a rejected field is deliberately not here: the blood-pressure editor draws
/// one message for its three fields (`BloodPressureEditorScreen.kt:133-139`) while the weight and
/// glucose editors draw one each, so the message belongs to the editor and only the field's own
/// parts — caption, field, stroke, suffix — are shared.
struct VitalsEditorField: View {
    /// Which number keyboard the field asks for, since the three editors do not agree.
    ///
    /// A small enum rather than a `UIKeyboardType` parameter because this package builds for macOS
    /// too (the test host), where that type does not exist.
    enum Keyboard {
        /// `KeyboardType.Number` — `BloodPressureEditorScreen.kt:190`.
        case number
        /// `KeyboardType.Decimal` — `WeightEditorScreen.kt:108`, `GlucoseEditorScreen.kt:117`.
        case decimal
    }

    let label: String
    let suffix: String
    @Binding var text: String
    let isError: Bool
    let keyboard: Keyboard

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: SalusSpacing.xs) {
            // Kotlin's `label = { Text(…) }`, which Material keeps on the border once the field is
            // filled. Repeating it as the placeholder costs nothing on an empty field and is what
            // the platform draws before the first character.
            Text(verbatim: label)
                .font(SalusTypography.labelMedium.font)
                .tracking(SalusTypography.labelMedium.tracking)
                .foregroundStyle(isError ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant)

            HStack(spacing: SalusSpacing.sm) {
                TextField(label, text: $text)
                    .textFieldStyle(.roundedBorder)
                #if os(iOS)
                    .keyboardType(keyboard == .number ? .numberPad : .decimalPad)
                #endif
                    .overlay {
                        if isError {
                            // `SalusShapes.extraSmall` rather than a literal: the shape token is
                            // the one sanctioned source for a radius, and `.roundedBorder`'s own
                            // corner is not a value the framework publishes.
                            RoundedRectangle(cornerRadius: SalusShapes.extraSmall)
                                .stroke(theme.colorScheme.error, lineWidth: 1)
                        }
                    }
                // The suffix is the literal Kotlin draws, not a string resource, on both platforms.
                Text(verbatim: suffix)
                    .font(SalusTypography.bodyMedium.font)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

#Preview("Accepted and rejected") {
    @Previewable @State var accepted = "72"
    @Previewable @State var rejected = "5"

    return Form {
        VitalsEditorField(
            label: "Kilo",
            suffix: "kg",
            text: $accepted,
            isError: false,
            keyboard: .decimal
        )
        VitalsEditorField(
            label: "Nabız",
            suffix: "bpm",
            text: $rejected,
            isError: true,
            keyboard: .number
        )
    }
}
