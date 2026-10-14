import SwiftUI

/// Which appointment detail a reminder tap pushed, and the stack depth it left behind.
///
/// A type of its own rather than a tuple so the comparison in `pushAppointmentDetail` is one
/// equality against one value; both fields have to match for the push to be a duplicate.
struct PushedAppointmentDetail: Equatable {
    let id: String
    let depth: Int
}

/// What sits on top of More's stack from the smoking screens: the main screen (`stageId == nil`) or
/// the timeline highlighting `stageId` over it, and the depth the stack had with it on top.
///
/// Seeded by a reminder tap and by More pushing `SmokingKey` itself; `pushSmoking` compares both
/// fields, because the same depth with another stage is a different highlight, not a duplicate.
struct PushedSmokingScreens: Equatable {
    let stageId: String?
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
