import SwiftUI

/// Top-level surface: brand, cinematic stadium photo, the investigation CTA and locked future modes.
struct HomeView: View {
    @State private var teamStore = TeamStore.shared
    @State private var isPlaying: Bool = false
    @State private var isEditingTeam: Bool = false
    @State private var lockedMessage: String?
    @State private var hasAppeared: Bool = false
    @State private var glow: Bool = false

    private let lockedModes: [(title: String, symbol: String)] = [
        ("DYNASTY", "trophy"),
        ("RECORDS", "chart.bar"),
        ("SETTINGS", "gearshape")
    ]

    var body: some View {
        ZStack {
            DeskBackground()

            ScrollView {
                VStack(spacing: 22) {
                    GSLogoView()
                        .padding(.top, 8)
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : -12)

                    heroPhoto
                        .opacity(hasAppeared ? 1 : 0)
                        .scaleEffect(hasAppeared ? 1 : 0.96)

                    Button {
                        Haptics.pickUp()
                        isPlaying = true
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 22, weight: .semibold))
                            Text("START INVESTIGATION")
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .padding(.horizontal, 26)
                    }
                    .buttonStyle(GoldCapsuleButtonStyle())
                    .shadow(color: Theme.gold.opacity(glow ? 0.35 : 0.1), radius: glow ? 22 : 10)
                    .accessibilityHint("Opens the first quarter mystery")

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 18) {
                        if let team = teamStore.userTeam {
                            Button {
                                Haptics.tick()
                                isEditingTeam = true
                            } label: {
                                MyTeamFolderTile(team: team)
                            }
                            .buttonStyle(PressableButtonStyle(scale: 0.97))
                        } else {
                            Button {
                                Haptics.warning()
                                withAnimation(.snappy) { lockedMessage = "Create your franchise first — tap START INVESTIGATION." }
                            } label: {
                                LockedFolderTile(title: "TEAM", symbol: "person.3")
                            }
                            .buttonStyle(PressableButtonStyle(scale: 0.97))
                        }
                        ForEach(lockedModes, id: \.title) { mode in
                            Button {
                                Haptics.warning()
                                withAnimation(.snappy) { lockedMessage = "\(mode.title.capitalized) opens in a future season." }
                            } label: {
                                LockedFolderTile(title: mode.title, symbol: mode.symbol)
                            }
                            .buttonStyle(PressableButtonStyle(scale: 0.97))
                        }
                    }
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)

            if let lockedMessage {
                VStack {
                    Spacer()
                    Text(lockedMessage)
                        .font(Theme.typewriter(14))
                        .foregroundStyle(Theme.paperInk)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .paperCard(cornerRadius: 4)
                        .padding(.bottom, 24)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: lockedMessage) {
                    try? await Task.sleep(for: .seconds(1.8))
                    withAnimation(.easeOut) { self.lockedMessage = nil }
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.05)) { hasAppeared = true }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { glow = true }
        }
        .fullScreenCover(isPresented: $isPlaying) {
            MatchLaunchView()
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

    private var heroPhoto: some View {
        Color.black
            .aspectRatio(1.45, contentMode: .fit)
            .overlay {
                Image("football_stadium_night")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .allowsHitTesting(false)
            }
            .overlay {
                LinearGradient(colors: [.clear, .black.opacity(0.35)], startPoint: .center, endPoint: .bottom)
            }
            .clipShape(.rect(cornerRadius: 2))
            .padding(9)
            .background(Theme.paper.opacity(0.92), in: .rect(cornerRadius: 3))
            .shadow(color: .black.opacity(0.7), radius: 14, y: 10)
            .rotationEffect(.degrees(-1.2))
            .overlay(alignment: .top) {
                PushPin().offset(y: -8)
            }
            .overlay(alignment: .bottomTrailing) {
                StickyNote(text: "TRUTH LIVES\nON THE FIELD", rotation: -3, width: 108)
                    .offset(x: 6, y: 14)
            }
            .overlay(alignment: .topLeading) {
                StickyNote(text: "SAME GAME.\nDIFFERENT\nANSWERS.", rotation: -6, width: 86)
                    .offset(x: -14, y: -30)
            }
            .overlay(alignment: .topTrailing) {
                StickyNote(text: "PLAYS\nHIDE\nTHE TRUTH", rotation: 5, width: 78)
                    .offset(x: 12, y: -40)
            }
            .padding(.top, 16)
            .accessibilityElement()
            .accessibilityLabel("Night stadium photograph pinned to the case board")
    }
}

/// Dark detective-desk backdrop with a warm stadium glow.
struct DeskBackground: View {
    var body: some View {
        Theme.ink
            .overlay {
                Image("detective_desk_bg")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .allowsHitTesting(false)
            }
            .overlay {
                RadialGradient(
                    colors: [Theme.bronze.opacity(0.18), .clear],
                    center: UnitPoint(x: 0.5, y: 0.25),
                    startRadius: 10,
                    endRadius: 420
                )
            }
            .overlay {
                LinearGradient(colors: [.black.opacity(0.35), .clear, .black.opacity(0.3)], startPoint: .top, endPoint: .bottom)
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

#Preview {
    HomeView()
}
