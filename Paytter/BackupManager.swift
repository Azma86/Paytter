import Foundation

class BackupManager {
    static let transFile = "paytter_transactions.json"
    static let accountsFile = "paytter_accounts.json"
    
    static func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    static func saveAll(transactions: [Transaction], accounts: [Account]) {
        saveToFile(data: transactions, filename: transFile)
        saveToFile(data: accounts, filename: accountsFile)
    }
    
    private static func saveToFile<T: Encodable>(data: T, filename: String) {
        let url = getDocumentsDirectory().appendingPathComponent(filename)
        try? JSONEncoder().encode(data).write(to: url)
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
