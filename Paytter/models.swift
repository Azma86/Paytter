import Foundation

// お財布・口座の定義
struct Account: Identifiable, Codable {
    var id = UUID()
    var name: String        // 名前（例：三菱UFJ、PayPay）
    var type: AccountType   // 種類
    var balance: Int        // 現在の金額
    var isVisible: Bool     // ホーム上部に表示するか
    var payday: Int?        // クレジットカードの場合の引き落とし日（1〜31）
}

enum AccountType: String, Codable, CaseIterable {
    case wallet = "財布"
    case bank = "口座"
    case card = "カード"
    case point = "ポイント"
    
    var icon: String {
        switch self {
        case .wallet: return "👛"
        case .bank: return "🏦"
        case .card: return "💳"
        case .point: return "📱"
        }
    }
}

struct Transaction: Identifiable, Codable {
    var id = UUID()
    var amount: Int
    var date: Date
    var note: String
    var accountId: UUID?    // どのお財布に関連するか
    var isIncome: Bool
    
    var cleanNote: String {
        note.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.hasPrefix("#") && !$0.hasPrefix("@") }
            .joined(separator: " ")
    }
    
    var tags: [String] {
        note.components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.hasPrefix("#") }
    }
}

// 配列保存用の拡張（既存）
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
