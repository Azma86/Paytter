import Foundation

struct Transaction: Identifiable, Codable {
    var id = UUID()
    var amount: Int
    var date: Date
    var note: String
    var source: String
    var isIncome: Bool
    
    var cleanNoteav
}

enum AccountType: String, Codable, CaseIterable {
    case wallet = "お財布"
    case bank = "口座"
    case credit = "クレジットカード"
    case point = "ポイント"
    
    var icon: String {
        switch self {
        case .wallet: return "wallet.pass"
        case .bank: return "building.columns"
        case .credit: return "creditcard"
        case .point: return "p.circle"
        }
    }
}

struct Account: Identifiable, Codable {
    var id = UUID()
    var name: String
    var balance: Int
    var type: AccountType = .wallet
    var isVisible: Bool = true
    var payday: Int? = 1
    var withdrawalAccountId: UUID? = nil
    
    // エフェクト表示用（保存不要なため、Codableからは除外するか無視されるようにします）
    var diffAmount: Int = 0
}

extension Array: RawRepresentable where Element: Codable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode([Element].self, from: data)
        else { return nil }
        self = result
    }
    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else { return "[]" }
        return result
    }
}
