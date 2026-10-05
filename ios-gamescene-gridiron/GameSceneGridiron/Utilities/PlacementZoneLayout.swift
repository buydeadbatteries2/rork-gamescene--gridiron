import CoreGraphics
import Foundation

/// Display-only layout for the temporary drag markers. When two authored slots
/// sit closer than their visible diameter, the markers are nudged apart so no
/// two mystery zones (or "?" glyphs) ever visually stack. Solved players and
/// drop snapping always use the slot's true field coordinates — this only
/// moves the temporary circles a few points for readability.
nonisolated enum PlacementZoneLayout {

    /// De-overlapped marker positions keyed by slot id, in field-local points.
    ///
    /// Iterative symmetric relaxation: any pair closer than `minSpacing`
    /// pushes apart along their axis with a deterministic tie-break for
    /// coincident points, then every marker is clamped inside the field.
    static func displayPositions(
        slots: [PlacementSlot],
        fieldSize: CGSize,
        visibleDiameter: CGFloat,
        gap: CGFloat = 5,
        boundsInset: CGFloat = 12,
        maxIterations: Int = 32
    ) -> [String: CGPoint] {
        guard fieldSize.width > 0, fieldSize.height > 0 else { return [:] }
        let minSpacing = visibleDiameter + gap
        let bounds = CGRect(
            x: boundsInset,
            y: boundsInset,
            width: max(fieldSize.width - boundsInset * 2, 0),
            height: max(fieldSize.height - boundsInset * 2, 0)
        )
        var points = slots.map { slot in
            CGPoint(x: fieldSize.width * CGFloat(slot.x), y: fieldSize.height * CGFloat(slot.y))
        }

        for _ in 0..<maxIterations {
            var moved = false
            for i in points.indices {
                for j in (i + 1)..<points.count {
                    let dx = points[j].x - points[i].x
                    let dy = points[j].y - points[i].y
                    let d = hypot(dx, dy)
                    guard d < minSpacing else { continue }
                    let push = (minSpacing - d) / 2 + 0.5
                    let dxn = d > 0.01 ? dx / d : CGFloat(1)
                    let dyn = d > 0.01 ? dy / d : CGFloat(0)
                    points[i].x -= dxn * push
                    points[i].y -= dyn * push
                    points[j].x += dxn * push
                    points[j].y += dyn * push
                    moved = true
                }
            }
            for index in points.indices {
                points[index].x = min(max(points[index].x, bounds.minX), bounds.maxX)
                points[index].y = min(max(points[index].y, bounds.minY), bounds.maxY)
            }
            if !moved { break }
        }

        var positions: [String: CGPoint] = [:]
        for (slot, point) in zip(slots, points) {
            positions[slot.id] = point
        }
        return positions
    }
}
