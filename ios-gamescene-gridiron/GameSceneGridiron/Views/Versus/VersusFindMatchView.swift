import SwiftUI

/// Phase 15B — FIND MATCH. The player picks a difficulty and nothing else:
/// `find-versus-match` chooses the opponent (or opens a waiting file) and
/// the five cases.
struct VersusFindMatchView: View {
    var store: VersusStore = .shared
    let onBack: () -> Void
    let onHome: () -> Void
    let onMatched: (UUID) -> Void

    @State private var selected: DifficultyLevel?

    /// An unplayed waiting file at another difficulty — the server closes it
    /// when the player searches a different one, so say so up front.
    private var waitingElsewhere: VersusMatch? {
        guard let selected else { return nil }
        return store.openMatches.first {
            VersusPhase.of($0) == .waitingCanPlay && $0.difficultyLevel != selected
        }
    }

    private var isSearching: Bool { store.findState == .searching }

    var body: some View {
        ZStack {
            DeskBackground()

            ScrollView {
                VStack(spacing: 16) {
                    VersusHeader(
                        title: "FIND MATCH",
                        subtitle: "PICK THE CASE DIFFICULTY. THE SERVER PICKS THE REST.",
                        onBack: onBack,
                        onHome: onHome
                    )

                    VStack(spacing: 10) {
                        ForEach(DifficultyLevel.allCases, id: \.self) { level in
                            difficultyCard(level)
                        }
                    }

                    if let waitingElsewhere, let level = waitingElsewhere.difficultyLevel {
                        Label("Searching here closes your unplayed \(level.title) waiting file.", systemImage: "exclamationmark.triangle.fill")
                            .font(Theme.typewriter(11, relativeTo: .caption))
                            .foregroundStyle(Theme.caution)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.5), in: .rect(cornerRadius: 6))
                    }

                    if case .failed(let message) = store.findState {
                        Text(message)
                            .font(Theme.typewriter(12, relativeTo: .caption))
                            .foregroundStyle(Theme.paper)
                            .multilineTextAlignment(.center)
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .background(Theme.danger.opacity(0.85), in: .rect(cornerRadius: 6))
                            .accessibilityIdentifier("versus.find.error")
                    }

                    rulesNote

                    Button(action: find) {
                        HStack {
                            Spacer()
                            if isSearching {
                                ProgressView().tint(Theme.ink)
                                Text("SEARCHING THE WIRE…")
                            } else {
                                Text("FIND OPPONENT")
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(GoldCapsuleButtonStyle())
                    .disabled(selected == nil || isSearching)
                    .opacity(selected == nil ? 0.5 : 1)
                    .accessibilityIdentifier("versus.find.submit")
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 26)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear { store.clearFindError() }
        .sensoryFeedback(.selection, trigger: selected)
    }

    private func difficultyCard(_ level: DifficultyLevel) -> some View {
        let isSelected = selected == level
        return Button {
            selected = level
            store.clearFindError()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.seal.fill" : "circle")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(isSelected ? Theme.turf : Theme.paperInk.opacity(0.35))
                VStack(alignment: .leading, spacing: 3) {
                    Text(level.title)
                        .font(.system(size: 20, weight: .black).width(.compressed))
                        .tracking(1)
                        .foregroundStyle(Theme.paperInk)
                    Text(level.blurb)
                        .font(Theme.typewriter(11, relativeTo: .caption))
                        .foregroundStyle(Theme.paperInkSoft)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .paperCard(cornerRadius: 6, darkness: isSelected ? 0 : 0.08)
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isSelected ? Theme.gold : .clear, lineWidth: 2.5)
            }
            .scaleEffect(isSelected ? 1.0 : 0.98)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.98))
        .disabled(isSearching)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("versus.find.\(level.rawValue)")
    }

    private var rulesNote: some View {
        VStack(alignment: .leading, spacing: 4) {
            VersusFileLabel(text: "HOUSE RULES")
            Text("Both detectives get the same five server-assigned cases. Hints are disabled. You don't have to wait here — the file stays in the Hub until the deadline.")
                .font(Theme.typewriter(11, relativeTo: .caption))
                .foregroundStyle(Theme.paperInkSoft)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(cornerRadius: 4, darkness: 0.1)
    }

    private func find() {
        guard let selected, !isSearching else { return }
        Haptics.pickUp()
        Task {
            if let match = await store.find(difficulty: selected) {
                Haptics.success()
                onMatched(match.matchID)
            } else {
                Haptics.error()
            }
        }
    }
}
