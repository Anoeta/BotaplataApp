import Foundation

enum AppTab: Hashable, CaseIterable, Sendable {
    case dashboard, sessions, analysis, journal, profile
    var title: String { switch self { case .dashboard: "Accueil"; case .sessions: "Sessions"; case .analysis: "Analyse"; case .journal: "Journal"; case .profile: "Profil" } }
    var symbol: String { switch self { case .dashboard: "gauge.with.dots.needle.67percent"; case .sessions: "list.bullet.rectangle.portrait"; case .analysis: "waveform.path.ecg"; case .journal: "book.pages"; case .profile: "person.crop.circle" } }
}
