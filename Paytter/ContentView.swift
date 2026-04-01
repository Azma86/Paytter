import SwiftUI
import Foundation
import UniformTypeIdentifiers

struct ContentView: View {
    @AppStorage("transactions_v4") var transactions: [Transaction] = []
    @AppStorage("accounts_v2") var accounts: [Account] = [
        Account(name: "お財布", balance: 0, type: .wallet),
        Account(name: "口座", balance: 0, type: .bank),
        Account(name: "ポイント", balance: 0, type: .point)
    ]
    @AppStorage("monthlyBudget") var monthlyBudget: Int = 50000
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    
    // --- テーマ設定データ ---
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_income") var themeIncome: String = "#FF19B219"
    @AppStorage("theme_expense") var themeExpense: String = "#FFFF3B30"
    @AppStorage("theme_holiday") var themeHoliday: String = "#FFFF3B30"
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_barBG") var themeBarBG: String = "#F8F8F8FF"
    @AppStorage("theme_barText") var themeBarText: String = "#FF000000"
    @AppStorage("theme_tabAccent") var themeTabAccent: String = "#FF007AFF"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"

    @State private var selection = 0
    @State private var isShowingInputSheet = false
    @State private var inputText: String = ""
    @State private var isShowingSwipeDeleteAlert = false
    @State private var transactionToDelete: Transaction?
    @State private var isShowingAccountCreator = false
    @State private var isShowingAccountDeleteAlert = false
    @State private var accountToDeleteIndex: IndexSet?
    
    @State private var isShowingResetAlert = false
    @State private var isShowingRestoreConfirm = false
    @State private var isShowingSaveConfirm = false
    @State private var isRestoringManual = false
    @State private var backupDateString = ""
    @State private var isShowingCompletionAlert = false
    @State private var completionMessage = ""
    @State private var isShowingImporter = false
    @State private var pendingImportData: ([Transaction], [Account], String)?
    @State private var isShowingImportConfirm = false

    let appearancePublisher = NotificationCenter.default.publisher(for: NSNotification.Name("UpdateAppearance"))

    var body: some View {
        ZStack {
            Color(hex: themeBG).ignoresSafeArea()
            TabView(selection: $selection) {
                homeTab.tag(0).tabItem { Label("ホーム", systemImage: "house") }
                calendarTab.tag(1).tabItem { Label("カレンダー", systemImage: "calendar") }
                walletTab.tag(2).tabItem { Label("お財布", systemImage: "wallet.pass") }
                settingTab.tag(3).tabItem { Label("設定", systemImage: "gearshape") }
            }
            .accentColor(Color(hex: themeTabAccent))
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .onAppear { recalculateBalances(); updateAppearance() }
        .onReceive(appearancePublisher) { _ in updateAppearance() }
        .onChange(of: themeBarBG) { _ in updateAppearance() }
        .onChange(of: isDarkMode) { _ in updateAppearance() }
        .sheet(isPresented: $isShowingInputSheet) { 
            PostView(inputText: $inputText, isPresented: $isShowingInputSheet, initialDate: Date(), onPost: { isInc, nDate in addTransaction(isInc: isInc, date: nDate) }, transactions: transactions, accounts: accounts) 
        }
    }

    private var homeTab: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                Color(hex: themeBG).ignoresSafeArea()
                VStack(spacing: 0) {
                    HStack(spacing: 15) {
                        ForEach(accounts.filter { $0.isVisible }) { acc in
                            BalanceView(title: acc.name, amount: acc.balance, color: Color(hex: themeBodyText), diff: acc.diffAmount)
                        }
                    }.padding().background(Color(hex: themeBarBG).opacity(0.8))
                    Divider()
                    List {
                        ForEach(transactions.sorted(by: { $0.date > $1.date })) { item in
                            ZStack {
                                NavigationLink(destination: TransactionDetailView(item: item, transactions: $transactions, accounts: $accounts)) { EmptyView() }.opacity(0)
                                TwitterRow(item: item)
                            }
                            .listRowInsets(EdgeInsets()).listRowBackground(Color(hex: themeBG))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button { transactionToDelete = item; isShowingSwipeDeleteAlert = true } label: { Text("削除") }.tint(.red)
                            }
                        }
                    }.listStyle(.plain).scrollContentBackground(.hidden)
                }
                Button(action: { inputText = ""; isShowingInputSheet = true }) {
                    Image(systemName: "plus").font(.system(size: 22, weight: .bold)).foregroundColor(.white).frame(width: 56, height: 56).background(Color(hex: themeMain)).clipShape(Circle())
                }.padding(20).padding(.bottom, 10)
            }
            .navigationTitle("ホーム").navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: themeBarBG), for: .navigationBar, .tabBar).toolbarBackground(.visible, for: .navigationBar, .tabBar)
            .alert("投稿を削除", isPresented: $isShowingSwipeDeleteAlert) {
                Button("キャンセル", role: .cancel) {}; Button("削除", role: .destructive) { if let t = transactionToDelete { transactions.removeAll(where: { $0.id == t.id }) } }
            }
        }
    }
    
    private var calendarTab: some View { NavigationView { CalendarView(transactions: $transactions, accounts: $accounts).navigationTitle("カレンダー").navigationBarTitleDisplayMode(.inline).toolbarBackground(Color(hex: themeBarBG), for: .navigationBar, .tabBar).toolbarBackground(.visible, for: .navigationBar, .tabBar) } }

    private var walletTab: some View { 
        NavigationView { 
            ZStack {
                Color(hex: themeBG).ignoresSafeArea()
                List { 
                    Section(header: Text("お財布の管理").foregroundColor(Color(hex: themeSubText))) { 
                        ForEach(Array(accounts.enumerated()), id: \.element.id) { index, acc in 
                            NavigationLink(destination: AccountEditView(account: $accounts[index], transactions: $transactions, allAccounts: accounts)) { 
                                HStack { Image(systemName: acc.type.icon).foregroundColor(Color(hex: themeBodyText).opacity(0.6)); Text(acc.name).foregroundColor(Color(hex: themeBodyText)); Spacer(); Text("¥\(acc.balance)").foregroundColor(Color(hex: themeBodyText).opacity(0.6)) } 
                            }.swipeActions(edge: .trailing, allowsFullSwipe: false) { Button { accountToDeleteIndex = IndexSet(integer: index); isShowingAccountDeleteAlert = true } label: { Text("削除") }.tint(.red) }
                        }
                        Button(action: { isShowingAccountCreator = true }) { Label("新しいお財布を追加", systemImage: "plus.circle") }.foregroundColor(Color(hex: themeMain))
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                }.scrollContentBackground(.hidden).listStyle(.insetGrouped) 
            }
            .navigationTitle("お財布").navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: themeBarBG), for: .navigationBar, .tabBar).toolbarBackground(.visible, for: .navigationBar, .tabBar)
            .sheet(isPresented: $isShowingAccountCreator) { AccountCreateView(accounts: $accounts, transactions: $transactions) }
            .alert("お財布の削除", isPresented: $isShowingAccountDeleteAlert) {
                Button("キャンセル", role: .cancel){}; Button("削除", role: .destructive){ if let o = accountToDeleteIndex { withAnimation { accounts.remove(atOffsets: o); recalculateBalances() } } }
            } message: { Text("金額計算に影響する可能性があります。") }
        } 
    }

    private var settingTab: some View { 
        NavigationView { 
            ZStack { 
                Color(hex: themeBG).ignoresSafeArea()
                List { 
                    Section(header: Text("カスタマイズ").foregroundColor(Color(hex: themeSubText))) { NavigationLink(destination: ThemeSettingView()) { Label("テーマ設定", systemImage: "paintpalette").foregroundColor(Color(hex: themeBodyText)) } }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    Section(header: Text("バックアップ管理").foregroundColor(Color(hex: themeSubText))) { 
                        Button("手動保存") { backupDateString = BackupManager.getBackupDate(isManual: true); isShowingSaveConfirm = true }.foregroundColor(Color(hex: themeBodyText))
                        Button("手動保存から復元") { isRestoringManual = true; backupDateString = BackupManager.getBackupDate(isManual: true); isShowingRestoreConfirm = true }.foregroundColor(Color(hex: themeBodyText))
                        Button("自動保存から復元") { isRestoringManual = false; backupDateString = BackupManager.getBackupDate(isManual: false); isShowingRestoreConfirm = true }.foregroundColor(Color(hex: themeBodyText))
                        Button("共有 (外部に書き出す)") { exportBackup() }.foregroundColor(Color(hex: themeMain))
                        Button("外部から読み込む") { isShowingImporter = true }.foregroundColor(Color(hex: themeMain))
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    Section(header: Text("データ管理").foregroundColor(Color(hex: themeSubText))) { Button("全データをリセット", role: .destructive) { isShowingResetAlert = true } }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                }.scrollContentBackground(.hidden).listStyle(.insetGrouped) 
            }
            .navigationTitle("設定").navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: themeBarBG), for: .navigationBar, .tabBar).toolbarBackground(.visible, for: .navigationBar, .tabBar)
            .alert("全リセット", isPresented: $isShowingResetAlert) { Button("キャンセル", role: .cancel) {}; Button("リセット", role: .destructive) { resetAll() } } message: { Text("全ての投稿とお財布設定を初期化します。") }
            .alert("復元", isPresented: $isShowingRestoreConfirm) { Button("キャンセル", role: .cancel) {}; Button("復元", role: .destructive) { if let t = BackupManager.loadTransactions(isManual: isRestoringManual), let a = BackupManager.loadAccounts(isManual: isRestoringManual) { transactions = t; accounts = a; recalculateBalances(); completionMessage = "復元完了"; isShowingCompletionAlert = true } } } message: { Text("\(isRestoringManual ? "手動":"自動")保存日時: \(backupDateString)") }
            .alert("外部読込", isPresented: $isShowingImportConfirm) { Button("キャンセル", role: .cancel) { pendingImportData = nil }; Button("復元", role: .destructive) { if let d = pendingImportData { transactions = d.0; accounts = d.1; recalculateBalances(); completionMessage = "読込完了"; isShowingCompletionAlert = true }; pendingImportData = nil } } message: { if let d = pendingImportData { Text("保存日時: \(d.2)") } }
            .alert("完了", isPresented: $isShowingCompletionAlert) { Button("OK"){} } message: { Text(completionMessage) }
            .fileImporter(isPresented: $isShowingImporter, allowedContentTypes: [.json]) { r in if case .success(let u) = r { if u.startAccessingSecurityScopedResource() { handleImport(from: u); u.stopAccessingSecurityScopedResource() } } }
        } 
    }

    func handleImport(from url: URL) {
        guard let data = try? Data(contentsOf: url), let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let txStr = json["transactions"] as? String, let accStr = json["accounts"] as? String, let dateStr = json["date"] as? String else { return }
        let dec = JSONDecoder(); if let t = try? dec.decode([Transaction].self, from: txStr.data(using: .utf8)!), let a = try? dec.decode([Account].self, from: accStr.data(using: .utf8)!) { self.pendingImportData = (t, a, dateStr); self.isShowingImportConfirm = true }
    }
    func resetAll() { transactions = []; accounts = [Account(name: "お財布", balance: 0, type: .wallet), Account(name: "口座", balance: 0, type: .bank), Account(name: "ポイント", balance: 0, type: .point)]; recalculateBalances(); completionMessage = "リセット完了"; isShowingCompletionAlert = true }
    func addTransaction(isInc: Bool, date: Date) { transactions.append(Transaction(amount: parseAmount(from: inputText), date: date, note: inputText, source: parseSourceName(from: inputText), isIncome: isInc)) }
    func recalculateBalances() { for i in 0..<accounts.count { var cur = 0; for tx in transactions where tx.source == accounts[i].name { cur += (tx.isIncome ? tx.amount : -tx.amount) }; accounts[i].diffAmount = cur - accounts[i].balance; accounts[i].balance = cur }; BackupManager.saveAll(transactions: transactions, accounts: accounts, isManual: false) }
    func parseAmount(from text: String) -> Int { text.components(separatedBy: .whitespacesAndNewlines).filter { $0.contains("¥") }.reduce(0) { $0 + (Int($1.replacingOccurrences(of: "¥", with: "")) ?? 0) } }
    func parseSourceName(from t: String) -> String { for acc in accounts { if t.contains("@\(acc.name)") { return acc.name } }; return accounts.first?.name ?? "お財布" }
    
    func exportBackup() {
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        let dict: [String: Any] = ["transactions": String(data: (try? encoder.encode(transactions)) ?? Data(), encoding: .utf8) ?? "", "accounts": String(data: (try? encoder.encode(accounts)) ?? Data(), encoding: .utf8) ?? "", "date": BackupManager.getBackupDate(isManual: true)]
        guard let finalData = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted) else { return }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("TwitterKakeibo_Backup.json")
        try? finalData.write(to: tempURL)
        let av = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene, let rootVC = scene.windows.first?.rootViewController {
            av.popoverPresentationController?.sourceView = rootVC.view
            av.popoverPresentationController?.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0, height: 0)
            rootVC.present(av, animated: true)
        }
    }

    func updateAppearance() {
        let bgColor = UIColor(Color(hex: themeBarBG)); let textColor = UIColor(Color(hex: themeBarText))
        let appearance = UINavigationBarAppearance(); appearance.configureWithOpaqueBackground(); appearance.backgroundColor = bgColor; appearance.titleTextAttributes = [.foregroundColor: textColor]
        UINavigationBar.appearance().standardAppearance = appearance; UINavigationBar.appearance().scrollEdgeAppearance = appearance
        let tabAppearance = UITabBarAppearance(); tabAppearance.configureWithOpaqueBackground(); tabAppearance.backgroundColor = bgColor
        UITabBar.appearance().standardAppearance = tabAppearance
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.windows.forEach { window in updateViewHierarchy(window.rootViewController); window.setNeedsLayout(); window.layoutIfNeeded() }
        }
    }

    private func updateViewHierarchy(_ vc: UIViewController?) {
        guard let vc = vc else { return }
        if let nav = vc as? UINavigationController { nav.navigationBar.standardAppearance = UINavigationBar.appearance().standardAppearance; nav.navigationBar.scrollEdgeAppearance = UINavigationBar.appearance().scrollEdgeAppearance; nav.navigationBar.setNeedsLayout(); nav.navigationBar.layoutIfNeeded() }
        if let tab = vc as? UITabBarController { tab.tabBar.standardAppearance = UITabBar.appearance().standardAppearance; if #available(iOS 15.0, *) { tab.tabBar.scrollEdgeAppearance = UITabBar.appearance().scrollEdgeAppearance } }
        vc.children.forEach { updateViewHierarchy($0) }
    }
}

// --- 部品（ここにあるColor拡張が正解です） ---
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
        let uic = UIColor(self)
        var r: CGFloat = 0; var g: CGFloat = 0; var b: CGFloat = 0; var a: CGFloat = 0
        uic.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X%02X", Int(a * 255), Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

struct BalanceView: View {
    let title: String; let amount: Int; let color: Color; let diff: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 10, weight: .bold)).foregroundColor(color.opacity(0.6))
            HStack(alignment: .bottom, spacing: 2) {
                Text("¥").font(.system(size: 10, weight: .bold)).foregroundColor(color).padding(.bottom, 2)
                Text("\(amount)").font(.system(size: 16, weight: .black, design: .rounded)).foregroundColor(color)
            }
            if diff != 0 { Text(diff > 0 ? "+\(diff)" : "\(diff)").font(.system(size: 8, weight: .bold, design: .rounded)).foregroundColor(diff > 0 ? .green : .red) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TwitterRow: View {
    let item: Transaction
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    @AppStorage("theme_income") var themeIncome: String = "#FF19B219"
    @AppStorage("theme_expense") var themeExpense: String = "#FFFF3B30"
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle().fill(Color(hex: themeMain)).frame(width: 44, height: 44).overlay(Text("M").foregroundColor(.white).fontWeight(.bold))
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("むつき").font(.subheadline).fontWeight(.bold).foregroundColor(Color(hex: themeBodyText))
                    Text("@mitsuki").font(.caption).foregroundColor(Color(hex: themeSubText))
                    Spacer(); Text(timeString(from: item.date)).font(.caption).foregroundColor(Color(hex: themeSubText))
                }
                Text(item.note).font(.body).foregroundColor(Color(hex: themeBodyText)).padding(.vertical, 2)
                HStack(spacing: 16) {
                    Label("\(item.amount)", systemImage: item.isIncome ? "arrow.up.right.circle" : "arrow.down.left.circle").foregroundColor(item.isIncome ? Color(hex: themeIncome) : Color(hex: themeExpense))
                    Label(item.source, systemImage: "wallet.pass")
                }.font(.caption).foregroundColor(Color(hex: themeSubText)).padding(.top, 2)
            }
        }.padding()
    }
    func timeString(from date: Date) -> String { let f = DateFormatter(); f.dateFormat = "H:mm"; return f.string(from: date) }
}

struct PostView: View {
    @Binding var inputText: String; @Binding var isPresented: Bool; let initialDate: Date; let onPost: (Bool, Date) -> Void; var transactions: [Transaction]; var accounts: [Account]
    @State private var postDate: Date = Date()
    var body: some View {
        NavigationView {
            VStack {
                TextField("今何してる？ (¥1000 @口座 #食費)", text: $inputText, axis: .vertical).textFieldStyle(.plain).padding().font(.body)
                DatePicker("日時", selection: $postDate).padding(); Spacer()
            }
            .navigationTitle("投稿する").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("キャンセル") { isPresented = false } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button("収入") { onPost(true, postDate); isPresented = false }.fontWeight(.bold)
                        Button("支出") { onPost(false, postDate); isPresented = false }.fontWeight(.bold)
                    }
                }
            }
        }.onAppear { postDate = initialDate }
    }
}
