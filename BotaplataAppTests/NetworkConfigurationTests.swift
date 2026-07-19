import XCTest
@testable import BotaplataApp

final class NetworkConfigurationTests: XCTestCase {
    func testDevelopmentLocalURLIsBuiltExactly() throws {
        let configuration = NetworkConfiguration(environment: .developmentLocal, baseURL: try XCTUnwrap(URL(string: "http://192.168.x.x:31119")))
        XCTAssertEqual(configuration.environment, .developmentLocal)
        XCTAssertEqual(configuration.baseURL.absoluteString, "http://192.168.x.x:31119")
    }

    func testDevelopmentRemoteURLIsBuiltExactly() throws {
        let configuration = NetworkConfiguration(environment: .developmentRemote, baseURL: try XCTUnwrap(URL(string: "https://tyvb2rpi42tyv.taild3ac1d.ts.net")))
        XCTAssertEqual(configuration.environment, .developmentRemote)
        XCTAssertEqual(configuration.baseURL.absoluteString, "https://tyvb2rpi42tyv.taild3ac1d.ts.net")
    }

    func testReleaseURLIsBuiltExactly() throws {
        let configuration = NetworkConfiguration(environment: .release, baseURL: try XCTUnwrap(URL(string: "https://tyvb2rpi42tyv.taild3ac1d.ts.net")))
        XCTAssertEqual(configuration.environment, .release)
        XCTAssertEqual(configuration.baseURL.absoluteString, "https://tyvb2rpi42tyv.taild3ac1d.ts.net")
    }
}
