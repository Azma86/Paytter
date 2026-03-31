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
    
    // --- 外観設定 ---
    @AppStorage("isDarkMode") var isDarkMode: Bool = false // ダークモード切替用
    
    // --- テーマ設定データ ---
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_income") var themeIncome: String = "#FF19B219"
    @AppStorage("theme_expense") var themeExpense: String = "#FFFF3B30"
    @AppStorage("theme_holiday") var themeHoliday: String = "#FFFF3B30"
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_barBG") var themeBarBG: String = "#F8F8F8FF"
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

    var body: some View {
        TabView(selection: $selection) {
            homeTab.tag(0).tabItem { Label("ホーム", systemImage: "house") }
            calendarTab.tag(1).tabItem { Label("カレンダー", systemImage: "calendar") }
            walletTab.tag(2).tabItem { Label("お財布", systemImage: "wallet.pass") }
            settingTab.tag(3).tabItem { Label("設定", systemImage: "gearshape") }
        }
        .accentColor(Color(hex: themeTabAccent))
        // ここでダークモードを強制適用
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .onAppear { recalculateBalances(); updateAppearance() }
        .onChange(of: transactions) { _ in recalculateBalances() }
        .onChange(of: isDarkMode) { _ in updateAppearance() } // モード変更時にバーの色を更新
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
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color(hex: themeBG))
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
            .toolbarBackground(Color(hex: themeBarBG), for: .navigationBar, .tabBar)
            .toolbarBackground(.visible, for: .navigationBar, .tabBar)
            .alert("削除", isPresented: $isShowingSwipeDeleteAlert) {
                Button("削除", role: .destructive) { if let t = transactionToDelete { deleteSpecificTransaction(t) } }
                Button("キャンセル", role: .cancel) {}
            }
        }
    }
    
    private var calendarTab: some View { NavigationView { CalendarView(transactions: $transactions, accounts: $accounts).toolbarBackground(Color(hex: themeBarBG), for: .navigationBar, .tabBar).toolbarBackground(.visible, for: .navigationBar, .tabBar) } }

    private var walletTab: some View { 
        NavigationView { 
            ZStack {
                Color(hex: themeBG).ignoresSafeArea()
                List { 
                    Section(header: Text("お財布の管理").foregroundColor(Color(hex: themeSubText))) { 
                        ForEach(Array(accounts.enumerated()), id: \.element.id) { index, acc in 
                            NavigationLink(destination: AccountEditView(account: $accounts[index], transactions: $transactions, allAccounts: accounts)) { 
                                HStack { 
                                    Image(systemName: acc.type.icon).foregroundColor(Color(hex: themeBodyText).opacity(0.6))
                                    Text(acc.name).foregroundColor(Color(hex: themeBodyText))
                                    Spacer()
                                    Text("¥\(acc.balance)").foregroundColor(Color(hex: themeBodyText).opacity(0.6))
                                } 
                            }.swipeActions(edge: .trailing, allowsFullSwipe: false) { 
                                Button { accountToDeleteIndex = IndexSet(integer: index); isShowingAccountDeleteAlert = true } label: { Text("削除") }.tint(.red) 
                            } 
                        }
                        Button(action: { isShowingAccountCreator = true }) { Label("新しいお財布を追加", systemImage: "plus.circle") }.foregroundColor(Color(hex: themeMain))
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    Section(header: Text("分析").foregroundColor(Color(hex: themeSubText))) { 
                        NavigationLink(destination: WalletAnalysisView(transactions: transactions)) { 
                            Label("今月の収支分析", systemImage: "chart.bar.xaxis").foregroundColor(Color(hex: themeBodyText))
                        } 
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5)) 
                }.scrollContentBackground(.hidden).listStyle(.insetGrouped) 
            }
            .navigationTitle("お財布")
            .toolbarBackground(Color(hex: themeBarBG), for: .navigationBar, .tabBar)
            .toolbarBackground(.visible, for: .navigationBar, .tabBar)
            .sheet(isPresented: $isShowingAccountCreator) { AccountCreateView(accounts: $accounts, transactions: $transactions) }
            .alert("削除", isPresented: $isShowingAccountDeleteAlert) {
                Button("キャンセル", role: .cancel){}; Button("削除", role: .destructive){ if let o = accountToDeleteIndex { withAnimation { accounts.remove(atOffsets: o); recalculateBalances() } } }
            } 
        } 
    }

    private var settingTab: some View { 
        NavigationView { 
            ZStack { 
                Color(hex: themeBG).ignoresSafeArea()
                List { 
                    Section(header: Text("カスタマイズ").foregroundColor(Color(hex: themeSubText))) { 
                        NavigationLink(destination: ThemeSettingView()) { Label("テーマ設定", systemImage: "paintpalette").foregroundColor(Color(hex: themeBodyText)) } 
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    Section(header: Text("予算設定").foregroundColor(Color(hex: themeSubText))) { 
                        Stepper(value: $monthlyBudget, in: 1000...500000, step: 1000) { Text("今月の予算: ¥\(monthlyBudget)").foregroundColor(Color(hex: themeBodyText)) } 
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    Section(header: Text("バックアップ管理").foregroundColor(Color(hex: themeSubText))) { 
                        Button("手動保存") { backupDateString = BackupManager.getBackupDate(isManual: true); isShowingSaveConfirm = true }.foregroundColor(Color(hex: themeBodyText))
                        Button("復元") { isRestoringManual = true; backupDateString = BackupManager.getBackupDate(isManual: true); isShowingRestoreConfirm = true }.foregroundColor(Color(hex: themeBodyText))
                        Button("共有 (外部に書き出す)") { exportBackup() }.foregroundColor(Color(hex: themeMain))
                        Button("外部から読み込む") { isShowingImporter = true }.foregroundColor(Color(hex: themeMain))
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    Section(header: Text("データ管理").foregroundColor(Color(hex: themeSubText))) { 
                        Button("全データをリセット", role: .destructive) { isShowingResetAlert = true } 
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5)) 
                }.scrollContentBackground(.hidden).listStyle(.insetGrouped) 
            }
            .navigationTitle("設定")
            .alert("保存", isPresented: $isShowingSaveConfirm) { Button("保存"){ BackupManager.saveAll(transactions: transactions, accounts: accounts, isManual: true); completionMessage = "保存完了"; isShowingCompletionAlert = true }; Button("キャンセル", role:.cancel){} }
            .alert("復元", isPresented: $isShowingRestoreConfirm) { Button("復元", role: .destructive) { if let t = BackupManager.loadTransactions(isManual: isRestoringManual), let a = BackupManager.loadAccounts(isManual: isRestoringManual) { transactions = t; accounts = a; recalculateBalances(); completionMessage = "復元完了"; isShowingCompletionAlert = true } }; Button("キャンセル", role: .cancel){} }
            .alert("リセット", isPresented: $isShowingResetAlert) { Button("初期化", role: .destructive) { resetAll(); completionMessage = "リセット完了"; isShowingCompletionAlert = true }; Button("キャンセル", role: .cancel){} }
            .alert("完了", isPresented: $isShowingCompletionAlert) { Button("OK"){} } message: { Text(completionMessage) }
            .fileImporter(isPresented: $isShowingImporter, allowedContentTypes: [.json]) { result in 
                switch result { 
                case .success(let url): if url.startAccessingSecurityScopedResource() { handleImport(from: url); url.stopAccessingSecurityScopedResource() }; 
                case .failure(let e): print(e.localizedDescription) 
                } 
            }
        } 
    }

    // --- 関数 ---
    func handleImport(from url: URL) { guard let data = try? Data(contentsOf: url), let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let txStr = json["transactions"] as? String, let accStr = json["accounts"] as? String, let dateStr = json["date"] as? String else { return }; let dec = JSONDecoder(); if let t = try? dec.decode([Transaction].self, from: txStr.data(using: .utf8)!), let a = try? dec.decode([Account].self, from: accStr.data(using: .utf8)!) { self.pendingImportData = (t, a, dateStr); self.isShowingImportConfirm = true } }
    func addTransaction(isInc: Bool, date: Date) { transactions.append(Transaction(amount: parseAmount(from: inputText), date: date, note: inputText, source: parseSourceName(from: inputText), isIncome: isInc)) }
    func deleteSpecificTransaction(_ target: Transaction) { if let index = transactions.firstIndex(where: { $0.id == target.id }) { transactions.remove(at: index) } }
    func recalculateBalances() { for i in 0..<accounts.count { var cur = 0; for tx in transactions where tx.source == accounts[i].name { cur += (tx.isIncome ? tx.amount : -tx.amount) }; accounts[i].diffAmount = cur - accounts[i].balance; accounts[i].balance = cur }; BackupManager.saveAll(transactions: transactions, accounts: accounts, isManual: false) }
    func parseAmount(from text: String) -> Int { text.components(separatedBy: .whitespacesAndNewlines).filter { $0.contains("¥") }.reduce(0) { $0 + (Int($1.replacingOccurrences(of: "¥", with: "")) ?? 0) } }
    func parseSourceName(from t: String) -> String { for acc in accounts { if t.contains("@\(acc.name)") { return acc.name } }; return accounts.first?.name ?? "お財布" }
    func exportBackup() { let fileName = "Paytter_Backup.json"; let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName); BackupManager.saveAll(transactions: transactions, accounts: accounts, isManual: true); let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName); try? FileManager.default.removeItem(at: tempURL); try? FileManager.default.copyItem(at: path, to: tempURL); let itemSource = DocumentItemSource(fileURL: tempURL); let av = UIActivityViewController(activityItems: [itemSource], applicationActivities: nil); if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene, let rootVC = scene.windows.first?.rootViewController { av.popoverPresentationController?.sourceView = rootVC.view; rootVC.present(av, animated: true) } }

    func updateAppearance() {
        let bgColor = UIColor(Color(hex: themeBarBG))
        let navBarAppearance = UINavigationBarAppearance(); navBarAppearance.configureWithOpaqueBackground(); navBarAppearance.backgroundColor = bgColor
        // モードに応じて文字色を自動セット（手動指定はやめました）
        UINavigationBar.appearance().standardAppearance = navBarAppearance; UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        let tabBarAppearance = UITabBarAppearance(); tabBarAppearance.configureWithOpaqueBackground(); tabBarAppearance.backgroundColor = bgColor
        UITabBar.appearance().standardAppearance = tabBarAppearance
    }
}
