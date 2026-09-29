import SwiftUI

/// CREATE YOUR TEAM — a four-step builder (state, name, logo, colors) with a
/// live uniform preview and a final YOUR FRANCHISE presentation. Everything is
/// picked from predefined local catalogs; nothing is typed or AI-generated.
struct TeamCreationView: View {
    /// Prefills the builder when editing an existing franchise.
    var existingTeam: GameTeam?
    /// Called once the franchise is confirmed and saved locally.
    let onConfirm: (GameTeam) -> Void
    var onClose: (() -> Void)?

    private enum Step: Int, CaseIterable {
        case state, name, logo, colors, franchise
    }

    @State private var step: Step = .state
    @State private var state: String?
    @State private var teamName: String?
    @State private var logoID: String?
    @State private var primaryIndex: Int = 0
    @State private var secondaryIndex: Int = 3
    @State private var hasAppeared: Bool = false

    private var draftTeam: GameTeam? {
        guard let state, let teamName, let logoID else { return nil }
        return GameTeam(
            id: existingTeam?.id ?? UUID(),
            state: state,
            teamName: teamName,
            logoID: logoID,
            primaryColorHex: ColorCatalog.colors[primaryIndex].hex,
            secondaryColorHex: ColorCatalog.colors[secondaryIndex].hex,
            isUserTeam: true
        )
    }

    private var canContinue: Bool {
        switch step {
        case .state: state != nil
        case .name: teamName != nil
        case .logo: logoID != nil
        case .colors: primaryIndex != secondaryIndex
        case .franchise: draftTeam != nil
        }
    }

    var body: some View {
        ZStack {
            DeskBackground()

            VStack(spacing: 14) {
                header

                if step == .franchise, let team = draftTeam {
                    FranchisePresentation(team: team, onConfirm: confirm, onEdit: { withAnimation(.snappy) { step = .colors } })
                        .transition(.opacity)
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            LiveTeamPreview(
                                state: state,
                                teamName: teamName,
                                logoID: logoID,
                                primaryHex: ColorCatalog.colors[primaryIndex].hex,
                                secondaryHex: ColorCatalog.colors[secondaryIndex].hex
                            )

                            switch step {
                            case .state: statePicker
                            case .name: namePicker
                            case .logo: logoPicker
                            case .colors: colorPickers
                            case .franchise: EmptyView()
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                    }
                    .scrollIndicators(.hidden)

                    continueButton
                }
            }
            .padding(.top, 12)
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 18)
        }
        .onAppear(perform: prefill)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) { hasAppeared = true }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            if let onClose {
                Button {
                    Haptics.tick()
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.goldLight)
                        .frame(width: 38, height: 38)
                        .background(Color.black.opacity(0.45), in: .circle)
                        .overlay { Circle().strokeBorder(Theme.gold.opacity(0.4), lineWidth: 1) }
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Close team builder")
            }

            VStack(spacing: 3) {
                Text(step == .franchise ? "YOUR FRANCHISE" : "CREATE YOUR TEAM")
                    .font(.system(size: 24, weight: .black).width(.compressed))
                    .tracking(1.5)
                    .foregroundStyle(Theme.goldGradient)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if step != .franchise {
                    StepDots(current: step.rawValue, total: 4)
                }
            }
            .frame(maxWidth: .infinity)

            Group {
                if step != .state && step != .franchise {
                    Button {
                        Haptics.tick()
                        withAnimation(.snappy) { step = Step(rawValue: step.rawValue - 1) ?? .state }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.goldLight)
                            .frame(width: 38, height: 38)
                            .background(Color.black.opacity(0.45), in: .circle)
                            .overlay { Circle().strokeBorder(Theme.gold.opacity(0.4), lineWidth: 1) }
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityLabel("Previous step")
                }
            }
            .frame(width: 38, height: 38)
        }
        .padding(.horizontal, 20)
        .accessibilityElement(children: .contain)
    }

    private struct StepDots: View {
        let current: Int
        let total: Int

        var body: some View {
            HStack(spacing: 6) {
                ForEach(0..<total, id: \.self) { index in
                    Capsule()
                        .fill(index <= current ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Theme.gold.opacity(0.2)))
                        .frame(width: index == current ? 22 : 10, height: 4)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: current)
                }
            }
            .accessibilityLabel("Step \(current + 1) of \(total)")
        }
    }

    // MARK: Pickers

    private var statePicker: some View {
        PickerSection(title: "SELECT STATE", hint: "Where your franchise calls home") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(StateCatalog.states, id: \.name) { entry in
                    SelectableChip(
                        label: entry.name,
                        isSelected: state == entry.name
                    ) {
                        Haptics.tick()
                        AudioManager.shared.play(.cardSelect)
                        withAnimation(.snappy) { state = entry.name }
                    }
                }
            }
        }
    }

    private var namePicker: some View {
        PickerSection(title: "TEAM NAME", hint: "50 original franchises — pick your mark") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                ForEach(TeamNameCatalog.names, id: \.self) { name in
                    SelectableChip(label: name, isSelected: teamName == name) {
                        Haptics.tick()
                        AudioManager.shared.play(.cardSelect)
                        withAnimation(.snappy) { teamName = name }
                    }
                }
            }
        }
    }

    private var logoPicker: some View {
        PickerSection(title: "TEAM LOGO", hint: "Inspect the artwork — your colors come later") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(LogoCatalog.logos) { logo in
                    LogoTile(logo: logo, isSelected: logoID == logo.id) {
                        Haptics.tick()
                        AudioManager.shared.play(.cardSelect)
                        withAnimation(.snappy) { logoID = logo.id }
                    }
                    .accessibilityLabel("Logo \(logo.name)")
                    .accessibilityAddTraits(logoID == logo.id ? .isSelected : [])
                }
            }
        }
    }

    private var colorPickers: some View {
        PickerSection(title: "TEAM COLORS", hint: "Primary and secondary — they must differ") {
            colorSection(
                title: "PRIMARY COLOR",
                selectedIndex: primaryIndex,
                disabledIndex: nil
            ) { index in
                primaryIndex = index
            }
            colorSection(
                title: "SECONDARY COLOR",
                selectedIndex: secondaryIndex,
                disabledIndex: primaryIndex
            ) { index in
                secondaryIndex = index
            }
            if primaryIndex == secondaryIndex {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("Choose a different secondary color — it cannot match the primary.")
                        .font(Theme.typewriter(12, relativeTo: .caption))
                }
                .foregroundStyle(Theme.danger)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// One compact 5-column swatch grid — all 15 colors visible at once,
    /// nothing extends past the safe area.
    private func colorSection(
        title: String,
        selectedIndex: Int,
        disabledIndex: Int?,
        onSelect: @escaping (Int) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .heavy).width(.condensed))
                .tracking(2)
                .foregroundStyle(Theme.paperInk)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                ForEach(Array(ColorCatalog.colors.enumerated()), id: \.element.id) { index, option in
                    let isSelected = selectedIndex == index
                    let isDisabled = disabledIndex == index
                    ColorSwatch(option: option, isSelected: isSelected, isDisabled: isDisabled) {
                        Haptics.tick()
                        AudioManager.shared.play(.cardSelect)
                        withAnimation(.snappy) { onSelect(index) }
                    }
                    .accessibilityLabel("\(title) color \(option.name)")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }

            Text(ColorCatalog.colors[selectedIndex].name.uppercased())
                .font(.system(size: 10, weight: .heavy).width(.condensed))
                .tracking(1.5)
                .foregroundStyle(Theme.goldLight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Flow

    private var continueButton: some View {
        Button {
            Haptics.pickUp()
            if step == .colors {
                withAnimation(.snappy) { step = .franchise }
            } else {
                withAnimation(.snappy) { step = Step(rawValue: step.rawValue + 1) ?? .colors }
            }
        } label: {
            HStack {
                Spacer()
                Text(step == .colors ? "REVIEW FRANCHISE" : "CONTINUE")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
            }
            .padding(.horizontal, 26)
        }
        .buttonStyle(GoldCapsuleButtonStyle())
        .disabled(!canContinue)
        .opacity(canContinue ? 1 : 0.45)
        .padding(.horizontal, 20)
        .padding(.bottom, 18)
        .accessibilityHint("Advances to the next team building step")
    }

    private func prefill() {
        guard let existingTeam else { return }
        state = existingTeam.state
        teamName = existingTeam.teamName
        logoID = existingTeam.logoID
        if let primary = ColorCatalog.colors.firstIndex(where: { $0.hex == existingTeam.primaryColorHex }) {
            primaryIndex = primary
        }
        if let secondary = ColorCatalog.colors.firstIndex(where: { $0.hex == existingTeam.secondaryColorHex }) {
            secondaryIndex = secondary
        }
    }

    private func confirm() {
        guard let team = draftTeam else { return }
        Haptics.success()
        TeamStore.shared.save(team)
        onConfirm(team)
    }
}

// MARK: - Live preview

/// The always-visible draft franchise: emblem, helmet, jersey and name, all
/// recoloring live with every selection.
struct LiveTeamPreview: View {
    let state: String?
    let teamName: String?
    let logoID: String?
    let primaryHex: UInt32
    let secondaryHex: UInt32

    var body: some View {
        let draft = GameTeam(
            state: state ?? "State",
            teamName: teamName ?? "Team",
            logoID: logoID ?? "shield",
            primaryColorHex: primaryHex,
            secondaryColorHex: secondaryHex,
            isUserTeam: true
        )

        HStack(spacing: 14) {
            TeamEmblemView(team: draft, size: 64)
                .frame(width: 64)

            VStack(alignment: .leading, spacing: 6) {
                Text(draft.displayName.uppercased())
                    .font(.system(size: 19, weight: .black).width(.compressed))
                    .tracking(1)
                    .foregroundStyle(Theme.paperInk)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                HStack(spacing: 5) {
                    Circle().fill(draft.primaryColor).frame(width: 12, height: 12)
                        .overlay { Circle().strokeBorder(Color.black.opacity(0.35), lineWidth: 1) }
                    Circle().fill(draft.secondaryColor).frame(width: 12, height: 12)
                        .overlay { Circle().strokeBorder(Color.black.opacity(0.35), lineWidth: 1) }
                    Text("DRAFT FRANCHISE")
                        .font(.system(size: 10, weight: .heavy).width(.condensed))
                        .tracking(1.5)
                        .foregroundStyle(Theme.paperInkSoft)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: -6) {
                TeamHelmetView(team: draft, size: 46)
                TeamJerseyView(team: draft, size: 44)
            }
        }
        .padding(12)
        .paperCard(cornerRadius: 8)
        .overlay(alignment: .topLeading) { PushPin(size: 16).offset(x: 12, y: -8) }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Franchise presentation

/// The final YOUR FRANCHISE showcase with CONFIRM TEAM.
private struct FranchisePresentation: View {
    let team: GameTeam
    let onConfirm: () -> Void
    let onEdit: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 10) {
                        TeamEmblemView(team: team, size: 128)
                        Text("YOUR FRANCHISE")
                            .font(.system(size: 13, weight: .heavy).width(.condensed))
                            .tracking(4)
                            .foregroundStyle(Theme.paperInkSoft)
                        Text(team.displayName)
                            .font(.system(size: 30, weight: .black).width(.compressed))
                            .tracking(1)
                            .foregroundStyle(Theme.paperInk)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .paperCard(cornerRadius: 8)
                    .overlay(alignment: .topLeading) { PushPin().offset(x: 18, y: -10) }
                    .padding(.top, 10)

                    HStack(spacing: 16) {
                        VStack(spacing: 8) {
                            TeamHelmetView(team: team, size: 92)
                            Text("HELMET")
                                .font(.system(size: 10, weight: .heavy).width(.condensed))
                                .tracking(2)
                                .foregroundStyle(Theme.paperInkSoft)
                        }
                        .frame(maxWidth: .infinity)
                        VStack(spacing: 8) {
                            TeamJerseyView(team: team, size: 92)
                            Text("JERSEY")
                                .font(.system(size: 10, weight: .heavy).width(.condensed))
                                .tracking(2)
                                .foregroundStyle(Theme.paperInkSoft)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 16)
                    .paperCard(cornerRadius: 8)

                    HStack(spacing: 8) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.bronzeDeep)
                        Text("You can redesign this franchise later from the TEAM folder.")
                            .font(Theme.typewriter(12, relativeTo: .caption))
                            .foregroundStyle(Theme.paperInkSoft)
                    }
                    .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: 10) {
                Button {
                    AudioManager.shared.play(.placementCorrect)
                    onConfirm()
                } label: {
                    HStack {
                        Spacer()
                        Text("CONFIRM TEAM")
                        Spacer()
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .padding(.horizontal, 26)
                }
                .buttonStyle(GoldCapsuleButtonStyle())
                .accessibilityHint("Saves your franchise locally")

                Button(action: onEdit) {
                    Text("BACK TO COLORS")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.paperInk)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .overlay { Capsule().strokeBorder(Theme.paperInk.opacity(0.4), lineWidth: 1.2) }
                        .contentShape(.capsule)
                }
                .buttonStyle(PressableButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
    }
}

// MARK: - Shared pieces

/// A titled picker section on manila paper.
private struct PickerSection<Content: View>: View {
    let title: String
    let hint: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .heavy).width(.condensed))
                    .tracking(2.5)
                    .foregroundStyle(Theme.paperInk)
                Text(hint)
                    .font(Theme.typewriter(11, relativeTo: .caption2))
                    .foregroundStyle(Theme.paperInkSoft)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .paperCard(cornerRadius: 6)
    }
}

/// A manila chip used for state and name selection.
struct SelectableChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .heavy : .semibold).width(.condensed))
                .tracking(0.5)
                .foregroundStyle(isSelected ? Theme.ink : Theme.paperInk)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 40)
                .padding(.horizontal, 8)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Theme.paper.opacity(0.55)))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(isSelected ? Theme.gold : Theme.paperInk.opacity(0.22), lineWidth: isSelected ? 1.6 : 1)
                }
        }
        .buttonStyle(PressableButtonStyle(scale: 0.95))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Logo tile

/// A high-contrast neutral logo tile: the raw vector emblem in bright ink on a
/// dark charcoal card, so the artwork itself is what the player evaluates.
/// Team colors are applied later in the live preview and franchise presentation.
private struct LogoTile: View {
    let logo: TeamLogoOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                TeamLogoGlyph(
                    logoID: logo.id,
                    primary: Color(hex: 0xF2ECDC),
                    secondary: Theme.gold
                )
                .aspectRatio(contentMode: .fit)
                .frame(height: 66)
                .frame(maxWidth: .infinity)

                Text(logo.name.uppercased())
                    .font(.system(size: 9, weight: .heavy).width(.condensed))
                    .tracking(0.7)
                    .foregroundStyle(isSelected ? Theme.goldLight : Theme.paperInkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [isSelected ? Theme.gold.opacity(0.22) : Color(hex: 0x2A2620), Color(hex: 0x191612)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isSelected ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Theme.gold.opacity(0.18)),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            .shadow(color: isSelected ? Theme.gold.opacity(0.45) : .black.opacity(0.35), radius: isSelected ? 9 : 4, y: 2)
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(Color.black)
                        .frame(width: 18, height: 18)
                        .background(Theme.gold, in: .circle)
                        .overlay { Circle().strokeBorder(Color.black.opacity(0.5), lineWidth: 1) }
                        .offset(x: 5, y: -5)
                }
            }
        }
        .buttonStyle(PressableButtonStyle(scale: 0.94))
    }
}

// MARK: - Color swatch

/// One uniform color swatch in the compact 5-column grid. The selected swatch
/// gets a gold outline, a checkmark and a soft glow; the disabled swatch (the
/// primary color inside the secondary grid) cannot be tapped.
private struct ColorSwatch: View {
    let option: TeamColorOption
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: option.hex).lightened(0.25), Color(hex: option.hex)],
                            center: UnitPoint(x: 0.35, y: 0.3),
                            startRadius: 2,
                            endRadius: 26
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.45), lineWidth: 1)
                    }

                if isSelected {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(Theme.goldGradient, lineWidth: 2.5)
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(TeamKitResolver.contrastColor(on: option.hex))
                        .shadow(color: .black.opacity(0.4), radius: 2)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .contentShape(.rect(cornerRadius: 11))
            .shadow(color: isSelected ? Theme.gold.opacity(0.5) : .clear, radius: 8, y: 2)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.9))
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.3 : 1)
    }
}

#Preview("Builder") {
    TeamCreationView { _ in }
        .background(Theme.ink)
}
