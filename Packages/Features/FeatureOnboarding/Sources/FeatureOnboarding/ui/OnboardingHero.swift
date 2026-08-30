// Ported 1:1 from
// `feature/onboarding/src/main/kotlin/com/alicansekban/salus/feature/onboarding/ui/
// OnboardingHero.kt`.
//
// Material → SwiftUI, and the mapping is mechanical because the whole file is boxes and circles:
//   `Box(Modifier.size(n))`          → `.frame(width: n, height: n)`.
//   `.background(color, CircleShape)`→ `.background(color, in: Circle())`.
//   `.background(color,             → `.background(color, in: RoundedRectangle(cornerRadius: 48,
//     RoundedCornerShape(48.dp))`      style: .continuous))` — `SalusShapes.rounded(_:)` is for the
//                                      five *token* radii (`SalusDimensions.swift:32-36`); 48 is a
//                                      component dimension this file owns, exactly as Kotlin owns
//                                      `WelcomeShieldCorner`, so it is spelled here.
//   `BoxScope.align(TopEnd)          → `.overlay(alignment: .topTrailing) { … .offset(…) }` on the
//    + .offset(x, y)`                  cluster box. Compose's y grows downward and so does
//                                      SwiftUI's, so the four offsets carry over sign for sign.
//   `Icons.Outlined.X`               → SF Symbols: `Shield`→`shield`, `Medication`→`pills` (the
//                                      name `MedicationsStrings`' rows already use),
//                                      `Notifications`→`bell`, `Favorite`→`heart`. Outlined, not
//                                      filled, so none of the four takes a `.fill` suffix.
//   `clearAndSetSemantics {}`        → `.accessibilityHidden(true)`. The cluster is decoration; the
//                                      heading under it already says what the picture stands for.
//
// The nine dimensions are the Kotlin file's own private vals (`OnboardingHero.kt:142-150`) —
// component dimensions, not `design-tokens.md` tokens, so they live beside the view on this side
// too rather than growing the token table.

import SalusDesignSystem
import SwiftUI

/// The two steps that lead with a picture instead of a question (`OnboardingHero.kt:32`).
enum OnboardingHeroVariant {
    case welcome
    case notifications
}

/// Decorative cluster at the top of the Welcome and Notifications steps (`OnboardingHero.kt:40-55`).
/// Purely visual — it is hidden from the accessibility tree, because the heading underneath already
/// says everything the picture is standing in for.
struct OnboardingHero: View {
    let variant: OnboardingHeroVariant

    @Environment(\.salusTheme) private var theme

    var body: some View {
        Group {
            switch variant {
            case .welcome: welcomeCluster
            case .notifications: notificationsCluster
            }
        }
        .frame(width: Dimensions.cluster, height: Dimensions.cluster)
        .accessibilityHidden(true)
    }

    /// `WelcomeCluster` (`OnboardingHero.kt:58-82`).
    private var welcomeCluster: some View {
        let colors = theme.colorScheme
        return Image(systemName: "shield")
            .font(.system(size: Dimensions.welcomeIcon))
            .foregroundStyle(colors.primary)
            .frame(width: Dimensions.welcomeInner, height: Dimensions.welcomeInner)
            .background(colors.surfaceContainerLowest, in: Circle())
            .frame(width: Dimensions.welcomeShield, height: Dimensions.welcomeShield)
            .background(
                colors.primaryContainer,
                in: RoundedRectangle(
                    cornerRadius: Dimensions.welcomeShieldCorner,
                    style: .continuous
                )
            )
    }

    /// `NotificationsCluster` (`OnboardingHero.kt:85-117`) — the pill circle with a bell and a
    /// heart orbiting it.
    private var notificationsCluster: some View {
        let colors = theme.colorScheme
        let vitals = theme.extendedColors.vitals
        return Image(systemName: "pills")
            .font(.system(size: Dimensions.centralIcon))
            .foregroundStyle(colors.onPrimary)
            .frame(width: Dimensions.centralCircle, height: Dimensions.centralCircle)
            .background(colors.primary, in: Circle())
            .frame(width: Dimensions.cluster, height: Dimensions.cluster)
            .overlay(alignment: .topTrailing) {
                SatelliteBadge(
                    systemImage: "bell",
                    background: colors.tertiary,
                    tint: colors.onTertiary,
                    size: Dimensions.bellBadge
                )
                .offset(x: -8, y: 12)
            }
            .overlay(alignment: .bottomLeading) {
                SatelliteBadge(
                    systemImage: "heart",
                    background: vitals.accent,
                    tint: vitals.onAccent,
                    size: Dimensions.heartBadge
                )
                .offset(x: 4, y: -24)
            }
    }
}

/// `SatelliteBadge` (`OnboardingHero.kt:120-140`) — a tinted circle with an icon at half its size.
private struct SatelliteBadge: View {
    let systemImage: String
    let background: Color
    let tint: Color
    let size: CGFloat

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size / 2))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(background, in: Circle())
    }
}

/// `OnboardingHero.kt:142-150`. Component dimensions, not design tokens.
private enum Dimensions {
    static let cluster: CGFloat = 192
    static let welcomeShield: CGFloat = 160
    static let welcomeShieldCorner: CGFloat = 48
    static let welcomeInner: CGFloat = 96
    static let welcomeIcon: CGFloat = 40
    static let centralCircle: CGFloat = 128
    static let centralIcon: CGFloat = 48
    static let bellBadge: CGFloat = 48
    static let heartBadge: CGFloat = 38
}

// `OnboardingHeroPreview` (`OnboardingHero.kt:152-163`).
#Preview("Onboarding heroes") {
    let theme = SalusTheme.resolve(systemIsDark: false)
    return ZStack {
        theme.colorScheme.background
        HStack(spacing: 0) {
            OnboardingHero(variant: .welcome)
            OnboardingHero(variant: .notifications)
        }
    }
    .salusTheme(theme)
}
