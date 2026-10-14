// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/craving/
// BreathingRing.kt`.
//
// Compose → SwiftUI:
//   `Animatable` + `LaunchedEffect(phase, still)`  → `@State breath` moved by `withAnimation` from
//                           `.onChange(of: phase, initial: true)`; the 4 s in-breath and the 6 s
//                           out-breath are the animations' durations, so the halo and the words under
//                           it keep one rhythm.
//   `animateFloatAsState` (1 s, linear)             → `.animation(_, value: arc)`.
//   `Canvas` + `drawArc`                            → `Circle().trim` strokes in a `GeometryReader`,
//                           drawn by hand like `SalusProgressRing` (the determinate system ring does
//                           not exist on iOS 17).
//
// Reduce motion removes the movement and nothing else (controller ruling R20): the halo stands still
// at its widest, the arc steps once a second instead of sliding, and the breath is carried by the
// phase label and the chips under the ring — which the screen draws in every case.

import SalusDesignSystem
import SalusUI
import SwiftUI

/// The craving flow's big ring: a track, an arc for the time still left, and a soft halo around it
/// that swells while the person breathes in, holds while they hold and shrinks as they breathe out.
///
/// `progress` is the share of the five minutes that is left, 0 to 1. `completed` stops the breathing
/// and fills the ring. `content` is drawn in the middle (the timer, or a check).
struct BreathingRing<Content: View>: View {
    let progress: Double
    let phase: BreathPhase
    let reduceMotion: Bool
    let completed: Bool
    @ViewBuilder let content: Content

    @Environment(\.salusTheme) private var theme

    /// 0 with the breath out and nothing around the ring, 1 with the breath in and the halo wide.
    @State private var breath: CGFloat

    init(
        progress: Double,
        phase: BreathPhase,
        reduceMotion: Bool,
        completed: Bool,
        @ViewBuilder content: () -> Content
    ) {
        self.progress = progress
        self.phase = phase
        self.reduceMotion = reduceMotion
        self.completed = completed
        self.content = content()
        let still = reduceMotion || completed
        _breath = State(initialValue: still ? BreathingRingDefaults.breathIn : BreathingRingDefaults.breathOut)
    }

    private var still: Bool {
        reduceMotion || completed
    }

    private var arc: Double {
        completed ? 1 : min(max(progress, 0), 1)
    }

    var body: some View {
        GeometryReader { proxy in
            let outer = min(proxy.size.width, proxy.size.height) / 2
            let ringRadius = outer * BreathingRingDefaults.ringRadiusShare
            let stroke = SalusProgressRingDefaults.strokeWidth
            // The arc is stroked on its radius, so the stroke's outer edge is `ringRadius` and the
            // centre line sits half a stroke inside it — Android's `ringRadius - stroke / 2`.
            let arcDiameter = (ringRadius - stroke / 2) * 2
            let haloScale = BreathingRingDefaults.ringRadiusShare
                + (1 - BreathingRingDefaults.ringRadiusShare) * breath

            ZStack {
                Circle()
                    .fill(theme.extendedColors.smoking.accent.opacity(BreathingRingDefaults.haloAlpha))
                    .frame(width: outer * 2 * haloScale, height: outer * 2 * haloScale)
                Circle()
                    .stroke(theme.colorScheme.surfaceContainerHigh, lineWidth: stroke)
                    .frame(width: arcDiameter, height: arcDiameter)
                Circle()
                    .trim(from: 0, to: arc)
                    .stroke(
                        theme.extendedColors.smoking.accent,
                        style: StrokeStyle(lineWidth: stroke, lineCap: .round)
                    )
                    .rotationEffect(.degrees(BreathingRingDefaults.topAngle))
                    .frame(width: arcDiameter, height: arcDiameter)
                    // The arc slides between two one-second steps, so it reads as time passing
                    // rather than ticking; with reduced motion it just steps.
                    .animation(reduceMotion ? nil : .linear(duration: BreathingRingDefaults.arcSeconds), value: arc)
                content
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        // Four fifths of the width, never past `maxSize`: `fillMaxWidth(0.8f).widthIn(max = …)`.
        .containerRelativeFrame(.horizontal) { length, _ in
            min(length * BreathingRingDefaults.widthShare, BreathingRingDefaults.maxSize)
        }
        .aspectRatio(1, contentMode: .fit)
        .onChange(of: phase, initial: true) { _, new in
            breathe(into: new)
        }
        .onChange(of: still) { _, _ in
            breathe(into: phase)
        }
    }

    /// Moves the halo to where `phase` wants it: wide on the in-breath and held there, narrow again
    /// over the out-breath. A still ring snaps open and stays.
    private func breathe(into phase: BreathPhase) {
        if still {
            breath = BreathingRingDefaults.breathIn
            return
        }
        switch phase {
        case .inhale:
            withAnimation(.easeInOut(duration: Double(inhaleMs) / 1000)) {
                breath = BreathingRingDefaults.breathIn
            }

        case .hold:
            breath = BreathingRingDefaults.breathIn

        case .exhale:
            withAnimation(.easeInOut(duration: Double(exhaleMs) / 1000)) {
                breath = BreathingRingDefaults.breathOut
            }
        }
    }
}

/// The ring's own dimensions, not design tokens (the twin of the private constants at the top of
/// `BreathingRing.kt`); the stroke is the shared ring's.
enum BreathingRingDefaults {
    /// The halo's smallest share of its room: the breath is out, the ring has nothing around it.
    static let breathOut: CGFloat = 0
    static let breathIn: CGFloat = 1

    /// The ring's radius as a share of the whole circle's; the halo breathes in the room outside it.
    static let ringRadiusShare: CGFloat = 0.78

    static let haloAlpha = 0.16

    /// Where the arc starts: 12 o'clock, as `Circle().trim` starts at 3 o'clock.
    static let topAngle: Double = -90

    /// The arc's slide between two one-second steps.
    static let arcSeconds: Double = 1

    /// The share of the available width the ring takes.
    static let widthShare: CGFloat = 0.8

    /// The ring never grows past this, however wide the screen: a few times the shared ring's size.
    static let maxSize: CGFloat = SalusProgressRingDefaults.size * 4

    /// The completed check, a little under half the ring at its widest.
    static let checkSize: CGFloat = 96
}
