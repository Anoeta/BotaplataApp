import SwiftUI
import Charts
import Accessibility

/// Shared by dashboard and session overview; detail retains the full candlestick cockpit.
struct PremiumMarketSection: View {
    let session: SessionDetail
    @Environment(RealSessionChartStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: BotaplataSpacing.sm) {
                HStack {
                    Label(session.pair, systemImage: "chart.xyaxis.line").font(.headline)
                    Spacer()
                    Text(session.priceObservedAt.map { "Cours · " + HistoryPresentation.time($0) } ?? "Cours · date inconnue").font(.caption).foregroundStyle(BotaplataColors.textMuted)
                }
                ChartRangeSelector(selected: store.selectedRange) { store.selectRange($0, sessionID: session.id) }
                content
            }
        }
        .task(id: activityKey) {
            guard scenePhase == .active else { store.stop(); return }
            store.load(sessionID: session.id)
            do {
                while !Task.isCancelled {
                    try await Task.sleep(for: .seconds(store.selectedRange.cacheTTL))
                    try Task.checkCancellation()
                    store.load(sessionID: session.id)
                }
            } catch { /* Cancellation ends foreground polling. */ }
        }
        .onDisappear { store.stop() }
    }

    private var activityKey: String { "\(session.id):\(scenePhase == .active):\(store.selectedRange.rawValue)" }

    @ViewBuilder private var content: some View {
        switch store.state {
        case .idle, .loading:
            ProgressView("Chargement des observations…").frame(maxWidth: .infinity, minHeight: 220)
        case .failed(let error):
            Text(error.message).font(.subheadline).foregroundStyle(BotaplataColors.textSecondary)
            Button("Réessayer") { store.refresh(sessionID: session.id) }.buttonStyle(PremiumSecondaryButtonStyle())
        case .loaded(let chart), .refreshing(let chart), .offline(let chart):
            if chart.sessionID == session.id && chart.displaySymbol.replacingOccurrences(of: "/", with: "").uppercased() == session.pair.replacingOccurrences(of: "/", with: "").uppercased() {
                if case .offline = store.state { Label("Historique en cache · hors ligne", systemImage: "wifi.slash").font(.caption).foregroundStyle(BotaplataColors.warning) }
                if case .refreshing = store.state { ProgressView("Actualisation…").font(.caption) }
                PremiumPriceChart(chart: chart, currentPrice: session.currentPrice)
                ForEach(chart.warnings) { warning in Text(warning.message).font(.caption).foregroundStyle(BotaplataColors.warning) }
            } else {
                Text("Le graphique reçu ne correspond pas à cette session ou à ce marché.").font(.caption).foregroundStyle(BotaplataColors.warning)
            }
        }
    }
}

struct PremiumPriceChart: View {
    let chart: TradingChart
    let currentPrice: MoneyAmount?
    @State private var selectedDate: Date?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let model: PremiumMarketPresentation
    init(chart: TradingChart, currentPrice: MoneyAmount?) {
        self.chart = chart; self.currentPrice = currentPrice
        model = PremiumMarketPresentation(chart: chart)
    }
    private var selected: MarketPricePoint? { selectedDate.flatMap { model.nearest(to: $0) } }
    private var markers: [TradingMarker] {
        guard let first = chart.candles.first?.openTime, let last = model.lastObservation else { return [] }
        return chart.markers.filter { first <= $0.timestamp && $0.timestamp <= last && $0.price > 0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BotaplataSpacing.sm) {
            priceHeader
            if model.points.isEmpty {
                Label("Historique indisponible", systemImage: "chart.xyaxis.line").font(.headline)
                Text("Aucune bougie persistée pour cette période. Essayez une autre période ; aucune courbe n’est reconstituée.")
                    .font(.subheadline).foregroundStyle(BotaplataColors.textSecondary)
                    .frame(minHeight: 160, alignment: .center)
            } else {
                priceChart
                observationFooter
            }
        }
        .onChange(of: chart.range) { _, _ in selectedDate = nil }
        .onChange(of: chart.sessionID) { _, _ in selectedDate = nil }
    }

    private var priceHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(selected.map { FinancialFormatters.money(MoneyAmount(Decimal($0.price), currency: chart.quoteAsset)) } ?? (currentPrice?.value == nil ? "Cours indisponible" : FinancialFormatters.money(currentPrice)))
                .font(.largeTitle.bold().monospacedDigit())
                .contentTransition(.identity)
            if let selected {
                Text(selected.date.formatted(date: .abbreviated, time: .shortened)).font(.caption)
            } else if let change = model.change {
                Label(FinancialFormatters.percent(change) + " · observations affichées", systemImage: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(change >= 0 ? BotaplataColors.success : BotaplataColors.danger)
            } else {
                Text("Variation non calculable sur les observations disponibles").font(.caption).foregroundStyle(BotaplataColors.textMuted)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var priceChart: some View {
        Chart {
            ForEach(model.gaps) { gap in
                RectangleMark(xStart: .value("Début du manque", gap.start), xEnd: .value("Fin du manque", gap.end))
                    .foregroundStyle(BotaplataColors.warning.opacity(0.12))
            }
            ForEach(model.points) { point in
                LineMark(x: .value("Heure", point.date), y: .value("Clôture", point.price), series: .value("Segment", point.segment))
                    .interpolationMethod(.linear)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .foregroundStyle(BotaplataColors.primaryTeal)
                if model.points.count == 1 {
                    PointMark(x: .value("Heure", point.date), y: .value("Clôture", point.price)).foregroundStyle(BotaplataColors.primaryTeal)
                }
            }
            ForEach(markers) { marker in
                PointMark(x: .value("Exécution", marker.timestamp), y: .value("Prix exécuté", NSDecimalNumber(decimal: marker.price).doubleValue))
                    .symbol(marker.kind == .buy || marker.kind == .partialBuy ? .triangle : .square)
                    .symbolSize(60)
                    .foregroundStyle(marker.kind == .buy || marker.kind == .partialBuy ? BotaplataColors.success : BotaplataColors.danger)
                    .annotation(position: .top) { Text(marker.kind == .buy || marker.kind == .partialBuy ? "BUY" : "SELL").font(.caption2.bold()) }
            }
            if let selected {
                RuleMark(x: .value("Sélection", selected.date)).foregroundStyle(BotaplataColors.textMuted).lineStyle(StrokeStyle(dash: [3, 3]))
                PointMark(x: .value("Sélection", selected.date), y: .value("Prix", selected.price)).foregroundStyle(BotaplataColors.textPrimary)
            }
        }
        .chartYScale(domain: chartDomain)
        .chartYAxis { AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) }
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 3)) { _ in AxisGridLine(); AxisValueLabel(format: chart.range == .sevenDays ? .dateTime.day().month() : .dateTime.hour().minute()) } }
        .chartXSelection(value: $selectedDate)
        .frame(height: dynamicTypeSize.isAccessibilitySize ? 260 : 210)
        .accessibilityLabel("Cours de \(chart.displaySymbol), \(model.points.count) observations. \(model.gaps.count) plages sans données.")
        .accessibilityChartDescriptor(MarketChartAccessibility(model: model, symbol: chart.displaySymbol))
    }

    private var chartDomain: ClosedRange<Double> {
        let values = model.points.map(\.price) + markers.map { NSDecimalNumber(decimal: $0.price).doubleValue }
        let low = values.min() ?? model.domain.lowerBound
        let high = values.max() ?? model.domain.upperBound
        let padding = max((high - low) * 0.12, max(high * 0.002, 0.01))
        return max(0, low - padding)...(high + padding)
    }

    private var observationFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let first = model.firstObservation, let last = model.lastObservation {
                Text("\(first.formatted(date: .abbreviated, time: .shortened)) → \(last.formatted(date: .abbreviated, time: .shortened))").font(.caption2)
            }
            if !model.gaps.isEmpty { Label("\(model.gaps.count) plages sans données · courbe interrompue", systemImage: "exclamationmark.triangle").font(.caption) }
            if chart.hasMore || !chart.isComplete { Text("Historique partiel · observations reçues uniquement").font(.caption) }
            if let last = model.lastObservation, Date().timeIntervalSince(last) > 1800 {
                Label("Dernière bougie ancienne · cours historique", systemImage: "clock.badge.exclamationmark").font(.caption)
            }
            Text("Clôtures \(chart.timeframe) · bougies persistées · généré à \(chart.generatedAt.formatted(date: .omitted, time: .shortened))").font(.caption2)
            if !markers.isEmpty { Text("△ BUY  □ SELL · exécutions reçues du backend").font(.caption2) }
        }
        .foregroundStyle(BotaplataColors.textSecondary)
    }
}

struct MarketChartAccessibility: AXChartDescriptorRepresentable {
    let model: PremiumMarketPresentation
    let symbol: String
    func makeChartDescriptor() -> AXChartDescriptor {
        let start = model.firstObservation?.timeIntervalSince1970 ?? 0
        let end = max(start + 1, model.lastObservation?.timeIntervalSince1970 ?? 1)
        let xAxis = AXNumericDataAxisDescriptor(title: "Heure", range: start...end, gridlinePositions: []) { value in
            Date(timeIntervalSince1970: value).formatted(date: .abbreviated, time: .shortened)
        }
        let yAxis = AXNumericDataAxisDescriptor(title: "Prix", range: model.domain, gridlinePositions: []) { value in
            FinancialFormatters.decimal(Decimal(value), min: 2, max: 4)
        }
        let segments = Dictionary(grouping: model.points, by: \.segment).sorted { $0.key < $1.key }.map { segment, points in
            AXDataSeriesDescriptor(name: "Observations \(segment + 1)", isContinuous: true, dataPoints: points.map { AXDataPoint(x: $0.date.timeIntervalSince1970, y: $0.price) })
        }
        return AXChartDescriptor(title: symbol, summary: "Clôtures persistées. \(model.gaps.count) plages sans observations.", xAxis: xAxis, yAxis: yAxis, additionalAxes: [], series: segments)
    }
}
