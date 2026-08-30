// Ported from `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/component/
// SalusPillTextField.kt:35-120`.
//
// The model for the SwiftUI shape is `FeatureVitals`' `VitalsEditorField` (iOS-M7's `D-M7-y`), not
// a bare `TextField`: Material's `TextField` carries `placeholder`, `suffix`, `isError` and
// `supportingText` as slots, SwiftUI's carries none of them, and the three vitals editors already
// proved that hand-drawing them per call site is how the four parts drift apart. So the same four
// parts — field, suffix, error stroke, message — live in one view here, on the pill Kotlin draws.
// (Migrating the vitals/medications/appointments editors onto this field is polish, not parity, and
// is deliberately out of scope.)
//
// Two spelling differences, both forced:
//
//   `TextFieldDefaults.colors(…)`   → the container is drawn by hand: a `SalusShapes.pill` filled
//    with four transparent          with `surfaceVariant` behind a `.plain` `TextField`. Kotlin
//    indicators                     clears all four indicator colours to get a pill with no
//                                   underline (`SalusPillTextField.kt:79-88`); SwiftUI's `.plain`
//                                   style has no indicator to clear.
//   `isError` on a Material field   → an error **stroke** on that capsule. Because Kotlin cleared
//                                   `errorIndicatorColor` too, `isError` there only reddens the
//                                   supporting text — a rejected value with no message would look
//                                   accepted. The stroke is `VitalsEditorField`'s
//                                   (`VitalsEditorField.swift:59-67`), and it is the one place
//                                   this port adds rather than maps. Recorded as a divergence.
//
// `KeyboardOptions` is not ported as a type: `keyboardType` and `capitalization` are the only two
// members any caller sets, and both are `#if os(iOS)` APIs here, so they arrive as two small enums
// this package can also compile on the macOS test host.

import SalusDesignSystem
import SwiftUI

/// Fully rounded filled text field carrying a placeholder instead of a floating label — the shape
/// Material's own fields cannot take, because their indicator line and label animation both assume
/// a flat-bottomed box (`SalusPillTextField.kt:26-33`).
///
/// `suffix` is the unit that trails the value (`cm`, `kg`); `supportingText` is rendered below the
/// pill rather than inside it, so the pill never changes height.
public struct SalusPillTextField: View {
    /// Which keyboard the field asks for. A small enum rather than a `UIKeyboardType`, because
    /// this package builds for macOS too (the test host), where that type does not exist — the
    /// same reason `VitalsEditorField.Keyboard` is one.
    public enum Keyboard: Sendable {
        /// `KeyboardOptions.Default` (`SalusPillTextField.kt:42`).
        case standard
        /// `KeyboardType.Decimal` — the height field (`ProfileScreen.kt:158`).
        case decimal
    }

    /// `KeyboardCapitalization`, in the three spellings the callers use.
    public enum Capitalization: Sendable {
        case none
        /// `KeyboardCapitalization.Words` — the name field (`ProfileScreen.kt:112`).
        case words
        /// `KeyboardCapitalization.Sentences` — the health-notes field (`ProfileScreen.kt:171`).
        case sentences
    }

    // Internal rather than private: the API test round-trips the error flag and the defaults, and
    // none of it is visible outside this module anyway.
    @Binding var text: String
    let placeholder: String
    let suffix: String?
    let isError: Bool
    let supportingText: String?
    let isSingleLine: Bool
    let keyboard: Keyboard
    let capitalization: Capitalization

    @Environment(\.salusTheme) private var theme

    /// Every argument past `placeholder` is defaulted, exactly as Kotlin defaults them
    /// (`SalusPillTextField.kt:39-45`). `enabled` is not ported: no caller disables one, and an
    /// unused knob is a knob that drifts.
    public init(
        text: Binding<String>,
        placeholder: String,
        suffix: String? = nil,
        isError: Bool = false,
        supportingText: String? = nil,
        isSingleLine: Bool = true,
        keyboard: Keyboard = .standard,
        capitalization: Capitalization = .none
    ) {
        _text = text
        self.placeholder = placeholder
        self.suffix = suffix
        self.isError = isError
        self.supportingText = supportingText
        self.isSingleLine = isSingleLine
        self.keyboard = keyboard
        self.capitalization = capitalization
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SalusSpacing.xs) {
            pill
            if SalusPillTextFieldStyle.showsSupportingText(supportingText) {
                // `SalusPillTextField.kt:91-104` — below the pill, inset to the content edge so it
                // lines up with the value above it.
                Text(verbatim: supportingText ?? "")
                    .font(SalusTypography.bodySmall.font)
                    .foregroundStyle(
                        SalusPillTextFieldStyle.supportingTextColor(isError: isError, colors: colors)
                    )
                    .padding(.horizontal, Self.contentInset)
            }
        }
    }

    /// `SalusPillTextField.kt:48-89` — the capsule, its value and its trailing unit.
    private var pill: some View {
        HStack(spacing: SalusSpacing.sm) {
            field
            if let suffix {
                // The unit symbol is a literal on both platforms, never a string resource.
                Text(verbatim: suffix)
                    .font(SalusTypography.bodyLarge.font)
                    .foregroundStyle(colors.onSurfaceVariant)
            }
        }
        .padding(.horizontal, Self.contentInset)
        .padding(.vertical, SalusSpacing.md)
        .frame(maxWidth: .infinity, minHeight: Self.height, alignment: .leading)
        .background(SalusShapes.pill.fill(colors.surfaceVariant))
        .overlay {
            if let stroke = SalusPillTextFieldStyle.stroke(isError: isError, colors: colors) {
                SalusShapes.pill.stroke(stroke, lineWidth: Self.errorStroke)
            }
        }
    }

    private var field: some View {
        // `prompt:` is Kotlin's `placeholder = { Text(…) }` (`SalusPillTextField.kt:56-62`); the
        // label repeats it so VoiceOver names a filled field too, and `.labelsHidden()` keeps it
        // off screen. `verbatim:` on both, because a resolved string handed to `Text(_:)` is read
        // as a `LocalizedStringKey` against the main bundle.
        TextField(text: $text, prompt: Text(verbatim: placeholder), axis: axis) {
            Text(verbatim: placeholder)
        }
        .labelsHidden()
        .textFieldStyle(.plain)
        .font(SalusTypography.bodyLarge.font)
        .foregroundStyle(colors.onSurface)
        .lineLimit(SalusPillTextFieldStyle.lineLimit(isSingleLine: isSingleLine))
        #if os(iOS)
            .keyboardType(keyboard == .decimal ? .decimalPad : .default)
            .textInputAutocapitalization(autocapitalization)
            // `autoCorrectEnabled = false` on the name field (`ProfileScreen.kt:113`), and a
            // measurement or a unit is never a word the dictionary should second-guess either.
            .autocorrectionDisabled(capitalization != .sentences)
        #endif
    }

    /// A single-line field never grows; a multi-line one does, which is what `singleLine = false`
    /// buys the health-notes field (`SalusPillTextField.kt:41`).
    private var axis: Axis {
        isSingleLine ? .horizontal : .vertical
    }

    #if os(iOS)
        private var autocapitalization: TextInputAutocapitalization {
            switch capitalization {
            case .none: .never
            case .words: .words
            case .sentences: .sentences
            }
        }
    #endif

    private var colors: SalusColorScheme { theme.colorScheme }

    /// `SalusPillTextFieldDefaults` (`SalusPillTextField.kt:109-120`). Component dimensions, not
    /// design tokens — Android keeps them in `:core:ui` too. `ContentPadding` is not ported: it
    /// exists there for the birth-date trigger, which on iOS is `SalusDateField` and draws its own.
    private static let height: CGFloat = 64
    private static let contentInset: CGFloat = 24
    /// The stroke width `VitalsEditorField` draws its error outline at.
    private static let errorStroke: CGFloat = 1
}

/// The decisions ``SalusPillTextField`` makes, lifted out of the view so they can be tested without
/// SwiftUI — the arrangement ``SalusDateFieldState`` sets.
enum SalusPillTextFieldStyle {
    /// `SalusPillTextField.kt:90` — an absent message and an empty one are the same thing, and
    /// neither may add a row under the pill.
    static func showsSupportingText(_ supportingText: String?) -> Bool {
        guard let supportingText else { return false }
        return !supportingText.isEmpty
    }

    /// `SalusPillTextField.kt:94-98`.
    static func supportingTextColor(isError: Bool, colors: SalusColorScheme) -> Color {
        isError ? colors.error : colors.onSurfaceVariant
    }

    /// The iOS-only half of `isError` (see the file note): nil for a healthy field, so no stroke
    /// layer is drawn at all.
    static func stroke(isError: Bool, colors: SalusColorScheme) -> Color? {
        isError ? colors.error : nil
    }

    /// `singleLine` (`SalusPillTextField.kt:41`). The upper bound on the growing field keeps a long
    /// note from pushing the rest of the form off screen, exactly as Compose's own scrolling field
    /// does.
    static func lineLimit(isSingleLine: Bool) -> ClosedRange<Int> {
        isSingleLine ? 1 ... 1 : 3 ... 8
    }
}

#Preview("Pill text fields") {
    @Previewable @State var empty = ""
    @Previewable @State var name = "Ayşe"
    @Previewable @State var height = "170"
    @Previewable @State var rejected = "999"

    let theme = SalusTheme.resolve(systemIsDark: false)
    return ZStack {
        theme.colorScheme.background
        VStack(spacing: SalusSpacing.md) {
            // The four fields of `SalusPillTextFieldPreview` (`SalusPillTextField.kt:122-154`).
            SalusPillTextField(text: $empty, placeholder: "Örn: Ayşe")
            SalusPillTextField(text: $name, placeholder: "Örn: Ayşe", capitalization: .words)
            SalusPillTextField(text: $height, placeholder: "Örn: 170", suffix: "cm", keyboard: .decimal)
            SalusPillTextField(
                text: $rejected,
                placeholder: "Örn: 170",
                suffix: "cm",
                isError: true,
                supportingText: "50 ile 250 cm arasında bir değer girin.",
                keyboard: .decimal
            )
        }
        .padding(SalusSpacing.lg)
    }
    .frame(height: 360)
    .salusTheme(theme)
}
