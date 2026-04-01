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
    
    // テーマ設定
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
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
    
    // バックアップ用アラート管理
    @State private var isShowingResetAlert = false
    @State private var isShowingRestoreConfirm = false
    @State private var isShowingSaveConfirm = false
    @State private var isRestoringManual = false
    @State private var backupDateString = ""
    @State private var isShowingCompletionAlert = false
    @State private var completionMessage = ""

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
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToHomeTab"))) { _ in
                self.selection = 0
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .onAppear { recalculateBalances() }
        .onChange(of: transactions) { _ in recalculateBalances() }
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
            .alert("投稿を削除しますか？", isPresented: $isShowingSwipeDeleteAlert) {
                Button("キャンセル", role: .cancel) { transactionToDelete = nil }
                Button("削除", role: .destructive) { if let t = transactionToDelete { deleteSpecificTransaction(t) }; transactionToDelete = nil }
            } message: { if let t = transactionToDelete { Text(t.cleanNote) } }
        }
    }
    
    private var calendarTab: some View { NavigationView { CalendarView(transactions: $transactions, accounts: $accounts).navigationTitle("カレンダー").navigationBarTitleDisplayMode(.inline) } }

    private var walletTab: some View { 
        NavigationView { 
            ZStack {
                Color(hex: themeBG).ignoresSafeArea()
                List { 
                    Section(header: Text("お財布の管理")) { 
                        ForEach(Array(accounts.enumerated()), id: \.element.id) { index, acc in 
                            NavigationLink(destination: AccountEditView(account: $accounts[index], transactions: $transactions, allAccounts: accounts)) { 
                                HStack { Image(systemName: acc.type.icon).foregroundColor(.secondary); Text(acc.name); Spacer(); Text("¥\(acc.balance)").foregroundColor(.secondary) } 
                            }.swipeActions(edge: .trailing, allowsFullSwipe: false) { Button { accountToDeleteIndex = IndexSet(integer: index); isShowingAccountDeleteAlert = true } label: { Text("削除") }.tint(.red) }
                        }
                        Button(action: { isShowingAccountCreator = true }) { Label("新しいお財布を追加", systemImage: "plus.circle") }
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                }.scrollContentBackground(.hidden).listStyle(.insetGrouped) 
            }
            .navigationTitle("お財布")
            .sheet(isPresented: $isShowingAccountCreator) { AccountCreateView(accounts: $accounts, transactions: $transactions) }
            .alert("お財布を削除しますか？", isPresented: $isShowingAccountDeleteAlert) {
                Button("キャンセル", role: .cancel) { accountToDeleteIndex = nil }
                Button("削除", role: .destructive) { if let o = accountToDeleteIndex { withAnimation { accounts.remove(atOffsets: o); recalculateBalances() } }; accountToDeleteIndex = nil }
            }
        } 
    }

    private var settingTab: some View { 
        NavigationView { 
            List { 
                Section(header: Text("カスタマイズ")) { NavigationLink(destination: ThemeSettingView()) { Label("テーマ設定", systemImage: "paintpalette") } }
                Section(header: Text("予算設定")) { Stepper("今月の予算: ¥\(monthlyBudget)", value: $monthlyBudget, in: 1000...500000, step: 1000) }
                Section(header: Text("バックアップ管理")) { 
                    Button("手動バックアップを作成") { backupDateString = BackupManager.getBackupDate(isManual: true); isShowingSaveConfirm = true }
                    Button("手動バックアップから復元") { isRestoringManual = true; backupDateString = BackupManager.getBackupDate(isManual: true); isShowingRestoreConfirm = true }
                    Button("自動保存から復元") { isRestoringManual = false; backupDateString = BackupManager.getBackupDate(isManual: false); isShowingRestoreConfirm = true }
                }
                Section(header: Text("データ管理")) { Button("全データをリセット", role: .destructive) { isShowingResetAlert = true } }
            }
            .navigationTitle("設定")
            .alert("バックアップの上書き", isPresented: $isShowingSaveConfirm) {
                Button("キャンセル", role: .cancel) { }
                Button("上書き保存") { BackupManager.saveAll(transactions: transactions, accounts: accounts, isManual: true); completionMessage = "手動バックアップの保存が完了しました。"; isShowingCompletionAlert = true }
            } message: { Text("前回保存: \(backupDateString)\n現在のお財布設定と投稿を保存しますか？") }
            .alert("バックアップの復元", isPresented: $isShowingRestoreConfirm) {
                Button("キャンセル", role: .cancel) { }
                Button("復元する", role: .destructive) { 
                    if let t = BackupManager.loadTransactions(isManual: isRestoringManual), let a = BackupManager.loadAccounts(isManual: isRestoringManual) { 
                        transactions = t; accounts = a; recalculateBalances() 
                        completionMessage = "復元が完了しました。"; isShowingCompletionAlert = true
                    } 
                }
            } message: { Text("\(isRestoringManual ? "手動":"自動")保存日時: \(backupDateString)\n現在のデータを上書きしますか？") }
            .alert("リセット", isPresented: $isShowingResetAlert) {
                Button("キャンセル", role: .cancel) { }; Button("初期化する", role: .destructive) { resetAll(); completionMessage = "リセットしました。"; isShowingCompletionAlert = true }
            }
            .alert("完了", isPresented: $isShowingCompletionAlert) { Button("OK") { } } message: { Text(completionMessage) }
        } 
    }

    func addTransaction(isInc: Bool, date: Date) { transactions.append(Transaction(amount: parseAmount(from: inputText), date: date, note: inputText, source: parseSourceName(from: inputText), isIncome: isInc)) }
    func deleteSpecificTransaction(_ target: Transaction) { if let index = transactions.firstIndex(where: { $0.id == target.id }) { transactions.remove(at: index) } }
    func recalculateBalances() { 
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            for i in 0..<accounts.count { 
                var cur = 0; for tx in transactions where tx.source == accounts[i].name { cur += (tx.isIncome ? tx.amount : -tx.amount) }
                let diff = cur - accounts[i].balance
                if diff != 0 { accounts[i].diffAmount = diff }
                accounts[i].balance = cur 
            }
        }
        BackupManager.saveAll(transactions: transactions, accounts: accounts, isManual: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.4)) { for i in 0..<accounts.count { accounts[i].diffAmount = 0 } }
        }
    }
    func resetAll() { transactions = []; accounts = [Account(name: "お財布", balance: 0, type: .wallet), Account(name: "口座", balance: 0, type: .bank), Account(name: "ポイント", balance: 0, type: .point)]; monthlyBudget = 50000 }
    func parseAmount(from text: String) -> Int { text.components(separatedBy: .whitespacesAndNewlines).filter { $0.contains("¥") }.reduce(0) { $0 + (Int($1.replacingOccurrences(of: "¥", with: "")) ?? 0) } }
    func parseSourceName(from t: String) -> String { for acc in accounts { if t.contains("@\(acc.name)") { return acc.name } }; return accounts.first?.name ?? "お財布" }

    func updateAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color(hex: themeBarBG))
        appearance.titleTextAttributes = [.foregroundColor: UIColor(Color(hex: themeBarText))]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
}
