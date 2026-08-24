// Divergence (e): Android hands a prefilled `Intent(ACTION_INSERT)` to whichever calendar app
// answers it (`AppointmentDetailScreen.kt:377-388`); iOS has no such hand-off, so the system's own
// event editor is presented instead and the user confirms there. Same contract on both platforms —
// Salus never writes to the calendar itself, it only proposes an event.
//
// **No calendar authorization is requested, and none is needed.** `EKEventEditViewController` runs
// out of process on iOS 17+: the app never sees the user's calendars, so presenting it requires no
// entitlement and shows no permission prompt (WWDC23, "Discover Calendar and EventKit"). The
// `EKEventStore` below therefore exists only to give the draft `EKEvent` an owner — nothing is read
// from it and nothing is saved through it. If this ever starts prompting, the fix is
// `NSCalendarsWriteOnlyAccessUsageDescription` plus `requestWriteOnlyAccessToEvents()`, and that
// would be a change to `App/`'s Info.plist strings, not to this file alone.
//
// The whole file is compiled only where EventKitUI exists — iOS. `swift test` runs on a macOS host,
// where EventKitUI is unavailable; everything else in the feature, `CalendarEventDraft` included,
// stays testable there because none of it imports EventKit.

#if canImport(EventKitUI)

    import EventKit
    import EventKitUI
    import SwiftUI

    /// The system's "new event" editor, prefilled from a `CalendarEventDraft`.
    ///
    /// - Parameter onDismiss: called for **any** outcome — saved, cancelled, deleted. The presenting
    ///   view clears its `isPresented` binding there, which is what actually takes the sheet down;
    ///   `EKEventEditViewController` never dismisses itself.
    struct CalendarEventEditSheet: UIViewControllerRepresentable {
        let draft: CalendarEventDraft
        let onDismiss: () -> Void

        func makeUIViewController(context: Context) -> EKEventEditViewController {
            let eventStore = EKEventStore()
            let event = EKEvent(eventStore: eventStore)
            event.title = draft.title
            event.notes = draft.notes
            event.location = draft.location
            event.startDate = draft.start
            event.endDate = draft.end

            let controller = EKEventEditViewController()
            controller.eventStore = eventStore
            controller.event = event
            controller.editViewDelegate = context.coordinator
            return controller
        }

        /// Nothing to update: the draft is read once, when the sheet is presented, and a new draft
        /// arrives as a new presentation.
        func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}

        func makeCoordinator() -> Coordinator {
            Coordinator(onDismiss: onDismiss)
        }

        /// Bridges the UIKit delegate back to the SwiftUI binding.
        ///
        /// Deliberately **not** `@MainActor`: `EKEventEditViewDelegate` is imported without an actor,
        /// so a main-actor witness would not satisfy the requirement, and hopping through
        /// `MainActor.assumeIsolated` from here would send this nonisolated object into the main
        /// actor's domain — which is the data race Swift 6 refuses to compile. The callback is
        /// therefore invoked directly; EventKitUI always delivers it on the main thread, and this
        /// object is created, used and released there and nowhere else.
        final class Coordinator: NSObject, EKEventEditViewDelegate {
            private let onDismiss: () -> Void

            init(onDismiss: @escaping () -> Void) {
                self.onDismiss = onDismiss
            }

            func eventEditViewController(
                _ controller: EKEventEditViewController,
                didCompleteWith action: EKEventEditViewAction
            ) {
                onDismiss()
            }
        }
    }

    #Preview("Calendar event editor") {
        // `verbatim:` is not needed here — these are arguments to a plain `String` parameter, not
        // `Text(_:)`'s `LocalizedStringKey` overload, so Xcode's extractor does not read them as keys.
        CalendarEventEditSheet(
            draft: CalendarEventDraft(
                title: "Annual check-up",
                notes: "Bring the last blood test results.",
                location: "City Clinic, Room 204",
                start: Date(timeIntervalSince1970: 1_776_000_000),
                end: Date(timeIntervalSince1970: 1_776_001_800)
            ),
            onDismiss: {}
        )
    }

#endif
