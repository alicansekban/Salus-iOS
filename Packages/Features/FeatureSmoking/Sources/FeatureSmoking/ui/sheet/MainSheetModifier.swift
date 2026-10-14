// No Kotlin twin: Android hosts the two sheets as two `when (sheet)` branches of the screen, each
// a `ModalBottomSheet` in its own window. SwiftUI cannot present two sheets at once, and the slip
// sheet's confirm swaps one for the other in a single state change, so both live in ONE
// presentation here: `isPresented` is "there is a sheet", the title and the content follow
// ``MainSheet``, and the sheet stays up while its content changes from "Olur böyle şeyler" to
// "Ne tetikledi?". Every dismissal route (close button, swipe, scrim) reports the event that sheet
// treats as leaving it: ``SmokingMainEvent/slipDismissed``, ``SmokingMainEvent/triggerSkipped``,
// for REDUCE's "Bırakmaya hazırım" ``SmokingMainEvent/quitDateDismissed`` and, for the savings goal,
// ``SmokingMainEvent/goalDismissed``.
//
// The quit-date sheet's confirm closes it as well as handing its instant up (`QuitDateSheet`), and
// the ViewModel ignores a dismissal while the write is in flight and keeps the sheet for a refused
// one — the binding reads `sheet`, not what the sheet last asked for.

import SalusCommon
import SalusUI
import SwiftUI

struct MainSheetModifier: ViewModifier {
    let sheet: MainSheet?
    let writing: Bool
    /// The plan's currency, which the goal sheet types its target in.
    let currencyCode: String?
    /// "Now" for the quit-date sheet's starting moment and its future check.
    let clock: any SalusClock
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
                case .quitDate: onEvent(.quitDateDismissed)
                case .goal: onEvent(.goalDismissed)
                case nil: break
                }
            }
        )
    }

    private var title: String {
        switch current {
        case .slip: SmokingStrings.slipTitle
        case .trigger: SmokingStrings.triggerTitle
        case .quitDate: SmokingStrings.quitSheetTitle
        case .goal: SmokingStrings.goalSheetTitle
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

        case .quitDate:
            QuitDateSheet(
                initialMs: clock.nowEpochMilliseconds(),
                onConfirm: { onEvent(.quitDateConfirmed(quitAtMs: $0)) },
                onDismiss: { onEvent(.quitDateDismissed) },
                clock: clock
            )

        case let .goal(title, targetMinor, editingGoalId):
            // A goal sheet only opens over a plan, so the currency is there; without it there is
            // nothing to type an amount in.
            if let currencyCode {
                GoalSheet(
                    currencyCode: currencyCode,
                    initialTitle: title,
                    initialTargetMinor: targetMinor,
                    editing: editingGoalId != nil,
                    writing: writing,
                    onSave: { title, target in onEvent(.goalSaved(title: title, targetMinor: target)) }
                )
            }

        case nil:
            EmptyView()
        }
    }
}

extension View {
    /// Hosts the main screen's slip, trigger, quit-date and savings-goal sheets.
    func mainSheets(
        _ sheet: MainSheet?,
        writing: Bool,
        currencyCode: String?,
        clock: any SalusClock,
        onEvent: @escaping (SmokingMainEvent) -> Void
    ) -> some View {
        modifier(
            MainSheetModifier(
                sheet: sheet,
                writing: writing,
                currencyCode: currencyCode,
                clock: clock,
                onEvent: onEvent
            )
        )
    }
}
