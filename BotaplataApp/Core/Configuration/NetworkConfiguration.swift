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
        guard let baseURL = bundle.botaplataURL(forInfoDictionaryKey: "BOTAPLATA_BASE_URL") ?? bundle.botaplataURL(forInfoDictionaryKey: key) else { return nil }
        self.init(environment: environment, baseURL: baseURL)
    }

    static func baseURLInfoKey(for environment: NetworkEnvironment) -> String {
        switch environment {
        case .developmentLocal: "BOTAPLATA_DEVELOPMENT_LOCAL_BASE_URL"
        case .developmentRemote: "BOTAPLATA_DEVELOPMENT_REMOTE_BASE_URL"
        case .release: "BOTAPLATA_RELEASE_BASE_URL"
        }
    }

    func logResolvedConfiguration(bundle: Bundle = .main) {
        let source = bundle.object(forInfoDictionaryKey: "BOTAPLATA_BASE_URL") as? String == baseURL.absoluteString ? "BOTAPLATA_BASE_URL" : Self.baseURLInfoKey(for: environment)
        let bundleIdentifier = bundle.bundleIdentifier ?? "unknown"
        let buildConfiguration = bundle.object(forInfoDictionaryKey: "BOTAPLATA_CONFIGURATION") as? String ?? "unknown"
        let infoPlistEnvironment = bundle.object(forInfoDictionaryKey: "BOTAPLATA_ENV") as? String ?? bundle.object(forInfoDictionaryKey: "BOTAPLATA_NETWORK_ENVIRONMENT") as? String ?? "missing"
        let infoPlistBaseURL = bundle.object(forInfoDictionaryKey: "BOTAPLATA_BASE_URL") as? String ?? bundle.object(forInfoDictionaryKey: Self.baseURLInfoKey(for: environment)) as? String ?? "missing"
        BotaplataLog.network.info("""
NetworkConfiguration
Environment = \(environment.rawValue, privacy: .public)
BaseURL = \(baseURL.absoluteString, privacy: .public)
Source = \(source, privacy: .public)
Bundle = \(bundleIdentifier, privacy: .public)
Configuration = \(buildConfiguration, privacy: .public)
Info.plist value = BOTAPLATA_ENV=\(infoPlistEnvironment, privacy: .public), BOTAPLATA_BASE_URL=\(infoPlistBaseURL, privacy: .public), NetworkConfiguration.baseURL=\(baseURL.absoluteString, privacy: .public)
""")
    }
}

extension Bundle {
    var botaplataNetworkConfiguration: NetworkConfiguration? { NetworkConfiguration(bundle: self) }

    fileprivate var botaplataNetworkEnvironment: NetworkEnvironment {
        let raw = object(forInfoDictionaryKey: "BOTAPLATA_ENV") as? String ?? object(forInfoDictionaryKey: "BOTAPLATA_NETWORK_ENVIRONMENT") as? String
        guard let raw, let environment = NetworkEnvironment(rawValue: raw) else { return .release }
        return environment
    }

    fileprivate func botaplataURL(forInfoDictionaryKey key: String) -> URL? {
        guard let raw = object(forInfoDictionaryKey: key) as? String, !raw.isEmpty else { return nil }
        return URL(string: raw)
    }
}
