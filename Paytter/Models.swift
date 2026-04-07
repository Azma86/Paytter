import Foundation
import SwiftUI
import LocalAuthentication
import Combine

enum ActiveAlert: Identifiable {
    case reset, restore, save, importConfirm, completion(String)
    var id: String { switch self { case .reset: return "reset"; case .restore: return "restore"; case .save: return "save"; case .importConfirm: return "import"; case .completion(let m): return m } }
}

class ImageCache {
    static let shared = ImageCache()
    private var cache = NSCache<NSString, UIImage>()
    func image(for data: Data) -> UIImage? {
        let key = NSString(string: String(data.hashValue))
        if let cached = cache.object(forKey: key) { return cached }
        if let image = UIImage(data: data) { cache.setObject(image, forKey: key); return image }
        return nil
    }
}

class LockManager: ObservableObject {
    static let shared = LockManager()
    @Published var isUnlocked: Bool = true
    @Published var isShowingLockScreen: Bool = false
    @Published var isSilentUpdate: Bool = false
    @Published var isProcessing: Bool = false
    
    var passcode: String { get { UserDefaults.standard.string(forKey: "app_passcode") ?? "" } set { UserDefaults.standard.set(newValue, forKey: "app_passcode"); objectWillChange.send() } }
    var passcodeType: Int { get { UserDefaults.standard.integer(forKey: "passcode_type") } set { UserDefaults.standard.set(newValue, forKey: "passcode_type"); objectWillChange.send() } }
    var useBiometrics: Bool { get { UserDefaults.standard.bool(forKey: "use_biometrics") } set { UserDefaults.standard.set(newValue, forKey: "use_biometrics"); objectWillChange.send() } }
    var lockBehavior: Int { get { UserDefaults.standard.integer(forKey: "lock_behavior") } set { UserDefaults.standard.set(newValue, forKey: "lock_behavior"); objectWillChange.send() } }
    var privatePostDisplayMode: Int { get { UserDefaults.standard.integer(forKey: "private_post_display") } set { UserDefaults.standard.set(newValue, forKey: "private_post_display"); objectWillChange.send() } }
    var reflectPrivateBalanceWhenLocked: Bool { get { UserDefaults.standard.bool(forKey: "reflect_private_balance") } set { UserDefaults.standard.set(newValue, forKey: "reflect_private_balance"); objectWillChange.send() } }
    
    init() { if !(UserDefaults.standard.string(forKey: "app_passcode") ?? "").isEmpty { isUnlocked = false } }
    func lock() { if !passcode.isEmpty { isSilentUpdate = true; isUnlocked = false; if lockBehavior == 0 { isShowingLockScreen = true }; DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.isSilentUpdate = false } } }
    func promptUnlock() { guard !passcode.isEmpty else { return }; isShowingLockScreen = true }
    func authenticateWithBiometrics() { let context = LAContext(); var error: NSError?; if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) { context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "アプリのロックを解除します") { success, _ in DispatchQueue.main.async { if success { self.isSilentUpdate = true; self.isUnlocked = true; self.isShowingLockScreen = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.isSilentUpdate = false } } } } } }
    func unlock(with code: String) -> Bool { if code == passcode { isSilentUpdate = true; isUnlocked = true; isShowingLockScreen = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.isSilentUpdate = false }; return true }; return false }
    func cancelUnlock() { isShowingLockScreen = false }
}

extension Color {
    init(hex: String) {
        var hexStr = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hexStr.hasPrefix("#") { hexStr.removeFirst() }
        let int = UInt64(hexStr, radix: 16) ?? 0
        let a, r, g, b: UInt64
        switch hexStr.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 255, 255, 255)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
    func toHex() -> String { let components = UIColor(self).cgColor.components; let r: CGFloat = components?[0] ?? 0.0; let g: CGFloat = components?[1] ?? 0.0; let b: CGFloat = components?[2] ?? 0.0; let a: CGFloat = components?[3] ?? 1.0; return String(format: "#%02lX%02lX%02lX%02lX", lroundf(Float(a * 255)), lroundf(Float(r * 255)), lroundf(Float(g * 255)), lroundf(Float(b * 255))) }
}

enum AccountType: String, Codable, CaseIterable {
    case wallet = "お財布", bank = "銀行口座", credit = "クレジットカード", point = "ポイント"
    var icon: String { switch self { case .wallet: return "wallet.pass"; case .bank: return "building.columns"; case .credit: return "creditcard"; case .point: return "p.circle" } }
}

struct AccountGroup: Identifiable, Codable, Equatable { var id = UUID(); var name: String; var isVisible: Bool = true; var accountIds: [UUID] = [] }
// 【修正】クレジットカード用の設定（closingDay, withdrawalDay）を追加しました
struct Account: Identifiable, Codable, Equatable { var id = UUID(); var name: String; var balance: Int; var type: AccountType; var isVisible: Bool = true; var payday: Int? = nil; var withdrawalAccountId: UUID? = nil; var diffAmount: Int = 0; var closingDay: Int? = nil; var withdrawalDay: Int? = nil }
struct UserProfile: Identifiable, Codable, Equatable { var id = UUID(); var name: String; var userId: String; var iconData: Data?; var isVisible: Bool = true; var isPrivate: Bool?; var isDeleted: Bool? }

enum MediaType: String, Codable {
    case image, video
}

struct AttachedMediaItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var type: MediaType
    var localFileName: String
    var originalFileName: String? 
    var thumbnailData: Data?
    var durationText: String?
}

struct AttachedVideo: Codable, Equatable { var id = UUID(); var localFileName: String; var thumbnailData: Data? }
struct AttachedFile: Codable, Equatable {
    var id = UUID(); var originalFileName: String; var localFileName: String; var fileSize: Int64
    var formattedSize: String { let formatter = ByteCountFormatter(); formatter.allowedUnits = [.useKB, .useMB, .useGB]; formatter.countStyle = .file; return formatter.string(fromByteCount: fileSize) }
    var fileExtension: String { return (originalFileName as NSString).pathExtension.uppercased() }
}

class MediaManager {
    static let shared = MediaManager()
    func getDocumentsDirectory() -> URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }
    func getMediaURL(fileName: String) -> URL { return getDocumentsDirectory().appendingPathComponent(fileName) }
    
    func saveMedia(from url: URL) -> String? {
        let ext = url.pathExtension; let fileName = UUID().uuidString + ".\(ext)"
        let destURL = getDocumentsDirectory().appendingPathComponent(fileName)
        do { try FileManager.default.copyItem(at: url, to: destURL); return fileName } catch { return nil }
    }
    func saveData(_ data: Data, extension ext: String) -> String? {
        let fileName = UUID().uuidString + ".\(ext)"
        let destURL = getDocumentsDirectory().appendingPathComponent(fileName)
        do { try data.write(to: destURL); return fileName } catch { return nil }
    }
    func loadImage(fileName: String) -> UIImage? {
        if fileName.isEmpty { return nil }
        let url = getMediaURL(fileName: fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
}

struct Transaction: Identifiable, Codable, Equatable {
    var id = UUID(); var amount: Int; var date: Date; var note: String; var source: String; var isIncome: Bool
    var isExcludedFromBalance: Bool?
    var profileId: UUID?
    
    var attachedImageDatas: [Data]? = nil
    var attachedVideos: [AttachedVideo]? = nil
    var attachedMediaItems: [AttachedMediaItem]? = nil
    var attachedFiles: [AttachedFile]? = nil
    
    var tags: [String] { note.components(separatedBy: .whitespacesAndNewlines).filter { $0.hasPrefix("#") } }
    var cleanNote: String { let lines = note.components(separatedBy: .newlines); let cleanedLines = lines.map { line in line.components(separatedBy: .whitespaces).filter { !$0.hasPrefix("#") && !$0.hasPrefix("@") }.joined(separator: " ") }; return cleanedLines.joined(separator: "\n") }
}

extension Transaction {
    var displayMediaItems: [AttachedMediaItem] {
        if let items = attachedMediaItems, !items.isEmpty { return items }
        var fallback: [AttachedMediaItem] = []
        if let datas = attachedImageDatas {
            for data in datas { fallback.append(AttachedMediaItem(type: .image, localFileName: "", originalFileName: "添付画像", thumbnailData: data)) }
        }
        if let vids = attachedVideos {
            for v in vids { fallback.append(AttachedMediaItem(type: .video, localFileName: v.localFileName, originalFileName: "添付動画", thumbnailData: v.thumbnailData)) }
        }
        return fallback
    }
}

struct RecurringPayment: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var amount: Int
    var startDate: Date
    var hasEndDate: Bool
    var endDate: Date
    var paymentDay: Int
    var profileId: UUID?
    var source: String
    var isIncome: Bool
    var fractionType: Int 
    var fractionAmount: Int
    var postedMonths: [String]?
    var createdAt: Date?
    
    func paymentInfo() -> (total: Int, paid: Int, remaining: Int) {
        let cal = Calendar.current
        guard let startNorm = cal.date(from: cal.dateComponents([.year, .month], from: startDate)),
              let endNorm = cal.date(from: cal.dateComponents([.year, .month], from: endDate)) else { return (0,0,0) }
        
        let now = Date()
        let nowComps = cal.dateComponents([.year, .month, .day], from: now)
        let nowNorm = cal.date(from: DateComponents(year: nowComps.year, month: nowComps.month))!
        
        var totalM = 1
        if hasEndDate { totalM = max(1, (cal.dateComponents([.month], from: startNorm, to: endNorm).month ?? 0) + 1) } else { totalM = 0 }
        
        var paidM = 0
        if nowNorm >= startNorm {
            paidM = (cal.dateComponents([.month], from: startNorm, to: nowNorm).month ?? 0)
            if (nowComps.day ?? 0) >= paymentDay { paidM += 1 }
            if hasEndDate && paidM > totalM { paidM = totalM }
        }
        
        var totalAmt = 0; var paidAmt = 0
        
        if hasEndDate {
            if fractionType == 1 { totalAmt = fractionAmount + max(0, totalM - 1) * amount } 
            else if fractionType == 2 { totalAmt = max(0, totalM - 1) * amount + fractionAmount } 
            else { totalAmt = totalM * amount }
        }
        
        for i in 0..<paidM {
            if i == 0 && fractionType == 1 { paidAmt += fractionAmount } 
            else if hasEndDate && i == (totalM - 1) && fractionType == 2 { paidAmt += fractionAmount } 
            else { paidAmt += amount }
        }
        
        let remAmt = hasEndDate ? max(0, totalAmt - paidAmt) : 0
        return (totalAmt, paidAmt, remAmt)
    }
}

extension Array: RawRepresentable where Element: Codable {
    public init?(rawValue: String) { guard let data = rawValue.data(using: .utf8), let result = try? JSONDecoder().decode([Element].self, from: data) else { return nil }; self = result }
    public var rawValue: String { guard let data = try? JSONEncoder().encode(self), let result = String(data: data, encoding: .utf8) else { return "[]" }; return result }
}

extension Int {
    var formattedWithComma: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
