import Testing
@testable import GameSceneGridiron

@MainActor
struct ShopResolutionTests {
    @Test func productionCatalogMapsExactly() {
        let ids = ["25_game_balls", "150_game_balls", "350_game_balls", "starter_pack", "remove_ads"]
        #expect(PurchaseManager.gameBallProductIDs + [PurchaseManager.starterPackProductID, PurchaseManager.removeAdsProductID] == ids)
        let metadata = ids.map { (package: $0 + "_app", product: $0) }
        for (index, id) in ids.enumerated() {
            #expect(PurchaseManager.packageIndex(forProductID: id, metadata: metadata, isDevelopmentBuild: false) == index)
            #expect(PurchaseManager.packageIndex(forProductID: id, metadata: [], isDevelopmentBuild: false) == nil)
            #expect(PurchaseManager.packageIndex(forProductID: id, metadata: [("custom", id)], isDevelopmentBuild: false) == 0)
        }
        #expect(PurchaseManager.gameBallAmounts == ["25_game_balls": 25, "150_game_balls": 150, "350_game_balls": 350])
        #expect(PurchaseManager.defaultOfferingID == "default")
        #expect(PurchaseManager.removeAdsEntitlementID == "remove_ads_ent")
        #expect(PurchaseManager.starterPackEntitlementID == "starter_pack_ent")
    }

    @Test func missingOfferingHasNoPriceWhileFutureModesDisabled() {
        #expect(!ReleaseAvailability.versus)
        let manager = PurchaseManager()
        for id in PurchaseManager.gameBallProductIDs + [PurchaseManager.starterPackProductID, PurchaseManager.removeAdsProductID] {
            #expect(manager.package(forProductID: id) == nil)
            #expect(manager.localizedPrice(forProductID: id) == nil)
            // The shipping flag is not consulted by the production mapping.
            #expect(PurchaseManager.packageIndex(forProductID: id, metadata: [(id + "_app", id)], isDevelopmentBuild: false) == 0)
        }
    }
}
