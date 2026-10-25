import Foundation
import Observation

/// Drives the LEADERBOARD screen. Talks only to `LeaderboardRepository` —
/// views never touch Supabase. Pages of 50, pull-to-refresh, a 60-second
/// cache, and a clean offline state.
@MainActor
@Observable
final class LeaderboardViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case empty
        case offline
        case unavailable
    }

    var board: LeaderboardBoard = .weekly {
        didSet { if board != oldValue { Task { await load() } } }
    }
    var difficulty: LeaderboardDifficultyFilter = .all {
        didSet { if difficulty != oldValue { Task { await load() } } }
    }

    private(set) var entries: [LeaderboardEntry] = []
    private(set) var mine: LeaderboardEntry?
    private(set) var state: LoadState = .idle
    private(set) var canLoadMore = false
    private(set) var isLoadingMore = false

    // Search
    var searchText: String = "" {
        didSet { if searchText != oldValue { scheduleSearch() } }
    }
    private(set) var searchResults: [PublicPlayerFile] = []
    private(set) var isSearching = false
    private(set) var searchFailed = false

    private let repository: (any LeaderboardRepository)?
    private let cache: LeaderboardCache
    let currentUserID: UUID?
    let pageSize: Int
    private let searchDebounce: Duration
    private var searchTask: Task<Void, Never>?
    private var loadGeneration = 0

    init(
        repository: (any LeaderboardRepository)?,
        currentUserID: UUID?,
        cache: LeaderboardCache = .shared,
        pageSize: Int = SupabaseLeaderboardRepository.pageSize,
        searchDebounce: Duration = .milliseconds(350)
    ) {
        self.repository = repository
        self.currentUserID = currentUserID
        self.cache = cache
        self.pageSize = pageSize
        self.searchDebounce = searchDebounce
    }

    /// Production wiring: live Supabase repository when configured.
    static func live() -> LeaderboardViewModel {
        let provider = SupabaseClientProvider.shared
        let repository: (any LeaderboardRepository)? = provider.isConfigured
            ? provider.supabase.map { SupabaseLeaderboardRepository(client: $0) }
            : nil
        var userID: UUID?
        if case .authenticated(let profile) = AuthService.shared.state { userID = profile.authUserID }
        return LeaderboardViewModel(repository: repository, currentUserID: userID)
    }

    private var cacheKey: LeaderboardCache.Key { .init(board: board, difficulty: difficulty) }

    // MARK: Loading

    func load(force: Bool = false) async {
        guard let repository else {
            state = .unavailable
            return
        }
        let key = cacheKey
        if !force, let cached = cache.snapshot(for: key) {
            apply(cached)
            return
        }
        loadGeneration += 1
        let generation = loadGeneration
        if entries.isEmpty || !force { state = .loading }
        do {
            async let pageTask = repository.page(board: key.board, difficulty: key.difficulty, limit: pageSize, offset: 0)
            async let mineTask = repository.myStanding(board: key.board, difficulty: key.difficulty)
            let (page, standing) = try await (pageTask, mineTask)
            guard generation == loadGeneration else { return }
            let snapshot = LeaderboardCache.Snapshot(
                entries: page, mine: standing,
                canLoadMore: page.count >= pageSize, fetchedAt: Date()
            )
            cache.store(snapshot, for: key)
            apply(snapshot)
        } catch {
            guard generation == loadGeneration else { return }
            entries = []
            mine = nil
            canLoadMore = false
            state = Self.isOffline(error) ? .offline : .unavailable
        }
    }

    func refresh() async {
        await load(force: true)
    }

    /// Next page when the last row appears.
    func loadMoreIfNeeded(current entry: LeaderboardEntry) async {
        guard canLoadMore, !isLoadingMore, let repository, entry.id == entries.last?.id else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        let key = cacheKey
        do {
            let page = try await repository.page(board: key.board, difficulty: key.difficulty, limit: pageSize, offset: entries.count)
            guard key == cacheKey else { return }
            let known = Set(entries.map(\.id))
            entries += page.filter { !known.contains($0.id) }
            canLoadMore = page.count >= pageSize
            cache.store(.init(entries: entries, mine: mine, canLoadMore: canLoadMore, fetchedAt: Date()), for: key)
        } catch {
            canLoadMore = false
        }
    }

    private func apply(_ snapshot: LeaderboardCache.Snapshot) {
        entries = snapshot.entries
        mine = snapshot.mine
        canLoadMore = snapshot.canLoadMore
        state = snapshot.entries.isEmpty ? .empty : .loaded
    }

    /// Pinned YOUR RANK row — shown when the player has a standing that is
    /// not already visible in the loaded rows.
    var pinnedStanding: LeaderboardEntry? {
        guard let mine, !entries.contains(where: { $0.id == mine.id }) else { return nil }
        return mine
    }

    func isCurrentUser(_ entry: LeaderboardEntry) -> Bool { entry.userID == currentUserID }

    // MARK: Search

    private func scheduleSearch() {
        searchTask?.cancel()
        guard let query = PlayerSearchQuery.normalized(searchText), let repository else {
            searchResults = []
            isSearching = false
            searchFailed = false
            return
        }
        isSearching = true
        let delay = searchDebounce
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            do {
                let results = try await repository.searchPlayers(query: query, limit: PlayerSearchQuery.resultLimit)
                guard !Task.isCancelled else { return }
                self?.searchResults = results
                self?.searchFailed = false
            } catch {
                guard !Task.isCancelled else { return }
                self?.searchResults = []
                self?.searchFailed = true
            }
            self?.isSearching = false
        }
    }

    func playerFile(for userID: UUID) async -> PublicPlayerFile? {
        try? await repository?.playerFile(userID: userID)
    }

    // MARK: Offline detection

    nonisolated static func isOffline(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost,
                 .cannotConnectToHost, .dnsLookupFailed, .dataNotAllowed, .internationalRoamingOff:
                return true
            default:
                return false
            }
        }
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain
    }
}
