import Foundation

enum AppEnvironmentKind: String, Sendable { case development, testFlight, production, preview, uiTesting }

struct AppEnvironment: Equatable, Sendable {
    let name: String
    let kind: AppEnvironmentKind
    let dataSource: DataSource
    let fixtureSource: String?
    let isProductionData: Bool
    let baseURL: URL?

    static let development = AppEnvironment(name: "Development", kind: .development, dataSource: .unknown, fixtureSource: nil, isProductionData: false, baseURL: URL(string: "http://192.168.1.47:31119"))
    static let testFlight = AppEnvironment(name: "TestFlight", kind: .testFlight, dataSource: .unknown, fixtureSource: nil, isProductionData: true, baseURL: Bundle.main.botaplataBaseURL)
    static let production = AppEnvironment(name: "Production", kind: .production, dataSource: .unknown, fixtureSource: nil, isProductionData: true, baseURL: Bundle.main.botaplataBaseURL)
    static let normal = AppEnvironment.production
    static let debugPreview = AppEnvironment(name: "Démo locale", kind: .preview, dataSource: .previewFixture, fixtureSource: PreviewFixtureMetadata.source, isProductionData: false, baseURL: nil)
    static let uiTesting = AppEnvironment(name: "UI Tests", kind: .uiTesting, dataSource: .previewFixture, fixtureSource: "ui-tests", isProductionData: false, baseURL: nil)
}

private extension Bundle {
    var botaplataBaseURL: URL? {
        guard let raw = object(forInfoDictionaryKey: "BOTAPLATA_API_BASE_URL") as? String, !raw.isEmpty else { return nil }
        return URL(string: raw)
    }
}
