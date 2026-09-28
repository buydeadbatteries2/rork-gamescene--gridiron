import SwiftUI

/// Yellow/black diagonal caution tape strip.
struct CautionTape: View {
    var stripeWidth: CGFloat = 9

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.caution))
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                var path = Path()
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + stripeWidth, y: size.height))
                path.addLine(to: CGPoint(x: x + stripeWidth + size.height, y: 0))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                path.closeSubpath()
                context.fill(path, with: .color(Color.black.opacity(0.88)))
                x += stripeWidth * 2
            }
        }
        .overlay {
            LinearGradient(colors: [.white.opacity(0.18), .clear, .black.opacity(0.25)], startPoint: .top, endPoint: .bottom)
        }
        .accessibilityHidden(true)
    }
}
