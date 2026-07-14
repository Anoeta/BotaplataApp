import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct APIEndpoint: Sendable {
    let method: HTTPMethod
    let path: String
    let queryItems: [URLQueryItem]
    let headers: [String: String]
    init(method: HTTPMethod, path: String, queryItems: [URLQueryItem] = [], headers: [String: String] = [:]) { self.method = method; self.path = path; self.queryItems = queryItems; self.headers = headers }
}
