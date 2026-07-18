import SwiftUI
import Charts

struct ChartRenderableCandle: Identifiable, Equatable { let id: String; let openTime: Date; let closeTime: Date; let isClosed: Bool; let open: Double; let high: Double; let low: Double; let close: Double; let volume: Double?; let vwap: Double?; let ema200: Double?; let bollingerUpper: Double?; let bollingerMiddle: Double?; let bollingerLower: Double?; var positive: Bool { close >= open } }
struct ChartRenderableMarker: Identifiable, Equatable { let id: String; let kind: TradingMarkerKind; let timestamp: Date; let price: Double; let quantity: Double?; let orderID: String?; let title: String }
struct ChartRenderableLevel: Identifiable, Equatable { let id: String; let title: String; let price: Double; let offset: Double }
struct ChartIndicatorPoint: Identifiable, Equatable { let id: String; let date: Date; let value: Double; let segment: Int }
struct RealTradingChartRenderModel: Equatable { let chart: TradingChart; let candles: [ChartRenderableCandle]; let markers: [ChartRenderableMarker]; let levels: [ChartRenderableLevel]; let hasVWAP: Bool; let hasEMA200: Bool; let hasBollinger: Bool; let hasVolume: Bool; let vwapSegments: [[ChartIndicatorPoint]]; let ema200Segments: [[ChartIndicatorPoint]]; let bollingerUpperSegments: [[ChartIndicatorPoint]]; let bollingerMiddleSegments: [[ChartIndicatorPoint]]; let bollingerLowerSegments: [[ChartIndicatorPoint]]; let priceDomain: ClosedRange<Double>?; static func make(chart: TradingChart) -> Self { let cs = chart.candles.map { ChartRenderableCandle(id: $0.id, openTime: $0.openTime, closeTime: $0.closeTime, isClosed: $0.isClosed, open: dbl($0.open), high: dbl($0.high), low: dbl($0.low), close: dbl($0.close), volume: $0.volume.map(dbl), vwap: $0.vwap.map(dbl), ema200: $0.ema200.map(dbl), bollingerUpper: $0.bollingerUpper.map(dbl), bollingerMiddle: $0.bollingerMiddle.map(dbl), bollingerLower: $0.bollingerLower.map(dbl)) }; let ms = chart.markers.map { ChartRenderableMarker(id: $0.id, kind: $0.kind, timestamp: $0.timestamp, price: dbl($0.price), quantity: $0.quantity.map(dbl), orderID: $0.orderID, title: $0.title) }; let ls = TradingChartPresentation.renderableLevels(chart.levels); return .init(chart: chart, candles: cs, markers: ms, levels: ls, hasVWAP: cs.contains { $0.vwap != nil }, hasEMA200: cs.contains { $0.ema200 != nil }, hasBollinger: cs.contains { $0.bollingerUpper != nil || $0.bollingerMiddle != nil || $0.bollingerLower != nil }, hasVolume: cs.contains { $0.volume != nil }, vwapSegments: TradingChartPresentation.continuousSegments(from: cs, value: \.vwap), ema200Segments: TradingChartPresentation.continuousSegments(from: cs, value: \.ema200), bollingerUpperSegments: TradingChartPresentation.continuousSegments(from: cs, value: \.bollingerUpper), bollingerMiddleSegments: TradingChartPresentation.continuousSegments(from: cs, value: \.bollingerMiddle), bollingerLowerSegments: TradingChartPresentation.continuousSegments(from: cs, value: \.bollingerLower), priceDomain: TradingChartPresentation.priceDomain(candles: cs, markers: ms, levels: ls)) } }
private func dbl(_ d: Decimal) -> Double { NSDecimalNumber(decimal: d).doubleValue }

enum TradingChartPresentation { static func nearestCandle(to date: Date, in candles: [ChartRenderableCandle]) -> ChartRenderableCandle? { guard var best = candles.first else { return nil }; var bestDelta = abs(best.openTime.timeIntervalSince(date)); for candle in candles.dropFirst() { let delta = abs(candle.openTime.timeIntervalSince(date)); if delta < bestDelta { best = candle; bestDelta = delta } }; return best }
    static func candleWidth(availableWidth: CGFloat, candleCount: Int) -> CGFloat { guard candleCount > 0, availableWidth.isFinite, availableWidth > 0 else { return 3 }; return min(10, max(2, (availableWidth / CGFloat(candleCount)) * 0.55)) }
    static func continuousSegments(from candles: [ChartRenderableCandle], value: (ChartRenderableCandle) -> Double?) -> [[ChartIndicatorPoint]] { var segments: [[ChartIndicatorPoint]] = []; var current: [ChartIndicatorPoint] = []; var index = 0; for candle in candles { if let raw = value(candle), raw.isFinite { current.append(.init(id: "\(index)-\(candle.id)", date: candle.openTime, value: raw, segment: index)) } else if !current.isEmpty { segments.append(current); current = []; index += 1 } }; if !current.isEmpty { segments.append(current) }; return segments }
    static func priceDomain(candles: [ChartRenderableCandle], markers: [ChartRenderableMarker] = [], levels: [ChartRenderableLevel] = []) -> ClosedRange<Double>? { var values = candles.flatMap { [$0.low, $0.high, $0.vwap, $0.ema200, $0.bollingerUpper, $0.bollingerMiddle, $0.bollingerLower].compactMap { $0 } }; values += markers.map(\.price) + levels.map(\.price); values = values.filter(\.isFinite); guard let minValue = values.min(), let maxValue = values.max() else { return nil }; let span = maxValue - minValue; let margin = max(span * 0.06, max(abs(maxValue) * 0.001, 0.01)); return (minValue - margin)...(maxValue + margin) }
    static func renderableLevels(_ levels: TradingLevels) -> [ChartRenderableLevel] { [("entry", "Prix d’entrée", levels.entryPrice), ("breakEven", "Seuil de rentabilité", levels.breakEvenPrice), ("minimumExit", "Prix minimum rentable", levels.minimumProfitableExitPrice), ("trailingStop", "Trailing stop", levels.trailingStopPrice)].compactMap { id, title, value in value.map { ChartRenderableLevel(id: id, title: title, price: dbl($0), offset: 0) } }.enumerated().map { idx, level in ChartRenderableLevel(id: level.id, title: level.title, price: level.price, offset: Double(idx % 4) * 14) } }
    static func axisFormat(for range: TradingChartRange) -> Date.FormatStyle { switch range { case .oneHour, .sixHours: return Date.FormatStyle().hour().minute(); case .oneDay: return Date.FormatStyle().hour(); case .sevenDays: return Date.FormatStyle().weekday(.abbreviated).day() } }
}

struct RealTradingChartSection: View { let session: SessionDetail; @Environment(RealSessionChartStore.self) private var store; var body: some View { RealTradingChartView(state: store.state, selectedRange: store.selectedRange, select: { store.selectRange($0, sessionID: session.id) }, refresh: { store.refresh(sessionID: session.id) }).task(id: session.id) { store.load(sessionID: session.id) }.onDisappear { store.stop() }.refreshable { store.refresh(sessionID: session.id) } } }

struct RealTradingChartView: View { let state: RealSessionChartState; let selectedRange: TradingChartRange; let select: (TradingChartRange) -> Void; let refresh: () -> Void; @State private var showVWAP = true; @State private var showEMA200 = true; @State private var showBollinger = false; @State private var selected: ChartRenderableCandle?
    var body: some View { ScrollView { LazyVStack(alignment: .leading, spacing: BotaplataSpacing.md) { ChartRangeSelector(selected: selectedRange, select: select); content }.padding() } }
    
    @ViewBuilder private var content: some View {
        switch state {
        case .idle, .loading:
            VStack(alignment: .leading, spacing: BotaplataSpacing.md) {
                PremiumSkeletonCard()
                PremiumSkeletonCard()
            }
        case .failed(let e):
            PremiumErrorState(title: e.title, message: e.message)
        case .loaded(let c), .refreshing(let c), .offline(let c):
            let m = RealTradingChartRenderModel.make(chart: c)
            VStack(alignment: .leading, spacing: BotaplataSpacing.md) {
                if case .offline = state {
                    PremiumOfflineBanner()
                }
                if c.candles.isEmpty {
                    PremiumEmptyState(
                        title: "Graphique en préparation",
                        message: c.warnings.first?.message ?? "Le serveur ne dispose pas encore d’un historique de prix suffisant pour afficher le graphique."
                    )
                    ForEach(c.warnings) { WarningBanner(warning: $0) }
                } else {
                    MarketSummary(chart: c)
                    IndicatorControls(model: m, showVWAP: $showVWAP, showEMA200: $showEMA200, showBollinger: $showBollinger)
                    CandlestickChart(model: m, showVWAP: showVWAP, showEMA200: showEMA200, showBollinger: showBollinger, selected: $selected)
                    if m.hasVolume { VolumeChart(candles: m.candles) }
                    ChartLevelsSummary(levels: c.levels, quote: c.quoteAsset)
                    ChartLegend(model: m, showVWAP: showVWAP, showEMA200: showEMA200, showBollinger: showBollinger)
                    ForEach(c.warnings) { WarningBanner(warning: $0) }
                    Text("Dernière actualisation : \(HistoryPresentation.fullDate(c.generatedAt))")
                        .font(.caption)
                        .foregroundStyle(BotaplataColors.textSecondary)
                }
            }
        }
    }
}
struct ChartRangeSelector: View { let selected: TradingChartRange; let select: (TradingChartRange) -> Void; var body: some View { HStack { ForEach(TradingChartRange.allCases, id: \.self) { r in Button(r.displayTitle) { select(r) }.buttonStyle(.borderedProminent).tint(r == selected ? BotaplataColors.primaryTeal : BotaplataColors.elevated).accessibilityLabel("Période \(r.displayTitle), \(r == selected ? "sélectionnée" : "non sélectionnée")") } } } }
struct CandlestickChart: View { let model: RealTradingChartRenderModel; let showVWAP: Bool; let showEMA200: Bool; let showBollinger: Bool; @Binding var selected: ChartRenderableCandle?; var body: some View { PremiumCard { GeometryReader { outer in Chart { ForEach(model.candles) { c in RuleMark(x: .value("Date", c.openTime), yStart: .value("Bas", c.low), yEnd: .value("Haut", c.high)).foregroundStyle(c.positive ? BotaplataColors.success : BotaplataColors.danger); RectangleMark(x: .value("Date", c.openTime), yStart: .value("Ouverture", c.open), yEnd: .value("Clôture", c.close), width: .fixed(TradingChartPresentation.candleWidth(availableWidth: outer.size.width, candleCount: model.candles.count))).foregroundStyle(c.positive ? BotaplataColors.success : BotaplataColors.danger).opacity(c.isClosed ? 1 : 0.55).accessibilityLabel("Bougie \(c.isClosed ? "clôturée" : "ouverte") ouverture \(c.open) haut \(c.high) bas \(c.low) clôture \(c.close)") }
                indicator(showVWAP, model.vwapSegments, "VWAP", BotaplataColors.accentCyan); indicator(showEMA200, model.ema200Segments, "EMA200", BotaplataColors.warning); indicator(showBollinger, model.bollingerUpperSegments, "Bollinger haute", BotaplataColors.textMuted); indicator(showBollinger, model.bollingerMiddleSegments, "Bollinger centrale", BotaplataColors.textSecondary); indicator(showBollinger, model.bollingerLowerSegments, "Bollinger basse", BotaplataColors.textMuted); ForEach(model.markers) { m in PointMark(x: .value("Date", m.timestamp), y: .value("Prix", m.price)).symbol { Image(systemName: m.kind == .sell || m.kind == .partialSell ? "arrow.down.circle.fill" : "arrow.up.circle.fill") }.foregroundStyle(m.kind == .sell || m.kind == .partialSell ? BotaplataColors.danger : BotaplataColors.success).accessibilityLabel("Marqueur \(m.title) prix \(m.price)") }; ForEach(model.levels) { l in RuleMark(y: .value(l.title, l.price)).foregroundStyle(BotaplataColors.accentCyan.opacity(0.55)).annotation(position: .top, alignment: .leading) { Text(l.title).font(.caption2).offset(y: l.offset).foregroundStyle(BotaplataColors.textSecondary) }.accessibilityLabel("Niveau \(l.title) \(l.price)") }; if let selected { RuleMark(x: .value("Sélection", selected.openTime)).foregroundStyle(BotaplataColors.textPrimary).lineStyle(.init(lineWidth: 1, dash: [4])); PointMark(x: .value("Date", selected.openTime), y: .value("Clôture", selected.close)).foregroundStyle(BotaplataColors.textPrimary) } }.chartYScale(domain: model.priceDomain ?? 0...1).chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) { AxisGridLine(); AxisTick(); AxisValueLabel(format: TradingChartPresentation.axisFormat(for: model.chart.range)) } }.chartOverlay { proxy in GeometryReader { geo in Rectangle().fill(.clear).contentShape(Rectangle()).gesture(DragGesture(minimumDistance: 0).onChanged { value in let origin = geo[proxy.plotAreaFrame].origin; let x = value.location.x - origin.x; if let date: Date = proxy.value(atX: x) { selected = TradingChartPresentation.nearestCandle(to: date, in: model.candles) } }.onEnded { _ in selected = nil }) } }.overlay(alignment: selected?.openTime ?? .distantPast < (model.candles[safe: model.candles.count / 2]?.openTime ?? .distantPast) ? .topTrailing : .topLeading) { if let selected { ChartTooltip(candle: selected, quote: model.chart.quoteAsset).frame(maxWidth: min(260, outer.size.width * 0.75)).padding(8) } }.frame(height: 300).accessibilityElement(children: .contain).accessibilityLabel(accessibilitySummary(model: model)) } } }
    @ChartContentBuilder
    private func indicator(_ visible: Bool, _ segments: [[ChartIndicatorPoint]], _ label: String, _ color: Color) -> some ChartContent {
        if visible {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                ForEach(segment) { p in
                    LineMark(
                        x: .value("Date", p.date),
                        y: .value(label, p.value),
                        series: .value("Segment", p.segment)
                    )
                    .foregroundStyle(color)
                }
            }
        } else {
            // Explicitly emit empty chart content so the builder has a value for all branches
            Group {}
        }
    }
    private func accessibilitySummary(model: RealTradingChartRenderModel) -> String { let high = model.candles.map(\.high).max() ?? 0; let low = model.candles.map(\.low).min() ?? 0; let last = model.candles.last?.close ?? 0; return "Graphique \(model.chart.displaySymbol) sur \(model.chart.range.displayTitle). \(model.candles.count) bougies. Dernier prix \(last) \(model.chart.quoteAsset). Plus haut \(high). Plus bas \(low)." }
}
extension Array { subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil } }
struct VolumeChart: View { let candles: [ChartRenderableCandle]; var body: some View { PremiumCard { Chart(candles.compactMap { $0.volume == nil ? nil : $0 }) { BarMark(x: .value("Date", $0.openTime), y: .value("Volume", $0.volume ?? 0)).foregroundStyle(BotaplataColors.accentCyan.opacity(0.55)) }.frame(height: 80) } } }
struct IndicatorControls: View { let model: RealTradingChartRenderModel; @Binding var showVWAP: Bool; @Binding var showEMA200: Bool; @Binding var showBollinger: Bool; var body: some View { HStack { if model.hasVWAP { Toggle("VWAP", isOn: $showVWAP) }; if model.hasEMA200 { Toggle("EMA200", isOn: $showEMA200) }; if model.hasBollinger { Toggle("Bollinger", isOn: $showBollinger) } }.font(.caption) } }
struct MarketSummary: View { let chart: TradingChart; var body: some View { PremiumCard { VStack(alignment: .leading) { Text("Résumé du marché").font(BotaplataTypography.cardTitle); PremiumKeyValueRow(label: "Dernier prix", value: FinancialFormatters.decimal(chart.candles.last?.close, suffix: chart.quoteAsset)); PremiumKeyValueRow(label: "Plus haut", value: FinancialFormatters.decimal(chart.candles.map(\.high).max(), suffix: chart.quoteAsset)); PremiumKeyValueRow(label: "Plus bas", value: FinancialFormatters.decimal(chart.candles.map(\.low).min(), suffix: chart.quoteAsset)); PremiumKeyValueRow(label: "Timeframe", value: chart.timeframe); PremiumKeyValueRow(label: "Bougies", value: String(chart.candles.count)) } } } }
struct ChartTooltip: View { let candle: ChartRenderableCandle; let quote: String; var body: some View { PremiumCard { VStack(alignment: .leading, spacing: 4) { Text(candle.openTime.formatted(date: .abbreviated, time: .shortened)).font(.caption.weight(.semibold)); row("Ouverture", candle.open); row("Plus haut", candle.high); row("Plus bas", candle.low); row("Clôture", candle.close); if let v = candle.volume { row("Volume", v, suffix: "") }; if let v = candle.vwap { row("VWAP", v) }; if let v = candle.ema200 { row("EMA200", v) }; if let v = candle.bollingerUpper { row("Bollinger haute", v) }; if let v = candle.bollingerMiddle { row("Bollinger milieu", v) }; if let v = candle.bollingerLower { row("Bollinger basse", v) }; Text(candle.isClosed ? "Bougie clôturée" : "Bougie ouverte").font(.caption2) }.font(.caption).monospacedDigit() }.accessibilityElement(children: .combine).accessibilityLabel("Bougie sélectionnée ouverture \(candle.open), haut \(candle.high), bas \(candle.low), clôture \(candle.close), \(candle.isClosed ? "clôturée" : "ouverte")") }
    private func row(_ label: String, _ value: Double, suffix: String? = nil) -> some View { HStack { Text(label); Spacer(); Text("\(value) \(suffix ?? quote)") } } }
struct ChartLevelsSummary: View { let levels: TradingLevels; let quote: String; var body: some View { PremiumCard { VStack(alignment: .leading) { Text("Niveaux financiers").font(BotaplataTypography.cardTitle); row("Prix d’entrée", levels.entryPrice); row("Seuil de rentabilité", levels.breakEvenPrice); row("Prix minimum rentable", levels.minimumProfitableExitPrice); row("Trailing stop", levels.trailingStopPrice) } } }
    private func row(_ t: String, _ v: Decimal?) -> some View { PremiumKeyValueRow(label: t, value: FinancialFormatters.decimal(v, suffix: quote)) } }
struct ChartLegend: View { let model: RealTradingChartRenderModel; let showVWAP: Bool; let showEMA200: Bool; let showBollinger: Bool; var body: some View { Text("Légende : hausse/baisse, bougie ouverte, marqueurs backend, niveaux persistés\(model.hasVWAP && showVWAP ? ", VWAP" : "")\(model.hasEMA200 && showEMA200 ? ", EMA200" : "")\(model.hasBollinger && showBollinger ? ", Bollinger" : "").").font(.caption).foregroundStyle(BotaplataColors.textSecondary) } }
extension FinancialFormatters { static func decimal(_ value: Decimal?, suffix: String) -> String { guard let value else { return "—" }; return "\(NSDecimalNumber(decimal: value).stringValue) \(suffix)" } }

