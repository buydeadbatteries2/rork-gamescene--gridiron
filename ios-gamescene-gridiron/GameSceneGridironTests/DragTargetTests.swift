import CoreGraphics
import Foundation
import Testing
@testable import GameSceneGridiron

/// Drag-target presentation: position-relevant candidate zones, de-overlapped
/// mystery markers and unambiguous nearest-target drop resolution. The puzzle
/// logic itself is untouched — these tests pin the presentation contract.
@MainActor
struct DragTargetTests {

    private let fieldFrame = CGRect(x: 0, y: 0, width: 360, height: 560)

    /// Every authored puzzle, handcrafted and library-generated.
    private var allPuzzles: [QuarterPuzzle] {
        MatchPuzzles.regulation
            + [MatchPuzzles.overtime]
            + CaseLibrary.all.map { CaseLibrary.puzzle(for: $0, quarterIndex: 0) }
    }

    // MARK: Relevance filtering

    /// Safety net across the entire content library: a solution slot the
    /// dragged player can never see would make a quarter unwinnable.
    @Test func everySolutionSlotIsACandidateForItsOwnPlayer() {
        let puzzles = allPuzzles
        #expect(puzzles.count > 50)
        for puzzle in puzzles {
            for (playerID, solution) in puzzle.solutions {
                guard let player = puzzle.player(id: playerID) else {
                    Issue.record("\(puzzle.id): unknown player \(playerID)")
                    continue
                }
                #expect(
                    SlotRole.accepts(player.position, slotID: solution.slotID),
                    "\(puzzle.id): \(player.position.rawValue) cannot target own slot \(solution.slotID)"
                )
            }
        }
    }

    @Test func slotRoleClassifierCoversFootballLandmarks() {
        #expect(SlotRole.accepts(.rb, slotID: "case_x-s-rb-right"))
        #expect(SlotRole.accepts(.rb, slotID: "s-backfield"))
        #expect(SlotRole.accepts(.qb, slotID: "case_x-s-under-center"))
        #expect(SlotRole.accepts(.qb, slotID: "case_x-s-left-gun"))
        #expect(SlotRole.accepts(.wr, slotID: "case_x-s-wr2-slot"))
        #expect(SlotRole.accepts(.cb, slotID: "case_x-s-cb-slot"))
        #expect(SlotRole.accepts(.dl, slotID: "case_x-s-over-te"))
        #expect(SlotRole.accepts(.ss, slotID: "case_x-s-deep-center"))
        #expect(SlotRole.accepts(.fs, slotID: "s-deep-middle"))
        #expect(SlotRole.accepts(.ol, slotID: "case_x-s-right-guard"))
        #expect(SlotRole.accepts(.lb, slotID: "case_x-s-mike-left"))

        // Irrelevant landmarks stay hidden for each position.
        #expect(!SlotRole.accepts(.rb, slotID: "case_x-s-right-corner"))
        #expect(!SlotRole.accepts(.rb, slotID: "case_x-s-right-wide"))
        #expect(!SlotRole.accepts(.wr, slotID: "case_x-s-box-right"))
        #expect(!SlotRole.accepts(.cb, slotID: "s-backfield"))
        #expect(!SlotRole.accepts(.fs, slotID: "case_x-s-rb-right"))
    }

    @Test func draggingARunningBackOnlyShowsBackfieldZones() {
        let viewModel = GameViewModel(puzzle: SampleQuarter.puzzle)
        viewModel.selectVariant(.fast, for: "p-rb")
        #expect(viewModel.beginDrag(playerID: "p-rb", at: CGPoint(x: 180, y: 300)))

        let candidates = viewModel.candidateSlots
        #expect(candidates.map(\.id).sorted() == ["s-backfield", "s-left-backfield"])
        #expect(candidates.count < viewModel.openSlots.count)
        #expect(!candidates.contains { slot in
            slot.id.contains("corner") || slot.id.contains("wide") || slot.id.contains("deep")
        })

        // The same quarter shows every open zone once nothing is dragged —
        // rejection flashes keep working after a release.
        viewModel.endDrag()
        #expect(viewModel.candidateSlots.count == viewModel.openSlots.count)
    }

    // MARK: Hover targeting

    @Test func hoveringAnIrrelevantLandmarkNeverHighlightsIt() {
        let viewModel = GameViewModel(puzzle: SampleQuarter.puzzle)
        viewModel.fieldFrame = fieldFrame
        viewModel.selectVariant(.fast, for: "p-rb")
        #expect(viewModel.beginDrag(playerID: "p-rb", at: .zero))

        // Dead center of the WR/CB sideline stack — an RB can never line up
        // there, so even dropping right between the two must hover nothing.
        let token = viewModel.point(x: 0.925, y: 0.485)
        viewModel.updateDrag(to: CGPoint(x: token.x, y: token.y + GameViewModel.dragLift))
        #expect(viewModel.hoveredSlotID == nil)
    }

    // MARK: Nearest-target resolution

    @Test func overlappingZonesResolveToTheNearestValidTarget() {
        let viewModel = GameViewModel(puzzle: SampleQuarter.puzzle)
        viewModel.fieldFrame = fieldFrame
        viewModel.selectVariant(.fast, for: "p-rb")
        #expect(viewModel.beginDrag(playerID: "p-rb", at: .zero))

        // s-backfield and s-left-backfield sit ~73pt apart — a drop point
        // between them is inside the snap radius of BOTH zones. The target
        // must resolve to the single nearest one, never ambiguously.
        let rightOfCenter = viewModel.point(x: 0.425, y: 0.74)
        viewModel.updateDrag(to: CGPoint(x: rightOfCenter.x, y: rightOfCenter.y + GameViewModel.dragLift))
        #expect(viewModel.hoveredSlotID == "s-backfield")

        let leftOfCenter = viewModel.point(x: 0.415, y: 0.74)
        viewModel.updateDrag(to: CGPoint(x: leftOfCenter.x, y: leftOfCenter.y + GameViewModel.dragLift))
        #expect(viewModel.hoveredSlotID == "s-left-backfield")
    }

    @Test func releasingAwayFromAnyCandidateReturnsThePlayerToTheTray() {
        let viewModel = GameViewModel(puzzle: SampleQuarter.puzzle)
        viewModel.fieldFrame = fieldFrame
        viewModel.selectVariant(.fast, for: "p-rb")

        // The deep-right decoy is a safety landmark — not an RB candidate —
        // and far outside the snap radius of every backfield zone.
        let deepSafety = viewModel.point(x: 0.84, y: 0.17)
        #expect(viewModel.beginDrag(
            playerID: "p-rb",
            at: CGPoint(x: deepSafety.x, y: deepSafety.y + GameViewModel.dragLift)
        ))
        viewModel.updateDrag(to: CGPoint(x: deepSafety.x, y: deepSafety.y + GameViewModel.dragLift))
        #expect(viewModel.hoveredSlotID == nil)
        viewModel.endDrag()

        #expect(viewModel.placements.isEmpty)
        #expect(viewModel.lives == viewModel.puzzle.startingLives)
        #expect(viewModel.result == .inProgress)
        #expect(!viewModel.isDragging)
    }

    @Test func aCorrectDropStillSnapsToItsTrueCoordinate() {
        let viewModel = GameViewModel(puzzle: SampleQuarter.puzzle)
        viewModel.fieldFrame = fieldFrame
        viewModel.selectVariant(.fast, for: "p-rb")
        #expect(viewModel.beginDrag(playerID: "p-rb", at: .zero))

        let slot = SampleQuarter.puzzle.slot(id: "s-backfield")!
        let point = viewModel.point(x: slot.x, y: slot.y)
        viewModel.updateDrag(to: CGPoint(x: point.x, y: point.y + GameViewModel.dragLift))
        #expect(viewModel.hoveredSlotID == "s-backfield")
        viewModel.endDrag()

        #expect(viewModel.placements.count == 1)
        // Solved players snap to the REAL football coordinate, never the
        // display-nudged marker position.
        #expect(viewModel.placements[0].slot.id == "s-backfield")
        #expect(viewModel.placements[0].slot.x == slot.x)
        #expect(viewModel.placements[0].slot.y == slot.y)
    }

    // MARK: Marker layout (no stacked "?")

    @Test func mysteryMarkersNeverOverlap() {
        let fieldSize = CGSize(width: 360, height: 560)
        let diameter = max(20 * 1.2, 24) // smallest in-game zone token
        let minSpacing = diameter + 5

        for puzzle in allPuzzles {
            let positions = PlacementZoneLayout.displayPositions(
                slots: puzzle.slots,
                fieldSize: fieldSize,
                visibleDiameter: diameter
            )
            #expect(positions.count == puzzle.slots.count, "\(puzzle.id)")
            let points = Array(positions.values)
            for i in points.indices {
                for j in (i + 1)..<points.count {
                    #expect(
                        hypot(points[i].x - points[j].x, points[i].y - points[j].y) >= minSpacing - 0.5,
                        "\(puzzle.id): markers for \(puzzle.slots[i].id) and \(puzzle.slots[j].id) overlap"
                    )
                }
            }
        }
    }

    /// The temporary marker may shift for readability, but only by a few
    /// points — it must still sit visually on the slot's football location.
    @Test func markerOffsetsStaySmall() {
        let puzzle = SampleQuarter.puzzle
        let fieldSize = CGSize(width: 360, height: 560)
        let positions = PlacementZoneLayout.displayPositions(
            slots: puzzle.slots,
            fieldSize: fieldSize,
            visibleDiameter: 30
        )
        #expect(positions.count == puzzle.slots.count)
        for slot in puzzle.slots {
            let marker = positions[slot.id] ?? .zero
            let shift = hypot(
                marker.x - CGFloat(slot.x) * fieldSize.width,
                marker.y - CGFloat(slot.y) * fieldSize.height
            )
            #expect(shift <= 24, "\(slot.id) moved \(shift)pt from its field position")
        }
    }
}
