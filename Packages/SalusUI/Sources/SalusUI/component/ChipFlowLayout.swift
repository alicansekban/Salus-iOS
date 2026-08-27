// Moved verbatim out of `FeatureAppointments/ui/detail/AppointmentDetailScreen.swift` (iOS-M4,
// which recorded belonging here as a deferred finding) when the medications screens became its
// second caller. Behaviour is unchanged; only the access level is.

import SwiftUI

/// The twin of Compose's `FlowRow` (`AppointmentDetailScreen.kt:290`), narrowed to what the chip
/// row needs: one horizontal spacing, the same value between rows, leading alignment.
///
/// SwiftUI ships no flow stack, and an `HStack` is not a substitute — three reminder chips at an
/// accessibility text size overflow the card on a small phone, which is exactly the case `FlowRow`
/// exists for.
public struct ChipFlowLayout: Layout {
    public let spacing: CGFloat

    public init(spacing: CGFloat) {
        self.spacing = spacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let rows = rows(of: subviews, in: proposal.width ?? .infinity)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var y = bounds.minY
        for row in rows(of: subviews, in: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: .unspecified)
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    /// One entry per drawn row: which subviews it holds and how big it is.
    private func rows(of subviews: Subviews, in maxWidth: CGFloat) -> [ChipFlowRow] {
        var rows: [ChipFlowRow] = []
        var current = ChipFlowRow(indices: [], width: 0, height: 0)
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let advance = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if !current.indices.isEmpty, advance > maxWidth {
                rows.append(current)
                current = ChipFlowRow(indices: [index], width: size.width, height: size.height)
            } else {
                current.indices.append(index)
                current.width = advance
                current.height = max(current.height, size.height)
            }
        }
        if !current.indices.isEmpty {
            rows.append(current)
        }
        return rows
    }
}

/// One row of `ChipFlowLayout`, named so the layout's two passes agree on what a row is.
private struct ChipFlowRow {
    var indices: [Int]
    var width: CGFloat
    var height: CGFloat
}
