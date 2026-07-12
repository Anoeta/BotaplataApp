import Foundation

enum FinancialFormatters {
    static func money(_ amount: MoneyAmount?) -> String {
        guard let amount, let value = amount.value else { return "—" }
        return decimal(value, min: 2, max: 4) + " " + amount.currency
    }
    static func percent(_ value: Decimal?) -> String {
        guard let value else { return "—" }
        return decimal(value * 100, min: 2, max: 2) + " %"
    }
    static func decimal(_ value: Decimal, min: Int, max: Int) -> String {
        let formatter = NumberFormatter(); formatter.numberStyle = .decimal; formatter.minimumFractionDigits = min; formatter.maximumFractionDigits = max; formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: value as NSDecimalNumber) ?? "—"
    }
}
