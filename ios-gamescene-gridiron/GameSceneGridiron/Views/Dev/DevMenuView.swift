import SwiftUI

/// DEBUG-ONLY developer QA menu (Phase 9). Excluded from release builds —
/// every use site is wrapped in `#if DEBUG`. Lets QA jump the season forward,
/// grant economy currency and reset local state without rebuilding.
#if DEBUG
struct DevMenuView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var seasonManager = SeasonManager.shared
    @State private var wallet = PlayerWallet.shared
    @State private var telemetry = BalanceTelemetry.shared
    @State private var adManager = AdManager.shared
    @State private var adMob = AdMobService.shared
    @State private var message: String?
    @State private var competitive = CompetitiveSubmissionService.shared
    @State private var auth = AuthService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                DeskBackground()
                ScrollView {
                    VStack(spacing: 14) {
                        devSection("SEASON") {
                            devButton("JUMP TO WEEK 10") { jumpWeeks(target: 10) }
                            devButton("FORCE PLAYOFF QUALIFICATION") { jumpWeeks(target: 11) }
                            devButton("COMPLETE SEASON (WIN OUT)") { jumpWeeks(target: 13) }
                        }
                        devSection("ECONOMY") {
                            devButton("+10 GAME BALLS") {
                                wallet.earn(amount: 10, kind: .matchReward)
                                done("+10 Game Balls")
                            }
                            devButton("+5 HINTS") {
                                wallet.addHints(5)
                                done("+5 Hints")
                            }
                        }
                        devSection("ADMOB (READ-ONLY INDICATORS)") {
                            statusIndicator("AdMob Initialized", value: adMob.isConfigured)
                            statusIndicator("Can Request Ads", value: adMob.canRequestAds)
                            statusIndicator("Banner Ready", value: adManager.isBannerAdLoaded)
                            statusIndicator("Interstitial Ready", value: adMob.isInterstitialReady)
                            statusIndicator("Rewarded Ready", value: adMob.isRewardedReady)
                            statusIndicator("Remove Ads Active", value: PurchaseManager.shared.hasAdFree)
                            devButton("PRELOAD TEST INTERSTITIAL") { AdMobService.shared.preloadInterstitial(); done("Interstitial preload requested") }
                            devButton("PRELOAD TEST REWARDED") { AdMobService.shared.preloadRewarded(); done("Rewarded preload requested") }
                        }
                        devSection("SUPABASE (READ-ONLY INDICATORS)") {
                            // Injection diagnostics only — never the values.
                            statusIndicator("Supabase URL Injected", value: SupabaseClientProvider.publicConfigURL != nil)
                            statusIndicator("Supabase Anon Key Injected", value: SupabaseClientProvider.publicConfigAnonKey != nil)
                            statusIndicator("Supabase Client Ready", value: SupabaseClientProvider.shared.isConfigured)
                        }
                        devSection("COMPETITIVE (READ-ONLY INDICATORS)") {
                            // Diagnostics only — never JWTs, keys or case solutions.
                            statusIndicator("Authenticated User ID Present", value: AccountGatePolicy.canAccessOnlineFeatures(auth.state))
                            statusIndicator("Ranked Repository Connected", value: competitive.isRepositoryConnected)
                            valueRow("Pending Submissions", "\(competitive.queue.pendingCount)")
                            valueRow("Last Submission State", lastSubmissionSummary)
                            valueRow("Last Ineligible Reason", competitive.lastIneligibleReason?.rawValue ?? "—")
                            devButton("FLUSH QUEUE NOW") {
                                Task { await competitive.flush() }
                                done("Flush requested")
                            }
                        }
                        devSection("DIFFICULTY") {
                            ForEach(DifficultyLevel.allCases, id: \.self) { level in
                                devButton(level.title) {
                                    DifficultyManager.shared.select(level)
                                    done("Difficulty: \(level.title)")
                                }
                            }
                        }
                        devSection("LOCAL DATA") {
                            devButton("RESET TUTORIAL DATA") {
                                TutorialManager.shared.resetTutorialData()
                                done("Tutorial data reset")
                            }
                            devButton("CLEAR BALANCE TELEMETRY") {
                                telemetry.clear()
                                done("Telemetry cleared")
                            }
                            devButton("CLEAR ALL LOCAL DATA", destructive: true) {
                                if let bundleID = Bundle.main.bundleIdentifier {
                                    UserDefaults.standard.removePersistentDomain(forName: bundleID)
                                }
                                done("All local data cleared — relaunch the app")
                            }
                        }
                        devSection("BALANCE TELEMETRY (LOCAL ONLY)") {
                            telemetrySummary
                        }
                        if let message {
                            Text(message)
                                .font(Theme.typewriter(12, relativeTo: .footnote))
                                .foregroundStyle(Theme.goldLight)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("DEV QA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("DONE") { dismiss() }
                }
            }
        }
    }

    private var telemetrySummary: some View {
        let records = telemetry.snapshot.cases.sorted { $0.key < $1.key }
        return VStack(alignment: .leading, spacing: 6) {
            if records.isEmpty {
                Text("No metrics recorded yet — play a case.")
                    .font(Theme.typewriter(11, relativeTo: .caption))
                    .foregroundStyle(Theme.paperInkSoft)
            } else {
                ForEach(records, id: \.key) { caseID, record in
                    Text("\(caseID): ✗\(record.wrongPlacements) 💡\(record.hintsUsed) ☠️\(record.quarterFailures)")
                        .font(Theme.typewriter(11, relativeTo: .caption))
                        .foregroundStyle(Theme.paperInkSoft)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Status indicators

    private var lastSubmissionSummary: String {
        guard let latest = competitive.queue.latest else { return "—" }
        var text = latest.state.rawValue.uppercased()
        if let score = latest.finalScore { text += " · \(score)" }
        if let category = latest.lastErrorCategory { text += " · \(category)" }
        return text
    }

    private func valueRow(_ title: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(Theme.typewriter(12, relativeTo: .caption))
                .foregroundStyle(Theme.paperInk)
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .heavy).width(.condensed))
                .tracking(1)
                .foregroundStyle(Theme.paperInkSoft)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }

    private func statusIndicator(_ title: String, value: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: value ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(value ? Theme.gold : Theme.paperInk.opacity(0.35))
            Text(title)
                .font(Theme.typewriter(12, relativeTo: .caption))
                .foregroundStyle(Theme.paperInk)
            Spacer()
            Text(value ? "YES" : "NO")
                .font(.system(size: 10, weight: .heavy).width(.condensed))
                .tracking(1)
                .foregroundStyle(Theme.paperInkSoft)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value ? "yes" : "no")")
    }

    // MARK: Actions

    /// Records user wins through the real season API until the target week /
    /// phase is reached — the same path a real playthrough takes.
    private func jumpWeeks(target: Int) {
        var recorded = 0
        while recorded < 40 {
            guard let season = seasonManager.season else { break }
            if target <= 10, season.currentWeek == target { break }
            if target == 11, season.phase == .postseason || season.phase == .complete { break }
            if target == 13, season.phase == .complete { break }
            guard seasonManager.recordUserResult(isWin: true, userScore: 3, opponentScore: 1, wentToOT: false) else { break }
            recorded += 1
        }
        done(recorded > 0 ? "Recorded \(recorded) wins" : "No further games to record")
    }

    private func done(_ text: String) {
        message = text
    }

    // MARK: Chrome

    private func devSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .heavy).width(.condensed))
                .tracking(1.5)
                .foregroundStyle(Theme.gold)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .paperCard(cornerRadius: 6)
    }

    private func devButton(_ title: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .heavy).width(.condensed))
                .tracking(1)
                .frame(maxWidth: .infinity, minHeight: 40)
        }
        .buttonStyle(GoldCapsuleButtonStyle())
        .tint(destructive ? Theme.highlightEvidence : Theme.gold)
    }
}
#endif
