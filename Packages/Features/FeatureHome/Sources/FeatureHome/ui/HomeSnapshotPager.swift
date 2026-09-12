// Ported from `feature/home/src/main/kotlin/com/alicansekban/salus/feature/home/ui/HomePager.kt` —
// the page list (`:60`, `:77-84`), the pager itself (`:89-124`), the per-page semantics wrapper
// (`:131-140`) and the shared card shell (`:143-171`). The three page contents live one per file
// beside this one — `HomeDosesCard`, `HomeVitalsCard`, `HomeCycleCard` — the way every Home card
// already does: Kotlin can keep them `private` in one file, Swift cannot.
//
// THE `TabView` BELOW IS THE ONE SANCTIONED OUTSIDE `App/` (spec §4.1). It is a paging container,
// not navigation: it has no tab bar, no routes and no stack, it never leaves Home's own scroll
// column, and it is `private` to this screen. The rule it does not break is the shell's — the tab
// bar and the one `NavigationStack` still belong to `App/`, and nothing here writes `.toolbar`,
// `.navigationTitle` or `.toolbar(…, for: .tabBar)`.
//
// Material → SwiftUI:
//   `HorizontalPager(state = rememberPagerState { pages.size })` → `TabView(selection:)` with
//                                                     `.tabViewStyle(.page(indexDisplayMode: .never))`.
//   `Column(verticalArrangement = spacedBy(md))`      → `VStack(spacing: SalusSpacing.md)`.
//   `Modifier.semantics { contentDescription = … }`   → `.accessibilityElement(children: .contain)`
//                                                       plus `.accessibilityLabel(_:)`.
//
// DIVERGENCE (a), NO PEEK. Kotlin buys the swipe affordance with `contentPadding` and `pageSpacing`
// (`HomePager.kt:93-94`), so the neighbouring card shows at both edges. SwiftUI's `.page` style
// has no equivalent — a page is exactly the container's width — so each page takes the full width
// with the screen's own `lg` inset and `SalusPagerDots` below carries the affordance alone. Faking
// the peek would mean hand-rolling the pager (a `ScrollView(.horizontal)` with
// `.scrollTargetBehavior(.viewAligned)`, iOS 17) and giving up the platform's paging physics and
// its VoiceOver page semantics, for a visual hint the dots already give.
//
// DIVERGENCE (b), A FIXED PAGE HEIGHT. Compose's pager measures its tallest page; a SwiftUI `.page`
// `TabView` has no intrinsic height at all and collapses without one. The height is therefore a
// named constant in ``HomePagerDefaults`` (never a raw point size inline) and is carried through
// `@ScaledMetric`, so the box grows with the reader's text size instead of clipping at the larger
// Dynamic Type steps.

import SalusDesignSystem
import SalusUI
import SwiftUI

/// The pages Home swipes through. Doses are always there; the other two follow the data, so a
/// profile without cycle tracking never swipes into an empty card (`HomePager.kt:56-60`).
enum HomeSnapshotPage: Hashable {
    case doses
    case vitals
    case cycle
}

/// The pager under the hero band: one card per page and the dots directly beneath it
/// (`HomePager.kt:62-125`).
///
/// The pages are the day at a glance, not a second navigation bar — every card still opens its own
/// tab on tap, so nothing here is the only way to reach a feature (`HomePager.kt:65-66`).
struct HomeSnapshotPager: View {
    let state: HomeUiState
    let onEvent: (HomeEvent) -> Void
    let onOpenMedications: () -> Void
    let onOpenVitals: () -> Void
    let onOpenCycle: () -> Void

    @State private var selection: HomeSnapshotPage = .doses
    /// Divergence (b): the page box, grown with the reader's text size.
    @ScaledMetric(relativeTo: .body) private var pageHeight = HomePagerDefaults.height

    /// `buildList { add(Doses); if (state.vitals != null) add(Vitals); if (state.cycle != null)
    /// add(Cycle) }` (`HomePager.kt:77-83`).
    private var pages: [HomeSnapshotPage] {
        var pages: [HomeSnapshotPage] = [.doses]
        if state.vitals != nil {
            pages.append(.vitals)
        }
        if state.cycle != nil {
            pages.append(.cycle)
        }
        return pages
    }

    /// Where the dots are. `firstIndex` answers nil for one frame after a page leaves under the
    /// selection, before the `onChange` below puts the pager back on the doses — the fallback is
    /// that frame, not a policy.
    private var selectedIndex: Int {
        pages.firstIndex(of: selection) ?? 0
    }

    var body: some View {
        VStack(spacing: SalusSpacing.md) {
            TabView(selection: $selection) {
                ForEach(pages, id: \.self) { page in
                    // Top-aligned inside the fixed box (`verticalAlignment = Alignment.Top`,
                    // `HomePager.kt:95`): a short card sits under the hero rather than floating in
                    // the middle of the page.
                    VStack(spacing: 0) {
                        content(for: page)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, SalusSpacing.lg)
                    .tag(page)
                }
            }
            .homePagingStyle()
            .frame(height: pageHeight)
            // A page can leave under the selection when the data behind it does — a profile stops
            // being tracked, a snapshot arrives empty — and a `TabView` whose selection matches no
            // tag draws a blank page. Doses are always in the list (`HomePager.kt:79`), so that is
            // where the pager lands. Compose has no equivalent because its pager state is an index
            // into the current list, which `rememberPagerState` re-reads on every recomposition.
            .onChange(of: pages) { _, pages in
                if !pages.contains(selection) {
                    selection = .doses
                }
            }
            // `SalusPagerDots(pageCount, currentPage, align(CenterHorizontally))`
            // (`HomePager.kt:119-123`).
            SalusPagerDots(count: pages.count, index: selectedIndex)
        }
    }

    /// One page's card, with the label a screen reader is told on arrival (`HomePager.kt:96-117`).
    @ViewBuilder private func content(for page: HomeSnapshotPage) -> some View {
        switch page {
        case .doses:
            HomeDosesCard(
                doses: state.doses,
                doseProgress: state.doseProgress,
                onEvent: onEvent,
                onTap: onOpenMedications
            )
            .homeSnapshotPage(label: HomeStrings.pagerDoses)

        case .vitals:
            // `state.vitals?.let { … }` (`HomePager.kt:111`) — the page exists only because the
            // snapshot does, so the optional is unwrapped rather than defaulted.
            if let vitals = state.vitals {
                HomeVitalsCard(vitals: vitals, onTap: onOpenVitals)
                    .homeSnapshotPage(label: HomeStrings.pagerVitals)
            }

        case .cycle:
            // `state.cycle?.let { … }` (`HomePager.kt:115`). Nil for a male or missing profile
            // (`TodayModels.kt:10-11`), which is why the page is not in `pages` at all then.
            if let cycle = state.cycle {
                HomeCycleCard(cycle: cycle, onTap: onOpenCycle)
                    .homeSnapshotPage(label: HomeStrings.pagerCycle)
            }
        }
    }
}

extension View {
    /// `.tabViewStyle(.page(indexDisplayMode: .never))`, guarded the way `SalusDialog`'s
    /// `fullScreenCover` is: the page style does not exist on the macOS test host, which is a
    /// `swift test` concession and never a ship target (`CLAUDE.md`). The dots are drawn by
    /// `SalusPagerDots` below the pager, so the built-in indicator is off on iOS too.
    @ViewBuilder func homePagingStyle() -> some View {
        #if os(iOS)
            tabViewStyle(.page(indexDisplayMode: .never))
        #else
            self
        #endif
    }

    /// A page's own accessibility node (`PagerPage`, `HomePager.kt:127-140`).
    ///
    /// The label sits on the wrapper rather than on the card, so a screen reader is told which page
    /// it landed on without losing the card's own content — `children: .contain` is what keeps the
    /// contents individually reachable, where `.combine` would flatten the card into one string.
    func homeSnapshotPage(label: String) -> some View {
        accessibilityElement(children: .contain)
            .accessibilityLabel(Text(verbatim: label))
    }
}

/// The shared shell of every page: the titled `elevated` card the content sits in
/// (`SnapshotCard`, `HomePager.kt:142-171`).
///
/// `onTap` is optional for the reason recorded in ``HomeDashboardCard``: a card holding a
/// `SalusButton` cannot itself be a `Button`, because SwiftUI lets the outer one swallow the tap.
/// The doses page passes nil and carries the open on its content; vitals and cycle pass the
/// callback and get the real button semantics.
struct HomeSnapshotCard<Content: View>: View {
    private let systemImage: String
    private let accent: FeatureAccent
    private let title: String
    private let onTap: (() -> Void)?
    private let content: Content

    init(
        systemImage: String,
        accent: FeatureAccent,
        title: String,
        onTap: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.systemImage = systemImage
        self.accent = accent
        self.title = title
        self.onTap = onTap
        self.content = content()
    }

    var body: some View {
        // Kotlin passes `PaddingValues(SalusSpacing.lg)` (`HomePager.kt:155`), which is
        // `SalusCardDefaults.contentPadding` here, so it is left at the default.
        SalusCard(tone: .elevated, onTap: onTap) {
            // `Row(verticalAlignment = CenterVertically, spacedBy(md))` (`HomePager.kt:157-167`).
            HStack(spacing: SalusSpacing.md) {
                SalusIconBadge(systemImage: systemImage, accent: accent)
                // `verbatim:` because the caller hands over a resolved string; the plain
                // initializer would treat it as a `LocalizedStringKey` and look it up in the
                // *main* bundle.
                Text(verbatim: title)
                    .font(SalusTypography.titleLarge.font)
                    .tracking(SalusTypography.titleLarge.tracking)
                    // `Modifier.weight(1f)` (`HomePager.kt:165`), and what keeps the title flush
                    // left inside the `Button` an interactive card is.
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            // `Spacer(Modifier.height(SalusSpacing.md))` (`HomePager.kt:168`).
            Spacer().frame(height: SalusSpacing.md)
            content
        }
        .frame(maxWidth: .infinity)
    }
}

/// The pager's own dimensions — component values, not design tokens, so they live here rather than
/// in `SalusDesignSystem` (the shape `SalusPagerDotsDefaults` sets).
enum HomePagerDefaults {
    /// Divergence (b): the page box at the default text size. Sized against the tallest page — the
    /// doses card holding a `SalusEmptyState` (a 72 pt badge, `xl` padding either side and a
    /// `titleMedium` line under the card's own `lg` inset and title row) — with a step of slack, so
    /// no page clips before `@ScaledMetric` starts growing the box.
    static let height: CGFloat = 260
}
