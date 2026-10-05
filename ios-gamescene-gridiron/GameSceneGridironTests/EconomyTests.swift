import Testing
import Foundation
@testable import GameSceneGridiron

/// Phase 6 economy contract: reward values, idempotent claiming, the hint
/// economy, rewarded-ad safety rules, Last Chance once per quarter, the
/// postgame 2× once per match and interstitial frequency control.
@MainActor
struct EconomyTests {

    // MARK: Helpers

    private func makeWallet() -> PlayerWallet {
        let suite = "economy-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return PlayerWallet(defaults: defaults)
    }

    /// A finished game: 4 quarters recorded, the given set solved, optional OT.
    private func makeMatch(
        solvedQuarters: Set<Int> = [0, 1, 2],
        wentToOvertime: Bool = false,
        overtimeSolved: Bool = false
    ) -> GameMatch {
        var match = GameMatch.fresh()
        for index in 0..<4 {
            match.recordQuarter(
                index: index,
                label: "Q\(index + 1)",
                isOvertime: false,
                outcome: solvedQuarters.contains(index) ? .solved : .failed,
                correctPlacements: 4,
                wrongPlacements: 0,
                livesLost: 0,
                hintsUsed: 0
            )
        }
        if wentToOvertime {
            match.recordQuarter(
                index: 4,
                label: "OT",
                isOvertime: true,
                outcome: overtimeSolved ? .solved : .failed,
                correctPlacements: 4,
                wrongPlacements: 0,
                livesLost: 0,
                hintsUsed: 0
            )
        }
        return match
    }

    private func breakdown(
        for match: GameMatch,
        isPlayoff: Bool = false,
        isChampionship: Bool = false,
        transactionID: String = "match-test"
    ) -> MatchRewardBreakdown {
        MatchRewardBreakdown.forMatch(
            match,
            isPlayoff: isPlayoff,
            isChampionship: isChampionship,
            transactionID: transactionID
        )
    }

    // MARK: 1–3. Reward values

    @Test func quarterSolvedAndRegulationWinRewardsMatchTheConfig() {
        let breakdown = self.breakdown(for: makeMatch())
        #expect(breakdown.lines.map(\.label) == ["3 Quarters Solved", "Game Victory"])
        #expect(breakdown.lines.map(\.amount) == [
            EconomyConfig.standard.quarterSolvedReward * 3,
            EconomyConfig.standard.regulationWinReward
        ])
        #expect(breakdown.total == 70)
    }

    @Test func overtimeWinPaysTheOvertimeReward() {
        // 2 regulation solves + the OT solve = 3 quarters solved, paid at the
        // overtime win rate instead of the regulation one.
        let breakdown = self.breakdown(for: makeMatch(solvedQuarters: [0, 1], wentToOvertime: true, overtimeSolved: true))
        #expect(breakdown.lines.map(\.label) == ["3 Quarters Solved", "Overtime Victory"])
        #expect(breakdown.total == 30 + EconomyConfig.standard.overtimeWinReward)
    }

    @Test func playoffAndChampionshipBonusesStackOnTop() {
        let playoff = breakdown(for: makeMatch(), isPlayoff: true)
        #expect(playoff.lines.map(\.label) == ["3 Quarters Solved", "Game Victory", "Playoff Win"])
        #expect(playoff.total == 70 + EconomyConfig.standard.playoffWinBonus)

        let championship = breakdown(for: makeMatch(), isPlayoff: true, isChampionship: true)
        #expect(championship.lines.map(\.label) == ["3 Quarters Solved", "Game Victory", "Playoff Win", "Gridiron Champions"])
        #expect(championship.total == 70 + EconomyConfig.standard.playoffWinBonus + EconomyConfig.standard.championshipWinBonus)
    }

    @Test func losingAGameNeverSubtractsAndStillPaysSolvedQuarters() {
        let breakdown = self.breakdown(for: makeMatch(solvedQuarters: [0]))
        #expect(breakdown.lines.map(\.label) == ["1 Quarter Solved"])
        #expect(breakdown.total == EconomyConfig.standard.quarterSolvedReward)
    }

    // MARK: 4. Claim safety

    @Test func matchRewardCannotBeClaimedTwice() {
        let wallet = makeWallet()
        let breakdown = self.breakdown(for: makeMatch(), transactionID: "match-abc")
        #expect(wallet.claimMatchReward(breakdown))
        #expect(wallet.gameBalls == breakdown.total)
        #expect(!wallet.claimMatchReward(breakdown))
        #expect(wallet.gameBalls == breakdown.total)
    }

    // MARK: 5. Hint persistence (16. full persistence lives here too)

    @Test func hintsAndBalancePersistAcrossWalletReloads() {
        let defaults = UserDefaults(suiteName: "economy-persist-\(UUID().uuidString)")!
        let first = PlayerWallet(defaults: defaults)
        #expect(first.hints == EconomyConfig.standard.startingHints)
        first.addHints(2)
        first.consumeHint()

        let reloaded = PlayerWallet(defaults: defaults)
        #expect(reloaded.hints == first.hints)
        #expect(reloaded.gameBalls == first.gameBalls)
    }

    // MARK: 6–7. Buying hints with Game Balls

    @Test func buyingAHintDeductsExactlyTheHintCost() {
        let wallet = makeWallet()
        wallet.earn(amount: EconomyConfig.standard.hintCost, kind: .matchReward, transactionID: "m1")
        let hintsBefore = wallet.hints
        #expect(wallet.buyHint())
        #expect(wallet.gameBalls == 0)
        #expect(wallet.hints == hintsBefore + 1)
        #expect(wallet.transactions.contains { $0.kind == .hintPurchase && $0.amount == -EconomyConfig.standard.hintCost })
    }

    @Test func insufficientGameBallsBlocksThePurchase() {
        let wallet = makeWallet()
        wallet.earn(amount: EconomyConfig.standard.hintCost - 1, kind: .matchReward, transactionID: "m2")
        let hintsBefore = wallet.hints
        #expect(!wallet.canAffordHint)
        #expect(!wallet.buyHint())
        #expect(wallet.gameBalls == EconomyConfig.standard.hintCost - 1)
        #expect(wallet.hints == hintsBefore)
    }

    // MARK: 8–9. Rewarded hint

    @Test func rewardedHintGrantsExactlyOneHint() {
        let wallet = makeWallet()
        // Drain the free starting hints first.
        while wallet.consumeHint() {}
        #expect(wallet.hints == 0)
        // The grant path the view calls after the reward callback fired.
        #expect(wallet.addHints(1))
        #expect(wallet.hints == 1)
        #expect(wallet.consumeHint())
        #expect(!wallet.consumeHint())
    }

    @Test func rewardedAdResolvesGrantedOnlyThroughTheCallback() async {
        let ads = AdManager(interstitialEveryNGames: 2)
        // Development placeholder maps a completed watch to `.granted`; the
        // live SDK maps its reward callback to `.granted` and an early close
        // to `.dismissed` — callers only grant on `.granted`.
        let result = await ads.showRewarded(.hint)
        #expect(result == .granted)
    }

    // MARK: 10. Last Chance

    @Test func lastChanceIsOfferedExactlyOncePerQuarter() {
        let wallet = makeWallet()
        let key = "match-abc-q1"
        #expect(!wallet.hasUsedLastChance(for: key))
        #expect(wallet.markLastChanceUsed(for: key))
        #expect(wallet.hasUsedLastChance(for: key))
        #expect(!wallet.markLastChanceUsed(for: key))

        // A different quarter still gets its own offer.
        #expect(wallet.markLastChanceUsed(for: "match-abc-q2"))
    }

    @Test func lastChanceUsageSurvivesRestarts() {
        let defaults = UserDefaults(suiteName: "economy-restart-\(UUID().uuidString)")!
        let first = PlayerWallet(defaults: defaults)
        #expect(first.markLastChanceUsed(for: "match-xyz-q3"))
        let reloaded = PlayerWallet(defaults: defaults)
        #expect(reloaded.hasUsedLastChance(for: "match-xyz-q3"))
        #expect(!reloaded.markLastChanceUsed(for: "match-xyz-q3"))
    }

    // MARK: 11. Postgame 2×

    @Test func doublingWorksExactlyOncePerMatch() {
        let wallet = makeWallet()
        let breakdown = self.breakdown(for: makeMatch(), transactionID: "match-double")
        #expect(wallet.claimMatchReward(breakdown))
        let afterClaim = wallet.gameBalls

        #expect(!wallet.hasDoubledMatchReward(transactionID: breakdown.transactionID))
        #expect(wallet.doubleMatchReward(breakdown))
        #expect(wallet.gameBalls == afterClaim + breakdown.total)
        #expect(wallet.hasDoubledMatchReward(transactionID: breakdown.transactionID))
        #expect(!wallet.doubleMatchReward(breakdown))
        #expect(wallet.gameBalls == afterClaim + breakdown.total)
    }

    @Test func doublingRequiresAClaimedBaseReward() {
        let wallet = makeWallet()
        let breakdown = self.breakdown(for: makeMatch(), transactionID: "match-unclaimed")
        #expect(!wallet.doubleMatchReward(breakdown))
        #expect(wallet.gameBalls == 0)
    }

    // MARK: Wallet safety

    @Test func balanceNeverGoesNegativeAndZeroEarnsAreRejected() {
        let wallet = makeWallet()
        #expect(!wallet.spend(amount: 1, kind: .hintPurchase))
        #expect(wallet.gameBalls == 0)
        #expect(!wallet.earn(amount: 0, kind: .matchReward))
        #expect(!wallet.earn(amount: -5, kind: .matchReward))
        #expect(wallet.gameBalls == 0)
    }

    // MARK: Interstitial frequency

    @Test func interstitialAppearsAtMostOnceEveryTwoCompletedGames() {
        let ads = AdManager(interstitialEveryNGames: EconomyConfig.standard.interstitialEveryNGames)
        ads.recordCompletedGame()
        #expect(!ads.canShowInterstitial())
        ads.recordCompletedGame()
        #expect(ads.canShowInterstitial())
        ads.maybeShowInterstitial()
        #expect(ads.completedGamesSinceInterstitial == 0)
        #expect(!ads.canShowInterstitial())
    }

    @Test func noInterstitialRightAfterARewardedAd() async {
        let ads = AdManager(interstitialEveryNGames: 1)
        ads.recordCompletedGame()
        #expect(ads.canShowInterstitial())

        // Watching a rewarded ad suppresses the very next forced break once.
        _ = await ads.showRewarded(.doubleReward)
        #expect(!ads.canShowInterstitial())
        ads.maybeShowInterstitial()
        #expect(!ads.isNextInterstitialSuppressed)

        // The skipped break never consumed the frequency count, so the gate
        // is immediately eligible again for the next natural break.
        #expect(ads.canShowInterstitial())
        ads.maybeShowInterstitial()
        #expect(ads.completedGamesSinceInterstitial == 0)
        #expect(!ads.canShowInterstitial())
    }

    // MARK: Unique reward transaction per game

    @Test func everyGameGetsAUniqueRewardTransactionID() {
        let matchViewModel = MatchViewModel()
        let firstID = matchViewModel.matchID
        #expect(matchViewModel.rewardBreakdown == nil)
        matchViewModel.startGame()
        #expect(matchViewModel.matchID != firstID)
        #expect(matchViewModel.rewardBreakdown == nil)
        #expect(matchViewModel.currentLastChanceKey.hasSuffix("-q0"))
    }
}
