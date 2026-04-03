import SwiftUI
import UniformTypeIdentifiers

struct SettingView: View {
    @Binding var transactions: [Transaction]
    @Binding var accounts: [Account]
    @Binding var groups: [AccountGroup]
    
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_barBG") var themeBarBG: String = "#F8F8F8FF"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    @AppStorage("monthlyBudget") var monthlyBudget: Int = 50000
    
    @State private var activeAlert: ActiveAlert?
    @State private var isRestoringManual = false
    @State private var backupDateString = ""
    @State private var isShowingImporter = false
    @State private var pendingImportData: ([Transaction], [Account], String)?

    var body: some View {
        NavigationView { 
            ZStack { 
                Color(hex: themeBG).ignoresSafeArea()
                List { 
                    Section(header: Text("カスタマイズ").foregroundColor(Color(hex: themeSubText))) { 
                        NavigationLink(destination: UserProfileSettingView()) { Label("表示ユーザー設定", systemImage: "person.crop.circle").foregroundColor(Color(hex: themeBodyText)) }
                        NavigationLink(destination: ThemeSettingView()) { Label("テーマ設定", systemImage: "paintpalette").foregroundColor(Color(hex: themeBodyText)) } 
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    Section(header: Text("予算設定").foregroundColor(Color(hex: themeSubText))) { Stepper("今月の予算: ¥\(monthlyBudget)", value: $monthlyBudget, in: 1000...500000, step: 1000).foregroundColor(Color(hex: themeBodyText)) }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    Section(header: Text("バックアップ管理").foregroundColor(Color(hex: themeSubText))) { 
                        Button("手動保存") { backupDateString = BackupManager.getBackupDate(isManual: true); activeAlert = .save }.foregroundColor(Color(hex: themeBodyText))
                        Button("手動保存から復元") { isRestoringManual = true; backupDateString = BackupManager.getBackupDate(isManual: true); activeAlert = .restore }.foregroundColor(Color(hex: themeBodyText))
                        Button("自動保存から復元") { isRestoringManual = false; backupDateString = BackupManager.getBackupDate(isManual: false); activeAlert = .restore }.foregroundColor(Color(hex: themeBodyText))
                        Button("バックアップを共有 (外部に書き出す)") { exportBackup() }.foregroundColor(Color(hex: themeMain))
                        Button("外部から読み込む") { isShowingImporter = true }.foregroundColor(Color(hex: themeMain))
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    Section(header: Text("データ管理").foregroundColor(Color(hex: themeSubText))) { Button("全データをリセット", role: .destructive) { activeAlert = .reset } }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                }.scrollContentBackground(.hidden).listStyle(.insetGrouped) 
            }
            .navigationTitle("設定").navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: themeBarBG), for: .navigationBar, .tabBar).toolbarBackground(.visible, for: .navigationBar, .tabBar)
            .fileImporter(isPresented: $isShowingImporter, allowedContentTypes: [.json]) { r in if case .success(let u) = r { if u.startAccessingSecurityScopedResource() { handleImport(from: u); u.stopAccessingSecurityScopedResource() } } }
        }
        .alert(item: $activeAlert) { type in
            switch type {
            case .reset:
                return Alert(title: Text("全リセット"), message: Text("全ての投稿とお財布設定を初期化します。"), primaryButton: .destructive(Text("リセット")) { resetAll() }, secondaryButton: .cancel(Text("キャンセル")))
            case .restore:
                return Alert(title: Text("バックアップの復元"), message: Text("\(isRestoringManual ? "手動":"自動")保存日時: \(backupDateString)\nデータを復元しますか？"), primaryButton: .destructive(Text("復元")) {
                    if let t = BackupManager.loadTransactions(isManual: isRestoringManual), let a = BackupManager.loadAccounts(isManual: isRestoringManual) {
                        transactions = t; accounts = a; activeAlert = .completion("復元完了")
                    }
                }, secondaryButton: .cancel(Text("キャンセル")))
            case .save:
                return Alert(title: Text("バックアップの保存"), message: Text("現在の手動保存日時: \(backupDateString)\n現在のデータで上書きしますか？"), primaryButton: .default(Text("保存")) {
                    BackupManager.saveAll(transactions: transactions, accounts: accounts, isManual: true); activeAlert = .completion("保存完了")
                }, secondaryButton: .cancel(Text("キャンセル")))
            case .importConfirm:
                return Alert(title: Text("外部データの読込"), message: Text("保存日時: \(pendingImportData?.2 ?? "")\nデータを上書きしますか？"), primaryButton: .destructive(Text("読み込む")) {
                    if let d = pendingImportData { transactions = d.0; accounts = d.1; activeAlert = .completion("読込完了") }; pendingImportData = nil
                }, secondaryButton: .cancel(Text("キャンセル")) { pendingImportData = nil })
            case .completion(let msg):
                return Alert(title: Text("完了"), message: Text(msg), dismissButton: .default(Text("OK")))
            }
        }
    }
    
    func resetAll() { transactions = []; accounts = [Account(name: "お財布", balance: 0, type: .wallet), Account(name: "口座", balance: 0, type: .bank), Account(name: "ポイント", balance: 0, type: .point)]; groups = []; monthlyBudget = 50000; activeAlert = .completion("リセット完了") }
    
    func handleImport(from url: URL) {
        guard let data = try? Data(contentsOf: url), let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let txStr = json["transactions"] as? String, let accStr = json["accounts"] as? String, let dateStr = json["date"] as? String else { return }
        let dec = JSONDecoder(); if let t = try? dec.decode([Transaction].self, from: txStr.data(using: .utf8)!), let a = try? dec.decode([Account].self, from: accStr.data(using: .utf8)!) { self.pendingImportData = (t, a, dateStr); self.activeAlert = .importConfirm }
    }
    
    func exportBackup() {
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        let dict: [String: Any] = ["transactions": String(data: (try? encoder.encode(transactions)) ?? Data(), encoding: .utf8) ?? "", "accounts": String(data: (try? encoder.encode(accounts)) ?? Data(), encoding: .utf8) ?? "", "date": BackupManager.getBackupDate(isManual: true)]
        guard let finalData = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted) else { return }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Paytter_Backup.json")
        try? finalData.write(to: tempURL)
        let av = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene, let rootVC = scene.windows.first?.rootViewController {
            av.popoverPresentationController?.sourceView = rootVC.view
            rootVC.present(av, animated: true)
        }
    }
}
