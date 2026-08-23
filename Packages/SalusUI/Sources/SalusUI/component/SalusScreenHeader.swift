// Ported from `core/ui/.../component/SalusScreenHeader.kt:26-47`.

import SalusDesignSystem
import SwiftUI

/// Large-title screen header for top-level destinations, with an optional trailing action
/// slot. Detail screens keep using `.navigationTitle` + `.toolbar` — the twin of Kotlin's
/// "detail screens keep using `TopAppBar`" note (`SalusScreenHeader.kt:21-24`).
public struct SalusScreenHeader<Actions: View>: View {
    private let title: String
    private let actions: Actions

    @Environment(\.salusTheme) private var theme

    public init(title: String, @ViewBuilder actions: () -> Actions) {
        self.title = title
        self.actions = actions()
    }

    public var body: some View {
        // Zero, matching Compose's `Arrangement.Start` default: the trailing icon buttons carry
        // their own touch-target padding, and a gap here would double it.
        HStack(spacing: 0) {
            Text(title)
                .font(SalusTypography.headlineLarge.font)
                .tracking(SalusTypography.headlineLarge.tracking)
                .foregroundStyle(theme.colorScheme.onBackground)
                // `Modifier.weight(1f)` (`SalusScreenHeader.kt:41`).
                .frame(maxWidth: .infinity, alignment: .leading)
            actions
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, SalusSpacing.lg)
        .padding(.vertical, SalusSpacing.md)
    }
}

extension SalusScreenHeader where Actions == EmptyView {
    /// The header with no trailing actions — Kotlin's `actions: (…)? = null` default
    /// (`SalusScreenHeader.kt:29`).
    public init(title: String) {
        self.init(title: title, actions: { EmptyView() })
    }
}

#Preview("Screen header") {
    let theme = SalusTheme.resolve(systemIsDark: false)
    return VStack(spacing: 0) {
        SalusScreenHeader(title: "Vitals") {
            Button {} label: {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(theme.colorScheme.onBackground)
            }
            .buttonStyle(.plain)
            .frame(minWidth: SalusTouchTarget.min, minHeight: SalusTouchTarget.min)
        }
        SalusScreenHeader(title: "Medications")
        Spacer()
    }
    .background(theme.colorScheme.background)
    .salusTheme(theme)
}
