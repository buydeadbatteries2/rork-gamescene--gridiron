import SwiftUI

/// Manila folder silhouette with a tab on the top-left.
struct FolderShape: Shape {
    var tabWidthRatio: CGFloat = 0.42
    var tabHeight: CGFloat = 14
    var radius: CGFloat = 8

    func path(in rect: CGRect) -> Path {
        let tabWidth = rect.width * tabWidthRatio
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + tabWidth - 10, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.minX + tabWidth + 8, y: rect.minY + tabHeight), control: CGPoint(x: rect.minX + tabWidth, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY + tabHeight))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + tabHeight + radius), control: CGPoint(x: rect.maxX, y: rect.minY + tabHeight))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - radius, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - radius), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// A locked "coming soon" evidence folder tile.
struct LockedFolderTile: View {
    let title: String
    let symbol: String

    var body: some View {
        ZStack {
            FolderShape()
                .fill(Theme.paperDark.opacity(0.55))
                .offset(x: 4, y: -5)
            PaperSurface(cornerRadius: 0, darkness: 0.12)
                .clipShape(FolderShape())
                .overlay {
                    FolderShape().stroke(Color.black.opacity(0.25), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.6), radius: 8, y: 6)

            Image(systemName: symbol)
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(Theme.paperInk.opacity(0.1))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .padding(.trailing, 14)
                .padding(.top, 20)

            VStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.paperInk.opacity(0.75))
                Text(title)
                    .font(.system(size: 17, weight: .heavy).width(.condensed))
                    .tracking(1)
                    .foregroundStyle(Theme.paperInk.opacity(0.8))
                Text("COMING SOON")
                    .font(Theme.typewriter(9, relativeTo: .caption2))
                    .tracking(1.5)
                    .foregroundStyle(Theme.danger.opacity(0.85))
            }
            .padding(.top, 12)
        }
        .overlay(alignment: .bottomLeading) {
            CautionTape(stripeWidth: 7)
                .frame(width: 90, height: 13)
                .rotationEffect(.degrees(28))
                .offset(x: -14, y: -12)
                .clipped()
        }
        .clipShape(FolderShape())
        .frame(height: 118)
        .opacity(0.92)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), locked, coming soon")
    }
}
