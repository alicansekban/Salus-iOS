import SalusModel

/// The five bottom-navigation destinations.
///
/// A 1:1 mirror of Android's `TopLevelDestination` list — `salus-android/app/src/main/kotlin/
/// com/alicansekban/salus/ui/SalusApp.kt:78-82` — in the same order, which is the order the
/// M9 restructure settled on. Order is behavior here: it is what the user sees left to right,
/// so it is pinned to the Android list rather than to anything alphabetical.
enum RootTab: String, CaseIterable, Identifiable {
    case home
    case medications
    case vitals
    case appointments
    case more

    var id: String { rawValue }

    /// A placeholder English label.
    ///
    /// M0 does no strings work by design (spec §10): the localized `nav_*` keys and the TR/EN
    /// parity rule arrive with the string catalogs. These five words exist only so the tab bar
    /// has something to draw, and every one of them is expected to be deleted — not translated
    /// — when `nav_home`, `nav_medications`, `nav_vitals`, `nav_appointments` and `nav_more`
    /// are ported.
    var placeholderLabel: String {
        switch self {
        case .home: "Home"
        case .medications: "Medications"
        case .vitals: "Vitals"
        case .appointments: "Appointments"
        case .more: "More"
        }
    }

    /// The SF Symbol standing in for the Material icon Android draws.
    ///
    /// Android carries a filled/outlined pair per destination and swaps on selection
    /// (`SalusApp.kt:145-150`). SF Symbols expresses the same distinction through the symbol
    /// variant the tab bar picks automatically, so one name per tab is the iOS-native spelling
    /// of that pair rather than a simplification of it.
    var symbolName: String {
        switch self {
        case .home: "house" // Icons.Filled/Outlined.Home
        case .medications: "pills" // Icons.Filled/Outlined.Medication
        case .vitals: "waveform.path.ecg" // Icons.Filled/Outlined.MonitorHeart
        case .appointments: "calendar" // Icons.Filled/Outlined.CalendarMonth
        case .more: "ellipsis.circle" // Icons.Filled/Outlined.MoreHoriz
        }
    }
}

extension RootTab {
    /// Which tab a fired reminder belongs to.
    ///
    /// The two obvious ones are the tabs of the same name. Cycle is the third, and it is `home`
    /// rather than a tab of its own because Android's M9 restructure removed the cycle tab and
    /// pushes `CycleKey` onto Home's stack instead (`SalusApp.kt:189`); the iOS shell mirrors that
    /// list, so it lands on Home here too.
    ///
    /// Since iOS-M6 the cycle answer is more than a tab: `RootView.openTappedReminder` pushes
    /// `CycleKey` onto the stack this returns, so a tapped cycle reminder opens the calendar rather
    /// than stopping at Home's root. That is an iOS-only behaviour — Android's tap builds a
    /// launcher intent and goes no further (iOS-M6 divergence (c)).
    static func hosting(_ type: ReminderType) -> RootTab {
        switch type {
        case .medicationDose: .medications
        case .appointment: .appointments
        case .cyclePeriod: .home
        }
    }
}
