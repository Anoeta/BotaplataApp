import SwiftUI
import Charts

/// Reuses the existing candlestick renderer in a compact, native dashboard composition.
struct PremiumCandlestickPanel: View {
    let chart: TradingChart
    let currentPrice: MoneyAmount?
    @State private var selected: ChartRenderableCandle?
    @State private var showVWAP = true
    @State private var showEMA200 = true
    @State private var showBollinger = false
    private let model: RealTradingChartRenderModel
    init(chart: TradingChart, currentPrice: MoneyAmount?) {
        self.chart = chart; self.currentPrice = currentPrice
        self.model = .make(chart: chart)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PremiumValueLabel(value: selected.flatMap { rendered in chart.candles.first { $0.id == rendered.id }.map { FinancialFormatters.money(MoneyAmount($0.close, currency: chart.quoteAsset)) } } ?? FinancialFormatters.money(currentPrice))
            if let selected {
                Text("Clôture · \(HistoryPresentation.fullDate(selected.closeTime))")
                    .font(.caption).foregroundStyle(BotaplataColors.textSecondary)
            } else {
                Text("Bougies \(chart.timeframe) · prix en \(chart.quoteAsset)")
                    .font(.caption).foregroundStyle(BotaplataColors.textSecondary)
            }
            if model.candles.isEmpty {
                PremiumEmptyState(title: "Historique indisponible", message: "Aucune bougie persistée pour cette période.", systemImage: "chart.xyaxis.line")
            } else {
                IndicatorControls(model: model, showVWAP: $showVWAP, showEMA200: $showEMA200, showBollinger: $showBollinger)
                CandlestickChart(model: model, showVWAP: showVWAP, showEMA200: showEMA200, showBollinger: showBollinger, selected: $selected)
                if model.hasVolume {
                    Text("Volume · \(chart.baseAssetLabel)").font(.caption).foregroundStyle(BotaplataColors.textSecondary)
                    VolumeChart(candles: model.candles)
                }
                ChartLegend(model: model, showVWAP: showVWAP, showEMA200: showEMA200, showBollinger: showBollinger)
                if !chart.isComplete || chart.hasMore { Text("Historique partiel · couverture limitée aux bougies reçues").font(.caption).foregroundStyle(BotaplataColors.warning) }
                if !PremiumMarketPresentation(chart: chart).gaps.isEmpty { Text("Intervalles sans bougies · aucune valeur interpolée").font(.caption).foregroundStyle(BotaplataColors.warning) }
                Text("Source : \(chart.dataSource) · généré \(HistoryPresentation.fullDate(chart.generatedAt))")
                    .font(.caption).foregroundStyle(BotaplataColors.textSecondary)
            }
        }.onChange(of: chart.range) { _, _ in selected = nil }
            .onChange(of: chart.sessionID) { _, _ in selected = nil }
            .onChange(of: chart.generatedAt) { _, _ in if let old = selected { selected = model.candles.first { $0.id == old.id } } }
    }
}

private extension TradingChart {
    var baseAssetLabel: String { displaySymbol.split(separator: "/").first.map(String.init) ?? displaySymbol }
}
