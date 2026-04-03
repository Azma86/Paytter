import Foundation
import SwiftUI

// アラートの種類を定義
enum ActiveAlert: Identifiable {
    case reset, restore, save, importConfirm, completion(String)
    var id: String {
        switch self {
        case .reset: return "reset"
        case .restore: return "restore"
        case .save: return "save"
        case .importConfirm: return "import"
        case .completion(let m): return m
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
    func toHex() -> String {
        let components = UIColor(self).cgColor.components
        let r: CGFloat = components?[0] ?? 0.0
        let g: CGFloat = components?[1] ?? 0.0
        let b: CGFloat = components?[2] ?? 0.0
        let a: CGFloat = components?[3] ?? 1.0
        return String(format: "#%02lX%02lX%02lX%02lX", lroundf(Float(a * 255)), lroundf(Float(r * 255)), lroundf(Float(g * 255)), lroundf(Float(b * 255)))
    }
}

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

struct AccountGroup: Identifiable, Codable, Equatable {
    var id = UUID(); var name: String; var isVisible: Bool = true; var accountIds: [UUID] = []
}

struct Account: Identifiable, Codable, Equatable {
    var id = UUID(); var name: String; var balance: Int; var type: AccountType
    var isVisible: Bool = true; var payday: Int? = nil; var withdrawalAccountId: UUID? = nil; var diffAmount: Int = 0
}

// 【新規】ユーザープロファイルモデル
struct UserProfile: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var userId: String
    var iconData: Data?
    var isVisible: Bool = true // タイムラインに表示するかどうか
}

struct Transaction: Identifiable, Codable, Equatable {
    var id = UUID(); var amount: Int; var date: Date; var note: String; var source: String; var isIncome: Bool
    
    var isExcludedFromBalance: Bool?
    // 【新規】どのユーザーの投稿かを紐付けるID
    var profileId: UUID?
    
    var tags: [String] { note.components(separatedBy: .whitespacesAndNewlines).filter { $0.hasPrefix("#") } }
    var cleanNote: String {
        let lines = note.components(separatedBy: .newlines)
        let cleanedLines = lines.map { line in
            line.components(separatedBy: .whitespaces).filter { !$0.hasPrefix("#") && !$0.hasPrefix("@") }.joined(separator: " ")
        }
        return cleanedLines.joined(separator: "\n")
    }
}

// 【新規】全データをまとめるバックアップ用モデル
struct FullBackupData: Codable {
    var transactions: [Transaction]; var accounts: [Account]; var groups: [AccountGroup]; var profiles: [UserProfile]
    var monthlyBudget: Int; var isDarkMode: Bool
    var themeMain: String; var themeIncome: String; var themeExpense: String; var themeHoliday: String; var themeSaturday: String
    var themeBG: String; var themeBarBG: String; var themeBarText: String; var themeTabAccent: String; var themeBodyText: String; var themeSubText: String
    var showTotalAssets: Bool; var homeDisplayOrder: [String]
    var backupDate: String
}

class BackupManager {
    static let manualFile = "paytter_fullbackup_manual.json"
    static let autoFile = "paytter_fullbackup_auto.json"
    
    static func getDocumentsDirectory() -> URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }
    static func currentDateString() -> String { let formatter = DateFormatter(); formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"; return formatter.string(from: Date()) }
    
    static func saveFullBackup(data: FullBackupData, isManual: Bool) {
        let fName = isManual ? manualFile : autoFile; let url = getDocumentsDirectory().appendingPathComponent(fName)
        try? JSONEncoder().encode(data).write(to: url)
    }
    static func loadFullBackup(isManual: Bool) -> FullBackupData? {
        let fName = isManual ? manualFile : autoFile; let url = getDocumentsDirectory().appendingPathComponent(fName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(FullBackupData.self, from: data)
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
