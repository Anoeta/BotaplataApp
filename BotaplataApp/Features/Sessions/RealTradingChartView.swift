import SwiftUI
import Charts

struct ChartRenderableCandle: Identifiable, Equatable {
    let id: String
    let openTime: Date
    let closeTime: Date
    let isClosed: Bool
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double?
    let vwap: Double?
    let ema200: Double?
    let bollingerUpper: Double?
    let bollingerMiddle: Double?
    let bollingerLower: Double?

    var positive: Bool {
        close >= open
    }
}

struct ChartRenderableMarker: Identifiable, Equatable {
    let id: String
    let kind: TradingMarkerKind
    let timestamp: Date
    let price: Double
    let quantity: Double?
    let orderID: String?
    let title: String
}

struct ChartRenderableLevel: Identifiable, Equatable {
    let id: String
    let title: String
    let price: Double
    let offset: Double
}

struct ChartIndicatorPoint: Identifiable, Equatable {
    let id: String
    let date: Date
    let value: Double
    let segment: Int
}

struct RealTradingChartRenderModel: Equatable {
    let chart: TradingChart
    let candles: [ChartRenderableCandle]
    let markers: [ChartRenderableMarker]
    let levels: [ChartRenderableLevel]
    let hasVWAP: Bool
    let hasEMA200: Bool
    let hasBollinger: Bool
    let hasVolume: Bool
    let vwapSegments: [[ChartIndicatorPoint]]
    let ema200Segments: [[ChartIndicatorPoint]]
    let bollingerUpperSegments: [[ChartIndicatorPoint]]
    let bollingerMiddleSegments: [[ChartIndicatorPoint]]
    let bollingerLowerSegments: [[ChartIndicatorPoint]]
    let priceDomain: ClosedRange<Double>?

    static func make(chart: TradingChart) -> Self {
        let candles = chart.candles.map { candle in
            ChartRenderableCandle(
                id: candle.id,
                openTime: candle.openTime,
                closeTime: candle.closeTime,
                isClosed: candle.isClosed,
                open: dbl(candle.open),
                high: dbl(candle.high),
                low: dbl(candle.low),
                close: dbl(candle.close),
                volume: candle.volume.map(dbl),
                vwap: candle.vwap.map(dbl),
                ema200: candle.ema200.map(dbl),
                bollingerUpper: candle.bollingerUpper.map(dbl),
                bollingerMiddle: candle.bollingerMiddle.map(dbl),
                bollingerLower: candle.bollingerLower.map(dbl)
            )
        }
        let markers = chart.markers.map { marker in
            ChartRenderableMarker(
                id: marker.id,
                kind: marker.kind,
                timestamp: marker.timestamp,
                price: dbl(marker.price),
                quantity: marker.quantity.map(dbl),
                orderID: marker.orderID,
                title: marker.title
            )
        }
        let levels = TradingChartPresentation.renderableLevels(chart.levels)

        return Self(
            chart: chart,
            candles: candles,
            markers: markers,
            levels: levels,
            hasVWAP: candles.contains { $0.vwap != nil },
            hasEMA200: candles.contains { $0.ema200 != nil },
            hasBollinger: candles.contains { candle in
                candle.bollingerUpper != nil || candle.bollingerMiddle != nil || candle.bollingerLower != nil
            },
            hasVolume: candles.contains { $0.volume != nil },
            vwapSegments: TradingChartPresentation.continuousSegments(from: candles, value: \.vwap),
            ema200Segments: TradingChartPresentation.continuousSegments(from: candles, value: \.ema200),
            bollingerUpperSegments: TradingChartPresentation.continuousSegments(from: candles, value: \.bollingerUpper),
            bollingerMiddleSegments: TradingChartPresentation.continuousSegments(from: candles, value: \.bollingerMiddle),
            bollingerLowerSegments: TradingChartPresentation.continuousSegments(from: candles, value: \.bollingerLower),
            priceDomain: TradingChartPresentation.priceDomain(candles: candles, markers: markers, levels: levels)
        )
    }
}

private func dbl(_ decimal: Decimal) -> Double {
    NSDecimalNumber(decimal: decimal).doubleValue
}

enum TradingChartPresentation {
    static func nearestCandle(to date: Date, in candles: [ChartRenderableCandle]) -> ChartRenderableCandle? {
        guard var best = candles.first else {
            return nil
        }

        var bestDelta = abs(best.openTime.timeIntervalSince(date))
        for candle in candles.dropFirst() {
            let delta = abs(candle.openTime.timeIntervalSince(date))
            if delta < bestDelta {
                best = candle
                bestDelta = delta
            }
        }
        return best
    }

    static let priceChartHeight: CGFloat = 268
    static let volumeChartHeight: CGFloat = 72
    static let chartCardSpacing: CGFloat = 16

    static func candleWidth(availableWidth: CGFloat, candleCount: Int) -> CGFloat {
        guard candleCount > 0, availableWidth.isFinite, availableWidth > 0 else {
            return 3
        }
        let densityWidth = (availableWidth / CGFloat(candleCount)) * 0.58
        switch candleCount {
        case 0...20:
            return min(12, max(7, densityWidth))
        case 21...100:
            return min(7, max(3, densityWidth))
        case 101...350:
            return min(4, max(1.6, densityWidth))
        default:
            return min(2.4, max(1, densityWidth))
        }
    }

    static func volumeBarWidth(availableWidth: CGFloat, candleCount: Int) -> CGFloat {
        max(1, min(6, candleWidth(availableWidth: availableWidth, candleCount: candleCount) * 0.9))
    }

    static func xAxisDesiredCount(for range: TradingChartRange, candleCount: Int) -> Int {
        guard candleCount > 12 else { return 3 }
        switch range {
        case .oneHour:
            return 4
        case .sixHours:
            return 4
        case .oneDay:
            return 5
        case .sevenDays:
            return 4
        }
    }

    static func continuousSegments(
        from candles: [ChartRenderableCandle],
        value: (ChartRenderableCandle) -> Double?
    ) -> [[ChartIndicatorPoint]] {
        var segments: [[ChartIndicatorPoint]] = []
        var current: [ChartIndicatorPoint] = []
        var index = 0

        for candle in candles {
            if let raw = value(candle), raw.isFinite {
                current.append(
                    ChartIndicatorPoint(
                        id: "\(index)-\(candle.id)",
                        date: candle.openTime,
                        value: raw,
                        segment: index
                    )
                )
            } else if !current.isEmpty {
                segments.append(current)
                current = []
                index += 1
            }
        }

        if !current.isEmpty {
            segments.append(current)
        }
        return segments
    }

    static func priceDomain(
        candles: [ChartRenderableCandle],
        markers: [ChartRenderableMarker] = [],
        levels: [ChartRenderableLevel] = []
    ) -> ClosedRange<Double>? {
        var values = candles.flatMap { candle in
            [
                candle.low,
                candle.high,
                candle.vwap,
                candle.ema200,
                candle.bollingerUpper,
                candle.bollingerMiddle,
                candle.bollingerLower
            ].compactMap { $0 }
        }
        values += markers.map(\.price) + levels.map(\.price)
        values = values.filter(\.isFinite)

        guard let minValue = values.min(), let maxValue = values.max() else {
            return nil
        }

        let span = maxValue - minValue
        let margin = max(span * 0.06, max(abs(maxValue) * 0.001, 0.01))
        return (minValue - margin)...(maxValue + margin)
    }

    static func renderableLevels(_ levels: TradingLevels) -> [ChartRenderableLevel] {
        [
            ("entry", "Prix d’entrée", levels.entryPrice),
            ("breakEven", "Seuil de rentabilité", levels.breakEvenPrice),
            ("minimumExit", "Prix minimum rentable", levels.minimumProfitableExitPrice),
            ("trailingStop", "Trailing stop", levels.trailingStopPrice)
        ]
        .compactMap { id, title, value in
            value.flatMap { $0 == 0 ? nil : ChartRenderableLevel(id: id, title: title, price: dbl($0), offset: 0) }
        }
        .enumerated()
        .map { index, level in
            ChartRenderableLevel(
                id: level.id,
                title: level.title,
                price: level.price,
                offset: Double(index % 4) * 14
            )
        }
    }

    static func axisFormat(for range: TradingChartRange) -> Date.FormatStyle {
        switch range {
        case .oneHour, .sixHours:
            return Date.FormatStyle().hour().minute()
        case .oneDay:
            return Date.FormatStyle().hour()
        case .sevenDays:
            return Date.FormatStyle().weekday(.abbreviated).day()
        }
    }
}

struct RealTradingChartSection: View {
    let session: SessionDetail
    @Environment(RealSessionChartStore.self) private var store

    var body: some View {
        RealTradingChartView(
            state: store.state,
            selectedRange: store.selectedRange,
            select: { store.selectRange($0, sessionID: session.id) },
            refresh: { store.refresh(sessionID: session.id) }
        )
        .task(id: session.id) { store.load(sessionID: session.id) }
        .onDisappear { store.stop() }
        .refreshable { store.refresh(sessionID: session.id) }
    }
}

struct RealTradingChartView: View {
    let state: RealSessionChartState
    let selectedRange: TradingChartRange
    let select: (TradingChartRange) -> Void
    let refresh: () -> Void

    @State private var showVWAP = true
    @State private var showEMA200 = true
    @State private var showBollinger = false
    @State private var selected: ChartRenderableCandle?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: BotaplataSpacing.lg) {
                ChartRangeSelector(selected: selectedRange, select: select)
                content
            }
            .padding()
            .safeAreaPadding(.bottom, BotaplataSpacing.xxl)
        }
    }

    @ViewBuilder private var content: some View {
        switch state {
        case .idle, .loading:
            loadingContent
        case .failed(let error):
            PremiumErrorState(title: error.title, message: error.message)
        case .loaded(let chart), .refreshing(let chart), .offline(let chart):
            loadedContent(chart: chart)
        }
    }

    private var loadingContent: some View {
        VStack(alignment: .leading, spacing: BotaplataSpacing.md) {
            PremiumSkeletonCard()
            PremiumSkeletonCard()
        }
    }

    private func loadedContent(chart: TradingChart) -> some View {
        let model = RealTradingChartRenderModel.make(chart: chart)

        return VStack(alignment: .leading, spacing: BotaplataSpacing.md) {
            if case .offline = state {
                PremiumOfflineBanner()
            }

            if chart.candles.isEmpty {
                emptyContent(chart: chart)
            } else {
                chartContent(chart: chart, model: model)
            }
        }
    }

    private func emptyContent(chart: TradingChart) -> some View {
        VStack(alignment: .leading, spacing: BotaplataSpacing.md) {
            PremiumEmptyState(
                title: "Graphique en préparation",
                message: chart.warnings.first?.message ?? "Le serveur ne dispose pas encore d’un historique de prix suffisant pour afficher le graphique."
            )
            ForEach(chart.warnings) { warning in
                WarningBanner(warning: warning)
            }
        }
    }

    private func chartContent(chart: TradingChart, model: RealTradingChartRenderModel) -> some View {
        VStack(alignment: .leading, spacing: BotaplataSpacing.lg) {
            MarketSummary(chart: chart)
            PremiumCard {
                VStack(alignment: .leading, spacing: TradingChartPresentation.chartCardSpacing) {
                    Text("Graphique")
                        .font(BotaplataTypography.cardTitle)
                    IndicatorControls(
                        model: model,
                        showVWAP: $showVWAP,
                        showEMA200: $showEMA200,
                        showBollinger: $showBollinger
                    )
                    CandlestickChart(
                        model: model,
                        showVWAP: showVWAP,
                        showEMA200: showEMA200,
                        showBollinger: showBollinger,
                        selected: $selected
                    )
                    if model.hasVolume {
                        VolumeChart(candles: model.candles)
                    }
                    ChartLegend(
                        model: model,
                        showVWAP: showVWAP,
                        showEMA200: showEMA200,
                        showBollinger: showBollinger
                    )
                }
            }
            ChartLevelsSummary(levels: chart.levels, quote: chart.quoteAsset)
            ForEach(chart.warnings) { warning in
                WarningBanner(warning: warning)
            }
            Text("Dernière actualisation : \(HistoryPresentation.fullDate(chart.generatedAt))")
                .font(.caption)
                .foregroundStyle(BotaplataColors.textSecondary)
        }
    }
}

struct ChartRangeSelector: View {
    let selected: TradingChartRange
    let select: (TradingChartRange) -> Void

    var body: some View {
        HStack(spacing: BotaplataSpacing.sm) {
            ForEach(TradingChartRange.allCases, id: \.self) { range in
                Button(range.displayTitle) {
                    select(range)
                }
                .buttonStyle(.borderedProminent)
                .tint(range == selected ? BotaplataColors.primaryTeal : BotaplataColors.elevated)
                .accessibilityLabel(
                    "Période \(range.displayTitle), \(range == selected ? "sélectionnée" : "non sélectionnée")"
                )
            }
        }
    }
}

struct CandlestickChart: View {
    let model: RealTradingChartRenderModel
    let showVWAP: Bool
    let showEMA200: Bool
    let showBollinger: Bool
    @Binding var selected: ChartRenderableCandle?

    @State private var availableWidth: CGFloat = 0

    var body: some View {
        chart
            .frame(maxWidth: .infinity)
            .frame(height: TradingChartPresentation.priceChartHeight)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear { availableWidth = geometry.size.width }
                        .onChange(of: geometry.size.width) { _, newWidth in availableWidth = newWidth }
                }
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel(accessibilitySummary)
    }

    private var chart: some View {
        Chart {
            candlestickContent
            indicatorsContent
            markersContent
            levelsContent
            selectionContent
        }
        .chartYScale(domain: priceDomain)
        .chartXAxis { chartXAxis }
        .chartYAxis { chartYAxis }
        .chartPlotStyle { plotArea in
            plotArea
                .background(BotaplataColors.backgroundNavy.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: BotaplataRadius.sm, style: .continuous))
        }
        .chartOverlay { proxy in chartOverlayContent(proxy: proxy) }
        .overlay(alignment: tooltipAlignment) { tooltipContent }
    }

    @ChartContentBuilder private var candlestickContent: some Charts.ChartContent {
        ForEach(model.candles) { candle in
            RuleMark(
                x: .value("Date", candle.openTime),
                yStart: .value("Bas", candle.low),
                yEnd: .value("Haut", candle.high),
                width: .fixed(max(1, min(2, candleWidth * 0.35)))
            )
            .foregroundStyle(candleColor(for: candle))

            RectangleMark(
                x: .value("Date", candle.openTime),
                yStart: .value("Ouverture", candle.open),
                yEnd: .value("Clôture", candle.close),
                width: .fixed(candleWidth)
            )
            .foregroundStyle(candleColor(for: candle))
            .opacity(candle.isClosed ? 1 : 0.55)
            .accessibilityLabel(candleAccessibilityLabel(candle))
        }
    }

    @ChartContentBuilder private var indicatorsContent: some Charts.ChartContent {
        indicatorContent(
            isVisible: showVWAP,
            segments: model.vwapSegments,
            label: "VWAP",
            color: BotaplataColors.accentCyan
        )
        indicatorContent(
            isVisible: showEMA200,
            segments: model.ema200Segments,
            label: "EMA200",
            color: BotaplataColors.warning
        )
        indicatorContent(
            isVisible: showBollinger,
            segments: model.bollingerUpperSegments,
            label: "Bollinger haute",
            color: BotaplataColors.textMuted
        )
        indicatorContent(
            isVisible: showBollinger,
            segments: model.bollingerMiddleSegments,
            label: "Bollinger centrale",
            color: BotaplataColors.textSecondary
        )
        indicatorContent(
            isVisible: showBollinger,
            segments: model.bollingerLowerSegments,
            label: "Bollinger basse",
            color: BotaplataColors.textMuted
        )
    }

    @ChartContentBuilder private func indicatorContent(
        isVisible: Bool,
        segments: [[ChartIndicatorPoint]],
        label: String,
        color: Color
    ) -> some Charts.ChartContent {
        if isVisible {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                ForEach(segment) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value(label, point.value),
                        series: .value("Segment", point.segment)
                    )
                    .foregroundStyle(color)
                }
            }
        }
    }

    @ChartContentBuilder private var markersContent: some Charts.ChartContent {
        ForEach(model.markers) { marker in
            PointMark(
                x: .value("Date", marker.timestamp),
                y: .value("Prix", marker.price)
            )
            .symbol { Image(systemName: markerSymbol(for: marker.kind)) }
            .foregroundStyle(markerColor(for: marker.kind))
            .accessibilityLabel(markerAccessibilityLabel(marker))
        }
    }

    @ChartContentBuilder private var levelsContent: some Charts.ChartContent {
        ForEach(model.levels) { level in
            RuleMark(y: .value(level.title, level.price))
                .foregroundStyle(BotaplataColors.accentCyan.opacity(0.55))
                .annotation(position: .overlay, alignment: .leading) {
                    ChartLevelAnnotation(level: level)
                }
                .accessibilityLabel("Niveau \(level.title), \(level.price)")
        }
    }

    @ChartContentBuilder private var selectionContent: some Charts.ChartContent {
        if let selected {
            RuleMark(x: .value("Sélection", selected.openTime))
                .foregroundStyle(BotaplataColors.textPrimary)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))

            PointMark(
                x: .value("Date", selected.openTime),
                y: .value("Clôture", selected.close)
            )
            .foregroundStyle(BotaplataColors.textPrimary)
        }
    }

    @AxisContentBuilder private var chartXAxis: some AxisContent {
        AxisMarks(values: .automatic(desiredCount: TradingChartPresentation.xAxisDesiredCount(for: model.chart.range, candleCount: model.candles.count))) {
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
            AxisTick(stroke: StrokeStyle(lineWidth: 0.5))
            AxisValueLabel(format: TradingChartPresentation.axisFormat(for: model.chart.range), centered: false)
                .font(.caption2)
                .foregroundStyle(BotaplataColors.textSecondary)
        }
    }

    @AxisContentBuilder private var chartYAxis: some AxisContent {
        AxisMarks(position: .trailing, values: .automatic(desiredCount: 5)) {
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
            AxisTick(stroke: StrokeStyle(lineWidth: 0.5))
            AxisValueLabel()
                .font(.caption2)
                .foregroundStyle(BotaplataColors.textSecondary)
        }
    }

    private var candleWidth: CGFloat {
        TradingChartPresentation.candleWidth(
            availableWidth: availableWidth,
            candleCount: model.candles.count
        )
    }

    private var priceDomain: ClosedRange<Double> {
        model.priceDomain ?? fallbackPriceDomain
    }

    private var fallbackPriceDomain: ClosedRange<Double> {
        guard let close = model.candles.last?.close else {
            return 0...1
        }
        let margin = max(abs(close) * 0.01, 0.01)
        return (close - margin)...(close + margin)
    }

    private var tooltipAlignment: Alignment {
        let midpoint = model.candles[safe: model.candles.count / 2]?.openTime ?? .distantPast
        let selectedTime = selected?.openTime ?? .distantPast
        return selectedTime < midpoint ? .topTrailing : .topLeading
    }

    @ViewBuilder private var tooltipContent: some View {
        if let selected {
            ChartTooltip(candle: selected, quoteAsset: model.chart.quoteAsset)
                .frame(maxWidth: min(260, availableWidth * 0.75))
                .padding(8)
        }
    }

    private var accessibilitySummary: String {
        let high = model.candles.map(\.high).max() ?? 0
        let low = model.candles.map(\.low).min() ?? 0
        let last = model.candles.last?.close ?? 0
        return "Graphique \(model.chart.displaySymbol) sur \(model.chart.range.displayTitle). \(model.candles.count) bougies. Dernier prix \(last) \(model.chart.quoteAsset). Plus haut \(high). Plus bas \(low)."
    }

    private func candleColor(for candle: ChartRenderableCandle) -> Color {
        candle.positive ? BotaplataColors.success : BotaplataColors.danger
    }

    private func candleAccessibilityLabel(_ candle: ChartRenderableCandle) -> String {
        "Bougie \(candle.isClosed ? "clôturée" : "ouverte") ouverture \(candle.open) haut \(candle.high) bas \(candle.low) clôture \(candle.close)"
    }

    private func markerSymbol(for kind: TradingMarkerKind) -> String {
        switch kind {
        case .buy:
            return "arrow.up.circle.fill"
        case .sell:
            return "arrow.down.circle.fill"
        case .partialBuy:
            return "arrow.up.right.circle.fill"
        case .partialSell:
            return "arrow.down.right.circle.fill"
        }
    }

    private func markerColor(for kind: TradingMarkerKind) -> Color {
        switch kind {
        case .buy, .partialBuy:
            return BotaplataColors.success
        case .sell, .partialSell:
            return BotaplataColors.danger
        }
    }

    private func markerAccessibilityLabel(_ marker: ChartRenderableMarker) -> String {
        "Marqueur \(marker.title) prix \(marker.price)"
    }

    private func chartOverlayContent(proxy: ChartProxy) -> some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(.clear)
                .contentShape(Rectangle())
                .gesture(selectionGesture(proxy: proxy, geometry: geometry))
        }
    }

    private func selectionGesture(proxy: ChartProxy, geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard let plotFrame = proxy.plotFrame else {
                    selected = nil
                    return
                }

                let origin = geometry[plotFrame].origin
                let xPosition = value.location.x - origin.x

                guard let date: Date = proxy.value(atX: xPosition) else {
                    selected = nil
                    return
                }

                selected = TradingChartPresentation.nearestCandle(
                    to: date,
                    in: model.candles
                )
            }
            .onEnded { _ in
                selected = nil
            }
    }
}

struct ChartLevelAnnotation: View {
    let level: ChartRenderableLevel

    var body: some View {
        Text(level.title)
            .font(.caption2)
            .padding(.vertical, 2)
            .foregroundStyle(BotaplataColors.textSecondary)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct VolumeChart: View {
    let candles: [ChartRenderableCandle]

    @State private var availableWidth: CGFloat = 0

    var body: some View {
        Chart(candles.compactMap { $0.volume == nil ? nil : $0 }) { candle in
            BarMark(
                x: .value("Date", candle.openTime),
                y: .value("Volume", candle.volume ?? 0),
                width: .fixed(TradingChartPresentation.volumeBarWidth(availableWidth: availableWidth, candleCount: candles.count))
            )
            .foregroundStyle(BotaplataColors.accentCyan.opacity(0.55))
        }
        .chartYAxis(.hidden)
        .chartXAxis(.hidden)
        .frame(maxWidth: .infinity)
        .frame(height: TradingChartPresentation.volumeChartHeight)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear { availableWidth = geometry.size.width }
                    .onChange(of: geometry.size.width) { _, newWidth in availableWidth = newWidth }
            }
        )
        .accessibilityLabel("Volume des bougies")
    }
}

struct IndicatorControls: View {
    let model: RealTradingChartRenderModel
    @Binding var showVWAP: Bool
    @Binding var showEMA200: Bool
    @Binding var showBollinger: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: BotaplataSpacing.sm) {
            if model.hasVWAP {
                Toggle("VWAP", isOn: $showVWAP)
            }
            if model.hasEMA200 {
                Toggle("EMA200", isOn: $showEMA200)
            }
            if model.hasBollinger {
                Toggle("Bollinger", isOn: $showBollinger)
            }
        }
        .font(.caption)
    }
}

struct MarketSummary: View {
    let chart: TradingChart

    var body: some View {
        PremiumCard {
            VStack(alignment: .leading) {
                Text("Résumé du marché")
                    .font(BotaplataTypography.cardTitle)
                PremiumKeyValueRow(
                    label: "Dernier prix",
                    value: FinancialFormatters.decimal(chart.candles.last?.close, suffix: chart.quoteAsset)
                )
                PremiumKeyValueRow(
                    label: "Plus haut",
                    value: FinancialFormatters.decimal(chart.candles.map(\.high).max(), suffix: chart.quoteAsset)
                )
                PremiumKeyValueRow(
                    label: "Plus bas",
                    value: FinancialFormatters.decimal(chart.candles.map(\.low).min(), suffix: chart.quoteAsset)
                )
                PremiumKeyValueRow(label: "Timeframe", value: chart.timeframe)
                PremiumKeyValueRow(label: "Bougies", value: String(chart.candles.count))
            }
        }
    }
}

struct ChartTooltip: View {
    let candle: ChartRenderableCandle
    let quoteAsset: String

    var body: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(candle.openTime.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption.weight(.semibold))
                valueRow("Ouverture", value: candle.open, suffix: quoteAsset)
                valueRow("Plus haut", value: candle.high, suffix: quoteAsset)
                valueRow("Plus bas", value: candle.low, suffix: quoteAsset)
                valueRow("Clôture", value: candle.close, suffix: quoteAsset)
                valueRow("Volume", value: candle.volume, suffix: nil)
                valueRow("VWAP", value: candle.vwap, suffix: quoteAsset)
                valueRow("EMA200", value: candle.ema200, suffix: quoteAsset)
                valueRow("Bollinger haute", value: candle.bollingerUpper, suffix: quoteAsset)
                valueRow("Bollinger milieu", value: candle.bollingerMiddle, suffix: quoteAsset)
                valueRow("Bollinger basse", value: candle.bollingerLower, suffix: quoteAsset)
                Text(candle.isClosed ? "Bougie clôturée" : "Bougie ouverte")
                    .font(.caption2)
            }
            .font(.caption)
            .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Bougie sélectionnée ouverture \(candle.open), haut \(candle.high), bas \(candle.low), clôture \(candle.close), \(candle.isClosed ? "clôturée" : "ouverte")"
        )
    }

    @ViewBuilder private func valueRow(
        _ label: String,
        value: Double?,
        suffix: String?
    ) -> some View {
        if let value {
            HStack {
                Text(label)
                Spacer()
                Text(rowText(value: value, suffix: suffix))
            }
        }
    }

    private func rowText(value: Double, suffix: String?) -> String {
        if let suffix, !suffix.isEmpty {
            return "\(value) \(suffix)"
        }
        return "\(value)"
    }
}

struct ChartLevelsSummary: View {
    let levels: TradingLevels
    let quote: String

    var body: some View {
        PremiumCard {
            VStack(alignment: .leading) {
                Text("Niveaux financiers")
                    .font(BotaplataTypography.cardTitle)
                row("Prix d’entrée", levels.entryPrice)
                row("Seuil de rentabilité", levels.breakEvenPrice)
                row("Prix minimum rentable", levels.minimumProfitableExitPrice)
                row("Trailing stop", levels.trailingStopPrice)
            }
        }
    }

    private func row(_ title: String, _ value: Decimal?) -> some View {
        PremiumKeyValueRow(label: title, value: FinancialFormatters.decimal(value, suffix: quote))
    }
}

struct ChartLegend: View {
    let model: RealTradingChartRenderModel
    let showVWAP: Bool
    let showEMA200: Bool
    let showBollinger: Bool

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: BotaplataSpacing.xs)], alignment: .leading, spacing: BotaplataSpacing.xs) {
            ForEach(legendItems, id: \.self) { item in
                Text(item)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(BotaplataColors.textSecondary)
                    .background(BotaplataColors.cardGlass.opacity(0.7), in: Capsule())
            }
        }
    }

    private var legendItems: [String] {
        var parts = ["Hausse", "Baisse", "Bougie ouverte"]
        if !model.markers.isEmpty {
            parts.append("Achats/Ventes")
        }
        if !model.levels.isEmpty {
            parts.append("Niveaux")
        }
        if model.hasVWAP && showVWAP {
            parts.append("VWAP")
        }
        if model.hasEMA200 && showEMA200 {
            parts.append("EMA200")
        }
        if model.hasBollinger && showBollinger {
            parts.append("Bollinger")
        }
        return parts
    }
}

extension FinancialFormatters {
    static func decimal(_ value: Decimal?, suffix: String) -> String {
        guard let value else {
            return "—"
        }
        return "\(NSDecimalNumber(decimal: value).stringValue) \(suffix)"
    }
}

#if DEBUG
private extension TradingChart {
    func withPreviewCandles(count: Int, range: TradingChartRange, levels: TradingLevels? = nil) -> TradingChart {
        let base = generatedAt.addingTimeInterval(-Double(count * 300))
        let candles = (0..<count).map { i -> TradingCandle in
            let open = Decimal(string: "74")! + Decimal(i) / Decimal(80)
            let close = open + (i % 2 == 0 ? Decimal(string: "0.08")! : Decimal(string: "-0.06")!)
            return TradingCandle(
                id: "preview-\(range.rawValue)-\(i)",
                openTime: base.addingTimeInterval(Double(i * 300)),
                closeTime: base.addingTimeInterval(Double((i + 1) * 300)),
                isClosed: i != count - 1,
                open: open,
                high: max(open, close) + Decimal(string: "0.14")!,
                low: min(open, close) - Decimal(string: "0.12")!,
                close: close,
                volume: Decimal(90 + (i % 20)),
                vwap: open + Decimal(string: "0.03")!,
                ema200: open - Decimal(string: "0.08")!,
                bollingerUpper: open + Decimal(string: "0.35")!,
                bollingerMiddle: open,
                bollingerLower: open - Decimal(string: "0.35")!
            )
        }
        return TradingChart(
            sessionID: sessionID,
            symbol: symbol,
            displaySymbol: displaySymbol,
            quoteAsset: quoteAsset,
            range: range,
            timeframe: "5m",
            generatedAt: generatedAt,
            dataSource: dataSource,
            isComplete: isComplete,
            hasMore: hasMore,
            nextBefore: nextBefore,
            candles: candles,
            markers: markers,
            levels: levels ?? self.levels,
            warnings: warnings
        )
    }
}

#Preview("Graphique réel 1h / 11 bougies") {
    RealTradingChartView(state: .loaded(PreviewFixtures.tradingChart(range: .oneHour).withPreviewCandles(count: 11, range: .oneHour, levels: TradingLevels(entryPrice: nil, breakEvenPrice: nil, minimumProfitableExitPrice: nil, trailingStopPrice: nil))), selectedRange: .oneHour, select: { _ in }, refresh: {})
}

#Preview("Graphique réel 6h / 71 bougies") {
    RealTradingChartView(state: .loaded(PreviewFixtures.tradingChart(range: .sixHours).withPreviewCandles(count: 71, range: .sixHours, levels: TradingLevels(entryPrice: nil, breakEvenPrice: nil, minimumProfitableExitPrice: nil, trailingStopPrice: nil))), selectedRange: .sixHours, select: { _ in }, refresh: {})
}

#Preview("Graphique réel 24h / 287 bougies") {
    RealTradingChartView(state: .loaded(PreviewFixtures.tradingChart(range: .oneDay).withPreviewCandles(count: 287, range: .oneDay, levels: TradingLevels(entryPrice: nil, breakEvenPrice: nil, minimumProfitableExitPrice: nil, trailingStopPrice: nil))), selectedRange: .oneDay, select: { _ in }, refresh: {})
}

#Preview("Graphique réel 7j / 672 bougies") {
    RealTradingChartView(state: .loaded(PreviewFixtures.tradingChart(range: .sevenDays).withPreviewCandles(count: 672, range: .sevenDays)), selectedRange: .sevenDays, select: { _ in }, refresh: {})
}
#endif
