import Foundation

class BackupManager {
    static let transFile = "paytter_transactions.json"
    static let accountsFile = "paytter_accounts.json"
    
    static func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    static func saveAll(transactions: [Transaction], accounts: [Account]) {
        let encoder = JSONEncoder()
        let tUrl = getDocumentsDirectory().appendingPathComponent(transFile)
        let aUrl = getDocumentsDirectory().appendingPathComponent(accountsFile)
        try? encoder.encode(transactions).write(to: tUrl)
        try? encoder.encode(accounts).write(to: aUrl)
    }
    
    static func loadTransactions() -> [Transaction]? {
        let url = getDocumentsDirectory().appendingPathComponent(transFile)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([Transaction].self, from: data)
    }
    
    static func loadAccounts() -> [Account]? {
        let url = getDocumentsDirectory().appendingPathComponent(accountsFile)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([Account].self, from: data)
    }
}
