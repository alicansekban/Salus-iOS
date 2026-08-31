import SwiftUI

/// Which appointment detail a reminder tap pushed, and the stack depth it left behind.
///
/// A type of its own rather than a tuple so the comparison in `pushAppointmentDetail` is one
/// equality against one value; both fields have to match for the push to be a duplicate.
struct PushedAppointmentDetail: Equatable {
    let id: String
    let depth: Int
}

#Preview("Light") {
    RootView()
        .environment(AppCompositionRoot())
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    RootView()
        .environment(AppCompositionRoot())
        .preferredColorScheme(.dark)
}
