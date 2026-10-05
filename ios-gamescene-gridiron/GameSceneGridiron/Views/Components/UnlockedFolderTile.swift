import SwiftUI

/// An unlocked folder tile on the home desk: same manila folder silhouette as
/// the locked tiles, but open for business — no lock, no caution tape, a gold
/// "TAP TO OPEN" hint instead.
struct UnlockedFolderTile: View {
    let title: String
    let symbol: String

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

            Image(systemName: symbol)
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(Theme.paperInk.opacity(0.12))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .padding(.trailing, 14)
                .padding(.top, 20)

            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.paperInk.opacity(0.8))
                Text(title)
                    .font(.system(size: 17, weight: .heavy).width(.condensed))
                    .tracking(1)
                    .foregroundStyle(Theme.paperInk)
                Text("TAP TO OPEN")
                    .font(Theme.typewriter(9, relativeTo: .caption2))
                    .tracking(1.5)
                    .foregroundStyle(Theme.bronzeDeep)
            }
            .padding(.top, 12)

            HStack(spacing: 3) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .black))
            }
            .foregroundStyle(Theme.gold)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.trailing, 12)
            .padding(.top, 22)
        }
        .clipShape(FolderShape())
        .frame(height: 118)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), tap to open")
    }
}
