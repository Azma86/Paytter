import Foundation
import SwiftUI

enum AccountType: String, Codable, CaseIterable {
    case wallet = "お財布", bank = "銀行口座", credit = "クレジットカード", point = "ポイント"
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
    var id = UUID(); var name: String; var balance: Int; var type: AccountType
    var isVisible: Bool = true; var payday: Int? = nil; var withdrawalAccountId: UUID? = nil; var diffAmount: Int = 0
}

struct Transaction: Identifiable, Codable, Equatable {
    var id = UUID(); var amount: Int; var date: Date; var note: String; var source: String; var isIncome: Bool
    var tags: [String] { note.components(separatedBy: .whitespacesAndNewlines).filter { $0.hasPrefix("#") } }
    var cleanNote: String {
        let lines = note.components(separatedBy: .newlines)
        let cleanedLines = lines.map { line in
            line.components(separatedBy: .whitespaces)
                .filter { !$0.hasPrefix("#") && !$0.hasPrefix("@") }
                .joined(separator: " ")
        }
        return cleanedLines.joined(separator: "\n")
    }
}

extension Array: RawRepresentable where Element: Codable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8), let result = try? JSONDecoder().decode([Element].self, from: data) else { return nil }
        self = result
    }
    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self), let result = String(data: data, encoding: .utf8) else { return "[]" }
        return result
    }
}
