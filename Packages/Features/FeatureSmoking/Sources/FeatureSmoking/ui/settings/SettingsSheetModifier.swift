// No Kotlin twin: Android hosts the settings screen's seven editors as the branches of one
// `when (sheet)`, each a `ModalBottomSheet` in its own window. SwiftUI presents one sheet at a time,
// and a pick can swap one editor for the next in a single state change (a currency is chosen and
// then confirmed), so they live in ONE presentation here: `isPresented` is "there is a sheet", the
// title and the content follow ``SettingsSheet``. Every dismissal route (close button, swipe, scrim)
// reports ``SmokingSettingsEvent/sheetDismissed``, which the ViewModel ignores while a write is in
// flight.

import SalusCommon
import SalusSmoking
import SalusUI
import SwiftUI

struct SettingsSheetModifier: ViewModifier {
    let state: SmokingSettingsUiState
    let clock: any SalusClock
    let onEvent: (SmokingSettingsEvent) -> Void

    /// The sheet last shown. While the sheet slides away `state.sheet` is already `.none`; drawing
    /// the last content through the animation keeps it from emptying out first.
    @State private var shown: SettingsSheet = .none

    func body(content: Content) -> some View {
        content
            .salusBottomSheet(isPresented: isPresented, title: title, sizing: .fitted) {
                sheetContent
            }
            .onChange(of: state.sheet, initial: true) { _, new in
                if new != .none {
                    shown = new
                }
            }
    }

    private var current: SettingsSheet {
        state.sheet == .none ? shown : state.sheet
    }

    private var isPresented: Binding<Bool> {
        Binding(
            get: { state.sheet != .none },
            set: { presented in
                if !presented {
                    onEvent(.sheetDismissed)
                }
            }
        )
    }

    private var title: String {
        switch current {
        case .price: SmokingStrings.settingsPriceSheetTitle
        case .limit: SmokingStrings.settingsLimitSheetTitle
        case .currency: SmokingStrings.settingsCurrencySheetTitle
        case .reason: SmokingStrings.settingsReasonSheetTitle
        case .quitDate, .switchToQuit: SmokingStrings.quitSheetTitle
        case .switchToReduce: SmokingStrings.settingsReduceSheetTitle
        case .none: ""
        }
    }

    @ViewBuilder private var sheetContent: some View {
        switch current {
        case .price:
            PriceSheet(
                currencyCode: state.currencyCode,
                unitCostMinor: state.unitCostMinor,
                product: state.productType,
                writing: state.writing,
                onSave: { onEvent(.priceSaved(unitCostMinor: $0)) }
            )

        case .limit:
            LimitSheet(
                confirmLabel: SmokingStrings.settingsSave,
                initialLimit: state.dailyLimit ?? 1,
                writing: state.writing,
                onConfirm: { onEvent(.limitSaved($0)) }
            )

        case .currency:
            CurrencySheet(selected: state.currencyCode, onPick: { onEvent(.currencyPicked($0)) })

        case .reason:
            ReasonSheet(
                initialReason: state.reason,
                writing: state.writing,
                onSave: { onEvent(.reasonSaved($0)) }
            )

        case let .quitDate(initialMs):
            QuitDateSheet(
                initialMs: initialMs,
                onConfirm: { onEvent(.quitDatePicked($0)) },
                onDismiss: { onEvent(.sheetDismissed) },
                clock: clock
            )

        case let .switchToReduce(suggestedLimit):
            LimitSheet(
                confirmLabel: SmokingStrings.settingsReduceSheetConfirm,
                initialLimit: suggestedLimit,
                writing: state.writing,
                note: SmokingStrings.settingsSwitchToReduceDesc,
                // A vape counts sessions with a baseline of one, so "currently n" would say nothing.
                baselineUnitsPerDay: state.productType == .vape ? nil : state.baselineUnitsPerDay,
                onConfirm: { onEvent(.switchToReduceConfirmed(limit: $0)) }
            )

        case let .switchToQuit(initialMs):
            QuitDateSheet(
                initialMs: initialMs,
                onConfirm: { onEvent(.switchToQuitConfirmed(quitAtMs: $0)) },
                onDismiss: { onEvent(.sheetDismissed) },
                clock: clock
            )

        case .none:
            EmptyView()
        }
    }
}

extension View {
    /// Hosts the settings screen's editors.
    func settingsSheets(
        _ state: SmokingSettingsUiState,
        clock: any SalusClock,
        onEvent: @escaping (SmokingSettingsEvent) -> Void
    ) -> some View {
        modifier(SettingsSheetModifier(state: state, clock: clock, onEvent: onEvent))
    }
}
