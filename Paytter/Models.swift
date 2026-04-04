import Foundation
import SwiftUI
import LocalAuthentication
import Combine

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

class LockManager: ObservableObject {
    static let shared = LockManager()
    
    @Published var isUnlocked: Bool = true
    @Published var isShowingLockScreen: Bool = false
    @Published var isSilentUpdate: Bool = false
    
    var passcode: String {
        get { UserDefaults.standard.string(forKey: "app_passcode") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "app_passcode"); objectWillChange.send() }
    }
    var passcodeType: Int {
        get { UserDefaults.standard.integer(forKey: "passcode_type") }
        set { UserDefaults.standard.set(newValue, forKey: "passcode_type"); objectWillChange.send() }
    }
    var useBiometrics: Bool {
        get { UserDefaults.standard.bool(forKey: "use_biometrics") }
        set { UserDefaults.standard.set(newValue, forKey: "use_biometrics"); objectWillChange.send() }
    }
    var lockBehavior: Int {
        get { UserDefaults.standard.integer(forKey: "lock_behavior") }
        set { UserDefaults.standard.set(newValue, forKey: "lock_behavior"); objectWillChange.send() }
    }
    var privatePostDisplayMode: Int {
        get { UserDefaults.standard.integer(forKey: "private_post_display") }
        set { UserDefaults.standard.set(newValue, forKey: "private_post_display"); objectWillChange.send() }
    }
    var reflectPrivateBalanceWhenLocked: Bool {
        get { UserDefaults.standard.bool(forKey: "reflect_private_balance") }
        set { UserDefaults.standard.set(newValue, forKey: "reflect_private_balance"); objectWillChange.send() }
    }
    
    init() {
        if !(UserDefaults.standard.string(forKey: "app_passcode") ?? "").isEmpty {
            isUnlocked = false
        }
    }
    
    func lock() {
        if !passcode.isEmpty {
            isSilentUpdate = true
            isUnlocked = false
            if lockBehavior == 0 {
                isShowingLockScreen = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.isSilentUpdate = false }
        }
    }
    
    func promptUnlock() {
        guard !passcode.isEmpty else { return }
        isShowingLockScreen = true
    }
    
    func authenticateWithBiometrics() {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "アプリのロックを解除します") { success, _ in
                DispatchQueue.main.async {
                    if success {
                        self.isSilentUpdate = true
                        self.isUnlocked = true
                        self.isShowingLockScreen = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.isSilentUpdate = false }
                    }
                }
            }
        }
    }
    
    func unlock(with code: String) -> Bool {
        if code == passcode {
            isSilentUpdate = true
            isUnlocked = true
            isShowingLockScreen = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.isSilentUpdate = false }
            return true
        }
        return false
    }
    
    func cancelUnlock() {
        isShowingLockScreen = false
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

struct UserProfile: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var userId: String
    var iconData: Data?
    var isVisible: Bool = true
    var isPrivate: Bool?
    var isDeleted: Bool?
}

struct Transaction: Identifiable, Codable, Equatable {
    var id = UUID(); var amount: Int; var date: Date; var note: String; var source: String; var isIncome: Bool
    var isExcludedFromBalance: Bool?
    var profileId: UUID?
    // 【新規】添付画像のデータ配列
    var attachedImageDatas: [Data]? = nil
    
    var tags: [String] { note.components(separatedBy: .whitespacesAndNewlines).filter { $0.hasPrefix("#") } }
    var cleanNote: String {
        let lines = note.components(separatedBy: .newlines)
        let cleanedLines = lines.map { line in
            line.components(separatedBy: .whitespaces).filter { !$0.hasPrefix("#") && !$0.hasPrefix("@") }.joined(separator: " ")
        }
        return cleanedLines.joined(separator: "\n")
    }
}

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
    static let transAutoFile = "paytter_transactions_auto.json"
    static let accountsAutoFile = "paytter_accounts_auto.json"
    static let transManualFile = "paytter_transactions_manual.json"
    static let accountsManualFile = "paytter_accounts_manual.json"
    
    static func getDocumentsDirectory() -> URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }
    static func currentDateString() -> String { let formatter = DateFormatter(); formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"; return formatter.string(from: Date()) }
    
    static func saveFullBackup(data: FullBackupData, isManual: Bool) {
        let fName = isManual ? manualFile : autoFile
        let url = getDocumentsDirectory().appendingPathComponent(fName)
        try? JSONEncoder().encode(data).write(to: url)
    }
    
    static func loadFullBackup(isManual: Bool) -> FullBackupData? {
        let fName = isManual ? manualFile : autoFile
        let url = getDocumentsDirectory().appendingPathComponent(fName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(FullBackupData.self, from: data)
    }
    
    static func getBackupDate(isManual: Bool) -> String {
        if let backup = loadFullBackup(isManual: isManual) { return backup.backupDate }
        let tName = isManual ? transManualFile : transAutoFile
        let url = getDocumentsDirectory().appendingPathComponent(tName)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path), let date = attributes[.modificationDate] as? Date else { return "なし" }
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"; return formatter.string(from: date)
    }
    
    static func loadTransactions(isManual: Bool) -> [Transaction]? {
        let tName = isManual ? transManualFile : transAutoFile
        let url = getDocumentsDirectory().appendingPathComponent(tName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([Transaction].self, from: data)
    }
    
    static func loadAccounts(isManual: Bool) -> [Account]? {
        let aName = isManual ? accountsManualFile : accountsAutoFile
        let url = getDocumentsDirectory().appendingPathComponent(aName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([Account].self, from: data)
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
