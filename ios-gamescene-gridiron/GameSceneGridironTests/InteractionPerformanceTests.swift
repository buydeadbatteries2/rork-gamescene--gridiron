import SwiftUI
import Foundation
import Testing
@testable import GameSceneGridiron

/// Behavioral guardrails for memoization/isolation, not frame-rate benchmarks.
@MainActor
struct InteractionPerformanceTests {
    @Test func selectionIsSynchronousAndToggleSemanticsArePreserved() {
        let model = GameViewModel(puzzle: SampleQuarter.puzzle)
        model.toggleExpanded("p-rb")
        #expect(model.expandedPlayerID == "p-rb")
        model.toggleExpanded("p-rb")
        #expect(model.expandedPlayerID == nil)
        model.selectProfile(.fast, for: "p-rb")
        #expect(model.expandedPlayerID == "p-rb")
        #expect(model.selectedProfile(for: "p-rb") == .fast)
        model.selectProfile(.fast, for: "p-rb")
        #expect(model.selectedProfile(for: "p-rb") == nil)
    }

    @Test func repeatedDragSamplesDoNotValidateOrChangeClues() {
        let model = GameViewModel(puzzle: SampleQuarter.puzzle)
        model.fieldFrame = CGRect(x: 0, y: 0, width: 360, height: 560)
        let clues = model.puzzle.clues.map(\.text)
        let lives = model.lives
        model.selectProfile(.fast, for: "p-rb")
        #expect(model.beginDrag(playerID: "p-rb", at: .zero))
        let wrong = model.puzzle.slot(id: "s-left-backfield")!
        let point = model.point(x: wrong.x, y: wrong.y)
        for _ in 0..<240 {
            model.updateDrag(to: CGPoint(x: point.x, y: point.y + GameViewModel.dragLift))
        }
        #expect(model.hoveredSlotID == wrong.id)
        #expect(model.placements.isEmpty)
        #expect(model.lives == lives)
        #expect(model.rejectionCount == 0)
        #expect(model.currentClueIndex == 0)
        #expect(model.puzzle.clues.map(\.text) == clues)
        model.cancelDrag()
        #expect(model.lives == lives)
        #expect(!model.isDragging)
    }

    @Test func targetCacheTracksFrameChangesAndReleaseUsesLatestGeometry() {
        let model = GameViewModel(puzzle: SampleQuarter.puzzle)
        model.fieldFrame = CGRect(x: 0, y: 0, width: 360, height: 560)
        model.selectProfile(.fast, for: "p-rb")
        #expect(model.beginDrag(playerID: "p-rb", at: .zero))
        let slot = model.puzzle.slot(id: "s-backfield")!
        model.fieldFrame = CGRect(x: 70, y: 120, width: 300, height: 400)
        let point = model.point(x: slot.x, y: slot.y)
        model.updateDrag(to: CGPoint(x: point.x, y: point.y + GameViewModel.dragLift))
        #expect(model.hoveredSlotID == slot.id)
        #expect(model.hoveredSlotPoint == point)
        model.endDrag()
        #expect(model.placements.count == 1)
        #expect(!model.candidateSlots.contains { $0.id == slot.id })
        model.endDrag()
        #expect(model.placements.count == 1)
    }

    @Test func releaseRechecksGeometryEvenWithoutAnotherMove() {
        let model = GameViewModel(puzzle: SampleQuarter.puzzle)
        model.fieldFrame = CGRect(x: 0, y: 0, width: 360, height: 560)
        model.selectProfile(.fast, for: "p-rb")
        let slot = model.puzzle.slot(id: "s-backfield")!
        let point = model.point(x: slot.x, y: slot.y)
        #expect(model.beginDrag(playerID: "p-rb", at: CGPoint(x: point.x, y: point.y + GameViewModel.dragLift)))
        #expect(model.hoveredSlotID == slot.id)
        model.fieldFrame.origin.y += 1000
        model.endDrag()
        #expect(model.placements.isEmpty)
        #expect(model.lives == model.puzzle.startingLives)
    }

    @Test func markerMemoizationMatchesOriginalForEveryInputChange() {
        let model = GameViewModel(puzzle: SampleQuarter.puzzle)
        for slots in [model.puzzle.slots, Array(model.puzzle.slots.prefix(2))] {
            for size in [CGSize(width: 360, height: 560), CGSize(width: 300, height: 400), .zero] {
                for diameter in [CGFloat(24), CGFloat(30)] {
                    let expected = PlacementZoneLayout.displayPositions(slots: slots, fieldSize: size, visibleDiameter: diameter)
                    for _ in 0..<3 {
                        #expect(model.markerPositions(slots: slots, fieldSize: size, visibleDiameter: diameter) == expected)
                    }
                }
            }
        }
    }

    @Test func highlightingPreservesCopyAndContrastAcrossCacheHits() {
        let text = "The fast running back is behind the orange cone."
        let normal = ClueHighlighter.highlighted(text)
        let contrast = ClueHighlighter.highlighted(text, highContrast: true)
        #expect(normal != contrast)
        #expect(normal == ClueHighlighter.highlighted(text))
        #expect(contrast == ClueHighlighter.highlighted(text, highContrast: true))
        #expect(String(normal.characters) == text)
        for item in CaseLibrary.all {
            for clue in CaseLibrary.puzzle(for: item, quarterIndex: 0).clues {
                for highContrast in [false, true] {
                    let value = ClueHighlighter.highlighted(clue.text, highContrast: highContrast)
                    #expect(String(value.characters) == clue.text)
                    #expect(value == ClueHighlighter.highlighted(clue.text, highContrast: highContrast))
                }
            }
        }
        #expect(ClueHighlighter.highlighted(text) == normal)
    }
}
