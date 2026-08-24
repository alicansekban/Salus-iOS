// The twin of the `titleSmall` group label Kotlin writes above a form section, e.g.
// `feature/appointments/src/main/kotlin/com/alicansekban/salus/feature/appointments/
// ui/editor/AppointmentEditorScreen.kt:310-313` (the reminder-offset row's heading).
//
// Note the name it shares with `core/ui/.../component/SalusSectionHeader.kt`, which is the *screen*
// section title above a group of cards — `titleLarge`, `onSurface`, with an optional trailing
// action. That one has no iOS caller yet; if it ever gains one it lands beside this file under the
// name Kotlin's other header earns, rather than by widening this one.

import SalusDesignSystem
import SwiftUI

/// Small heading above a group of form rows or chips.
public struct SalusSectionHeader: View {
    private let title: String

    @Environment(\.salusTheme) private var theme

    public init(title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title)
            .font(SalusTypography.titleSmall.font)
            .tracking(SalusTypography.titleSmall.tracking)
            .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, SalusSpacing.sm)
    }
}

#Preview("Section header") {
    let theme = SalusTheme.resolve(systemIsDark: false)
    return ZStack(alignment: .top) {
        theme.colorScheme.background
        VStack(alignment: .leading, spacing: 0) {
            SalusSectionHeader(title: "Reminders")
            SalusFilterChip(label: "1 hour before", isSelected: true, action: {})
        }
        .padding(SalusSpacing.lg)
    }
    .frame(height: 140)
    .salusTheme(theme)
}
