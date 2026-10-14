// No Kotlin twin: Android hosts the two sheets as two `when (sheet)` branches of the screen, each
// a `ModalBottomSheet` in its own window. SwiftUI cannot present two sheets at once, and the slip
// sheet's confirm swaps one for the other in a single state change, so both live in ONE
// presentation here: `isPresented` is "there is a sheet", the title and the content follow
// ``MainSheet``, and the sheet stays up while its content changes from "Olur böyle şeyler" to
// "Ne tetikledi?". Every dismissal route (close button, swipe, scrim) reports the event that sheet
// treats as leaving it: ``SmokingMainEvent/slipDismissed`` or ``SmokingMainEvent/triggerSkipped``.

import SalusUI
import SwiftUI

struct MainSheetModifier: ViewModifier {
    let sheet: MainSheet?
    let writing: Bool
    let onEvent: (SmokingMainEvent) -> Void

    /// The sheet last shown. While the sheet slides away `sheet` is already `nil`; drawing the
    /// last content through the animation keeps it from emptying out first.
    @State private var shown: MainSheet?

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

    private var current: MainSheet? {
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
        case let .slip(units):
            SlipSheet(
                initialUnits: units,
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
    /// Hosts the main screen's slip and trigger sheets.
    func mainSheets(
        _ sheet: MainSheet?,
        writing: Bool,
        onEvent: @escaping (SmokingMainEvent) -> Void
    ) -> some View {
        modifier(MainSheetModifier(sheet: sheet, writing: writing, onEvent: onEvent))
    }
}
