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

    @Test func figuresShareOneBodyScaleAcrossStancesAndSides() {
        for position in FootballPosition.allCases {
            let ratio = FieldFigureCatalog.figure(for: position).heightRatio
            #expect(ratio > 0.5 && ratio <= 1.0, "\(position) ratio \(ratio)")
        }
        let ol = FieldFigureCatalog.figure(for: .ol).heightRatio
        let dl = FieldFigureCatalog.figure(for: .dl).heightRatio
        #expect(FieldFigureCatalog.figure(for: .fs).heightRatio > FieldFigureCatalog.figure(for: .lb).heightRatio)
        #expect(abs(ol - dl) < 0.05)
        #expect(FieldFigureCatalog.figure(for: .cb).heightRatio == FieldFigureCatalog.figure(for: .wr).heightRatio)
        #expect(FieldFigureCatalog.standingHeightScale > 2 && FieldFigureCatalog.standingHeightScale < 3.5)
    }

    @Test func turfRenderIsBundledAndScrimmageSitsBelowFirstDown() {
        #expect(UIImage(named: FieldTurf.turfAsset) != nil)
        #expect(FieldMarkings.firstDownY < FieldMarkings.scrimmageY)
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

    @Test func offenseAlwaysDrawsOverDefenseAndNearerFiguresDrawOverFartherOnes() {
        // Viewer looks up-field from behind the offense: any offensive figure
        // beats any defensive figure, even one lower on the field.
        let deepOffense = GameFieldView.figureZIndex(position: .wr, y: 0.55)
        let lowDefense = GameFieldView.figureZIndex(position: .cb, y: 0.95)
        #expect(deepOffense > lowDefense)
        // Within a side, the figure closer to the bottom edge is in front.
        #expect(GameFieldView.figureZIndex(position: .ol, y: 0.7) > GameFieldView.figureZIndex(position: .qb, y: 0.6))
        #expect(GameFieldView.figureZIndex(position: .dl, y: 0.5) > GameFieldView.figureZIndex(position: .lb, y: 0.3))
        // Figures never climb above the placement-zone / inspected-evidence layers.
        #expect(GameFieldView.figureZIndex(position: .qb, y: 1.0) < 4)
    }
}
