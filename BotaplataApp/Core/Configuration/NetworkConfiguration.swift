import Foundation
import OSLog

enum NetworkEnvironment: String, CaseIterable, Sendable {
    case developmentLocal = "DevelopmentLocal"
    case developmentRemote = "DevelopmentRemote"
    case release = "Release"
}

struct NetworkConfiguration: Equatable, Sendable {
    let environment: NetworkEnvironment
    let baseURL: URL

    init(environment: NetworkEnvironment, baseURL: URL) {
        self.environment = environment
        self.baseURL = baseURL
    }

    init?(bundle: Bundle = .main) {
        let environment = bundle.botaplataNetworkEnvironment
        let key = Self.baseURLInfoKey(for: environment)
        guard let baseURL = bundle.botaplataURL(forInfoDictionaryKey: key) else { return nil }
        self.init(environment: environment, baseURL: baseURL)
    }

    static func baseURLInfoKey(for environment: NetworkEnvironment) -> String {
        switch environment {
        case .developmentLocal: "BOTAPLATA_DEVELOPMENT_LOCAL_BASE_URL"
        case .developmentRemote: "BOTAPLATA_DEVELOPMENT_REMOTE_BASE_URL"
        case .release: "BOTAPLATA_RELEASE_BASE_URL"
        }
    }

    func logResolvedConfiguration() {
#if DEBUG
        BotaplataLog.network.debug("NetworkConfiguration environment=\(environment.rawValue, privacy: .public) baseURL=\(baseURL.absoluteString, privacy: .public)")
#endif
    }
}

extension Bundle {
    var botaplataNetworkConfiguration: NetworkConfiguration? { NetworkConfiguration(bundle: self) }

    fileprivate var botaplataNetworkEnvironment: NetworkEnvironment {
        guard let raw = object(forInfoDictionaryKey: "BOTAPLATA_NETWORK_ENVIRONMENT") as? String,
              let environment = NetworkEnvironment(rawValue: raw) else { return .release }
        return environment
    }

    fileprivate func botaplataURL(forInfoDictionaryKey key: String) -> URL? {
        guard let raw = object(forInfoDictionaryKey: key) as? String, !raw.isEmpty else { return nil }
        return URL(string: raw)
    }
}
