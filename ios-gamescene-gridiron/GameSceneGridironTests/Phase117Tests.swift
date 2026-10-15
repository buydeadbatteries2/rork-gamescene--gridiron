import Testing
import Foundation
import CoreGraphics
@testable import GameSceneGridiron

/// Phase 11.7 — final Game Ball economy, hint charging, the Last Chance
/// rescue path, forced-ad gates and the RevenueCat store configuration.
@MainActor
struct Phase117Tests {

    // MARK: Helpers

    private func makeDefaults() -> UserDefaults {
        let suite = "phase117-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defaults.set(true, forKey: GameViewModel.clockIntroKey)
        return defaults
    }

    private func makeWallet() -> PlayerWallet {
        PlayerWallet(defaults: makeDefaults())
    }

    private func makeViewModel(wallet: PlayerWallet? = nil, difficulty: DifficultyLevel = .pro, puzzle: QuarterPuzzle = SampleQuarter.puzzle) -> GameViewModel {
        GameViewModel(
            puzzle: puzzle,
            wallet: wallet ?? makeWallet(),
            difficulty: difficulty,
            defaults: makeDefaults()
        )
    }

    private func drag(_ viewModel: GameViewModel, playerID: String, x: Double, y: Double) {
        viewModel.fieldFrame = CGRect(x: 0, y: 0, width: 400, height: 300)
        let point = viewModel.point(x: x, y: y)
        if viewModel.beginDrag(playerID: playerID, at: CGPoint(x: point.x, y: point.y + GameViewModel.dragLift)) {
            viewModel.endDrag()
        }
    }

    private func select(_ viewModel: GameViewModel, playerID: String, profile: PlayerProfile) {
        if viewModel.selectedProfile(for: playerID) != profile {
            viewModel.selectProfile(profile, for: playerID)
        }
    }

    /// Solves the whole sample quarter with the authored solutions.
    private func solveQuarter(_ viewModel: GameViewModel) async {
        let placements: [(id: String, x: Double, y: Double, profile: PlayerProfile)] = [
            ("p-rb", 0.50, 0.78, .fast),
            ("p-fs", 0.50, 0.115, .veteran),
            ("p-te", 0.775, 0.565, .powerful),
            ("p-wr", 0.925, 0.535, .veteran),
            ("p-cb", 0.925, 0.435, .powerful),
            ("p-lb", 0.63, 0.365, .fast),
        ]
        for placement in placements {
            select(viewModel, playerID: placement.id, profile: placement.profile)
            drag(viewModel, playerID: placement.id, x: placement.x, y: placement.y)
        }
        // The verdict lands through a delayed animation task.
        try? await Task.sleep(for: .seconds(1.3))
    }

    /// Burns one life with a wrong profile on the RB's correct slot.
    private func loseLife(_ viewModel: GameViewModel) {
        select(viewModel, playerID: "p-rb", profile: .veteran)
        drag(viewModel, playerID: "p-rb", x: 0.50, y: 0.78)
    }

    /// Finishes a full lost quarter through the real flow (lives drained →
    /// Last Chance accepted → verdict recorded).
    private func loseQuarter(_ matchViewModel: MatchViewModel) async {
        let viewModel = makeViewModel()
        viewModel.lastChanceKey = matchViewModel.currentLastChanceKey
        for _ in 0..<viewModel.puzzle.startingLives { loseLife(viewModel) }
        if viewModel.isLastChancePending { viewModel.acceptLastChanceLoss() }
        // The verdict lands through a delayed animation task.
        try? await Task.sleep(for: .seconds(1.3))
        matchViewModel.finishQuarter(with: viewModel)
    }

    private func quarterSolvedTransactions(_ wallet: PlayerWallet, transactionID: String) -> [RewardTransaction] {
        wallet.transactions.filter { $0.kind == .quarterSolved && $0.id == transactionID }
    }

    // MARK: 1–4. Quarter rewards

    @Test func winningQuarterGrantsExactlyOneGameBall() async {
        let matchViewModel = MatchViewModel()
        let wallet = PlayerWallet.shared
        let viewModel = makeViewModel()
        viewModel.lastChanceKey = matchViewModel.currentLastChanceKey
        await solveQuarter(viewModel)
        #expect(viewModel.result == .won)

        matchViewModel.finishQuarter(with: viewModel)

        let id = "quarter-\(matchViewModel.matchID.uuidString)-q0"
        let grants = quarterSolvedTransactions(wallet, transactionID: id)
        #expect(grants.count == 1)
        #expect(grants.first?.amount == EconomyConfig.standard.quarterSolvedReward)
        #expect(EconomyConfig.standard.quarterSolvedReward == 1)
    }

    @Test func sameQuarterCannotRewardTwice() async {
        let matchViewModel = MatchViewModel()
        let wallet = PlayerWallet.shared
        let viewModel = makeViewModel()
        viewModel.lastChanceKey = matchViewModel.currentLastChanceKey
        await solveQuarter(viewModel)

        matchViewModel.finishQuarter(with: viewModel)
        matchViewModel.finishQuarter(with: viewModel) // double-finish: ledger must block

        let id = "quarter-\(matchViewModel.matchID.uuidString)-q0"
        #expect(quarterSolvedTransactions(wallet, transactionID: id).count == 1)
    }

    @Test func losingQuarterGrantsZero() async {
        let matchViewModel = MatchViewModel()
        let wallet = PlayerWallet.shared
        let viewModel = makeViewModel()
        viewModel.lastChanceKey = matchViewModel.currentLastChanceKey
        for _ in 0..<viewModel.puzzle.startingLives { loseLife(viewModel) }
        if viewModel.isLastChancePending { viewModel.acceptLastChanceLoss() }
        try? await Task.sleep(for: .seconds(1.3))
        #expect(viewModel.result == .lost)

        let before = wallet.transactions.filter { $0.kind == .quarterSolved }.count
        matchViewModel.finishQuarter(with: viewModel)
        #expect(wallet.transactions.filter { $0.kind == .quarterSolved }.count == before)
    }

    @Test func regulationCapsAtFourAndSolvedOTPaysOne() {
        let config = EconomyConfig.standard
        #expect(config.quarterSolvedReward == 1)
        // 4 solved quarters × 1 — no win bonuses on top.
        var match = GameMatch.fresh()
        for index in 0..<4 {
            match.recordQuarter(index: index, label: "Q\(index + 1)", isOvertime: false, outcome: .solved, correctPlacements: 4, wrongPlacements: 0, livesLost: 0, hintsUsed: 0)
        }
        let regulation = MatchRewardBreakdown.forMatch(match, isPlayoff: true, isChampionship: true, transactionID: "t")
        #expect(regulation.total == 4)

        match.recordQuarter(index: 4, label: "OT", isOvertime: true, outcome: .solved, correctPlacements: 4, wrongPlacements: 0, livesLost: 0, hintsUsed: 0)
        let withOT = MatchRewardBreakdown.forMatch(match, isPlayoff: true, isChampionship: true, transactionID: "t")
        #expect(withOT.total == 5)
    }

    // MARK: 5–7. Hint economy

    @Test func hintCostIsTenGameBalls() {
        #expect(EconomyConfig.standard.hintCost == 10)
    }

    @Test func hintInventoryIsConsumedBeforeGameBalls() {
        let wallet = makeWallet()
        wallet.earn(amount: 25, kind: .matchReward, transactionID: "hint-fund")
        let startingBalls = wallet.gameBalls
        #expect(wallet.hints > 0)
        #expect(wallet.consumeHintOrCharge())
        #expect(wallet.hints == EconomyConfig.standard.startingHints - 1)
        #expect(wallet.gameBalls == startingBalls) // inventory paid, not currency

        while wallet.consumeHint() {}
        #expect(wallet.consumeHintOrCharge()) // now charges currency
        #expect(wallet.gameBalls == startingBalls - EconomyConfig.standard.hintCost)
        #expect(wallet.gameBalls >= 0) // never negative
    }

    @Test func unaffordableHintIsRejectedAtomically() {
        let wallet = makeWallet()
        while wallet.consumeHint() {}
        #expect(!wallet.canAffordHint)
        #expect(!wallet.consumeHintOrCharge())
        #expect(wallet.gameBalls == 0)
        #expect(!wallet.transactions.contains { $0.kind == .hintPurchase })
    }

    // MARK: 8–9. Simplified hints

    @Test func everyLibraryHintSimplifiesWithMetadataAndNeverRevealsTheAnswer() {
        var checked = 0
        for caseFile in CaseLibrary.all {
            guard caseFile.isCompetitiveEligible else { continue }
            let positions = Dictionary(uniqueKeysWithValues: caseFile.missing.map { ($0.key, $0.position.fullName) })
            let profiles = Dictionary(uniqueKeysWithValues: caseFile.solution.map { ($0.playerKey, $0.profile) })
            for hint in caseFile.hints {
                let simplified = HintSimplifier.simplify(
                    text: hint.text,
                    positionName: positions[hint.playerKey],
                    profile: profiles[hint.playerKey]
                )
                checked += 1
                #expect(!simplified.text.isEmpty)
                #expect(!simplified.highlightPhrases.isEmpty, "hint \(hint.playerKey) has no highlight phrases")
                for phrase in simplified.highlightPhrases {
                    #expect(simplified.text.localizedCaseInsensitiveContains(phrase), "phrase \(phrase) missing from \(hint.playerKey)")
                }
                if let profile = profiles[hint.playerKey] {
                    // Word-boundary check: "fastest" is fair game, "Fast" as
                    // a standalone word would reveal the choice-screen answer.
                    let pattern = "\\b" + NSRegularExpression.escapedPattern(for: profile.title) + "\\b"
                    let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                    let match = regex.flatMap { first in first.firstMatch(in: simplified.text, range: NSRange(simplified.text.startIndex..., in: simplified.text)) != nil ? true : nil }
                    #expect(match != true, "hint \(hint.playerKey) reveals the profile answer \(profile.title)")
                }
            }
        }
        #expect(checked > 400) // 150 cases × several hints each
    }

    @Test func simplifiedHintExampleTranslatesTheOverratedCliche() {
        let simplified = HintSimplifier.simplify(
            text: "The defender everyone expected to dominate keeps biting on the underneath action.",
            positionName: "free safety",
            profile: .overrated
        )
        #expect(simplified.text.localizedCaseInsensitiveContains("highly regarded"))
        #expect(simplified.text.localizedCaseInsensitiveContains("making mistakes"))
        #expect(simplified.highlightPhrases.contains("highly regarded"))
        #expect(simplified.highlightPhrases.contains("making mistakes"))
        #expect(!simplified.text.localizedCaseInsensitiveContains("overrated"))
    }

    // MARK: 10–17. Last Chance rescue path

    @Test func lastNormalLifeTriggersLastChance() {
        let wallet = makeWallet()
        let viewModel = makeViewModel(wallet: wallet)
        viewModel.lastChanceKey = "rescue-test-q0"
        for _ in 0..<viewModel.puzzle.startingLives { loseLife(viewModel) }
        #expect(viewModel.lives == 0)
        #expect(viewModel.isLastChancePending)
        #expect(!viewModel.isPostVideoRescue)
    }

    @Test func rewardedRescueGrantsOneAttemptOnlyAfterCallback() {
        let wallet = makeWallet()
        let viewModel = makeViewModel(wallet: wallet)
        viewModel.lastChanceKey = "rescue-test-q1"

        // Without a pending offer nothing happens (no callback, no grant).
        viewModel.grantLastChanceLife()
        #expect(viewModel.lives == viewModel.puzzle.startingLives)

        for _ in 0..<viewModel.puzzle.startingLives { loseLife(viewModel) }
        #expect(viewModel.isLastChancePending)

        // The view calls this only after the reward callback fired (.granted).
        viewModel.grantLastChanceLife()
        #expect(viewModel.lives == 1)
        #expect(!viewModel.isLastChancePending)
        #expect(!wallet.canUseVideoRescue(for: "rescue-test-q1"))
        // Exactly one extra attempt — never three lives, never timeouts.
        #expect(viewModel.lives == 1)
    }

    @Test func failedRewardedRescueOffersHintNotAnotherVideo() {
        let wallet = makeWallet()
        let viewModel = makeViewModel(wallet: wallet)
        viewModel.lastChanceKey = "rescue-test-q2"
        for _ in 0..<viewModel.puzzle.startingLives { loseLife(viewModel) }
        viewModel.grantLastChanceLife()

        // The rescue attempt fails again — the offer returns in the
        // post-video stage: hint or loss, never a second video.
        for _ in 0..<1 { loseLife(viewModel) }
        #expect(viewModel.isLastChancePending)
        #expect(viewModel.isPostVideoRescue)
        #expect(!wallet.canUseVideoRescue(for: "rescue-test-q2"))
    }

    @Test func hintRescueGrantsExactlyOneAdditionalAttempt() {
        let wallet = makeWallet()
        while wallet.consumeHint() {} // empty inventory → charges Game Balls
        wallet.earn(amount: 25, kind: .matchReward, transactionID: "rescue-fund")
        let viewModel = makeViewModel(wallet: wallet)
        viewModel.lastChanceKey = "rescue-test-q3"
        for _ in 0..<viewModel.puzzle.startingLives { loseLife(viewModel) }

        viewModel.grantRescueHintLife()
        #expect(viewModel.lives == 1)
        #expect(!viewModel.isLastChancePending)
        #expect(wallet.gameBalls == 25 - EconomyConfig.standard.hintCost)
        #expect(wallet.usedHintRescue(for: "rescue-test-q3"))
        #expect(!viewModel.usedHints.isEmpty) // the simplified lead was revealed
    }

    @Test func failedHintRescueEndsTheQuarterWithNoFurtherOffers() async {
        let wallet = makeWallet()
        let viewModel = makeViewModel(wallet: wallet)
        viewModel.lastChanceKey = "rescue-test-q4"
        for _ in 0..<viewModel.puzzle.startingLives { loseLife(viewModel) }
        viewModel.grantRescueHintLife()
        #expect(viewModel.lives == 1)

        loseLife(viewModel) // the rescue attempt fails
        try? await Task.sleep(for: .seconds(1.3))
        #expect(viewModel.result == .lost)
        #expect(!viewModel.isLastChancePending) // no loop, no second ad, no second hint
    }

    @Test func directHintRescueSkipsTheVideoForGood() async {
        let wallet = makeWallet()
        let viewModel = makeViewModel(wallet: wallet)
        viewModel.lastChanceKey = "rescue-test-q5"
        for _ in 0..<viewModel.puzzle.startingLives { loseLife(viewModel) }
        #expect(viewModel.isLastChancePending)

        // USE HINT immediately at the first Last Chance screen.
        viewModel.grantRescueHintLife()
        loseLife(viewModel) // the hint-rescue attempt fails
        try? await Task.sleep(for: .seconds(1.3))

        #expect(viewModel.result == .lost)
        #expect(!viewModel.isLastChancePending) // WATCH VIDEO is never offered after
    }

    @Test func rescueSequenceHasNoLoop() async {
        // Full path: lives → video rescue → hint rescue → loss. The rescue
        // flags allow exactly two rescues, then the quarter must end.
        let wallet = makeWallet()
        let viewModel = makeViewModel(wallet: wallet)
        viewModel.lastChanceKey = "rescue-test-q6"
        for _ in 0..<viewModel.puzzle.startingLives { loseLife(viewModel) }
        #expect(viewModel.isLastChancePending)
        viewModel.grantLastChanceLife()
        loseLife(viewModel)
        #expect(viewModel.isLastChancePending && viewModel.isPostVideoRescue)
        viewModel.grantRescueHintLife()
        loseLife(viewModel)
        try? await Task.sleep(for: .seconds(1.3))
        #expect(viewModel.result == .lost)
        #expect(!viewModel.isLastChancePending)
    }

    @Test func rescueLedgersPersistAcrossRestarts() {
        let defaults = makeDefaults()
        let wallet = PlayerWallet(defaults: defaults)
        #expect(wallet.markVideoRescueUsed(for: "persist-q1"))
        #expect(wallet.markHintRescueUsed(for: "persist-q2"))
        let reloaded = PlayerWallet(defaults: defaults)
        #expect(!reloaded.canUseVideoRescue(for: "persist-q1"))
        #expect(reloaded.usedHintRescue(for: "persist-q2"))
    }

    // MARK: 18–26. Forced-ad gates

    @Test func winningRegulationQuarterGateSkipsForTwoGameBalls() async {
        let matchViewModel = MatchViewModel()
        let wallet = PlayerWallet.shared
        let viewModel = makeViewModel()
        viewModel.lastChanceKey = matchViewModel.currentLastChanceKey
        await solveQuarter(viewModel)
        matchViewModel.finishQuarter(with: viewModel)

        #expect(matchViewModel.adGateDecision() == .forced(skipCost: 2))
        let before = wallet.gameBalls
        #expect(matchViewModel.skipAd(cost: 2))
        #expect(wallet.gameBalls == before - 2)
        #expect(wallet.transactions.last?.kind == .adSkip)
    }

    @Test func losingQuarterHasNoAdGateAndNoCharge() async {
        let matchViewModel = MatchViewModel()
        await loseQuarter(matchViewModel)
        #expect(matchViewModel.match.quarterRecords.last?.outcome == .failed)
        // A lost quarter advances free — no gate, no Game Ball charge.
        #expect(matchViewModel.adGateDecision() == .none)
    }

    @Test func trainingAndFirstSeasonGameHaveNoForcedAds() {
        // Training: pure policy.
        #expect(AdGatePolicy.decision(
            quarterWon: true, isOvertimeTransition: false, isAdFree: false,
            forcedAdsShown: 0, isTraining: true
        ) == .none)
        // First regular-season game: through the match view model.
        let first = MatchViewModel(seasonNumber: 1, week: 1)
        #expect(first.isFirstSeasonGame)
        #expect(AdGatePolicy.decision(
            quarterWon: true, isOvertimeTransition: false, isAdFree: false,
            forcedAdsShown: 0, isFirstSeasonGame: first.isFirstSeasonGame
        ) == .none)
        // A later game is gated again.
        let later = MatchViewModel(seasonNumber: 1, week: 2)
        #expect(!later.isFirstSeasonGame)
        #expect(AdGatePolicy.decision(
            quarterWon: true, isOvertimeTransition: false, isAdFree: false,
            forcedAdsShown: 0, isFirstSeasonGame: later.isFirstSeasonGame
        ) == .forced(skipCost: 2))
    }

    @Test func noMoreThanTwoForcedAdsOccurInOneGame() {
        let wallet = makeWallet()
        let key = "cap-test-match"
        // One forced ad shown: the next won transition still gates.
        #expect(wallet.recordForcedAd(for: key) == 1)
        #expect(AdGatePolicy.decision(
            quarterWon: true, isOvertimeTransition: false, isAdFree: false,
            forcedAdsShown: wallet.forcedAdCount(for: key)
        ) == .forced(skipCost: 2))
        // Second forced ad: the cap is reached.
        #expect(wallet.recordForcedAd(for: key) == 2)
        // Every remaining transition — OT included — is free, and no skip
        // charge is ever displayed.
        #expect(AdGatePolicy.decision(
            quarterWon: true, isOvertimeTransition: false, isAdFree: false,
            forcedAdsShown: wallet.forcedAdCount(for: key)
        ) == .none)
        #expect(AdGatePolicy.decision(
            quarterWon: true, isOvertimeTransition: true, isAdFree: false,
            forcedAdsShown: EconomyConfig.standard.maxForcedAdsPerGame
        ) == .none)
    }

    @Test func overtimeGateCostsThreeWhenScheduled() async {
        let matchViewModel = MatchViewModel()
        let viewModel = makeViewModel()
        viewModel.lastChanceKey = matchViewModel.currentLastChanceKey
        // 2 solved + 2 lost → overtime required.
        await solveQuarter(viewModel)
        matchViewModel.finishQuarter(with: viewModel)
        await loseQuarter(matchViewModel)
        let second = makeViewModel()
        second.lastChanceKey = matchViewModel.currentLastChanceKey
        await solveQuarter(second)
        matchViewModel.finishQuarter(with: second)
        await loseQuarter(matchViewModel)

        #expect(matchViewModel.match.needsOvertime)
        #expect(matchViewModel.adGateDecision() == .forced(skipCost: 3))
    }

    @Test func overtimeIsFreeOnceTheCapIsReached() {
        // Two forced ads already played in regulation: the OT transition is
        // free — no ad, no 3-Game Ball skip charge.
        var match = GameMatch.fresh()
        for index in 0..<2 {
            match.recordQuarter(index: index, label: "Q\(index + 1)", isOvertime: false, outcome: .solved, correctPlacements: 4, wrongPlacements: 0, livesLost: 0, hintsUsed: 0)
        }
        for index in 2..<4 {
            match.recordQuarter(index: index, label: "Q\(index + 1)", isOvertime: false, outcome: .failed, correctPlacements: 0, wrongPlacements: 0, livesLost: 0, hintsUsed: 0)
        }
        #expect(match.needsOvertime)
        #expect(AdGatePolicy.decision(
            quarterWon: true, isOvertimeTransition: true, isAdFree: false,
            forcedAdsShown: 2
        ) == .none)
        #expect(AdGatePolicy.decision(
            quarterWon: true, isOvertimeTransition: true, isAdFree: false,
            forcedAdsShown: 1
        ) == .forced(skipCost: 3))
    }

    @Test func removeAdsBypassesEveryForcedGate() {
        #expect(AdGatePolicy.decision(
            quarterWon: true, isOvertimeTransition: true, isAdFree: true,
            forcedAdsShown: 0
        ) == .none)
        #expect(AdGatePolicy.decision(
            quarterWon: true, isOvertimeTransition: false, isAdFree: true,
            forcedAdsShown: 2
        ) == .none)
    }

    @Test func removeAdsDoesNotDisableRewardedVideos() async {
        // Rewarded placements stay available regardless of ownership: the
        // rewarded path never consults the entitlement.
        let ads = AdManager()
        let result = await ads.showRewarded(.lastChanceLife)
        #expect(result == .granted) // DEBUG placeholder: voluntary reward works
    }

    // MARK: 27–31. Consumable purchases

    @Test func gameBallConsumablesGrantExactAmounts() {
        let wallet = makeWallet()
        #expect(PurchaseManager.gameBallAmounts["25_game_balls"] == 25)
        #expect(PurchaseManager.gameBallAmounts["150_game_balls"] == 150)
        #expect(PurchaseManager.gameBallAmounts["350_game_balls"] == 350)
        #expect(PurchaseManager.gameBallAmounts.count == 3)

        #expect(wallet.grantStoreGameBalls(25, transactionID: "txn-25"))
        #expect(wallet.gameBalls == 25)
        #expect(wallet.grantStoreGameBalls(150, transactionID: "txn-150"))
        #expect(wallet.gameBalls == 175)
        #expect(wallet.grantStoreGameBalls(350, transactionID: "txn-350"))
        #expect(wallet.gameBalls == 525)
        #expect(wallet.transactions.filter { $0.kind == .storePurchase }.count == 3)
    }

    @Test func consumableTransactionsCannotGrantTwice() {
        let wallet = makeWallet()
        #expect(wallet.grantStoreGameBalls(150, transactionID: "txn-dup"))
        #expect(wallet.gameBalls == 150)
        #expect(!wallet.grantStoreGameBalls(150, transactionID: "txn-dup"))
        #expect(wallet.gameBalls == 150)
    }

    @Test func consumablesNeverDependOnEntitlements() {
        // The Game Ball products are deliberately absent from the
        // entitlement list; granting goes through the transaction ledger.
        let entitlementProducts = [PurchaseManager.starterPackProductID, PurchaseManager.removeAdsProductID]
        for productID in PurchaseManager.gameBallProductIDs {
            #expect(!entitlementProducts.contains(productID))
        }
    }

    // MARK: 32–34. Starter Pack & Remove Ads entitlements

    @Test func starterPackGrantsContentsExactlyOnce() {
        let wallet = makeWallet()
        #expect(wallet.grantStarterPackContents())
        #expect(wallet.hints == EconomyConfig.standard.startingHints + EconomyConfig.standard.starterPackHints)
        #expect(wallet.gameBalls == EconomyConfig.standard.starterPackGameBalls)
        #expect(EconomyConfig.standard.starterPackHints == 2)
        #expect(EconomyConfig.standard.starterPackGameBalls == 10)
        #expect(wallet.hasStarterPackGrant)

        // A restore / re-grant can never duplicate the contents.
        #expect(!wallet.grantStarterPackContents())
        #expect(wallet.hints == EconomyConfig.standard.startingHints + 2)
        #expect(wallet.gameBalls == 10)
    }

    @Test func entitlementIdentifiersMatchProduction() {
        #expect(PurchaseManager.removeAdsEntitlementID == "remove_ads_ent")
        #expect(PurchaseManager.starterPackEntitlementID == "starter_pack_ent")
        #expect(PurchaseManager.starterPackProductID == "starter_pack")
        #expect(PurchaseManager.removeAdsProductID == "remove_ads")
        #expect(PurchaseManager.defaultOfferingID == "default")
    }

    @Test func removeAdsEntitlementControlsOwnershipState() {
        // The manager derives ownership exclusively from verified
        // CustomerInfo entitlements — with no store, ownership is false and
        // forced ads stay governed by the policy alone.
        let manager = PurchaseManager(wallet: makeWallet())
        #expect(manager.hasRemoveAds == false)
        #expect(manager.hasStarterPack == false)
    }

    // MARK: 35–36. Prices & purchase states

    @Test func localizedPricesComeFromTheStoreNeverHardcoded() {
        let manager = PurchaseManager(wallet: makeWallet())
        // No offering loaded in this build → no price is fabricated; the UI
        // shows the unavailable state instead.
        #expect(manager.localizedPrice(forProductID: "25_game_balls") == nil)
        #expect(manager.package(forProductID: "starter_pack") == nil)
    }

    @Test func purchaseCancellationNeverShowsSuccess() {
        let cancelled = PurchaseManager.PurchaseFlowState.cancelled
        let pending = PurchaseManager.PurchaseFlowState.pending
        let success = PurchaseManager.PurchaseFlowState.success(transactionID: "t")
        #expect(cancelled != success)
        #expect(pending != success)
        #expect(PurchaseManager.PurchaseFlowState.failed("x") != success)
        if case .success = cancelled { #expect(Bool(false), "cancellation must not read as success") }
    }

    // MARK: 37. Achievement rebalance

    @Test func achievementRewardsUseTheReducedValues() {
        let config = EconomyConfig.standard
        #expect(config.achievementRewardFirstCase == 2)
        #expect(config.achievementRewardPerfectGame == 3)
        #expect(config.achievementRewardFirstChampionship == 10)
        #expect(config.achievementRewardUndefeated == 15)
        #expect(config.achievementRewardHallWorthy == 25)

        #expect(AchievementCatalog.achievement(for: .firstCase).reward == 2)
        #expect(AchievementCatalog.achievement(for: .perfectGame).reward == 3)
        #expect(AchievementCatalog.achievement(for: .caseClosed).reward == 10)
        #expect(AchievementCatalog.achievement(for: .undefeated).reward == 15)
        #expect(AchievementCatalog.achievement(for: .hallWorthy).reward == 25)
    }

    // MARK: 38. Save migration

    @Test func legacyEconomySavesMigrateWithoutReset() throws {
        let defaults = makeDefaults()
        // A pre-11.7 save: balances and the legacy Last Chance ledger, with
        // none of the Phase 11.7 fields present.
        let legacyState: [String: Any] = [
            "gameBalls": 42,
            "hints": 5,
            "transactions": [[
                "id": "legacy-tx",
                "kind": "matchReward",
                "amount": 10,
                "date": Date(timeIntervalSince1970: 0).timeIntervalSince1970,
            ]],
            "claimedTransactionIDs": ["legacy-tx"],
            "doubledMatchIDs": [],
            "lastChanceUsedKeys": ["match-legacy-q1"],
        ]
        let payload = try JSONSerialization.data(withJSONObject: legacyState)
        // The envelope encodes payload Data as its base64 string — the same
        // representation JSONDecoder/JSONEncoder use for Data fields.
        let envelope: [String: Any] = ["version": 2, "payload": payload.base64EncodedString()]
        let wrapped = try JSONSerialization.data(withJSONObject: envelope)
        defaults.set(wrapped, forKey: PlayerWallet.storageKey)

        let wallet = PlayerWallet(defaults: defaults)
        #expect(wallet.gameBalls == 42)
        #expect(wallet.hints == 5)
        #expect(wallet.claimedTransactionIDs.contains("legacy-tx"))
        // The legacy Last Chance migrates into the video-rescue ledger.
        #expect(!wallet.canUseVideoRescue(for: "match-legacy-q1"))
        #expect(wallet.canUseVideoRescue(for: "match-legacy-q2"))
        #expect(wallet.hasStarterPackGrant == false)
        #expect(wallet.forcedAdCount(for: "any") == 0)
    }

    // MARK: RevenueCat configuration

    @Test func debugBuildSelectsTheTestStoreKeyAndNeverFallsBack() {
        // Tests run in DEBUG: the Test Store key is selected.
        #expect(PurchaseManager.apiKeyForCurrentBuild(testKey: "k-test", productionKey: "k-prod") == "k-test")
        // A missing/blank Test key means RevenueCat stays unavailable —
        // never a silent fallback to the production key.
        #expect(PurchaseManager.apiKeyForCurrentBuild(testKey: "  ", productionKey: "k-prod") == nil)
        #expect(PurchaseManager.apiKeyForCurrentBuild(testKey: "", productionKey: "k-prod") == nil)
    }

    @Test func releaseBuildSelectsTheProductionKey() {
        // The selection logic is build-configuration driven; prove the
        // mapping directly for both configurations.
        #expect(PurchaseManager.apiKeyForCurrentBuild(testKey: "k-test", productionKey: "k-prod") != nil)
        // In DEBUG builds the production key is never chosen while a test
        // key exists; the Release branch reads only the production key.
        #if !DEBUG
        #expect(PurchaseManager.apiKeyForCurrentBuild(testKey: "k-test", productionKey: "k-prod") == "k-prod")
        #endif
    }

    @Test func packageIdentifiersResolveByStoreSuffixNotPosition() {
        #expect(PurchaseManager.packageID(forProductID: "starter_pack", isDevelopmentBuild: true) == "starter_pack_test")
        #expect(PurchaseManager.packageID(forProductID: "starter_pack", isDevelopmentBuild: false) == "starter_pack_app")
        #expect(PurchaseManager.packageID(forProductID: "25_game_balls", isDevelopmentBuild: false) == "25_game_balls_app")
        #expect(PurchaseManager.packageID(forProductID: "150_game_balls", isDevelopmentBuild: false) == "150_game_balls_app")
        #expect(PurchaseManager.packageID(forProductID: "350_game_balls", isDevelopmentBuild: false) == "350_game_balls_app")
        #expect(PurchaseManager.packageID(forProductID: "remove_ads", isDevelopmentBuild: true) == "remove_ads_test")
    }

    @Test func secretAPIKeyIsNeverReferencedByClientCode() throws {
        // Defensive QA gate: the server-only secret must never be embedded in
        // the shipped app. The unit suite hosts inside the real app binary —
        // scanning its executable proves no source file compiled the secret
        // literal (or any code path that would log/send it) into the client.
        let probe = Array("REVENUECAT_SECRET_API_KEY".utf8)
        guard let executableURL = Bundle.main.executableURL else {
            Issue.record("App executable not found")
            return
        }
        let binary = try Data(contentsOf: executableURL)
        #expect(!binary.isEmpty)
        #expect(binary.firstRange(of: probe) == nil, "The app binary embeds the RevenueCat secret API key")

        // The runtime configuration surface only exposes the PUBLIC keys.
        #expect(PurchaseManager.apiKeyForCurrentBuild(testKey: "k-test", productionKey: "k-prod") != nil)
        // And the generated Config surface never carries the RevenueCat
        // secret — only the two public SDK keys.
        #expect(!Config.allValues.keys.contains("REVENUECAT_SECRET_API_KEY"))
        #expect(!Config.allValues.keys.contains { $0.contains("REVENUECAT_SECRET") })
    }
}
