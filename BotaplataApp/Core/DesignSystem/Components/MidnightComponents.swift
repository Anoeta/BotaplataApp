import SwiftUI

extension PremiumValueTone {
    var color: Color {
        switch self { case .positive: BotaplataColors.success; case .negative: BotaplataColors.danger; case .neutral: BotaplataColors.textPrimary }
    }
}

struct PremiumValueLabel: View {
    let value: String
    var tone: PremiumValueTone = .neutral
    var font: Font = BotaplataTypography.metricValue
    var body: some View {
        Text(value == "—" ? "Indisponible" : value)
            .font(font).monospacedDigit().foregroundStyle(tone.color)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct PremiumMetricCard: View {
    let title: String
    let value: String
    var footnote: String? = nil
    var tone: PremiumValueTone = .neutral
    var symbol: String? = nil
    var body: some View {
        PremiumCard {
            if let symbol { Image(systemName: symbol).foregroundStyle(BotaplataColors.accent).accessibilityHidden(true) }
            Text(title).font(BotaplataTypography.caption).foregroundStyle(BotaplataColors.textSecondary)
            PremiumValueLabel(value: value, tone: tone, font: .title2.weight(.semibold))
            if let footnote { Text(footnote).font(BotaplataTypography.caption).foregroundStyle(BotaplataColors.textSecondary) }
        }.frame(maxHeight: .infinity, alignment: .topLeading)
            .accessibilityElement(children: .combine)
    }
}

struct PremiumFilterChip: View {
    let title: String
    var isSelected: Bool
    var body: some View {
        Text(title).font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14).frame(minHeight: BotaplataTouch.minimum)
            .foregroundStyle(isSelected ? BotaplataColors.accent : BotaplataColors.textSecondary)
            .background(isSelected ? BotaplataColors.accent.opacity(0.12) : BotaplataColors.surface, in: Capsule())
            .overlay(Capsule().stroke(isSelected ? BotaplataColors.accent.opacity(0.45) : BotaplataColors.border, lineWidth: 1))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Wraps into rows for large text instead of clipping a native segmented Picker.
struct PremiumSegmentedControl<Selection: Hashable>: View {
    let title: String
    let options: [Selection]
    @Binding var selection: Selection
    let label: (Selection) -> String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: dynamicTypeSize.isAccessibilitySize ? 1 : min(options.count, 4)), spacing: 4) {
            ForEach(options, id: \.self) { option in
                Button { selection = option } label: {
                    Text(label(option)).font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: BotaplataTouch.minimum)
                        .padding(.horizontal, 4)
                        .foregroundStyle(selection == option ? BotaplataColors.accent : BotaplataColors.textSecondary)
                        .background(selection == option ? BotaplataColors.elevated : .clear, in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
                    .accessibilityLabel("\(title), \(label(option))")
                    .accessibilityAddTraits(selection == option ? .isSelected : [])
            }
        }.padding(4).background(BotaplataColors.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(BotaplataColors.border, lineWidth: 1))
    }
}

struct PremiumAssetIcon: View {
    let pair: String
    @ScaledMetric(relativeTo: .title3) private var size: CGFloat = 42
    var body: some View {
        Text(String((pair.split(separator: "/").first.map(String.init) ?? pair).prefix(3)))
            .font(.caption.weight(.bold)).foregroundStyle(BotaplataColors.accent)
            .frame(width: size, height: size)
            .background(BotaplataColors.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(BotaplataColors.accent.opacity(0.2), lineWidth: 1))
            .accessibilityHidden(true)
    }
}

struct PremiumTimelineRow<Content: View>: View {
    let symbol: String
    let color: Color
    let date: Date
    @ViewBuilder let content: Content
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 8) {
                Image(systemName: symbol).font(.subheadline).foregroundStyle(color)
                    .frame(width: 34, height: 34).background(color.opacity(0.12), in: Circle())
                Rectangle().fill(BotaplataColors.border).frame(width: 1).frame(maxHeight: .infinity)
            }.accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(HistoryPresentation.fullDate(date)).font(BotaplataTypography.caption).monospacedDigit().foregroundStyle(BotaplataColors.textSecondary)
                content
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.fixedSize(horizontal: false, vertical: true)
    }
}

struct PremiumChartContainer<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder let content: Content
    var body: some View {
        PremiumCard {
            PremiumSectionHeader(title: title, subtitle: subtitle)
            content
        }
    }
}

/// Native tabs own safe areas, VoiceOver focus and NavigationStack state.
struct PremiumBottomNavigation<Content: View>: View {
    @Binding var selection: AppTab
    @ViewBuilder let content: Content
    var body: some View { TabView(selection: $selection) { content }.tint(BotaplataColors.accent) }
}

struct PremiumEyebrow: View {
    let title: String
    var body: some View { Text(title.uppercased()).font(BotaplataTypography.eyebrow).tracking(1.2).foregroundStyle(BotaplataColors.textSecondary) }
}

#if DEBUG
#Preview("V3 · composants Midnight · fixtures") {
    ZStack {
        PremiumScreenBackground()
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PremiumEyebrow(title: "Fixture de preview")
                PremiumSectionHeader(title: "Midnight Premium", subtitle: "Police système · Dynamic Type")
                PremiumMetricCard(title: "P&L net réalisé · fixture", value: "+42,80 USDC", tone: .positive, symbol: "chart.line.uptrend.xyaxis")
                PremiumMetricCard(title: "Donnée absente", value: "Indisponible", footnote: "Non fournie par l’API")
                PremiumStatusBadge(status: .warning, text: "Données anciennes")
                PremiumSegmentedControl(title: "Sessions", options: ["Toutes", "En cours", "Terminées"], selection: .constant("Toutes"), label: { $0 })
                HStack { PremiumAssetIcon(pair: "SOL/USDC"); PremiumFilterChip(title: "Signaux", isSelected: true) }
                PremiumEmptyState(title: "Courbe de P&L indisponible", message: "Aucune série fournie par le backend.")
                PremiumErrorState(title: "Serveur indisponible", message: "Actualisez lorsque la connexion revient.")
                PremiumLoadingSkeleton()
            }.padding()
        }
    }.preferredColorScheme(.dark)
}
#endif
