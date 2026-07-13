import Foundation

struct AppEnvironment: Equatable, Sendable {
    let name: String
    let dataSource: DataSource
    let fixtureSource: String?
    let isProductionData: Bool

    static let normal = AppEnvironment(name: "Production", dataSource: .unknown, fixtureSource: nil, isProductionData: true)
    static let debugPreview = AppEnvironment(name: "Démo locale", dataSource: .previewFixture, fixtureSource: PreviewFixtureMetadata.source, isProductionData: false)
    static let uiTesting = AppEnvironment(name: "UI Tests", dataSource: .previewFixture, fixtureSource: "ui-tests", isProductionData: false)
}

