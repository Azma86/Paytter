import Foundation

class BackupManager {
    static let filename = "paytter_backup.json"
    
    static func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    static func saveToFile(transactions: [Transaction]) {
        let url = getDocumentsDirectory().appendingPathComponent(filename)
        do {
            let data = try JSONEncoder().encode(transactions)
            try data.write(to: url, options: [.atomicWrite, .completeFileProtection])
        } catch {
            print("Failed to save backup: \(error.localizedDescription)")
        }
    }
    
    static func loadFromFile() -> [Transaction]? {
        let url = getDocumentsDirectory().appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([Transaction].self, from: data)
        } catch {
            print("Failed to load backup: \(error.localizedDescription)")
            return nil
        }
    }
}
