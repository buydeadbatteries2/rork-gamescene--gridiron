import Foundation
import Testing
@testable import GameSceneGridiron

// MARK: - Phase 14B — server-owned seasons + ranked assignments
//
//  * the assignment model, its persisted prefetch store (offline policy A)
//    and the start-ranked-match wire decoding,
//  * the prefetch service (game-1-only season creation, ≤ 3 ahead, flush
//    first, game_already_recorded continues, failures stop),
//  * MatchViewModel plays EXACTLY the assigned cases,
//  * start-ranked-match / submit-ranked-result request hardening and the
//    schema's definer / name / assignment / rate-limit guarantees (fixtures).

private enum P14B {
    static let owner = UUID(uuidString: "0e0e0e0e-1111-2222-3333-444444444444")!
    static let season = UUID(uuidString: "5e5e5e5e-1111-2222-3333-444444444444")!
    static let now = Date(timeIntervalSince1970: 1_790_000_000)

    /// Five real catalog cases at their real local versions.
    static let caseIDs: [String] = Array(CompetitiveCaseCatalog.entries.keys.sorted().prefix(5))
    static let versions: [Int] = caseIDs.map { CompetitiveCaseCatalog.entries[$0]!.version }

    static func assignment(
        owner: UUID = owner, season: UUID = season, game: Int = 1, difficulty: String = "pro",
        caseIDs: [String] = caseIDs, versions: [Int] = versions,
        issued: Date = now, expires: Date = now.addingTimeInterval(14 * 86_400)
    ) -> RankedAssignment {
        RankedAssignment(
            assignmentID: UUID(), matchID: UUID(), seasonID: season, gameNumber: game, difficulty: difficulty,
            caseIDs: caseIDs, caseVersions: versions, issuedAt: issued, expiresAt: expires,
            catalogFingerprint: CompetitiveCaseCatalog.catalogFingerprint, ownerUserID: owner
        )
    }

    static func wire(season: UUID = season, game: Int, difficulty: String = "pro", caseIDs: [String] = caseIDs) -> RankedAssignmentWire {
        RankedAssignmentWire(
            assignmentID: UUID(), matchID: UUID(), seasonID: season, gameNumber: game, difficulty: difficulty,
            caseIDs: caseIDs, caseVersions: versions,
            issuedAt: "2026-09-21T14:13:20.000Z", expiresAt: "2026-10-05T14:13:20.000Z",
            catalogFingerprint: CompetitiveCaseCatalog.catalogFingerprint, reused: false
        )
    }

    static func defaults() -> UserDefaults {
        let name = "phase14b-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    static func normalizedSQL(_ raw: String) -> String {
        raw.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("--") }
            .joined(separator: " ")
            .split(whereSeparator: { $0 == " " || $0 == "\r" || $0 == "\n" || $0 == "\t" })
            .joined(separator: " ")
    }

    static let sql = normalizedSQL(SchemaFixture.sql)

    static func section(_ text: String, from marker: String, to endMarker: String) -> String {
        guard let start = text.range(of: marker),
              let end = text.range(of: endMarker, range: start.upperBound..<text.endIndex) else { return "" }
        return String(text[start.lowerBound..<end.upperBound])
    }

    static func count(_ needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }

    /// Byte offset of `needle` in `text` (Int.max when absent).
    static func offset(of needle: String, in text: String) -> Int {
        guard let range = text.range(of: needle) else { return .max }
        return text.distance(from: text.startIndex, to: range.lowerBound)
    }
}

// MARK: Assignment model + store

@MainActor
@Suite("Phase 14B — ranked assignment model")
struct Phase14BAssignmentModelTests {

    @Test func wellFormedNeedsFiveDistinctCasesAndValidContext() {
        #expect(P14B.assignment().isWellFormed)
        #expect(!P14B.assignment(caseIDs: Array(P14B.caseIDs.prefix(4)), versions: Array(P14B.versions.prefix(4))).isWellFormed)
        #expect(!P14B.assignment(caseIDs: [P14B.caseIDs[0]] + Array(P14B.caseIDs.prefix(4))).isWellFormed)
        #expect(!P14B.assignment(game: 13).isWellFormed)
        #expect(!P14B.assignment(difficulty: "legend").isWellFormed)
    }

    @Test func regulationAndOvertimeSplit() {
        let a = P14B.assignment()
        #expect(a.regulationCaseIDs == Array(P14B.caseIDs.prefix(4)))
        #expect(a.overtimeCaseID == P14B.caseIDs[4])
        #expect(a.id == a.matchID)
    }

    @Test func localCatalogMustHoldTheExactVersions() {
        #expect(P14B.assignment().matchesLocalCatalog())
        var bumped = P14B.versions
        bumped[2] += 1
        #expect(!P14B.assignment(versions: bumped).matchesLocalCatalog())
        let unknown = ["case_does_not_exist"] + Array(P14B.caseIDs.suffix(4))
        #expect(!P14B.assignment(caseIDs: unknown).matchesLocalCatalog())
    }

    @Test func playableOnlyForTheExactContext() {
        let a = P14B.assignment(game: 3, difficulty: "all_pro")
        #expect(a.isPlayable(owner: P14B.owner, seasonID: P14B.season, gameNumber: 3, difficulty: .allPro, now: P14B.now))
        #expect(!a.isPlayable(owner: UUID(), seasonID: P14B.season, gameNumber: 3, difficulty: .allPro, now: P14B.now))
        #expect(!a.isPlayable(owner: P14B.owner, seasonID: UUID(), gameNumber: 3, difficulty: .allPro, now: P14B.now))
        #expect(!a.isPlayable(owner: P14B.owner, seasonID: P14B.season, gameNumber: 4, difficulty: .allPro, now: P14B.now))
        #expect(!a.isPlayable(owner: P14B.owner, seasonID: P14B.season, gameNumber: 3, difficulty: .hallOfFamer, now: P14B.now))
        #expect(!a.isPlayable(owner: P14B.owner, seasonID: P14B.season, gameNumber: 3, difficulty: .allPro, now: a.expiresAt))
    }

    @Test func storeUpsertReplacesTheSameGame() {
        var store = RankedAssignmentStore()
        let first = P14B.assignment(game: 2)
        let second = P14B.assignment(game: 2)
        store.upsert(first)
        store.upsert(second)
        #expect(store.assignments.count == 1)
        #expect(store.assignments.first?.matchID == second.matchID)
        store.upsert(P14B.assignment(caseIDs: Array(P14B.caseIDs.prefix(4)), versions: Array(P14B.versions.prefix(4))))
        #expect(store.assignments.count == 1) // malformed never stored
    }

    @Test func storePruneKeepsAtMostThreeLiveUpcomingGames() {
        var store = RankedAssignmentStore()
        for game in 1...6 { store.upsert(P14B.assignment(game: game)) }
        store.upsert(P14B.assignment(owner: UUID(), game: 7))
        store.upsert(P14B.assignment(season: UUID(), game: 8))
        store.upsert(P14B.assignment(game: 9, expires: P14B.now.addingTimeInterval(-1)))
        store.prune(owner: P14B.owner, seasonID: P14B.season, minGameNumber: 2, now: P14B.now)
        #expect(store.assignments.map(\.gameNumber) == [2, 3, 4])
        #expect(RankedAssignmentStore.maxPrefetched == 3)
        store.prune(owner: nil, seasonID: P14B.season, now: P14B.now)
        #expect(store.assignments.isEmpty) // signed out → nothing kept
    }

    @Test func storePlayableAndRemove() {
        var store = RankedAssignmentStore()
        let a = P14B.assignment(game: 4)
        store.upsert(a)
        #expect(store.playable(owner: P14B.owner, seasonID: P14B.season, gameNumber: 4, difficulty: .pro, now: P14B.now) == a)
        #expect(store.playable(owner: P14B.owner, seasonID: P14B.season, gameNumber: 4, difficulty: .rookie, now: P14B.now) == nil)
        #expect(store.has(owner: P14B.owner, seasonID: P14B.season, gameNumber: 4, now: P14B.now))
        store.consume(matchID: a.matchID)
        #expect(!store.has(owner: P14B.owner, seasonID: P14B.season, gameNumber: 4, now: P14B.now))
    }

    @Test func storeSurvivesRelaunch() {
        let defaults = P14B.defaults()
        var store = RankedAssignmentStore()
        let a = P14B.assignment(game: 5)
        store.upsert(a)
        RankedAssignmentStore.save(store, defaults: defaults)
        let restored = RankedAssignmentStore.load(defaults: defaults)
        #expect(restored.assignments == [a])
        #expect(RankedAssignmentStore.key == "gamescene.gridiron.rankedAssignments.v1")
    }

    @Test func wireDecodesServerShapeWithAndWithoutFractions() throws {
        let json = """
        {"assignment_id":"\(UUID().uuidString)","match_id":"\(UUID().uuidString)","season_id":"\(P14B.season.uuidString)",
         "game_number":2,"difficulty":"hall_of_famer","case_ids":[\(P14B.caseIDs.map { "\"\($0)\"" }.joined(separator: ","))],
         "case_versions":\(P14B.versions),"issued_at":"2026-10-20T12:30:01.123Z","expires_at":"2026-11-03T12:30:01+00:00",
         "catalog_fingerprint":"a30cb39044dc193b","reused":true}
        """
        let wire = try JSONDecoder().decode(RankedAssignmentWire.self, from: Data(json.utf8))
        let a = try #require(wire.assignment(owner: P14B.owner))
        #expect(a.ownerUserID == P14B.owner)
        #expect(a.gameNumber == 2 && a.difficulty == "hall_of_famer")
        #expect(a.caseIDs == P14B.caseIDs)
        #expect(a.expiresAt > a.issuedAt)
    }

    @Test func wireRejectsMalformedAssignments() {
        #expect(P14B.wire(game: 1).assignment(owner: P14B.owner) != nil)
        #expect(P14B.wire(game: 1, caseIDs: Array(P14B.caseIDs.prefix(4))).assignment(owner: P14B.owner) == nil)
        let badDate = RankedAssignmentWire(
            assignmentID: UUID(), matchID: UUID(), seasonID: P14B.season, gameNumber: 1, difficulty: "pro",
            caseIDs: P14B.caseIDs, caseVersions: P14B.versions, issuedAt: "yesterday", expiresAt: "2026-11-03T12:30:01Z",
            catalogFingerprint: nil, reused: nil
        )
        #expect(badDate.assignment(owner: P14B.owner) == nil)
    }

    @Test func wireCarriesNoSolutionsOrSeed() {
        let labels = Set(Mirror(reflecting: P14B.wire(game: 1)).children.compactMap(\.label))
        #expect(!labels.contains { $0.lowercased().contains("solution") || $0.lowercased().contains("seed") || $0.lowercased().contains("variant") })
        let model = Set(Mirror(reflecting: P14B.assignment()).children.compactMap(\.label))
        #expect(!model.contains { $0.lowercased().contains("solution") || $0.lowercased().contains("seed") })
    }
}

// MARK: Prefetch service

@MainActor
final class MockAssignmentFetcher: RankedAssignmentFetching {
    struct Call: Equatable, Sendable { let seasonID: UUID?; let gameNumber: Int; let difficulty: String }
    private(set) var calls: [Call] = []
    /// Per game: the result to return; default = a fresh assignment.
    private var scripted: [Int: RankedAssignmentFetchResult] = [:]
    private let serverSeason: UUID

    init(serverSeason: UUID = P14BServer.season) { self.serverSeason = serverSeason }

    func script(_ game: Int, _ result: RankedAssignmentFetchResult) { scripted[game] = result }

    func start(seasonID: UUID?, gameNumber: Int, difficulty: String) async -> RankedAssignmentFetchResult {
        calls.append(Call(seasonID: seasonID, gameNumber: gameNumber, difficulty: difficulty))
        if let result = scripted[gameNumber] { return result }
        return .assigned(P14BServer.wire(season: seasonID ?? serverSeason, game: gameNumber, difficulty: difficulty))
    }
}

/// Non-private bridge so the actor (outside the private enum) can build wires.
enum P14BServer {
    static let season = UUID(uuidString: "5e5e5e5e-1111-2222-3333-444444444444")!
    static func wire(season: UUID, game: Int, difficulty: String) -> RankedAssignmentWire {
        let ids = Array(CompetitiveCaseCatalog.entries.keys.sorted().prefix(5))
        return RankedAssignmentWire(
            assignmentID: UUID(), matchID: UUID(), seasonID: season, gameNumber: game, difficulty: difficulty,
            caseIDs: ids, caseVersions: ids.map { CompetitiveCaseCatalog.entries[$0]!.version },
            issuedAt: "2026-09-21T14:13:20.000Z", expiresAt: "2026-10-05T14:13:20.000Z",
            catalogFingerprint: CompetitiveCaseCatalog.catalogFingerprint, reused: false
        )
    }
}

@MainActor
final class AssignmentHarness {
    var context: RankedSeasonContext?
    var user: UUID? = P14BHarnessIDs.owner
    var adopted: [(UUID, Int)] = []
    var cleared = 0
    var flushes = 0
    let fetcher: MockAssignmentFetcher
    let defaults: UserDefaults
    lazy var service = RankedAssignmentService(
        defaults: defaults,
        fetcher: fetcher,
        currentUserID: { [unowned self] in self.user },
        seasonContext: { [unowned self] in self.context },
        adoptSeasonID: { [unowned self] id, number in
            self.adopted.append((id, number))
            if let c = self.context {
                self.context = RankedSeasonContext(seasonNumber: c.seasonNumber, rankedSeasonID: id,
                                                   nextGameNumber: c.nextGameNumber, difficulty: c.difficulty)
            }
        },
        clearSeasonID: { [unowned self] in self.cleared += 1 },
        flushSubmissions: { [unowned self] in self.flushes += 1 },
        now: { Date(timeIntervalSince1970: 1_790_000_000) }
    )

    init(context: RankedSeasonContext?, fetcher: MockAssignmentFetcher? = nil) {
        self.context = context
        self.fetcher = fetcher ?? MockAssignmentFetcher()
        let name = "phase14b-svc-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
    }
}

enum P14BHarnessIDs {
    static let owner = UUID(uuidString: "0e0e0e0e-1111-2222-3333-444444444444")!
}

@MainActor
@Suite("Phase 14B — assignment prefetch service")
struct Phase14BServiceTests {

    @Test func gameOneCreatesTheServerSeasonAndPrefetchesThree() async {
        let h = AssignmentHarness(context: RankedSeasonContext(seasonNumber: 4, rankedSeasonID: nil, nextGameNumber: 1, difficulty: .pro))
        await h.service.refresh()
        let calls = h.fetcher.calls
        #expect(calls.map(\.gameNumber) == [1, 2, 3])
        #expect(calls[0].seasonID == nil)                       // only game 1 asks for a new season
        #expect(calls.dropFirst().allSatisfy { $0.seasonID == P14BServer.season })
        #expect(calls.allSatisfy { $0.difficulty == "pro" })
        #expect(h.adopted.count == 1)
        #expect(h.adopted.first?.0 == P14BServer.season && h.adopted.first?.1 == 4)
        #expect(h.service.store.assignments.map(\.gameNumber) == [1, 2, 3])
        #expect(h.service.store.assignments.allSatisfy { $0.ownerUserID == P14BHarnessIDs.owner })
        #expect(h.flushes == 1)
    }

    @Test func neverSendsANullSeasonAfterGameOne() async {
        // A season started on a pre-14B build: stays unranked until next season.
        let h = AssignmentHarness(context: RankedSeasonContext(seasonNumber: 2, rankedSeasonID: nil, nextGameNumber: 4, difficulty: .allPro))
        await h.service.refresh()
        #expect(h.fetcher.calls.isEmpty)
        #expect(h.service.store.assignments.isEmpty)
    }

    @Test func midSeasonUsesTheServerSeasonAndCapsAtTwelve() async {
        let h = AssignmentHarness(context: RankedSeasonContext(seasonNumber: 1, rankedSeasonID: P14BServer.season, nextGameNumber: 11, difficulty: .hallOfFamer))
        await h.service.refresh()
        let calls = h.fetcher.calls
        #expect(calls.map(\.gameNumber) == [11, 12])
        #expect(calls.allSatisfy { $0.seasonID == P14BServer.season && $0.difficulty == "hall_of_famer" })
        #expect(h.adopted.isEmpty)
    }

    @Test func alreadyRecordedGameContinuesToTheNext() async {
        let fetcher = MockAssignmentFetcher()
        fetcher.script(5, .rejected(reason: "game_already_recorded"))
        let h = AssignmentHarness(context: RankedSeasonContext(seasonNumber: 1, rankedSeasonID: P14BServer.season, nextGameNumber: 5, difficulty: .pro), fetcher: fetcher)
        await h.service.refresh()
        #expect(fetcher.calls.map(\.gameNumber) == [5, 6, 7])
        #expect(h.service.store.assignments.map(\.gameNumber) == [6, 7])
    }

    @Test func otherRejectionsAndRetryablesStop() async {
        // The SERVER says the season is closed → stale local ranked state is
        // cleared wholesale (snapshot + assignments + season id) and the
        // session state becomes .noSeason — never an active card from cache.
        let rejecting = MockAssignmentFetcher()
        rejecting.script(3, .rejected(reason: "season_closed"))
        let h = AssignmentHarness(context: RankedSeasonContext(seasonNumber: 1, rankedSeasonID: P14BServer.season, nextGameNumber: 2, difficulty: .pro), fetcher: rejecting)
        await h.service.refresh()
        #expect(rejecting.calls.map(\.gameNumber) == [2, 3])
        #expect(h.service.store.assignments.isEmpty)
        #expect(h.service.store.snapshot == nil)
        #expect(h.service.lastErrorCategory == "season_closed")
        #expect(h.service.sessionState == .noSeason)
        #expect(h.cleared == 1)

        let offline = MockAssignmentFetcher()
        offline.script(2, .retryable(category: "network"))
        let h2 = AssignmentHarness(context: RankedSeasonContext(seasonNumber: 1, rankedSeasonID: P14BServer.season, nextGameNumber: 2, difficulty: .pro), fetcher: offline)
        await h2.service.refresh()
        #expect(offline.calls.map(\.gameNumber) == [2])
        #expect(h2.service.store.assignments.isEmpty)
        // Server unreachable → cached state must not pose as truth.
        #expect(h2.service.sessionState == .unavailable)
    }

    @Test func heldAssignmentsAreNotRefetched() async {
        let h = AssignmentHarness(context: RankedSeasonContext(seasonNumber: 1, rankedSeasonID: P14BServer.season, nextGameNumber: 3, difficulty: .pro))
        await h.service.refresh()
        await h.service.refresh()
        #expect(h.fetcher.calls.map(\.gameNumber) == [3, 4, 5])
        #expect(h.service.store.assignments.count == 3)
    }

    @Test func mismatchedServerResponseIsNeverStored() async {
        let fetcher = MockAssignmentFetcher()
        fetcher.script(2, .assigned(P14BServer.wire(season: P14BServer.season, game: 9, difficulty: "pro")))
        let h = AssignmentHarness(context: RankedSeasonContext(seasonNumber: 1, rankedSeasonID: P14BServer.season, nextGameNumber: 2, difficulty: .pro), fetcher: fetcher)
        await h.service.refresh()
        #expect(h.service.store.assignments.isEmpty)
        #expect(h.service.lastErrorCategory == "unexpected_response")

        let foreign = MockAssignmentFetcher()
        foreign.script(2, .assigned(P14BServer.wire(season: UUID(), game: 2, difficulty: "pro")))
        let h2 = AssignmentHarness(context: RankedSeasonContext(seasonNumber: 1, rankedSeasonID: P14BServer.season, nextGameNumber: 2, difficulty: .pro), fetcher: foreign)
        await h2.service.refresh()
        #expect(h2.service.store.assignments.isEmpty)
    }

    @Test func guestsNeverFetch() async {
        let h = AssignmentHarness(context: RankedSeasonContext(seasonNumber: 1, rankedSeasonID: nil, nextGameNumber: 1, difficulty: .pro))
        h.user = nil
        await h.service.refresh()
        #expect(h.fetcher.calls.isEmpty)
        #expect(h.service.playableAssignment(seasonID: P14BServer.season, gameNumber: 1, difficulty: .pro) == nil)
    }

    @Test func playableAndConsume() async {
        let h = AssignmentHarness(context: RankedSeasonContext(seasonNumber: 1, rankedSeasonID: P14BServer.season, nextGameNumber: 1, difficulty: .rookie))
        await h.service.refresh()
        let a = h.service.playableAssignment(seasonID: P14BServer.season, gameNumber: 1, difficulty: .rookie)
        #expect(a != nil)
        #expect(h.service.playableAssignment(seasonID: P14BServer.season, gameNumber: 1, difficulty: .pro) == nil)
        #expect(h.service.playableAssignment(seasonID: nil, gameNumber: 1, difficulty: .rookie) == nil)
        h.user = UUID() // another account can never play it
        #expect(h.service.playableAssignment(seasonID: P14BServer.season, gameNumber: 1, difficulty: .rookie) == nil)
        h.user = P14BHarnessIDs.owner
        if let a { h.service.consume(matchID: a.matchID) }
        #expect(h.service.playableAssignment(seasonID: P14BServer.season, gameNumber: 1, difficulty: .rookie) == nil)
        // Persisted: a relaunch sees the same store.
        let reloaded = RankedAssignmentStore.load(defaults: h.defaults)
        #expect(reloaded.assignments.map(\.gameNumber) == [2, 3])
    }
}

// MARK: Match plays the assigned cases

@MainActor
@Suite("Phase 14B — match uses the assignment")
struct Phase14BMatchTests {

    @Test func rankedGamePlaysExactlyTheAssignedCases() {
        let a = P14B.assignment(game: 2, difficulty: "pro")
        let vm = MatchViewModel(seasonNumber: 1, week: 2, difficulty: .pro, rankedAssignment: a)
        #expect(vm.competitive?.assignment == a)
        #expect(vm.competitive?.ineligibleReason == nil)
        #expect(vm.competitive?.competitiveMatchID == a.matchID)
        #expect(vm.currentPuzzle.id == a.caseIDs[0])
    }

    @Test func catalogMismatchFallsBackToTheLocalScheduleUnranked() {
        var bumped = P14B.versions
        bumped[0] += 1
        let a = P14B.assignment(game: 2, versions: bumped)
        let vm = MatchViewModel(seasonNumber: 1, week: 2, difficulty: .pro, rankedAssignment: a)
        #expect(vm.competitive?.ineligibleReason == .assignmentCatalogMismatch)
        #expect(vm.currentPuzzle.id == CaseScheduler.gameCaseIDs(seasonNumber: 1, week: 2).regulation[0])
    }

    @Test func wrongGameOrDifficultyIsUnranked() {
        let wrongGame = MatchViewModel(seasonNumber: 1, week: 3, difficulty: .pro, rankedAssignment: P14B.assignment(game: 2))
        #expect(wrongGame.competitive?.ineligibleReason == .assignmentCatalogMismatch)
        let wrongLevel = MatchViewModel(seasonNumber: 1, week: 2, difficulty: .hallOfFamer, rankedAssignment: P14B.assignment(game: 2))
        #expect(wrongLevel.competitive?.ineligibleReason == .assignmentCatalogMismatch)
    }

    @Test func noAssignmentMeansUnranked() {
        // Tests run signed out: no prefetched assignment can be playable.
        let vm = MatchViewModel(seasonNumber: 1, week: 2, difficulty: .pro)
        #expect(vm.competitive?.ineligibleReason == .noAssignment)
        #expect(vm.competitive?.assignment == nil)
        #expect(vm.currentPuzzle.id == CaseScheduler.gameCaseIDs(seasonNumber: 1, week: 2).regulation[0])
    }

    @Test func standaloneGamesHaveNoCompetitiveState() {
        let vm = MatchViewModel(seasonNumber: 0, week: 1, difficulty: .pro, rankedAssignment: P14B.assignment())
        #expect(vm.competitive == nil)
    }

    @Test func queueKeyWasBumpedForTheNewPayload() {
        #expect(CompetitiveSubmissionStore.key == "gamescene.gridiron.competitiveQueue.v2")
        #expect(CompetitiveResultPayload.currentRankedProtocol == 2)
    }
}

// MARK: Edge Functions (fixtures)

@MainActor
@Suite("Phase 14B — Edge Function hardening")
struct Phase14BEdgeTests {
    static let start = EdgeFunctionFixture.startRankedMatch
    static let submit = EdgeFunctionFixture.submitRankedResult

    @Test func startDerivesUserFromJWTOnly() {
        let edge = Self.start
        #expect(edge.contains("admin.auth.getUser(token)"))
        #expect(edge.contains("p_user_id: userID"))
        #expect(edge.contains("reason: \"unauthorized\""))
        for forbidden in ["p.user_id", "body.user_id", "payload.user_id"] {
            #expect(!edge.contains(forbidden), "\(forbidden)")
        }
        #expect(!edge.contains("SUPABASE_ANON_KEY"))
    }

    @Test func startChecksSizeAndRateBeforeReadingTheBody() {
        let edge = Self.start
        #expect(edge.contains("const MAX_BODY_BYTES = 2 * 1024;"))
        let declared = P14B.offset(of: "req.headers.get(\"Content-Length\")", in: edge)
        let limit = P14B.offset(of: "p_bucket: \"assign\"", in: edge)
        let read = P14B.offset(of: "await req.text()", in: edge)
        #expect(declared < limit && limit < read && read < .max)
        #expect(edge.contains("if (new TextEncoder().encode(raw).length > MAX_BODY_BYTES) return reject(\"body_too_large\", 413);"))
    }

    @Test func startValidatesStructureAndOnlyGameOneCreatesASeason() {
        let edge = Self.start
        #expect(edge.contains("ensure(season === null || (typeof season === \"string\" && UUID_RE.test(season)), \"invalid_season_id\");"))
        #expect(edge.contains("ensure(isInt(p.game_number, 1, 12), \"invalid_game_number\");"))
        #expect(edge.contains("ensure(season !== null || p.game_number === 1, \"season_required\");"))
        #expect(edge.contains("[\"SEASON_CONFLICT\", 403]"))
        #expect(edge.contains("[\"GAME_ALREADY_RECORDED\", 409]"))
        #expect(edge.contains("return { reason: \"assignment_failed\", status: 503 };"))
    }

    @Test func startReturnsOnlyPlayData() {
        let whitelist = P14B.section(Self.start, from: "export function publicAssignment(", to: "Deno.serve(")
        #expect(!whitelist.isEmpty)
        for forbidden in ["solution", "expected", "variant", "seed", "user_id", "consumed"] {
            #expect(!whitelist.contains(forbidden), "start response leaks \(forbidden)")
        }
        for field in ["match_id:", "season_id:", "case_ids:", "case_versions:", "expires_at:"] {
            #expect(whitelist.contains(field))
        }
    }

    @Test func submitChecksSizeAndRateBeforeReadingTheBody() {
        let edge = Self.submit
        #expect(edge.contains("const MAX_BODY_BYTES = 32 * 1024;"))
        let declared = P14B.offset(of: "req.headers.get(\"Content-Length\")", in: edge)
        let limit = P14B.offset(of: "p_bucket: \"submit\"", in: edge)
        let read = P14B.offset(of: "await req.text()", in: edge)
        #expect(declared < limit && limit < read && read < .max)
        #expect(edge.contains("if (new TextEncoder().encode(raw).length > MAX_BODY_BYTES) return reject(\"body_too_large\", 413);"))
    }

    @Test func submitBoundsVersionAndProtocol() {
        let edge = Self.submit
        #expect(edge.contains("const MAX_GAME_VERSION = 40;"))
        #expect(edge.contains("p.game_version.trim().length <= MAX_GAME_VERSION, \"invalid_game_version\""))
        #expect(edge.contains("ensure(isInt(p.ranked_protocol, 1, 1000), \"client_outdated\");"))
        #expect(edge.contains("const MAX_PLACEMENTS = 8;"))
    }

    @Test func noEdgeClaimsAntiCheat() {
        for edge in [Self.start, Self.submit] {
            #expect(edge.contains("NOT secret"))
            #expect(!edge.lowercased().contains("tamper-proof"))
            #expect(!edge.lowercased().contains("cheat-proof"))
        }
    }
}

// MARK: Schema (fixture)

@MainActor
@Suite("Phase 14B — schema guarantees")
struct Phase14BSchemaTests {

    @Test func everySecurityDefinerPinsAnEmptySearchPath() {
        let sql = P14B.sql
        let definers = P14B.count("security definer", in: sql)
        #expect(definers >= 10)
        #expect(P14B.count("security definer set search_path = ''", in: sql) == definers)
        #expect(!sql.contains("search_path = public"))
        #expect(!sql.contains("search_path to public"))
    }

    @Test func assignmentsArePrivateAndServiceIssued() {
        let sql = P14B.sql
        #expect(sql.contains("create table if not exists public.ranked_match_assignments ("))
        #expect(sql.contains("alter table public.ranked_match_assignments force row level security;"))
        #expect(sql.contains("revoke all on public.ranked_match_assignments from anon, authenticated;"))
        #expect(!sql.contains("on public.ranked_match_assignments for insert"))
        #expect(!sql.contains("on public.ranked_match_assignments for update"))
        #expect(sql.contains("constraint ranked_match_assignments_match_id_key unique (match_id)"))
        #expect(sql.contains("revoke all on public.ranked_seasons from anon, authenticated;"))
        let sig = "public.issue_ranked_match_assignment(uuid, uuid, int, text)"
        #expect(sql.contains("revoke all on function \(sig) from public, anon, authenticated;"))
        #expect(sql.contains("grant execute on function \(sig) to service_role;"))
    }

    @Test func seasonIsRequiredAndGamesAreUnique() {
        let sql = P14B.sql
        #expect(sql.contains("alter table public.ranked_game_results alter column season_id set not null;"))
        #expect(sql.contains("create unique index ranked_game_results_season_game_key on public.ranked_game_results (user_id, season_id, game_number);"))
        #expect(sql.contains("constraint ranked_game_results_match_id_key unique (match_id)"))
    }

    @Test func submissionIsVerifiedAgainstTheAssignment() {
        let body = P14B.section(P14B.sql, from: "create or replace function public.record_verified_ranked_result(", to: "end; $$;")
        for code in ["ASSIGNMENT_OWNER_MISMATCH", "ASSIGNMENT_MISMATCH", "ASSIGNMENT_CONSUMED", "ASSIGNMENT_REPLACED",
                     "ASSIGNMENT_EXPIRED", "CASE_MISMATCH", "CASE_VERSION_MISMATCH", "PLACEMENT_MISMATCH"] {
            #expect(body.contains("raise exception '\(code)'"), "\(code)")
        }
        #expect(body.contains("from public.ranked_match_assignments a where a.match_id = p_match_id for update;"))
        #expect(body.contains("set consumed_result_id = v_id, consumed_at = v_received"))
    }

    @Test func easierCasesCannotEarnHallOfFamerPoints() {
        let issuer = P14B.section(P14B.sql, from: "create or replace function public.issue_ranked_match_assignment(", to: "end; $$;")
        #expect(issuer.contains("v_floor := case when p_difficulty in ('all_pro', 'hall_of_famer') then 1 else 0 end;"))
        #expect(issuer.contains("and public.ranked_tier_rank(c.difficulty) >= v_floor"))
        #expect(issuer.contains("v_variant := public.ranked_solution_variant(p_difficulty, p_game_number);"))
        // Every band still has ≥ 12 non-rookie bundled cases for a full season.
        let lines = CompetitiveCatalogFixture.canonicalLines.split(separator: "\n").map { $0.split(separator: "|").map(String.init) }
        for band in 1...5 {
            let pool = lines.filter { $0[4] == String(band) && $0[2] != "rookie" && $0[8] == "client_bundled" && $0[6] == "true" }
            #expect(pool.count >= 12, "band \(band) HoF pool \(pool.count)")
        }
    }

    @Test func namesAreBoundedByChecks() {
        let sql = P14B.sql
        #expect(sql.contains("add constraint profiles_first_name_length check (char_length(first_name) <= 50);"))
        #expect(sql.contains("add constraint profiles_last_name_length check (char_length(last_name) <= 50);"))
    }

    @Test func usernameOracleIsBoundedAndBooleanOnly() {
        let fn = P14B.section(P14B.sql, from: "create or replace function public.is_username_available(", to: "$$;")
        #expect(fn.contains("returns boolean"))
        #expect(fn.contains("char_length(requested) > 64 then false"))
        #expect(fn.contains("!~ '^[A-Za-z0-9_]{3,20}$' then false"))
        // Format is validated BEFORE the table is touched.
        #expect(P14B.offset(of: "!~", in: fn) < P14B.offset(of: "from public.profiles", in: fn))
    }

    @Test func rateLimitIsAnAtomicUpsert() {
        let fn = P14B.section(P14B.sql, from: "create or replace function public.consume_ranked_rate_limit(", to: "end; $$;")
        #expect(fn.contains("on conflict (user_id, bucket, window_start) do update set count = l.count + 1 where l.count < v_limit"))
        #expect(fn.contains("returning l.count into v_count;"))
        #expect(fn.contains("when 'submit' then c.submissions_per_hour"))
        #expect(fn.contains("when 'assign' then c.assignments_per_hour"))
        #expect(P14B.sql.contains("grant execute on function public.consume_ranked_rate_limit(uuid, text) to service_role;"))
    }

    @Test func untrustedTimestampsNeverPoisonLaterGames() {
        let body = P14B.section(P14B.sql, from: "create or replace function public.record_verified_ranked_result(", to: "end; $$;")
        #expect(body.contains("and r.leaderboard_at_source = 'completed_at'"))
        #expect(body.contains("r.leaderboard_at > least(p_completed_at, v_received)"))
        #expect(body.contains("p_started_at >= v_asg.issued_at - make_interval(secs => cfg.max_clock_skew_seconds)"))
    }

    @Test func caseVersionHistoryIsEnforced() {
        let sql = P14B.sql
        #expect(sql.contains("raise exception 'CASE_VERSION_REGRESSION:"))
        #expect(sql.contains("raise exception 'CASE_FINGERPRINT_CHANGED_WITHOUT_VERSION_BUMP:"))
        #expect(sql.contains("create or replace function public.enforce_case_version_history()"))
    }

    @Test func protocolMinimumIsConfigurable() {
        let sql = P14B.sql
        #expect(sql.contains("min_ranked_protocol int not null default 2"))
        let body = P14B.section(sql, from: "create or replace function public.record_verified_ranked_result(", to: "end; $$;")
        #expect(body.contains("'CLIENT_OUTDATED'"))
        #expect(body.contains("char_length(v_version) > 40"))
    }
}
