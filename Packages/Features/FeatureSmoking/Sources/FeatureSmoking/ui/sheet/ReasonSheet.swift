// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/sheet/
// ReasonSheet.kt`.
//
// The person's own reason, shown back to them in hard moments. Free text, optional: saving it blank
// clears it. It never leaves the device, which the hint says. Nothing is handed out until "Kaydet".
//
// Compose → SwiftUI: `SalusTextField(singleLine = false, minLines = 3)` → `SalusTextField(
// isSingleLine: false)`, which grows with its text; `rememberSaveable` → `@State`.

import SalusDesignSystem
import SalusUI
import SwiftUI

/// The body of the reason sheet, with its own state.
struct ReasonSheet: View {
    let writing: Bool
    let onSave: (String) -> Void

    @State private var text: String

    init(initialReason: String?, writing: Bool, onSave: @escaping (String) -> Void) {
        self.writing = writing
        self.onSave = onSave
        _text = State(initialValue: initialReason ?? "")
    }

    var body: some View {
        ReasonSheetContent(text: $text, writing: writing) { onSave(text) }
            .interactiveDismissDisabled(writing)
    }
}

/// The sheet's body without its state, so a preview can draw every case.
struct ReasonSheetContent: View {
    @Binding var text: String
    let writing: Bool
    let onSave: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: SalusSpacing.md) {
            SalusTextField(
                text: $text,
                label: SmokingStrings.settingsReasonLabel,
                placeholder: SmokingStrings.setupReasonPlaceholder,
                supportingText: SmokingStrings.settingsReasonHint,
                isSingleLine: false,
                capitalization: .sentences
            )
            SalusButton(
                SmokingStrings.settingsSave,
                accent: theme.extendedColors.smoking,
                enabled: !writing,
                action: onSave
            )
        }
        .padding(.horizontal, SalusSpacing.lg)
        .padding(.bottom, SalusSpacing.xl)
    }
}

// MARK: - Previews

#Preview("Reason sheet — empty and filled") {
    SalusPreviewPalettes {
        ReasonSheetContent(text: .constant(""), writing: false, onSave: {})
        ReasonSheetContent(text: .constant("Kızım için"), writing: false, onSave: {})
    }
}

#Preview("Reason sheet — accessibility3") {
    ReasonSheetContent(
        text: .constant("Kızım için, daha rahat nefes almak için"),
        writing: false,
        onSave: {}
    )
    .salusTheme(SalusTheme.resolve(systemIsDark: false))
    .dynamicTypeSize(.accessibility3)
}
