// Ported 1:1 from
// `feature/onboarding/src/main/kotlin/com/alicansekban/salus/feature/onboarding/ui/
// OnboardingStepContent.kt`.
//
// Material → SwiftUI, and the icon table is the bulk of it. Compose names an `ImageVector` from
// `Icons`; the iOS twin of that catalogue is SF Symbols, named rather than referenced:
//
//   Icons.Outlined.Wc              → `figure.dress.line.vertical.figure`  (the restroom pair)
//   Icons.Outlined.Cake            → `birthday.cake`
//   Icons.Outlined.Height          → `ruler`
//   Icons.Outlined.MonitorWeight   → `scalemass`
//   Icons.Outlined.EditNote        → `square.and.pencil`
//   Icons.Outlined.Shield          → `shield`
//   Icons.Outlined.Verified        → `checkmark.seal`
//   Icons.Filled.Lock              → `lock.fill`
//   Icons.Outlined.Female/Male/    → `figure.stand.dress` / `figure.stand` / `person.2`, the three
//     Transgender                    `ProfileScreen.swift:219-227` already chose. The sex step and
//                                    the profile editor must not disagree about which glyph means
//                                    which option, so this file reuses that mapping rather than
//                                    picking a second one.
//
// The rest of the mapping:
//   `SalusListItem`                → BUILT INLINE. `core/ui`'s `SalusListItem` has no iOS twin yet
//                                    (`SalusUI/component/` carries only its `SalusListItemChevron`),
//                                    and this is its single onboarding call site, so the row is
//                                    spelled here from the Kotlin's own layout
//                                    (`SalusListItem.kt:44-74`: badge, `lg` gap, title
//                                    `titleMedium`/`onSurface` over subtitle
//                                    `bodyMedium`/`onSurfaceVariant`, `lg`/`md` insets, a
//                                    `SalusTouchTarget.min` floor) rather than by promoting a
//                                    component this milestone has no second caller for.
//   `BasicTextField` +             → `TextEditor` with `.scrollContentBackground(.hidden)` and the
//     `decorationBox` placeholder    placeholder as a top-leading overlay. Compose's
//                                    `decorationBox` and SwiftUI's overlay are the same trick:
//                                    the field draws nothing of its own, the caller draws the
//                                    chrome.
//   `KeyboardCapitalization.       → `.textInputAutocapitalization(.sentences)`, iOS-only, so it
//     Sentences`                     sits behind `#if os(iOS)` exactly as `ProfileScreen.swift:129`
//                                    does for `.textContentType`.
//   `ContentType.PersonFullName`   → `.textContentType(.name)` (same precedent).
//   `imeAction = ImeAction.Done`   → DROPPED on both text steps, the recorded `SalusPillTextField`
//     (`:83`, `:281`)                divergence: Compose's IME action relabels the return key *and*
//                                    drives focus, SwiftUI splits those, and half of it is worse
//                                    than none. `SalusPillTextField.swift`'s header carries the
//                                    reasoning; the profile editor dropped `ImeAction.Next` for it.
//   `MaterialTheme.shapes.large`   → `SalusShapes.largeShape` (24, `SalusDimensions.swift:35`).
//
// `MeasureField` keeps Kotlin's name and shape but calls `SalusPillTextField` with
// `keyboard: .decimal`, which is where `MeasurementInput`'s comma→dot normalisation (divergence
// (h)) matters: the Turkish keyboard's decimal separator is a comma, and the state's
// `showInvalidWeight` already parses through it.

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// The body of whichever step is showing (`OnboardingStepContent.kt:60-189`).
struct OnboardingStepContent: View {
    let state: OnboardingUiState
    let onEvent: (OnboardingEvent) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        switch state.step {
        case .welcome:
            CenteredStep(
                hero: .welcome,
                title: OnboardingStrings.onboardingWelcomeTitle,
                message: OnboardingStrings.onboardingWelcomeBody
            )

        case .name:
            CenteredStep(
                title: OnboardingStrings.onboardingNameTitle,
                message: OnboardingStrings.onboardingNameBody
            ) {
                nameField
            }

        case .sex:
            LeadingStep(
                systemImage: "figure.dress.line.vertical.figure",
                title: OnboardingStrings.onboardingSexTitle,
                message: OnboardingStrings.onboardingSexBody
            ) {
                sexOptions
            }

        case .birthDate:
            CenteredStep(
                systemImage: "birthday.cake",
                title: OnboardingStrings.onboardingBirthTitle,
                message: OnboardingStrings.onboardingBirthBody
            ) {
                birthDateField
            }

        case .height:
            CenteredStep(
                systemImage: "ruler",
                title: OnboardingStrings.onboardingHeightTitle,
                message: OnboardingStrings.onboardingHeightBody
            ) {
                MeasureField(
                    value: state.heightText,
                    onValueChange: { onEvent(.heightChanged($0)) },
                    placeholder: OnboardingStrings.onboardingHeightPlaceholder,
                    suffix: "cm",
                    isError: state.showInvalidHeight,
                    error: OnboardingStrings.onboardingHeightInvalid
                )
            }

        case .weight:
            CenteredStep(
                systemImage: "scalemass",
                title: OnboardingStrings.onboardingWeightTitle,
                message: OnboardingStrings.onboardingWeightBody
            ) {
                MeasureField(
                    value: state.weightText,
                    onValueChange: { onEvent(.weightChanged($0)) },
                    placeholder: OnboardingStrings.onboardingWeightPlaceholder,
                    suffix: "kg",
                    isError: state.showInvalidWeight,
                    error: OnboardingStrings.onboardingWeightInvalid
                )
            }

        case .healthNotes:
            CenteredStep(
                systemImage: "square.and.pencil",
                title: OnboardingStrings.onboardingNotesTitle,
                message: OnboardingStrings.onboardingNotesBody
            ) {
                HealthNotesField(value: state.healthNotes) { onEvent(.healthNotesChanged($0)) }
                privacyCard
            }

        case .notifications:
            CenteredStep(
                hero: .notifications,
                title: OnboardingStrings.onboardingNotificationsTitle,
                message: OnboardingStrings.onboardingNotificationsBody
            ) {
                benefitCard
            }
        }
    }

    /// `OnboardingStepContent.kt:75-88`.
    private var nameField: some View {
        SalusPillTextField(
            text: Binding(get: { state.name }, set: { onEvent(.nameChanged($0)) }),
            placeholder: OnboardingStrings.onboardingNamePlaceholder,
            capitalization: .words,
            // `autoCorrectEnabled = false` (`:82`) — names are not dictionary words; the suggestion
            // strip only gets in the way.
            autocorrects: false
        )
        #if os(iOS)
        // `ContentType.PersonFullName` (`:87`) — one of only two fields in the app with a real
        // autofill category, so the suggestion bar can offer the device owner's own name here.
        .textContentType(.name)
        #endif
    }

    /// `OnboardingStepContent.kt:96-104`. The three rows are direct children of `LeadingStep`'s
    /// `Column(verticalArrangement = spacedBy(SalusSpacing.lg))` in Kotlin; SwiftUI has no
    /// per-child arrangement, so they need a wrapper — and the wrapper carries the same `lg`, or
    /// the gap between the rows would silently shrink to `md` (review M-1).
    private var sexOptions: some View {
        VStack(alignment: .leading, spacing: SalusSpacing.lg) {
            ForEach(Sex.allCases, id: \.self) { option in
                SalusOptionRow(
                    systemImage: option.onboardingSystemImage,
                    label: option.onboardingLabel,
                    isSelected: state.sex == option,
                    accent: option.onboardingAccent(theme)
                ) {
                    onEvent(.sexSelected(option))
                }
            }
        }
    }

    /// `OnboardingStepContent.kt:112-116`. `SalusDateField` on iOS takes a `title` (its
    /// accessibility name, which Compose gets from the surrounding label) and a `seedEpochDay` —
    /// the day the wheel opens on before one is picked. The profile editor seeds the same way
    /// (`ProfileScreen.swift:143-145`): the epoch, because a birth date is scrolled to anyway.
    private var birthDateField: some View {
        SalusDateField(
            title: OnboardingStrings.onboardingBirthTitle,
            epochDay: state.birthDateEpochDay,
            placeholder: OnboardingStrings.onboardingBirthSelect,
            seedEpochDay: state.birthDateEpochDay ?? 0
        ) { onEvent(.birthDateSelected($0)) }
    }

    /// `OnboardingStepContent.kt:158-171` — the shield card under the notes field.
    private var privacyCard: some View {
        SalusCard {
            HStack(alignment: .top, spacing: SalusSpacing.md) {
                Image(systemName: "shield")
                    .foregroundStyle(theme.colorScheme.primary)
                Text(verbatim: OnboardingStrings.onboardingNotesPrivacyBody)
                    .font(SalusTypography.bodyMedium.font)
                    .tracking(SalusTypography.bodyMedium.tracking)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                    .lineLimit(nil)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// `OnboardingStepContent.kt:180-186` — `SalusCard(contentPadding = 0)` wrapping a
    /// `SalusListItem`, which brings its own insets. The row is inline (see the file header).
    private var benefitCard: some View {
        SalusCard(contentPadding: 0) {
            HStack(spacing: SalusSpacing.lg) {
                SalusIconBadge(systemImage: "checkmark.seal")
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: OnboardingStrings.onboardingNotificationsBenefitTitle)
                        .font(SalusTypography.titleMedium.font)
                        .tracking(SalusTypography.titleMedium.tracking)
                        .foregroundStyle(theme.colorScheme.onSurface)
                        .lineLimit(nil)
                    Text(verbatim: OnboardingStrings.onboardingNotificationsBenefitBody)
                        .font(SalusTypography.bodyMedium.font)
                        .tracking(SalusTypography.bodyMedium.tracking)
                        .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                        .lineLimit(nil)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, SalusSpacing.lg)
            .padding(.vertical, SalusSpacing.md)
            // `defaultMinSize` sits outside the padding in Compose's modifier order
            // (`SalusListItem.kt:49-51`), so the 48 pt floor is the whole row's, not the label's.
            .frame(minHeight: SalusTouchTarget.min)
        }
    }
}

/// The steps that ask one thing: everything centred under a hero or a badge, with generous air
/// around it. `content` is whatever the step collects (`OnboardingStepContent.kt:196-231`).
private struct CenteredStep<Content: View>: View {
    let title: String
    /// Kotlin's `bodyRes`; named `message` here because `body` is `View`'s own requirement.
    let message: String
    var hero: OnboardingHeroVariant?
    var systemImage: String?
    @ViewBuilder var content: () -> Content

    @Environment(\.salusTheme) private var theme

    init(
        hero: OnboardingHeroVariant? = nil,
        systemImage: String? = nil,
        title: String,
        message: String,
        @ViewBuilder content: @escaping () -> Content = { EmptyView() }
    ) {
        self.hero = hero
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.content = content
    }

    var body: some View {
        VStack(spacing: SalusSpacing.lg) {
            if let hero {
                OnboardingHero(variant: hero)
            } else if let systemImage {
                SalusIconBadge(
                    systemImage: systemImage,
                    size: SalusIconBadgeDefaults.largeSize,
                    iconSize: SalusIconBadgeDefaults.largeIconSize
                )
            }
            Text(verbatim: title)
                .font(SalusTypography.headlineMedium.font)
                .tracking(SalusTypography.headlineMedium.tracking)
                .foregroundStyle(theme.colorScheme.onSurface)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
            Text(verbatim: message)
                .font(SalusTypography.bodyLarge.font)
                .tracking(SalusTypography.bodyLarge.tracking)
                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
            content()
        }
        .frame(maxWidth: .infinity)
    }
}

/// The one step that offers a list rather than a field, so its text is read left to right
/// (`OnboardingStepContent.kt:235-259`).
private struct LeadingStep<Content: View>: View {
    let systemImage: String
    let title: String
    /// Kotlin's `bodyRes`; named `message` here because `body` is `View`'s own requirement.
    let message: String
    @ViewBuilder var content: () -> Content

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: SalusSpacing.lg) {
            SalusIconBadge(systemImage: systemImage)
            Text(verbatim: title)
                .font(SalusTypography.headlineSmall.font)
                .tracking(SalusTypography.headlineSmall.tracking)
                .foregroundStyle(theme.colorScheme.onSurface)
                .lineLimit(nil)
            Text(verbatim: message)
                .font(SalusTypography.bodyLarge.font)
                .tracking(SalusTypography.bodyLarge.tracking)
                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                .lineLimit(nil)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// `OnboardingStepContent.kt:262-284`.
private struct MeasureField: View {
    let value: String
    let onValueChange: (String) -> Void
    let placeholder: String
    let suffix: String
    let isError: Bool
    let error: String

    var body: some View {
        SalusPillTextField(
            text: Binding(get: { value }, set: { onValueChange($0) }),
            placeholder: placeholder,
            suffix: suffix,
            isError: isError,
            supportingText: isError ? error : nil,
            keyboard: .decimal,
            autocorrects: false
        )
    }
}

/// A note area rather than a pill: this is the one field where the answer is a paragraph, so it is
/// given the room to be one. The chip states where the text ends up, which is the question a
/// free-text health field raises (`OnboardingStepContent.kt:292-340`).
private struct HealthNotesField: View {
    let value: String
    let onValueChange: (String) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        // VStack rather than an overlaid chip: the chip is the floor the text stops at, so a long
        // note scrolls above it instead of underneath it (`:300-301`).
        VStack(alignment: .trailing, spacing: SalusSpacing.sm) {
            editor
            SalusStatusChip(
                label: OnboardingStrings.onboardingNotesPrivate,
                status: .success,
                systemImage: "lock.fill"
            )
        }
        .padding(SalusSpacing.lg)
        .frame(maxWidth: .infinity)
        .frame(height: Self.fieldHeight)
        .background(theme.colorScheme.surfaceContainerLowest, in: SalusShapes.largeShape)
    }

    private var editor: some View {
        TextEditor(text: Binding(get: { value }, set: { onValueChange($0) }))
            .scrollContentBackground(.hidden)
            .font(SalusTypography.bodyLarge.font)
            .foregroundStyle(theme.colorScheme.onSurface)
            .tint(theme.colorScheme.primary)
            // `TextEditor` inherits `UITextView`'s 5 pt text container inset, which would push the
            // first line off the `lg` padding the surface already applies.
            .padding(.horizontal, -Self.editorTextInset)
            .overlay(alignment: .topLeading) {
                if value.isEmpty {
                    Text(verbatim: OnboardingStrings.onboardingNotesPlaceholder)
                        .font(SalusTypography.bodyLarge.font)
                        .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                        .lineLimit(nil)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        #if os(iOS)
            .textInputAutocapitalization(.sentences)
        #endif
    }

    /// `private val NotesFieldHeight = 240.dp` (`OnboardingStepContent.kt:342`).
    private static let fieldHeight: CGFloat = 240
    private static let editorTextInset: CGFloat = 5
}

extension Sex {
    /// `OnboardingStepContent.kt:345-349`.
    fileprivate var onboardingLabel: String {
        switch self {
        case .female: OnboardingStrings.onboardingSexFemale
        case .male: OnboardingStrings.onboardingSexMale
        case .other: OnboardingStrings.onboardingSexOther
        }
    }

    /// `OnboardingStepContent.kt:351-355`, mapped exactly as `ProfileScreen.swift:221-227` maps it.
    fileprivate var onboardingSystemImage: String {
        switch self {
        case .female: "figure.stand.dress"
        case .male: "figure.stand"
        case .other: "person.2"
        }
    }

    /// Female borrows the cycle accent and male the vitals one, so the option already looks like the
    /// part of the app it unlocks. Other has no feature of its own and stays on the default
    /// (`OnboardingStepContent.kt:362-366`).
    fileprivate func onboardingAccent(_ theme: SalusResolvedTheme) -> FeatureAccent? {
        switch self {
        case .female: theme.extendedColors.cycle
        case .male: theme.extendedColors.vitals
        case .other: nil
        }
    }
}
