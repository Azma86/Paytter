import Foundation
import SwiftUI

struct FullBackupData: Codable {
    var transactions: [Transaction]
    var accounts: [Account]
    var groups: [AccountGroup]
    var profiles: [UserProfile]
    var monthlyBudget: Int
    var isDarkMode: Bool
    var themeMain: String
    var themeIncome: String
    var themeExpense: String
    var themeHoliday: String
    var themeSaturday: String
    var themeBG: String
    var themeBarBG: String
    var themeBarText: String
    var themeTabAccent: String
    var themeBodyText: String
    var themeSubText: String
    var showTotalAssets: Bool
    var homeDisplayOrder: [String]
    var backupDate: String
}

class BackupManager {
    static let manualFile = "paytter_fullbackup_manual.json"
    static let autoFile = "paytter_fullbackup_auto.json"
    static let transAutoFile = "paytter_transactions_auto.json"
    static let accountsAutoFile = "paytter_accounts_auto.json"
    static let transManualFile = "paytter_transactions_manual.json"
    static let accountsManualFile = "paytter_accounts_manual.json"
    
    static func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    static func currentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return formatter.string(from: Date())
    }
    
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
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let date = attributes[.modificationDate] as? Date else { return "なし" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return formatter.string(from: date)
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
