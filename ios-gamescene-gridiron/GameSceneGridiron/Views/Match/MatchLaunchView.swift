import SwiftUI

/// The entry point behind START INVESTIGATION. First run: CREATE YOUR TEAM.
/// Afterwards: SELECT OPPONENT (until the season schedule replaces it), with
/// the franchise editable from here as well.
struct MatchLaunchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var teamStore = TeamStore.shared
    @State private var isEditingTeam: Bool = false

    var body: some View {
        Group {
            if let team = teamStore.userTeam {
                OpponentSelectView(
                    userTeam: team,
                    onEditTeam: {
                        Haptics.tick()
                        isEditingTeam = true
                    },
                    onClose: { dismiss() }
                )
            } else {
                TeamCreationView { _ in
                    // TeamStore now has a franchise, so this view switches
                    // to the opponent board automatically.
                } onClose: {
                    dismiss()
                }
            }
        }
        .fullScreenCover(isPresented: $isEditingTeam) {
            if let team = teamStore.userTeam {
                TeamCreationView(existingTeam: team) { _ in
                    isEditingTeam = false
                } onClose: {
                    isEditingTeam = false
                }
            }
        }
    }
}

#Preview {
    MatchLaunchView()
}
