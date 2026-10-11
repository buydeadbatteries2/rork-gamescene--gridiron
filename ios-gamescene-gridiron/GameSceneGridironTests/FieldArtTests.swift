import Testing
import UIKit
@testable import GameSceneGridiron

/// Field art contract: every position has a photoreal figure facing the right
/// way (offense seen from behind, defense from the front), and every evidence
/// object has a bundled photoreal render.
@MainActor
struct FieldArtTests {

    @Test func offenseFiguresAreSeenFromBehindAndDefenseFromTheFront() {
        for position in FootballPosition.allCases {
            let figure = FieldFigureCatalog.figure(for: position)
            #expect(figure.facing == FieldFigureCatalog.requiredFacing(for: position))
            switch position.side {
            case .offense:
                #expect(figure.facing == .back)
                #expect(figure.asset.hasSuffix("_back"))
            case .defense:
                #expect(figure.facing == .front)
                #expect(figure.asset.hasSuffix("_front"))
            }
        }
    }

    @Test func everyPositionGroupHasItsOwnFigureAndSafetiesShareOne() {
        #expect(FieldFigureCatalog.figure(for: .ss).asset == FieldFigureCatalog.figure(for: .fs).asset)
        let distinct = Set(FootballPosition.allCases.map { FieldFigureCatalog.figure(for: $0).asset })
        #expect(distinct.count == 9)
        #expect(FieldFigureCatalog.allAssets.count == 9)
    }

    @Test func everyFieldFigureIsBundled() {
        for asset in FieldFigureCatalog.allAssets {
            #expect(UIImage(named: asset) != nil, "missing field figure \(asset)")
        }
    }

    @Test func everyEvidenceKindHasABundledRender() {
        #expect(EvidenceItem.Kind.allCases.count == 38)
        for kind in EvidenceItem.Kind.allCases {
            #expect(UIImage(named: kind.assetName) != nil, "missing evidence render \(kind.assetName)")
        }
    }

    @Test func evidenceAssetNamesFollowTheSnakeCaseConvention() {
        #expect(EvidenceItem.Kind.brokenHelmetStrap.assetName == "evidence_broken_helmet_strap")
        #expect(EvidenceItem.Kind.pylon.assetName == "evidence_pylon")
        #expect(EvidenceItem.Kind.draggedFootTrail.assetName == "evidence_dragged_foot_trail")
        #expect(EvidenceItem.Kind.muddyFootprints.isFieldMark)
        #expect(!EvidenceItem.Kind.clipboard.isFieldMark)
    }

    @Test func clueBadgeColorsCycleSafely() {
        #expect(ClueNotebookView.clueBadgeColors.count == 6)
        #expect(ClueNotebookView.badgeColor(for: 0) == ClueNotebookView.badgeColor(for: 6))
        #expect(ClueNotebookView.badgeColor(for: -1) == ClueNotebookView.badgeColor(for: 5))
    }
}
