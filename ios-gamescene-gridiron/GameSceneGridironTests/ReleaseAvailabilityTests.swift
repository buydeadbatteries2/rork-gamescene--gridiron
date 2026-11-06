import Foundation
import Testing
@testable import GameSceneGridiron

@MainActor
struct ReleaseAvailabilityTests {
    @Test func futureEntriesAreDisabled() {
        #expect(!ReleaseAvailability.versus)
        #expect(!ReleaseAvailability.brandBattle)
    }

    @Test func productionVersusStoreIsDormantEvenWhenAskedToRecover() async {
        let store = VersusStore()
        #expect(!store.isAvailable)
        await store.refresh(force: true)
        await store.loadHistory()
        await store.flushPending()
        let match = await store.find(difficulty: .pro)
        #expect(match == nil)
        #expect(!store.hasPendingWork)
        #expect(store.attentionCount == 0)
        #expect(store.openMatches.isEmpty)
        #expect(store.unviewedResults.isEmpty)
        #expect(store.history.isEmpty)
        #expect(!store.isRefreshing)
    }

    @Test func guestCoreAccessIsIndependentOfFutureFeatures() {
        #expect(AccountGatePolicy.canPlaySolo(.guest))
        #expect(AccountGatePolicy.requiresAccount(.guest))
    }
}
