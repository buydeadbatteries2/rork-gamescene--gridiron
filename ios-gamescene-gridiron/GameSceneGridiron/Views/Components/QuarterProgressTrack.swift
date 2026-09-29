import SwiftUI

/// Regulation game state shown on the HUD and result screens:
/// ✓ solved · ✕ failed · ● current quarter · ○ upcoming.
struct QuarterProgressTrack: View {
    let match: GameMatch
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<GameMatch.regulationQuarters, id: \.self) { index in
                chip(label: "Q\(index + 1)", index: index, isOvertime: false)
            }
            if showsOvertime {
                chip(label: "OT", index: GameMatch.regulationQuarters, isOvertime: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private var showsOvertime: Bool {
        match.isOvertime || match.needsOvertime || match.overtimeRecord != nil
    }

    private enum ChipState { case solved, failed, current, upcoming }

    private func state(for index: Int) -> ChipState {
        if index < match.quarterRecords.count {
            return match.quarterRecords[index].outcome == .solved ? .solved : .failed
        }
        if match.overtimeRecord != nil, index == GameMatch.regulationQuarters {
            return match.overtimeRecord?.outcome == .solved ? .solved : .failed
        }
        return index == match.currentQuarterIndex ? .current : .upcoming
    }

    @ViewBuilder
    private func chip(label: String, index: Int, isOvertime: Bool) -> some View {
        let chipState = state(for: index)
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .heavy).width(.condensed))
                .tracking(0.6)
            Image(systemName: symbol(for: chipState))
                .font(.system(size: 8, weight: .black))
        }
        .foregroundStyle(foreground(for: chipState))
        .padding(.horizontal, 6)
        .frame(height: 20)
        .background(background(for: chipState, isOvertime: isOvertime), in: .capsule)
        .overlay {
            Capsule().strokeBorder(outline(for: chipState), lineWidth: 1)
        }
        .opacity(chipState == .current ? (pulse ? 1 : 0.62) : 1)
        .accessibilityAddTraits(chipState == .current ? [.isSelected] : [])
    }

    private func symbol(for state: ChipState) -> String {
        switch state {
        case .solved: "checkmark"
        case .failed: "xmark"
        case .current: "circle.fill"
        case .upcoming: "circle"
        }
    }

    private func foreground(for state: ChipState) -> Color {
        switch state {
        case .solved: Theme.easy
        case .failed: Theme.danger
        case .current: Theme.goldLight
        case .upcoming: Theme.paperInk.opacity(0.45)
        }
    }

    private func background(for state: ChipState, isOvertime: Bool) -> Color {
        switch state {
        case .solved: Theme.easy.opacity(0.18)
        case .failed: Theme.danger.opacity(0.2)
        case .current: Theme.gold.opacity(0.2)
        case .upcoming: Color.black.opacity(0.3)
        }
    }

    private func outline(for state: ChipState) -> Color {
        switch state {
        case .solved: Theme.easy.opacity(0.6)
        case .failed: Theme.danger.opacity(0.6)
        case .current: Theme.gold.opacity(0.8)
        case .upcoming: Theme.paperInk.opacity(0.2)
        }
    }

    private var accessibilityDescription: String {
        var parts = match.quarterRecords.map { record in
            "\(record.label) \(record.outcome == .solved ? "solved" : "failed")"
        }
        if match.quarterRecords.count < GameMatch.regulationQuarters {
            parts.append("\(match.currentLabel) in progress")
        } else if match.needsOvertime {
            parts.append("overtime in progress")
        }
        return "Game progress: " + parts.joined(separator: ", ")
    }
}
