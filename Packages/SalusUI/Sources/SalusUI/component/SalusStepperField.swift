// Ported from `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/component/
// SalusStepperField.kt:79-287`.
//
// **The value is a `String` here, and the arithmetic is the caller's.** Kotlin owns a `Double`, a
// `step`, a `range` and a `format`/`parse` pair (`SalusStepperField.kt:80-92`), and clamps every
// path into `onValueChange` itself. The iOS twin takes the number already written
// (`value: String`), reports the text an edit produced (`onValueChange`) and hands the two nudges
// straight back (`onDecrement` / `onIncrement`) — the feature's state holder already owns the unit,
// the step and the bounds, and duplicating them in the component is how the two drift apart.
// `parse` therefore answers a yes/no (is this text a number this field accepts?) rather than
// returning one, and `rangeHint` is Kotlin's `hint` (`:89`) under the name spec §3.3 gives it.
//
// **THE CALLER CONTRACT THAT COMES WITH THAT, and it binds: a state holder must answer every
// `onValueChange` — by accepting the text as the new `value`, or by clamping it and re-emitting
// the value it will accept. Silently ignoring one is a bug in the caller, not in the field.**
//
// The field cannot cover for it. `value` reaches a SwiftUI view only as a new struct, so from in
// here "the caller declined" and "the caller has not answered yet" are the same non-event: there
// is nothing to re-seed from and the field would go on displaying a number the state holder
// rejected. Kotlin is not in this position twice over — its re-seed block runs on *every*
// recomposition (`SalusStepperField.kt:111-121`), and it clamps to `range` itself before reporting
// (`:151`), so a decline is close to unreachable there. Neither half survives moving the range out
// of the component, which is why the obligation is written down here instead.
//
// A caller that honours it is corrected on the very next update at no cost: `commit()` leaves
// `lastSeed` holding what was reported, so a re-emitted (clamped) `value` differs from it and
// `syncSeed()` replaces the text, while an accepted one matches and nothing moves — no flash
// either way. Recorded as an iOS divergence for spec §9 (see `task-3-report.md`).
//
// **Recorded deviation from the plan's Interfaces block:** `keyboard` is a
// ``SalusTextField/Keyboard``, not a `UIKeyboardType`. `SalusUI` builds for macOS too — that is
// what hosts `swift test` — and `UIKeyboardType` does not exist there, so the parameter would
// break every package build on the host. `SalusTextField.Keyboard` is the package's existing
// answer to exactly this problem (`SalusTextField.swift:57-65`), and `.decimal` is `.decimalPad`.
//
// The minus glyph is `minus` from SF Symbols, so Kotlin's hand-built `MinusIcon` vector
// (`SalusStepperField.kt:289-311`, a 14 × 2 bar drawn because Material ships `Add` but no
// `Remove`) has no twin here.

import SalusDesignSystem
import SwiftUI

/// A number the user nudges — or types: a large editable value between a − and a +
/// (`SalusStepperField.kt:53-54`).
///
/// Nudging covers the common case, a step or two from where the value already is. Typing covers
/// the rest, because reaching 250 from a default of 120 one tap at a time is not an input method.
/// An edit commits exactly once, on the keyboard's Done or on the field losing focus; text `parse`
/// rejects reverts to the current value rather than reporting an error, since there is nothing for
/// the user to fix in a field that only holds numbers (`SalusStepperField.kt:62-67`).
///
/// `placeholder` says the number on screen is a *suggestion*, not something the user entered: it
/// is drawn in `onSurfaceVariant` behind an empty field, so the first keystroke starts a fresh
/// number instead of appending to one nobody typed, and VoiceOver is told as much
/// (`SalusStepperField.kt:69-74`). `autoFocus` opens the field and its keyboard as the screen
/// appears, once per view instance (`:74-77`).
public struct SalusStepperField: View {
    private let label: String
    private let value: String
    private let placeholder: Bool
    private let rangeHint: String
    private let autoFocus: Bool
    private let keyboard: SalusTextField.Keyboard
    private let parse: (String) -> Bool
    private let onValueChange: (String) -> Void
    private let onDecrement: () -> Void
    private let onIncrement: () -> Void

    @Environment(\.salusTheme) private var theme
    @State private var text = ""
    @State private var lastSeed = ""
    @State private var editing = false
    /// `rememberSaveable { mutableStateOf(false) }` (`SalusStepperField.kt:106`) — the opening
    /// focus is a one-off per view instance, not something a re-appearance re-fires.
    @State private var autoFocused = false
    @FocusState private var focused: Bool

    public init(
        label: String,
        value: String,
        placeholder: Bool = false,
        rangeHint: String,
        autoFocus: Bool = false,
        keyboard: SalusTextField.Keyboard = .decimal,
        parse: @escaping (String) -> Bool,
        onValueChange: @escaping (String) -> Void,
        onDecrement: @escaping () -> Void,
        onIncrement: @escaping () -> Void
    ) {
        self.label = label
        self.value = value
        self.placeholder = placeholder
        self.rangeHint = rangeHint
        self.autoFocus = autoFocus
        self.keyboard = keyboard
        self.parse = parse
        self.onValueChange = onValueChange
        self.onDecrement = onDecrement
        self.onIncrement = onIncrement
    }

    public var body: some View {
        // `Arrangement.spacedBy(SalusSpacing.sm)` under the overline (`SalusStepperField.kt:161`).
        VStack(alignment: .leading, spacing: SalusSpacing.sm) {
            Text(verbatim: label)
                .font(SalusTypography.labelSmall.font)
                .tracking(SalusTypography.labelSmall.tracking)
                .foregroundStyle(theme.extendedColors.overline)
            // `Row(spacedBy(SalusSpacing.md))` — button, value column, button
            // (`SalusStepperField.kt:168-276`).
            HStack(spacing: SalusSpacing.md) {
                SalusIconButton(
                    systemImage: "minus",
                    accessibilityLabel: SalusUIStrings.stepperDecrease,
                    action: onDecrement
                )
                valueColumn
                SalusIconButton(
                    systemImage: "plus",
                    accessibilityLabel: SalusUIStrings.stepperIncrease,
                    action: onIncrement
                )
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear(perform: syncSeed)
        .onChange(of: seed) { syncSeed() }
        .onChange(of: focused) { _, isFocused in
            if isFocused {
                editing = true
            } else if editing {
                // Still open, so Done did not already commit it: the user tapped elsewhere
                // (`SalusStepperField.kt:232-240`).
                commit()
            }
        }
        .task {
            // Kotlin waits one frame before requesting focus, because a field that is still
            // unplaced throws (`SalusStepperField.kt:123-134`); `.task` runs after the first
            // layout pass, which is the same wait.
            guard autoFocus, !autoFocused else { return }
            autoFocused = true
            focused = true
        }
    }

    /// `Column(weight(1f))` — the field, its suggestion and the range hint
    /// (`SalusStepperField.kt:180-268`).
    private var valueColumn: some View {
        VStack(spacing: SalusSpacing.xs) {
            field
            Text(verbatim: rangeHint)
                .font(SalusTypography.bodySmall.font)
                .tracking(SalusTypography.bodySmall.tracking)
                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var field: some View {
        ZStack {
            if placeholder, text.isEmpty {
                // The suggestion sits behind the field at the size and position the real value
                // would take, dimmed to say it is not one yet (`SalusStepperField.kt:196-208`).
                Text(verbatim: value)
                    .font(SalusTypography.displaySmall.font)
                    .tracking(SalusTypography.displaySmall.tracking)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                    .accessibilityHidden(true)
            }
            // `verbatim:` on the label too: `Text(_:)` with a resolved string is read as a
            // `LocalizedStringKey` against the main bundle (the M7 `c726e22` finding).
            TextField(text: $text, prompt: nil) { Text(verbatim: label) }
                .labelsHidden()
                .textFieldStyle(.plain)
                .font(SalusTypography.displaySmall.font)
                .foregroundStyle(theme.colorScheme.onSurface)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .focused($focused)
                .submitLabel(.done)
                // Done must be wired by hand on both platforms: it hides the keyboard without
                // moving focus, so without this a typed value would be dropped when the user went
                // straight on to save (`SalusStepperField.kt:218-228`).
                .onSubmit {
                    commit()
                    focused = false
                }
            #if os(iOS)
                .keyboardType(keyboard == .decimal ? .decimalPad : .default)
            #endif
                // The number alone reads as a bare figure; the field says which number it is, and
                // — while it is only a suggestion — that it is not the user's own answer yet
                // (`SalusStepperField.kt:241-249`).
                .accessibilityLabel(Text(verbatim: label))
                .accessibilityValue(Text(verbatim: spokenValue))
        }
        .frame(minWidth: SalusStepperFieldDefaults.minValueWidth)
    }

    /// `stateDescription = suggestionDescription` while the number is only a suggestion
    /// (`SalusStepperField.kt:246-248`) — VoiceOver has to say that the figure it is reading is
    /// not the user's own answer yet, which the dimmed drawing says to everyone else.
    private var spokenValue: String {
        placeholder && text.isEmpty ? SalusUIStrings.stepperSuggested : text
    }

    /// `val seed = if (placeholder) "" else formatted` (`SalusStepperField.kt:100`).
    private var seed: String {
        SalusStepperFieldState.seed(value: value, placeholder: placeholder)
    }

    /// `SalusStepperField.kt:110-121` — the value moved underneath the field (a nudge, a unit
    /// switch, a reload) and that wins, even mid-edit; while the field is not being edited the
    /// value is the source of truth, and while it is, the user's keystrokes are.
    ///
    /// Kotlin runs this on every recomposition; here it runs when the field appears and whenever
    /// `value` or `placeholder` actually changes — which is every moment it has anything to do,
    /// **provided the caller answers what `commit()` reported** (see the file header). It cannot
    /// restore a value the caller declined without changing `value`, because no update arrives to
    /// run it.
    private func syncSeed() {
        let seed = seed
        text = SalusStepperFieldState.reseeded(
            text: text,
            seed: seed,
            lastSeed: lastSeed,
            editing: editing
        )
        lastSeed = seed
    }

    /// Ends the edit. Clearing `editing` first is what makes this run exactly once: Done commits
    /// and then drops focus, and the focus handler only commits while an edit is still open
    /// (`SalusStepperField.kt:136-157`).
    ///
    /// What it reports is a *proposal*, and the caller owes it an answer — accept it as the new
    /// `value`, or clamp it and re-emit (the file header states the contract and why the field
    /// cannot enforce it). `lastSeed` is left holding the reported text so that either answer is
    /// picked up by ``syncSeed()`` on the next update: a clamped re-emission differs from it and
    /// replaces the text, an accepted one matches and nothing moves.
    private func commit() {
        editing = false
        let typed = text
        let resolved = SalusStepperFieldState.committed(text: typed, seed: seed, parse: parse)
        text = resolved
        lastSeed = resolved
        // Reverted text is not an answer, and neither is an empty field: only a resolution that
        // kept what was typed is reported (`SalusStepperField.kt:144-152`).
        guard resolved == typed, SalusStepperFieldState.hasValue(text: resolved) else { return }
        onValueChange(resolved)
    }
}

/// The decisions ``SalusStepperField`` makes about the text in its field, lifted out of the view so
/// they can be tested without SwiftUI — the arrangement ``SalusTextFieldStyle`` sets.
enum SalusStepperFieldState {
    /// What the field holds when it opens: nothing while the number on screen is only a
    /// suggestion, the value itself otherwise (`SalusStepperField.kt:98-100`).
    static func seed(value: String, placeholder: Bool) -> String {
        placeholder ? "" : value
    }

    /// Whether the field holds a value of the user's own. A suggestion is drawn *behind* an empty
    /// field, so a placeholder field reports none until something is typed or nudged
    /// (`SalusStepperField.kt:69-73`).
    static func hasValue(text: String) -> Bool {
        !text.isEmpty
    }

    /// The text the field is left holding once an edit ends: what was typed when `parse` accepts
    /// it, and otherwise the number the field showed — there is nothing to correct in a field that
    /// only holds numbers (`SalusStepperField.kt:141-157`).
    static func committed(text: String, seed: String, parse: (String) -> Bool) -> String {
        parse(text) ? text : seed
    }

    /// The text the field holds after an update, given the seed it now has and the one it had
    /// (`SalusStepperField.kt:110-121`).
    ///
    /// A seed that moved wins outright, mid-edit included: with the field focused, tapping − or +
    /// is the only way that happens and the user is watching the number they just nudged. It is
    /// also how a caller's clamped re-emission lands, because `commit()` leaves `lastSeed` holding
    /// what it reported. A seed that did not move yields to the keystrokes while an edit is open,
    /// and otherwise re-asserts itself, which is the "the value is the source of truth" half.
    static func reseeded(text: String, seed: String, lastSeed: String, editing: Bool) -> String {
        guard seed == lastSeed else { return seed }
        return editing ? text : seed
    }
}

/// `object SalusStepperFieldDefaults` (`SalusStepperField.kt:280-287`). Component dimensions, not
/// design tokens — Android keeps them in `:core:ui` too.
public enum SalusStepperFieldDefaults {
    /// Keeps a one-digit value a comfortable tap target: an intrinsically sized field around "3"
    /// would be a few points wide (`SalusStepperField.kt:283-287`).
    public static let minValueWidth: CGFloat = 64
}

#Preview("Stepper fields") {
    @Previewable @State var dose = "2"

    SalusPreviewPalettes {
        VStack(spacing: SalusSpacing.xl) {
            SalusStepperField(
                label: "DOZ",
                value: dose,
                rangeHint: "1 - 10 tablet",
                parse: { Double($0.replacingOccurrences(of: ",", with: ".")) != nil },
                onValueChange: { dose = $0 },
                onDecrement: { dose = "1" },
                onIncrement: { dose = "3" }
            )
            SalusStepperField(
                label: "KİLO",
                value: "72",
                placeholder: true,
                rangeHint: "30 - 300 kg",
                parse: { _ in true },
                onValueChange: { _ in },
                onDecrement: {},
                onIncrement: {}
            )
        }
    }
}
