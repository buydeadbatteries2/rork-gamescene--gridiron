import SwiftUI

/// The unlocked TEAM folder on the home desk once a franchise exists: shows the
/// team's emblem, name and kit colors. Tapping reopens the team builder.
struct MyTeamFolderTile: View {
    let team: GameTeam

    var body: some View {
        ZStack {
            FolderShape()
                .fill(Theme.paperDark.opacity(0.55))
                .offset(x: 4, y: -5)
            PaperSurface(cornerRadius: 0, darkness: 0.08)
                .clipShape(FolderShape())
                .overlay {
                    FolderShape().stroke(Color.black.opacity(0.25), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.6), radius: 8, y: 6)

            VStack(spacing: 7) {
                TeamEmblemView(team: team, size: 44)
                Text(team.teamName.uppercased())
                    .font(.system(size: 16, weight: .heavy).width(.condensed))
                    .tracking(1)
                    .foregroundStyle(Theme.paperInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(team.state.uppercased()) — TAP TO OPEN ROSTER")
                    .font(.system(size: 9, weight: .heavy).width(.condensed))
                    .tracking(1.2)
                    .foregroundStyle(Theme.bronzeDeep)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.top, 18)

            HStack(spacing: 4) {
                Circle()
                    .fill(team.primaryColor)
                    .frame(width: 12, height: 12)
                    .overlay { Circle().strokeBorder(Color.black.opacity(0.4), lineWidth: 1) }
                Circle()
                    .fill(team.secondaryColor)
                    .frame(width: 12, height: 12)
                    .overlay { Circle().strokeBorder(Color.black.opacity(0.4), lineWidth: 1) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.trailing, 12)
            .padding(.top, 22)
        }
        .clipShape(FolderShape())
        .frame(height: 118)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your team \(team.displayName), tap to open the roster")
    }
}
