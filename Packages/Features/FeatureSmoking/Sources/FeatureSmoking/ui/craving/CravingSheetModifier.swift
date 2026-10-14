// No Kotlin twin: Android hosts the two sheets as two `when (sheet)` branches of the screen, each a
// `ModalBottomSheet` in its own window. SwiftUI cannot present two sheets at once, and the slip
// sheet's confirm swaps one for the other in a single state change, so both live in ONE presentation
// here — the same shape as the main screen's ``MainSheetModifier``, over ``CravingSheet`` and
// ``CravingEvent``. Every dismissal route (close button, swipe, scrim) reports the event that sheet
// treats as leaving it: ``CravingEvent/slipDismissed`` or ``CravingEvent/triggerSkipped``.

import SalusUI
import SwiftUI

struct CravingSheetModifier: ViewModifier {
    let sheet: CravingSheet?
    let writing: Bool
    let onEvent: (CravingEvent) -> Void

    /// The sheet last shown. While the sheet slides away `sheet` is already `nil`; drawing the last
    /// content through the animation keeps it from emptying out first.
    @State private var shown: CravingSheet?

    func body(content: Content) -> some View {
        content
            .salusBottomSheet(isPresented: isPresented, title: title, sizing: .fitted) {
                sheetContent
            }
            .onChange(of: sheet, initial: true) { _, new in
                if let new {
                    shown = new
                }
            }
    }

    private var current: CravingSheet? {
        sheet ?? shown
    }

    private var isPresented: Binding<Bool> {
        Binding(
            get: { sheet != nil },
            set: { presented in
                guard !presented else { return }
                switch sheet {
                case .slip: onEvent(.slipDismissed)
                case .trigger: onEvent(.triggerSkipped)
                case nil: break
                }
            }
        )
    }

    private var title: String {
        switch current {
        case .slip: SmokingStrings.slipTitle
        case .trigger: SmokingStrings.triggerTitle
        case nil: ""
        }
    }

    @ViewBuilder private var sheetContent: some View {
        switch current {
        case .slip:
            SlipSheet(
                initialUnits: CravingDefaults.slipDefaultUnits,
                writing: writing,
                onConfirm: { units, restart in onEvent(.slipConfirmed(units: units, restart: restart)) },
                onDismiss: { onEvent(.slipDismissed) }
            )

        case .trigger:
            TriggerSheet(
                writing: writing,
                onSave: { trigger, intensity in onEvent(.triggerSaved(trigger: trigger, intensity: intensity)) },
                onSkip: { onEvent(.triggerSkipped) }
            )

        case nil:
            EmptyView()
        }
    }
}

extension View {
    /// Hosts the craving flow's slip and trigger sheets.
    func cravingSheets(
        _ sheet: CravingSheet?,
        writing: Bool,
        onEvent: @escaping (CravingEvent) -> Void
    ) -> some View {
        modifier(CravingSheetModifier(sheet: sheet, writing: writing, onEvent: onEvent))
    }
}
