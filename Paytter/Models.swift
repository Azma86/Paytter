import Foundation
import SwiftUI
import LocalAuthentication

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

// 【新規】アプリ全体のロック状態を管理するマネージャー
class LockManager: ObservableObject {
    static let shared = LockManager()
    
    @Published var isUnlocked: Bool = true
    @Published var isShowingLockScreen: Bool = false
    
    var passcode: String {
        get { UserDefaults.standard.string(forKey: "app_passcode") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "app_passcode"); objectWillChange.send() }
    }
    var passcodeType: Int { // 0: 4桁, 1: 6桁, 2: 自由入力
        get { UserDefaults.standard.integer(forKey: "passcode_type") }
        set { UserDefaults.standard.set(newValue, forKey: "passcode_type"); objectWillChange.send() }
    }
    var useBiometrics: Bool {
        get { UserDefaults.standard.bool(forKey: "use_biometrics") }
        set { UserDefaults.standard.set(newValue, forKey: "use_biometrics"); objectWillChange.send() }
    }
    
    init() {
        if !(UserDefaults.standard.string(forKey: "app_passcode") ?? "").isEmpty {
            isUnlocked = false
        }
    }
    
    func lock() {
        if !passcode.isEmpty { isUnlocked = false }
    }
    
    func promptUnlock() {
        guard !passcode.isEmpty else { return }
        isShowingLockScreen = true
        if useBiometrics { authenticateWithBiometrics() }
    }
    
    func authenticateWithBiometrics() {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "アプリのロックを解除します") { success, _ in
                DispatchQueue.main.async {
                    if success {
                        self.isUnlocked = true
                        self.isShowingLockScreen = false
                    }
                }
            }
        }
    }
    
    func unlock(with code: String) -> Bool {
        if code == passcode {
            isUnlocked = true
            isShowingLockScreen = false
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
    // 【新規】鍵アカウントフラグ
    var isPrivate: Bool?
}

struct Transaction: Identifiable, Codable, Equatable {
    var id = UUID(); var amount: Int; var date: Date; var note: String; var source: String; var isIncome: Bool
    var isExcludedFromBalance: Bool?
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
