import Foundation
struct ExchangeHealth: Equatable, Sendable { let provider: TradingProvider; let state: RuntimeHealthState; let message: String }
struct SystemHealth: Equatable, Sendable { let raspberry: RuntimeHealthState; let exchange: ExchangeHealth; let monitoring: RuntimeHealthState; let message: String }
