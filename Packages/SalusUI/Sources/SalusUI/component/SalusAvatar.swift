// Ported from `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/component/
// SalusAvatar.kt:34-95` in its M15 shape.
//
// Kotlin's composable takes `name`, `size` (defaulting to `SalusAvatarDefaults.Size` = 48),
// `containerColor` (defaulting to `colorScheme.primaryContainer`) and `contentColor`
// (defaulting to `colorScheme.onPrimaryContainer`) (`SalusAvatar.kt:36-42`). The M15 avatar sits
// on `primaryContainer` with `onPrimaryContainer` glyphs — the tinted circle, not the strong
// primary disc of the M14 port.
//
// The initials rule is `SalusAvatar.kt:87-94`: first letters of the first two whitespace-separated
// words, uppercased; one char if a single word; `nil` for a blank name. The text style switch is
// `SalusAvatarDefaults.LargeSize` = 72 (`SalusAvatar.kt:61-65`): `titleMedium` below it,
// `titleLarge` at or above it.

import SalusDesignSystem
import SwiftUI

/// Circular avatar on `primaryContainer`, showing the person's initials or a person glyph when no
/// name is available — the shared leading visual for people across Home and Profile
/// (`SalusAvatar.kt:29-34`).
public struct SalusAvatar: View {
    private let name: String?
    private let size: CGFloat

    @Environment(\.salusTheme) private var theme

    /// - Parameters:
    ///   - name: the person's name; `nil` or blank draws the person glyph.
    ///   - size: the circle's diameter (`SalusAvatar.kt:38`).
    public init(
        name: String?,
        size: CGFloat = SalusAvatarDefaults.size
    ) {
        self.name = name
        self.size = size
    }

    public var body: some View {
        let initials = Self.initials(from: name)

        Circle()
            .fill(theme.colorScheme.primaryContainer)
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
                        .foregroundStyle(theme.colorScheme.onPrimaryContainer)
                } else {
                    // `Icons.Filled.Person` (`SalusAvatar.kt:51-55`), tinted `onPrimaryContainer`
                    // and drawn at half the avatar's diameter. `person.fill` is the plain bust —
                    // the closer twin to Material's `Person` than `person.crop.circle.fill`,
                    // which would draw a person-in-a-circle inside the tinted circle.
                    Image(systemName: "person.fill")
                        .font(.system(size: size / 2))
                        .foregroundStyle(theme.colorScheme.onPrimaryContainer)
                }
            }
            // `contentDescription = null` (`SalusAvatar.kt:51-55`): the avatar repeats the name the
            // row beside it already says.
            .accessibilityHidden(true)
    }

    /// First letters of the first two whitespace-separated words, uppercased; one char if a
    /// single word; `nil` for a `nil` or blank name (`SalusAvatar.kt:87-94`).
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

/// `object SalusAvatarDefaults` (`SalusAvatar.kt:71-84`). Component dimensions, not design tokens
/// — Android keeps them in `:core:ui` too, not in `:core:designsystem`.
public enum SalusAvatarDefaults {
    /// `SalusAvatarDefaults.Size` (`SalusAvatar.kt:72`).
    public static let size: CGFloat = 48
    /// `SalusAvatarDefaults.LargeSize` (`SalusAvatar.kt:73`).
    public static let largeSize: CGFloat = 72
    /// The root toolbar's avatar. Kotlin has no `SalusAvatarDefaults` entry for it because its
    /// top bar draws a disc of its own rather than this component; the value is that disc's,
    /// `SalusTopBarDefaults.MarkSize` (`SalusTopBar.kt:60`), so the two platforms put the same
    /// 32 pt circle in the same corner.
    public static let toolbar: CGFloat = 32
}

#Preview("Avatars") {
    SalusPreviewPalettes {
        HStack(spacing: SalusSpacing.sm) {
            SalusAvatar(name: "Alican Sekban")
            SalusAvatar(name: "Ayşe", size: SalusAvatarDefaults.largeSize)
            SalusAvatar(name: nil)
        }
    }
}
