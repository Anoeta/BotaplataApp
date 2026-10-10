import Foundation

extension Warning {
    init(api: APIWarning) {
        self.init(id: api.code, severity: api.code == "monitoring_degraded" || api.code == "stale_session_data" ? .warning : .information, title: Self.title(for: api.code), message: api.message)
    }
    static func title(for code: String) -> String {
        switch code { case "monitoring_degraded": return "Surveillance perturbée"; case "stale_session_data": return "Données à vérifier"; case "multiple_active_real_sessions": return "Plusieurs sessions actives"; default: return "Information Botaplata" }
    }
}
