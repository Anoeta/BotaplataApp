import Foundation
struct DashboardSummary: Equatable, Sendable { let title: String; let fixtureNotice: String; let systemHealth: SystemHealth; let activeSession: SessionDetail?; let warnings: [Warning] }
