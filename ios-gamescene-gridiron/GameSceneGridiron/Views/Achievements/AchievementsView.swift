import SwiftUI

/// ACHIEVEMENTS — every achievement grouped by category: icon, name,
/// description, locked/unlocked state, unlock date and progress where it
/// applies. Locked rows render slightly muted. Pure presentation: all state
/// comes from `AchievementManager`.
struct AchievementsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var achievementManager = AchievementManager.shared
    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            DeskBackground()

            ScrollView {
                VStack(spacing: 16) {
                    header
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 16)

                    ForEach(AchievementCategory.allCases, id: \.rawValue) { category in
                        categorySection(category)
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 14)
                    }

                    Spacer(minLength: 12)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.05)) { hasAppeared = true }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                Haptics.tick()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.goldLight)
                    .frame(width: 38, height: 38)
                    .background(Color.black.opacity(0.45), in: .circle)
                    .overlay { Circle().strokeBorder(Theme.gold.opacity(0.4), lineWidth: 1) }
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Back")

            VStack(spacing: 3) {
                Text("ACHIEVEMENTS")
                    .font(.system(size: 24, weight: .black).width(.compressed))
                    .tracking(1.5)
                    .foregroundStyle(Theme.goldGradient)
                Text("\(achievementManager.unlockedCount) / \(achievementManager.totalCount) UNLOCKED")
                    .font(.system(size: 10, weight: .heavy).width(.condensed))
                    .tracking(1.5)
                    .foregroundStyle(Theme.paperInkSoft)
            }
            .frame(maxWidth: .infinity)

            Image(systemName: "rosette")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.gold)
                .frame(width: 38)
        }
        .padding(.horizontal, 20)
        .accessibilityElement(children: .contain)
    }

    // MARK: Sections

    private func categorySection(_ category: AchievementCategory) -> some View {
        let achievements = AchievementCatalog.achievements(in: category)
        let unlocked = achievements.filter { achievementManager.isUnlocked($0.id) }.count

        return VStack(spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: category.symbol)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.gold)
                Text(category.displayName)
                    .font(.system(size: 12, weight: .heavy).width(.condensed))
                    .tracking(2)
                    .foregroundStyle(Theme.paperInk)
                Spacer()
                Text("\(unlocked)/\(achievements.count)")
                    .font(.system(size: 11, weight: .heavy).width(.condensed))
                    .monospacedDigit()
                    .foregroundStyle(Theme.paperInkSoft)
            }
            .padding(.bottom, 4)

            ForEach(achievements) { achievement in
                AchievementRow(achievement: achievement)
            }
        }
        .padding(14)
        .paperCard(cornerRadius: 6)
        .rotationEffect(.degrees(category.hashValue % 2 == 0 ? -0.4 : 0.4))
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Row

/// One achievement line: medallion icon, name, description, progress or
/// unlock date. Unlocked rows get the gold treatment; locked rows sit muted.
struct AchievementRow: View {
    let achievement: Achievement

    @State private var achievementManager = AchievementManager.shared

    private var isUnlocked: Bool { achievementManager.isUnlocked(achievement.id) }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Theme.surfaceRaised))
                Circle()
                    .strokeBorder(isUnlocked ? Theme.bronzeDeep : Theme.paperInk.opacity(0.15), lineWidth: 1.5)
                    .padding(1.5)
                Image(systemName: achievement.symbol)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(isUnlocked ? Theme.ink : Theme.paperInkSoft.opacity(0.6))
            }
            .frame(width: 40, height: 40)
            .shadow(color: isUnlocked ? Theme.gold.opacity(0.35) : .clear, radius: 6)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(achievement.name)
                        .font(.system(size: 14, weight: .heavy).width(.condensed))
                        .tracking(0.8)
                        .foregroundStyle(isUnlocked ? Theme.goldLight : Theme.paperInk.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if isUnlocked, achievement.reward > 0, achievementManager.hasClaimedReward(achievement.id) {
                        Image(systemName: "sportscourt.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.gold)
                            .accessibilityLabel("Game Ball reward claimed")
                    }
                }

                Text(achievement.detail)
                    .font(Theme.typewriter(11, relativeTo: .caption))
                    .foregroundStyle(isUnlocked ? Theme.paperInk : Theme.paperInkSoft.opacity(0.75))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let holder = achievementManager.holderName(achievement.id) {
                    Text("EARNED BY \(holder.uppercased())")
                        .font(.system(size: 9, weight: .black).width(.condensed))
                        .tracking(1)
                        .foregroundStyle(Theme.bronzeDeep)
                        .lineLimit(1)
                }

                bottomLine
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            statusMark
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.paperInk.opacity(0.1)).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    /// Progress bar for goal-based achievements, otherwise the unlock date.
    @ViewBuilder
    private var bottomLine: some View {
        if let goal = achievement.goal {
            HStack(spacing: 8) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.paperInk.opacity(0.14))
                        Capsule()
                            .fill(isUnlocked ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Theme.bronze))
                            .frame(width: max(4, proxy.size.width * achievementManager.progressFraction(for: achievement)))
                    }
                }
                .frame(height: 5)
                Text("\(achievementManager.progressValue(for: achievement)) / \(goal)")
                    .font(.system(size: 10, weight: .heavy).width(.condensed))
                    .monospacedDigit()
                    .foregroundStyle(Theme.paperInkSoft)
                    .lineLimit(1)
            }
        } else if let date = achievementManager.unlockDate(achievement.id) {
            Text("UNLOCKED · \(date.formatted(date: .abbreviated, time: .omitted).uppercased())")
                .font(.system(size: 9, weight: .black).width(.condensed))
                .tracking(1)
                .foregroundStyle(Theme.bronzeDeep)
        }
    }

    private var statusMark: some View {
        Image(systemName: isUnlocked ? "checkmark.circle.fill" : "lock.fill")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(isUnlocked ? Theme.gold : Theme.paperInkSoft.opacity(0.45))
            .frame(width: 24)
            .accessibilityHidden(true)
    }

    private var accessibilityText: String {
        let state = isUnlocked ? "Unlocked" : "Locked"
        let progress: String
        if let goal = achievement.goal, !isUnlocked {
            progress = " Progress \(achievementManager.progressValue(for: achievement)) of \(goal)."
        } else {
            progress = ""
        }
        return "\(state): \(achievement.name). \(achievement.detail).\(progress)"
    }
}
