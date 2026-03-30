import Foundation

class BackupManager {
    static let transAutoFile = "paytter_transactions_auto.json"
    static let accountsAutoFile = "paytter_accounts_auto.json"
    static let transManualFile = "paytter_transactions_manual.json"
    static let accountsManualFile = "paytter_accounts_manual.json"
    
    static func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    // 保存処理（isManualがtrueなら手動用、falseなら自動用ファイルへ）
    static func saveAll(transactions: [Transaction], accounts: [Account], isManual: Bool) {
        let encoder = JSONEncoder()
        let tName = isManual ? transManualFile : transAutoFile
        let aName = isManual ? accountsManualFile : accountsAutoFile
        
        let tUrl = getDocumentsDirectory().appendingPathComponent(tName)
        let aUrl = getDocumentsDirectory().appendingPathComponent(aName)
        
        try? encoder.encode(transactions).write(to: tUrl)
        try? encoder.encode(accounts).write(to: aUrl)
    }
    
    // 指定したファイルの最終更新日時を取得
    static func getBackupDate(isManual: Bool) -> String {
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
