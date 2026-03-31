import SwiftUI
import Foundation

struct ContentView: View {
    @AppStorage("transactions_v4") var transactions: [Transaction] = []
    @AppStorage("accounts_v2") var accounts: [Account] = [
        Account(name: "お財布", balance: 0, type: .wallet),
        Account(name: "口座", balance: 0, type: .bank),
        Account(name: "ポイント", balance: 0, type: .point)
    ]
    @AppStorage("monthlyBudget") var monthlyBudget: Int = 50000
    @AppStorage("app_theme") var theme = AppTheme() // テーマ取得
    
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

    var body: some View {
        TabView {
            homeTab.tabItem { Label("ホーム", systemImage: "house") }
            calendarTab.tabItem { Label("カレンダー", systemImage: "calendar") }
            walletTab.tabItem { Label("お財布", systemImage: "wallet.pass") }
            settingTab.tabItem { Label("設定", systemImage: "gearshape") }
        }
        .onAppear { recalculateBalances() }
        .onChange(of: transactions) { _ in recalculateBalances() }
        .sheet(isPresented: $isShowingInputSheet) { 
            PostView(inputText: $inputText, isPresented: $isShowingInputSheet, initialDate: Date(), onPost: { isInc, nDate in addTransaction(isInc: isInc, date: nDate) }, transactions: transactions, accounts: accounts) 
        }
    }

    private var homeTab: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    HStack(spacing: 15) {
                        ForEach(accounts.filter { $0.isVisible }) { acc in
                            BalanceView(title: acc.name, amount: acc.balance, color: .primary, diff: acc.diffAmount)
                        }
                    }.padding().background(Color(.systemGray6))
                    Divider()
                    List {
                        ForEach(transactions.sorted(by: { $0.date > $1.date })) { item in
                            ZStack {
                                NavigationLink(destination: TransactionDetailView(item: item, transactions: $transactions, accounts: $accounts)) { EmptyView() }.opacity(0)
                                TwitterRow(item: item)
                            }
                            .listRowInsets(EdgeInsets())
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button { transactionToDelete = item; isShowingSwipeDeleteAlert = true } label: { Text("削除") }.tint(.red)
                            }
                        }
                    }.listStyle(.plain)
                }
                Button(action: { inputText = ""; isShowingInputSheet = true }) {
                    Image(systemName: "plus").font(.system(size: 22, weight: .bold)).foregroundColor(.white).frame(width: 56, height: 56).background(theme.mainColor).clipShape(Circle())
                }.padding(20).padding(.bottom, 10)
            }
            .navigationTitle("ホーム").navigationBarTitleDisplayMode(.inline)
            .alert("投稿を削除しますか？", isPresented: $isShowingSwipeDeleteAlert) {
                Button("キャンセル", role: .cancel) { transactionToDelete = nil }
                Button("削除", role: .destructive) { if let t = transactionToDelete, let idx = transactions.firstIndex(where: { $0.id == t.id }) { withAnimation(.easeOut(duration: 0.2)) { transactions.remove(at: idx) } }; transactionToDelete = nil }
            } message: { if let t = transactionToDelete { Text(t.cleanNote) } }
        }
    }
    
    private var calendarTab: some View { NavigationView { CalendarView(transactions: $transactions, accounts: $accounts) } }
    private var walletTab: some View { NavigationView { List { Section(header: Text("お財布の管理")) { ForEach(Array(accounts.enumerated()), id: \.element.id) { index, acc in NavigationLink(destination: AccountEditView(account: $accounts[index], transactions: $transactions, allAccounts: accounts)) { HStack { Image(systemName: acc.type.icon).foregroundColor(.secondary); Text(acc.name); Spacer(); Text("¥\(acc.balance)").foregroundColor(.secondary) } }.swipeActions(edge: .trailing, allowsFullSwipe: false) { Button { accountToDeleteIndex = IndexSet(integer: index); isShowingAccountDeleteAlert = true } label: { Text("削除") }.tint(.red) } }; Button(action: { isShowingAccountCreator = true }) { Label("新しいお財布を追加", systemImage: "plus.circle") } }; Section(header: Text("分析")) { NavigationLink(destination: WalletAnalysisView(transactions: transactions)) { Label("今月の収支分析", systemImage: "chart.bar.xaxis") } } }.navigationTitle("お財布").sheet(isPresented: $isShowingAccountCreator) { AccountCreateView(accounts: $accounts, transactions: $transactions) }.alert("お財布を削除しますか？", isPresented: $isShowingAccountDeleteAlert) { Button("キャンセル", role: .cancel) { }; Button("削除", role: .destructive) { if let o = accountToDeleteIndex { withAnimation { accounts.remove(atOffsets: o); recalculateBalances() } } } } message: { Text("金額計算に影響が出る可能性があります。") } } }

    private var settingTab: some View {
        NavigationView {
            List {
                Section(header: Text("テーマ設定")) {
                    ColorPicker("メインカラー", selection: $theme.mainColor)
                    ColorPicker("収入の色", selection: $theme.incomeColor)
                    ColorPicker("支出の色", selection: $theme.expenseColor)
                    ColorPicker("祝日の色", selection: $theme.holidayColor)
                }
                Section(header: Text("予算設定")) { Stepper("今月の予算: ¥\(monthlyBudget)", value: $monthlyBudget, in: 1000...500000, step: 1000) }
                Section(header: Text("バックアップ")) {
                    Button("手動保存") { backupDateString = BackupManager.getBackupDate(isManual: true); isShowingSaveConfirm = true }
                    Button("復元") { isRestoringManual = true; backupDateString = BackupManager.getBackupDate(isManual: true); isShowingRestoreConfirm = true }
                }
                Section(header: Text("データ")) { Button("全リセット", role: .destructive) { isShowingResetAlert = true } }
            }
            .navigationTitle("設定")
            .alert("バックアップ保存", isPresented: $isShowingSaveConfirm) { Button("キャンセル", role: .cancel) { }; Button("保存") { BackupManager.saveAll(transactions: transactions, accounts: accounts, isManual: true); completionMessage = "完了しました"; isShowingCompletionAlert = true } }
            .alert("全リセット", isPresented: $isShowingResetAlert) { Button("キャンセル", role: .cancel) { }; Button("リセット", role: .destructive) { transactions = []; accounts = [Account(name: "お財布", balance: 0, type: .wallet)]; monthlyBudget = 50000 } }
        }
    }

    func addTransaction(isInc: Bool, date: Date) { transactions.append(Transaction(amount: parseAmount(from: inputText), date: date, note: inputText, source: parseSourceName(from: inputText), isIncome: isInc)) }
    func recalculateBalances() { for i in 0..<accounts.count { var cur = 0; for tx in transactions where tx.source == accounts[i].name { cur += (tx.isIncome ? tx.amount : -tx.amount) }; accounts[i].diffAmount = cur - accounts[i].balance; accounts[i].balance = cur }; BackupManager.saveAll(transactions: transactions, accounts: accounts, isManual: false) }
    func parseAmount(from text: String) -> Int { text.components(separatedBy: .whitespacesAndNewlines).filter { $0.contains("¥") }.reduce(0) { $0 + (Int($1.replacingOccurrences(of: "¥", with: "")) ?? 0) } }
    func parseSourceName(from t: String) -> String { for acc in accounts { if t.contains("@\(acc.name)") { return acc.name } }; return accounts.first?.name ?? "お財布" }
}
