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
// DIVERGENCE (b), THE PAGE HEIGHT IS MEASURED HERE RATHER THAN GIVEN BY THE CONTAINER. Compose's
// pager measures its tallest page; a SwiftUI `.page` `TabView` has no intrinsic height at all and
// collapses without one, so something has to hand it a number. Until owner QA round 1 that number
// was a constant (`HomePagerDefaults.height`, 260 pt, `@ScaledMetric`-scaled) — which is a floor as
// well as a ceiling, and left a page whose card is ~150 pt tall sitting in a 260 pt box with a
// visible gap between the card and the dots.
//
// So the pages are measured instead, the way Compose measures them: a hidden copy of every page is
// laid out at the pager's own width and at its NATURAL height (``pageMeasuringStack``), each page
// reports that height through ``HomePagerHeightKey``, the key keeps the largest, and the `TabView`
// is framed to it. `HomePagerDefaults.fallbackHeight` is what the box uses for the single layout
// pass before the first measurement lands, and nothing else — in particular the measurement is
// never clamped up to it, because that clamp was the bug.

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
    /// Divergence (b): the tallest page's natural height, reported by ``pageMeasuringStack``. Nil
    /// until the first measurement lands — one layout pass — and never nil again.
    @State private var measuredHeight: CGFloat?
    /// Divergence (b): the box for that one pass, grown with the reader's text size so the first
    /// frame is not wildly wrong at the larger Dynamic Type steps. A seed, never a floor.
    @ScaledMetric(relativeTo: .body) private var fallbackHeight = HomePagerDefaults.fallbackHeight

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
            // Divergence (b): the tallest page's own height, not a constant.
            .frame(height: measuredHeight ?? fallbackHeight)
            // The measuring copy rides along as a background so that it is proposed exactly the
            // pager's width — a page measured at any other width would report the wrong number of
            // wrapped lines. It is `.top`-aligned for the same reason the real pages are, and it
            // costs nothing in layout: it draws nothing and the frame above is already resolved.
            .background(alignment: .top) { pageMeasuringStack }
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

    /// Divergence (b): a hidden copy of every page, laid out at the pager's width and at its own
    /// natural height, which is where ``measuredHeight`` comes from.
    ///
    /// Outside the `TabView` on purpose — a `.page` `TabView` gives each of its pages the box's
    /// height, so a page measured *inside* it could only ever report the number it was given.
    /// `.fixedSize(vertical:)` is what makes the copy answer with its ideal height rather than with
    /// the height the background was proposed; `.hidden()` keeps it out of the drawing, and the two
    /// lines under it keep it out of VoiceOver and out of hit testing, so the only thing this
    /// second copy of the cards contributes is its size.
    ///
    /// No `Spacer` here, unlike the real pages: the spacer is what pushes a short card to the top
    /// of a box that is taller than it, and the whole point of this copy is that it has no such box.
    private var pageMeasuringStack: some View {
        ZStack(alignment: .top) {
            ForEach(pages, id: \.self) { page in
                content(for: page)
                    .padding(.horizontal, SalusSpacing.lg)
                    .background { pageHeightReporter }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .hidden()
        .accessibilityHidden(true)
        .allowsHitTesting(false)
        .onPreferenceChange(HomePagerHeightKey.self) { height in
            // Zero is "nothing has been laid out yet", not "the tallest page is empty", so it
            // leaves the seed in place rather than collapsing the box.
            measuredHeight = height > 0 ? height : nil
        }
    }

    /// What one page reports its height with. A background rather than a wrapper, so the reader is
    /// handed the page's resolved size and cannot influence it.
    private var pageHeightReporter: some View {
        GeometryReader { proxy in
            Color.clear.preference(key: HomePagerHeightKey.self, value: proxy.size.height)
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

/// The tallest page's height, which is what the pager's box is (divergence (b)). `reduce` keeps the
/// maximum because that is the question — Compose's pager asks its pages the same one
/// (`HorizontalPager` measures every page and takes the largest).
private struct HomePagerHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
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
    /// Divergence (b): the page box for the **one** layout pass before the first measurement
    /// lands, at the default text size. It is a seed, not a size: `HomeSnapshotPager` replaces it
    /// with the tallest page's own height and never clamps that measurement back up to this
    /// number — used as a floor it left short pages sitting in a 260 pt box with a gap above the
    /// dots, which is the bug it is named `fallbackHeight` to keep it from being again.
    ///
    /// The value is the old constant unchanged: sized against the tallest page — the doses card
    /// holding a `SalusEmptyState` (a 72 pt badge, `xl` padding either side and a `titleMedium`
    /// line under the card's own `lg` inset and title row) — with a step of slack. It is carried
    /// through `@ScaledMetric` for the same reason it always was, so that the single unmeasured
    /// frame is not wildly short at the larger Dynamic Type steps.
    static let fallbackHeight: CGFloat = 260
}
