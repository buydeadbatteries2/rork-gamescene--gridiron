import SwiftUI

/// Full-screen verdict for the quarter. Continue returns to Home in Phase 1.
struct QuarterResultView: View {
    let viewModel: GameViewModel
    let onContinue: () -> Void

    @State private var stampIn: Bool = false
    @State private var photoIn: Bool = false

    private var isWin: Bool { viewModel.result == .won }

    var body: some View {
        ZStack {
            DeskBackground()
            if !isWin {
                Color.black.opacity(0.35).ignoresSafeArea()
            }

            ScrollView {
                VStack(spacing: 22) {
                    GSLogoView(scale: 0.8)
                        .padding(.top, 8)

                    stamp
                        .scaleEffect(stampIn ? 1 : 1.9)
                        .opacity(stampIn ? 1 : 0)
                        .rotationEffect(.degrees(stampIn ? -2 : -9))

                    fieldPhoto
                        .opacity(photoIn ? 1 : 0)
                        .offset(y: photoIn ? 0 : 30)

                    Button {
                        Haptics.pickUp()
                        onContinue()
                    } label: {
                        HStack {
                            Spacer()
                            Text("CONTINUE")
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 15, weight: .bold))
                        }
                        .padding(.horizontal, 26)
                    }
                    .buttonStyle(GoldCapsuleButtonStyle())
                    .opacity(photoIn ? 1 : 0)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .overlay(alignment: .topLeading) {
            Button(action: onContinue) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.45), in: .circle)
            }
            .padding(.leading, 16)
            .accessibilityLabel("Close")
        }
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.55).delay(0.15)) { stampIn = true }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.45)) { photoIn = true }
        }
        .sensoryFeedback(isWin ? .success : .warning, trigger: stampIn)
    }

    private var stamp: some View {
        VStack(spacing: 6) {
            Text(isWin ? "CASE SOLVED" : "QUARTER LOST")
                .font(.system(size: 46, weight: .black).width(.compressed))
                .foregroundStyle(isWin ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Theme.danger))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            HStack(spacing: 10) {
                Rectangle().fill(Theme.gold.opacity(0.7)).frame(width: 28, height: 2)
                Text(isWin ? "QUARTER WON" : "REGROUP")
                    .font(.system(size: 22, weight: .heavy).width(.compressed))
                    .tracking(2)
                    .foregroundStyle(Theme.goldLight)
                Rectangle().fill(Theme.gold.opacity(0.7)).frame(width: 28, height: 2)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.7), in: .rect(cornerRadius: 4))
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(isWin ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Theme.danger), lineWidth: 3)
                .padding(4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var fieldPhoto: some View {
        VStack(spacing: 0) {
            GameFieldView(viewModel: viewModel, isInteractive: false)
                .aspectRatio(0.96, contentMode: .fit)
                .saturation(isWin ? 1 : 0.35)
                .overlay {
                    if isWin {
                        GSShieldMark(size: 44).opacity(0.85)
                    }
                }
                .padding(9)
                .background(Theme.paper.opacity(0.92))
                .overlay(alignment: .top) { PushPin().offset(y: -9) }
                .rotationEffect(.degrees(1))
                .shadow(color: .black.opacity(0.7), radius: 14, y: 10)

            Text(caption)
                .font(Theme.typewriter(14))
                .foregroundStyle(Theme.paperInk)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .paperCard(cornerRadius: 2, darkness: 0.05)
                .rotationEffect(.degrees(-0.6))
                .padding(.horizontal, 6)
                .offset(y: -10)
        }
    }

    private var caption: String {
        if isWin {
            return "All \(viewModel.puzzle.missingPlayers.count) missing players have been identified and placed. The quarter is complete."
        }
        return "The game isn't over. Regroup for the next quarter.\n\(viewModel.placements.count) of \(viewModel.puzzle.missingPlayers.count) players identified."
    }
}
