// Ported from `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/component/
// SalusTextField.kt:35-162` in its M15 shape.
//
// The M15 text field is a bordered box on `surfaceContainerHigh` with the label lifted out of the
// field and set as an overline above it, so the field never changes height when it gains a value and
// a column of fields keeps one baseline grid (`SalusTextField.kt:43-46`).
//
// SwiftUI's `TextField` has no label/suffix/supporting-text slots, so they are hand-drawn around
// the box exactly as Kotlin draws them:
//
//   `label`          → `labelSmall` on `overline`, above the box (`SalusTextField.kt:88-95`).
//   `supportingText` → `bodySmall`, below the box, `error` while `isError`
//                      (`SalusTextField.kt:149-161`).
//   `container/border` → `surfaceContainerHigh` fill and `shapes.medium` corners
//                      (`SalusTextField.kt:102-110`).
//
// Two spelling differences, both deliberate:
//
//   `isError` on a Material field   → an error **stroke** on the box. Because Kotlin's M14 pill
//                                   cleared `errorIndicatorColor`, `isError` there only reddened the
//                                   supporting text; the M15 box strokes its border instead — the
//                                   `VitalsEditorField` stroke (`VitalsEditorField.swift:59-67`),
//                                   and it is the one place this port adds rather than maps.
//   `focused -> primary` border    → the M15 `animateColorAsState` border is driven by a focus
//                                   interaction source; the iOS port keeps a resting `outlineVariant`
//                                   edge and the `error` stroke, because a `@FocusState` binding on
//                                   this shared component would pull layout into the callers.
//
// `KeyboardOptions` is not ported as a type. Its members arrive as three separate arguments —
// `keyboard`, `capitalization`, `autocorrects` — because each is a `#if os(iOS)` API here, so a
// Compose-shaped options struct would not compile on the macOS test host.
//
// **`imeAction` is deliberately NOT among them — a recorded divergence.** Kotlin sets
// `imeAction = ImeAction.Next` on the two single-line profile fields (`ProfileScreen.kt:114`,
// `:159`) and pointedly omits it on the multi-line one, with the reason written down: *"A
// multi-line field gets no imeAction: it would steal the newline key"* (`:169-170`). Compose's
// `Next` both relabels the key **and** advances focus, for free. SwiftUI splits those: only
// `.submitLabel(.next)` is free, and the advance needs a `@FocusState` the caller owns and a
// `FocusState.Binding` parameter on this component — generics on a view two features share, for an
// affordance neither platform's design calls out. A "next" key that relabels but does not advance
// is worse than no claim at all, so **neither half is ported**: both single-line fields keep the
// platform's default return key. The half that actually matters is preserved by construction — the
// multi-line field is `axis: .vertical`, which keeps its newline key because nothing was added to
// take it away. If the advance is ever wanted, it arrives as a focus binding here and a
// `@FocusState` in `ProfileScreen`, together, never as a bare `.submitLabel`.

import SalusDesignSystem
import SwiftUI

/// A bordered box on `surfaceContainerHigh` with the label above and the supporting text below —
/// the M15 text field (`SalusTextField.kt:43-53`).
///
/// `label` is rendered as an overline above the box, `suffix` trails the value (`cm`, `kg`), and
/// `supportingText` sits below it, reddened while `isError`. Any of the three may be omitted;
/// the box alone never changes height.
public struct SalusTextField: View {
    /// Which keyboard the field asks for. A small enum rather than a `UIKeyboardType`, because
    /// this package builds for macOS too (the test host), where that type does not exist — the
    /// same reason `VitalsEditorField.Keyboard` is one.
    public enum Keyboard: Sendable {
        /// `KeyboardOptions.Default` (`SalusTextField.kt:42`).
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
    let label: String?
    let placeholder: String
    let suffix: String?
    let isError: Bool
    let supportingText: String?
    let isSingleLine: Bool
    let keyboard: Keyboard
    let capitalization: Capitalization
    let autocorrects: Bool

    @Environment(\.salusTheme) private var theme

    /// Every argument past `placeholder` is defaulted, exactly as Kotlin defaults them
    /// (`SalusTextField.kt:59-69`). `label` is optional, so the placeholder-only model every
    /// existing call site uses stays valid; it is the M15 overline above the box. `enabled` is not
    /// ported: no caller disables one, and an unused knob is a knob that drifts.
    ///
    /// - Parameter autocorrects: Kotlin's `autoCorrectEnabled`, which it sets independently of
    ///   capitalization (`false` on the name field, `ProfileScreen.kt:113`). A separate argument
    ///   rather than something inferred from `capitalization`, so a caller that wants `.words`
    ///   *with* autocorrect can say so and the coupling is not invisible at the call site.
    public init(
        text: Binding<String>,
        label: String? = nil,
        placeholder: String,
        suffix: String? = nil,
        isError: Bool = false,
        supportingText: String? = nil,
        isSingleLine: Bool = true,
        keyboard: Keyboard = .standard,
        capitalization: Capitalization = .none,
        autocorrects: Bool = true
    ) {
        _text = text
        self.label = label
        self.placeholder = placeholder
        self.suffix = suffix
        self.isError = isError
        self.supportingText = supportingText
        self.isSingleLine = isSingleLine
        self.keyboard = keyboard
        self.capitalization = capitalization
        self.autocorrects = autocorrects
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let label {
                // `Text(label, style = labelSmall, color = overline, padding(bottom = sm))`
                // (`SalusTextField.kt:88-95`) — the M15 overline above the box, so a column of
                // fields keeps one baseline grid.
                Text(verbatim: label)
                    .font(SalusTypography.labelSmall.font)
                    .tracking(SalusTypography.labelSmall.tracking)
                    .foregroundStyle(theme.extendedColors.overline)
                    .padding(.bottom, SalusSpacing.sm)
            }
            fieldBox
            if SalusTextFieldStyle.showsSupportingText(supportingText) {
                // `SalusTextField.kt:149-161` — below the box, inset to the content edge so it
                // lines up with the value above it.
                Text(verbatim: supportingText ?? "")
                    .font(SalusTypography.bodySmall.font)
                    .foregroundStyle(
                        SalusTextFieldStyle.supportingTextColor(isError: isError, colors: colors)
                    )
                    .padding(.horizontal, Self.contentInset)
                    .padding(.top, SalusSpacing.xs)
            }
        }
    }

    /// `SalusTextField.kt:96-148` — the field's box, its value and its trailing unit.
    private var fieldBox: some View {
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
        // `MaterialTheme.shapes.medium` with a `surfaceContainerHigh` fill (`SalusTextField.kt:102-110`).
        .background(SalusShapes.mediumShape.fill(colors.surfaceContainerHigh))
        .overlay {
            if let stroke = SalusTextFieldStyle.stroke(isError: isError, colors: colors) {
                SalusShapes.mediumShape.strokeBorder(stroke, lineWidth: Self.errorStroke)
            } else {
                SalusShapes.mediumShape.strokeBorder(
                    colors.outlineVariant,
                    lineWidth: Self.errorStroke
                )
            }
        }
    }

    private var field: some View {
        // `prompt:` is Kotlin's `placeholder = { Text(…) }` (`SalusTextField.kt:56-62`); the
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
        .lineLimit(SalusTextFieldStyle.lineLimit(isSingleLine: isSingleLine))
        #if os(iOS)
            .keyboardType(keyboard == .decimal ? .decimalPad : .default)
            .textInputAutocapitalization(autocapitalization)
            // `autoCorrectEnabled` (`ProfileScreen.kt:113`), which the caller sets on its own.
            .autocorrectionDisabled(!autocorrects)
        #endif
    }

    /// A single-line field never grows; a multi-line one does, which is what `singleLine = false`
    /// buys the health-notes field (`SalusTextField.kt:41`).
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

    /// `SalusTextFieldDefaults` (`SalusTextField.kt:109-120`). Component dimensions, not
    /// design tokens — Android keeps them in `:core:ui` too. `ContentPadding` is not ported: it
    /// exists there for the birth-date trigger, which on iOS is `SalusDateField` and draws its own.
    private static let height: CGFloat = 64
    private static let contentInset: CGFloat = 24
    /// The stroke width `VitalsEditorField` draws its error outline at.
    private static let errorStroke: CGFloat = 1
}

/// The decisions ``SalusTextField`` makes, lifted out of the view so they can be tested without
/// SwiftUI — the arrangement ``SalusDateFieldState`` sets.
enum SalusTextFieldStyle {
    /// `SalusTextField.kt:90` — an absent message and an empty one are the same thing, and
    /// neither may add a row under the pill.
    static func showsSupportingText(_ supportingText: String?) -> Bool {
        guard let supportingText else { return false }
        return !supportingText.isEmpty
    }

    /// `SalusTextField.kt:94-98`.
    static func supportingTextColor(isError: Bool, colors: SalusColorScheme) -> Color {
        isError ? colors.error : colors.onSurfaceVariant
    }

    /// The iOS-only half of `isError` (see the file note): nil for a healthy field, so no stroke
    /// layer is drawn at all.
    static func stroke(isError: Bool, colors: SalusColorScheme) -> Color? {
        isError ? colors.error : nil
    }

    /// `singleLine` (`SalusTextField.kt:41`). The upper bound on the growing field keeps a long
    /// note from pushing the rest of the form off screen, exactly as Compose's own scrolling field
    /// does.
    static func lineLimit(isSingleLine: Bool) -> ClosedRange<Int> {
        isSingleLine ? 1 ... 1 : 3 ... 8
    }
}

#Preview("Text fields") {
    @Previewable @State var empty = ""
    @Previewable @State var height = "170"
    @Previewable @State var rejected = "999"

    let theme = SalusTheme.resolve(systemIsDark: false)
    ZStack {
        theme.colorScheme.background
        VStack(spacing: SalusSpacing.md) {
            // The fields of `SalusTextFieldPreview` (`SalusTextField.kt:180-244`), the overline
            // label and its error stroke drawn in.
            SalusTextField(text: $empty, label: "NAME", placeholder: "Örn: Ayşe", capitalization: .words)
            SalusTextField(text: $height, placeholder: "Örn: 170", suffix: "cm", keyboard: .decimal)
            SalusTextField(
                text: $rejected,
                label: "BOY",
                placeholder: "Örn: 170",
                suffix: "cm",
                isError: true,
                supportingText: "50 ile 250 cm arasında bir değer girin.",
                keyboard: .decimal
            )
        }
        .padding(SalusSpacing.lg)
    }
    .frame(height: 260)
    .salusTheme(theme)
}

#Preview("Text fields — dark") {
    @Previewable @State var empty = ""
    @Previewable @State var rejected = "999"

    let theme = SalusTheme.resolve(systemIsDark: true)
    ZStack {
        theme.colorScheme.background
        VStack(spacing: SalusSpacing.md) {
            SalusTextField(text: $empty, label: "NAME", placeholder: "Örn: Ayşe", capitalization: .words)
            SalusTextField(
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
    .frame(height: 180)
    .salusTheme(theme)
}
