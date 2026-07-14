import Foundation
struct ExchangeHealth: Equatable, Sendable, Codable { let provider: TradingProvider; let state: RuntimeHealthState; let message: String }
struct SystemHealth: Equatable, Sendable, Codable { let raspberry: RuntimeHealthState; let exchange: ExchangeHealth; let monitoring: RuntimeHealthState; let message: String }
