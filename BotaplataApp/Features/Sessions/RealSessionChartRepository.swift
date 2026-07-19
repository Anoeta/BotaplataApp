import Foundation
import Observation
import OSLog

protocol RealSessionChartRepositoryProtocol: Sendable { func fetchChart(sessionID: String, range: TradingChartRange, before: Date?, limit: Int?, accessToken: String) async throws -> TradingChart }

struct RealSessionChartRepository: RealSessionChartRepositoryProtocol {
    let client: APIClientProtocol

    func fetchChart(sessionID: String, range: TradingChartRange, before: Date? = nil, limit: Int? = nil, accessToken: String) async throws -> TradingChart {
        var q = [URLQueryItem(name: "range", value: range.rawValue)]
        if let before { q.append(.init(name: "before", value: ISO8601DateFormatter().string(from: before))) }
        if let limit { q.append(.init(name: "limit", value: String(limit))) }
        let path = "/api/mobile/v1/real/sessions/\(sessionID)/chart"
        BotaplataLog.chart.info("ChartRepository.request session=\(sessionID, privacy: .public) range=\(range.rawValue, privacy: .public) url=\(Self.redactedURL(path: path, queryItems: q), privacy: .public)")
        do {
            let envelope: APIEnvelope<RealSessionChartDTO> = try await client.sendEnvelope(APIEndpoint(method: .get, path: path, queryItems: q, headers: HTTPHeaders.bearer(accessToken)))
            BotaplataLog.chart.info("DECODING SUCCESS dto=RealSessionChartDTO session=\(envelope.data?.sessionID ?? sessionID, privacy: .public) range=\(envelope.data?.range ?? range.rawValue, privacy: .public)")
            let mapped = try RealSessionChartMapper.mapWithDiagnostics(envelope: envelope)
            let d = mapped.diagnostics
            BotaplataLog.chart.info("ChartMapper session=\(mapped.chart.sessionID, privacy: .public) input=\(d.inputCandles, privacy: .public) invalid=\(d.invalidCandles, privacy: .public) duplicates=\(d.duplicateCandles, privacy: .public) output=\(d.outputCandles, privacy: .public) first=\(String(describing: d.firstTimestamp), privacy: .public) last=\(String(describing: d.lastTimestamp), privacy: .public) hasVWAP=\(d.hasVWAP, privacy: .public) hasEMA200=\(d.hasEMA200, privacy: .public) hasBollinger=\(d.hasBollinger, privacy: .public) hasVolume=\(d.hasVolume, privacy: .public) markers=\(d.markers, privacy: .public) levels=\(d.nonNullLevels, privacy: .public)")
            return mapped.chart
        } catch APIClientError.network { throw AuthenticationError.offline }
        catch APIClientError.timeout { throw AuthenticationError.serverUnavailable }
        catch APIClientError.httpStatus(401, _) { throw AuthenticationError.accessTokenExpired }
        catch APIClientError.decoding { throw AuthenticationError.contractIncompatible }
        catch APIClientError.invalidVersion { throw AuthenticationError.contractIncompatible }
        catch let e as AuthenticationError { throw e }
        catch { throw AuthenticationError.serverUnavailable }
    }

    private static func redactedURL(path: String, queryItems: [URLQueryItem]) -> String {
        guard !queryItems.isEmpty else { return path }
        return path + "?" + queryItems.map { "\($0.name)=\($0.name == "range" ? ($0.value ?? "") : "<redacted>")" }.joined(separator: "&")
    }
}

struct UnconfiguredRealSessionChartRepository: RealSessionChartRepositoryProtocol { func fetchChart(sessionID: String, range: TradingChartRange, before: Date?, limit: Int?, accessToken: String) async throws -> TradingChart { throw AuthenticationError.notConfigured } }
struct MockRealSessionChartRepository: RealSessionChartRepositoryProtocol { func fetchChart(sessionID: String, range: TradingChartRange, before: Date?, limit: Int?, accessToken: String) async throws -> TradingChart { PreviewFixtures.tradingChart(range: range) } }
