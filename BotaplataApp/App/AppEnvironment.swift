import Foundation

enum AppEnvironmentKind: String, Sendable { case development, testFlight, production, preview, uiTesting }

struct AppEnvironment: Equatable, Sendable {
    let name: String
    let kind: AppEnvironmentKind
    let dataSource: DataSource
    let fixtureSource: String?
    let isProductionData: Bool
    let networkConfiguration: NetworkConfiguration?
    var baseURL: URL? { networkConfiguration?.baseURL }

    static let development = AppEnvironment(name: "DevelopmentLocal", kind: .development, dataSource: .unknown, fixtureSource: nil, isProductionData: false, networkConfiguration: Bundle.main.botaplataNetworkConfiguration)
    static let testFlight = AppEnvironment(name: "DevelopmentRemote", kind: .testFlight, dataSource: .unknown, fixtureSource: nil, isProductionData: true, networkConfiguration: Bundle.main.botaplataNetworkConfiguration)
    static let production = AppEnvironment(name: "Release", kind: .production, dataSource: .unknown, fixtureSource: nil, isProductionData: true, networkConfiguration: Bundle.main.botaplataNetworkConfiguration)
    static var configuredDevelopment: AppEnvironment {
        guard let configuration = Bundle.main.botaplataNetworkConfiguration else { return development }
        switch configuration.environment {
        case .developmentLocal:
            return AppEnvironment(name: configuration.environment.rawValue, kind: .development, dataSource: .unknown, fixtureSource: nil, isProductionData: false, networkConfiguration: configuration)
        case .developmentRemote:
            return AppEnvironment(name: configuration.environment.rawValue, kind: .testFlight, dataSource: .unknown, fixtureSource: nil, isProductionData: true, networkConfiguration: configuration)
        case .release:
            return AppEnvironment(name: configuration.environment.rawValue, kind: .production, dataSource: .unknown, fixtureSource: nil, isProductionData: true, networkConfiguration: configuration)
        }
    }
    static let normal = AppEnvironment.production
    static let debugPreview = AppEnvironment(name: "Démo locale", kind: .preview, dataSource: .previewFixture, fixtureSource: PreviewFixtureMetadata.source, isProductionData: false, networkConfiguration: nil)
    static let uiTesting = AppEnvironment(name: "UI Tests", kind: .uiTesting, dataSource: .previewFixture, fixtureSource: "ui-tests", isProductionData: false, networkConfiguration: nil)
}
