import Foundation

struct AppEnvironment: Equatable, Sendable {
    let name: String
    let dataSource: DataSource
    let fixtureSource: String?
    let isProductionData: Bool

    static let debugPreview = AppEnvironment(name: "Démo locale", dataSource: .previewFixture, fixtureSource: PreviewFixtureMetadata.source, isProductionData: false)
}
