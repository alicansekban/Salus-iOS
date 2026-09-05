// Ported from `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/component/
// SalusAvatar.kt:34-95`.
//
// Kotlin's composable takes `name`, `size` (defaulting to `SalusAvatarDefaults.Size` = 48) and
// `gradient` (defaulting to `MaterialTheme.salusColors.hero`). The iOS port keeps the same three
// knobs, with one deliberate difference: `gradient` is `SalusGradient? = nil` and the hero
// gradient is resolved from the environment at render time (`SalusAvatar.kt:39`), because the
// resolved theme travels in the environment rather than as a parameter (CLAUDE.md, design system
// rules). A caller that wants a non-hero gradient passes it explicitly.
//
// The initials rule is `SalusAvatar.kt:88-95`: first letters of the first two whitespace-separated
// words, uppercased; one char if a single word; `nil` for a blank name. The text style switches
// at `SalusAvatarDefaults.LargeSize` = 72 (`SalusAvatar.kt:62-66`): `titleMedium` below it,
// `titleLarge` at or above it.

import SalusDesignSystem
import SwiftUI

/// Circular avatar filled with the hero gradient, showing the person's initials or a person icon
/// when no name is available — the shared leading visual for people across Home and Profile
/// (`SalusAvatar.kt:29-33`).
public struct SalusAvatar: View {
    private let name: String?
    private let size: CGFloat
    private let gradient: SalusGradient?

    @Environment(\.salusTheme) private var theme

    /// - Parameters:
    ///   - name: the person's name; `nil` or blank draws the person icon (`SalusAvatar.kt:51-57`).
    ///   - size: the circle's diameter (`SalusAvatar.kt:38`).
    ///   - gradient: the fill; `nil` resolves `theme.extendedColors.hero` at render
    ///     (`SalusAvatar.kt:39`).
    public init(
        name: String?,
        size: CGFloat = SalusAvatarDefaults.size,
        gradient: SalusGradient? = nil
    ) {
        self.name = name
        self.size = size
        self.gradient = gradient
    }

    public var body: some View {
        let resolvedGradient = gradient ?? theme.extendedColors.hero
        let initials = Self.initials(from: name)

        Circle()
            .fill(resolvedGradient.vertical)
            .frame(width: size, height: size)
            .overlay {
                if let initials {
                    Text(verbatim: initials)
                        .font(
                            (size >= SalusAvatarDefaults.largeSize
                                ? SalusTypography.titleLarge
                                : SalusTypography.titleMedium).font
                        )
                        .tracking(
                            size >= SalusAvatarDefaults.largeSize
                                ? SalusTypography.titleLarge.tracking
                                : SalusTypography.titleMedium.tracking
                        )
                        .foregroundStyle(.white)
                } else {
                    // `Icons.Filled.Person` (`SalusAvatar.kt:53`), tinted white and drawn at
                    // half the avatar's diameter (`SalusAvatar.kt:56`).
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: size / 2))
                        .foregroundStyle(.white)
                }
            }
            // `contentDescription = null` (`SalusAvatar.kt:54`): the avatar repeats the name the
            // row beside it already says.
            .accessibilityHidden(true)
    }

    /// First letters of the first two whitespace-separated words, uppercased; one char if a
    /// single word; `nil` for a `nil` or blank name (`SalusAvatar.kt:88-95`).
    /// `nonisolated` so the pure helper is callable from a nonisolated test context.
    nonisolated static func initials(from name: String?) -> String? {
        guard let name else { return nil }
        let words = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .filter { !$0.isEmpty }
        guard let first = words.first, let firstChar = first.first else { return nil }
        var result = String(firstChar).uppercased()
        if words.count > 1, let secondChar = words[1].first {
            result += String(secondChar).uppercased()
        }
        return result
    }
}

/// `object SalusAvatarDefaults` (`SalusAvatar.kt:72-85`). Component dimensions, not design tokens
/// — Android keeps them in `:core:ui` too, not in `:core:designsystem`.
public enum SalusAvatarDefaults {
    /// `SalusAvatarDefaults.Size` (`SalusAvatar.kt:73`).
    public static let size: CGFloat = 48
    /// `SalusAvatarDefaults.LargeSize` (`SalusAvatar.kt:74`).
    public static let largeSize: CGFloat = 72
}

#Preview("Avatars") {
    let theme = SalusTheme.resolve(systemIsDark: false)
    return ZStack {
        theme.colorScheme.surfaceContainerLow
        HStack(spacing: SalusSpacing.sm) {
            SalusAvatar(name: "Alican Sekban")
            SalusAvatar(name: "Ayşe", size: SalusAvatarDefaults.largeSize)
            SalusAvatar(name: nil)
        }
        .padding(SalusSpacing.lg)
    }
    .frame(height: 120)
    .salusTheme(theme)
}
