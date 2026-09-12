// Ported from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/medications/
// ui/editor/MedicationEditorSections.kt:272-354` (`MedicationStockCard`).
//
// Its own file rather than a member of `MedicationEditorSections.swift`: Kotlin keeps six sections
// in one 422-line file, and six here would run that one past the 500-line limit.
//
// Stock tracking is on exactly when a remaining count is stored, so the switch is a disclosure for
// the two fields under it: turning it off clears them, which is what makes the medication save with
// no stock at all. The switch itself is **view state, not editor state** on both platforms — Kotlin
// keeps it in `rememberSaveable`, and the UiState is deliberately not grown for it.
//
// `rememberSaveable(state.isLoading)` (`MedicationEditorSections.kt:283-285`) re-seeds the switch
// once, when the loaded medication arrives; after that the user owns it. `.onChange(of:initial:)`
// is the SwiftUI spelling of that key: it runs on first appearance and again on every flip of
// `isLoading`, which for this screen is exactly the moment the load lands.

import SalusDesignSystem
import SalusUI
import SwiftUI

/// The stock card (`MedicationEditorSections.kt:277-354`).
struct MedicationStockCard: View {
    let state: MedicationEditorUiState
    let onEvent: (MedicationEditorEvent) -> Void

    @Environment(\.salusTheme) private var theme

    /// Re-seeded once, when the loaded medication arrives; after that the user owns the switch
    /// (`MedicationEditorSections.kt:283-285`).
    @State private var tracking = false

    var body: some View {
        SalusCard {
            VStack(alignment: .leading, spacing: SalusSpacing.md) {
                header
                if tracking {
                    fields
                }
            }
        }
        .onChange(of: state.isLoading, initial: true) { _, _ in
            tracking = !state.stockCountInput.isBlank || !state.stockThresholdInput.isBlank
        }
    }

    /// The title, its subtitle and the switch (`MedicationEditorSections.kt:286-311`).
    private var header: some View {
        HStack(alignment: .center, spacing: SalusSpacing.sm) {
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: MedicationsStrings.editorSectionStock)
                    .font(SalusTypography.titleMedium.font)
                    .foregroundStyle(theme.colorScheme.onSurface)
                Text(verbatim: MedicationsStrings.editorStockTrackingDescription)
                    .font(SalusTypography.bodySmall.font)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            }
            // `Modifier.weight(1f)` (`MedicationEditorSections.kt:288`).
            .frame(maxWidth: .infinity, alignment: .leading)

            // The label is given and then hidden rather than omitted: `Toggle("")` would announce
            // an unnamed switch to VoiceOver, where Compose's `Switch` inherits the row's text from
            // the semantics around it.
            Toggle(MedicationsStrings.editorSectionStock, isOn: isOn)
                .labelsHidden()
        }
    }

    /// The remaining count and the warning threshold (`MedicationEditorSections.kt:316-352`).
    private var fields: some View {
        HStack(alignment: .top, spacing: SalusSpacing.md) {
            SalusTextField(
                text: Binding(get: { state.stockCountInput }, set: { onEvent(.stockCountChanged($0)) }),
                label: MedicationsStrings.editorStock,
                placeholder: MedicationsStrings.editorStockPlaceholder,
                keyboard: .decimal
            )
            SalusTextField(
                text: Binding(
                    get: { state.stockThresholdInput },
                    set: { onEvent(.stockThresholdChanged($0)) }
                ),
                label: MedicationsStrings.editorStockThreshold,
                placeholder: MedicationsStrings.editorStockThresholdPlaceholder,
                keyboard: .decimal
            )
        }
    }

    /// `onCheckedChange = { on -> tracking = on; if (!on) { clear both } }`
    /// (`MedicationEditorSections.kt:299-308`).
    ///
    /// The setter is a closure literal rather than a stored function passed through: `Binding`'s
    /// setter is `@isolated(any) @Sendable`, and only a literal written here picks up this view's
    /// main-actor isolation.
    private var isOn: Binding<Bool> {
        Binding(
            get: { tracking },
            set: { on in
                tracking = on
                guard !on else { return }
                onEvent(.stockCountChanged(""))
                onEvent(.stockThresholdChanged(""))
            }
        )
    }
}
