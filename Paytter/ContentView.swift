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
    
    @State private var isShowingInputSheet = false
    @State private var inputText: String = ""
    @State private var isShowingSwipeDeleteAlert = false
    @State private var transactionToDelete: Transaction?
    
    @State private var isShowingAccountCreator = false
    @State private var isShowingAccountDeleteAlert = false
    @State private var accountToDeleteIndex: IndexSet?
    
    @State private var isShowingRestoreConfirm = false
    @State private var isShowingSaveConfirm = false
    @State private var isRestoringManual = false
    @State private var backupDateString = ""
    @State private var isShowingCompletionAlert = false
    @State private var completionMessage = ""

    var displayedTransactions: [Transaction] {
        transactions.sorted(by: { $0.date > $1.date })
    }

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
                        ForEach(displayedTransactions, id: \.id) { item in
                            ZStack {
                                // リンクを透明にして背面に配置（ガタつき防止）
                                NavigationLink(destination: TransactionDetailView(item: item, transactions: $transactions, accounts: $accounts)) {
                                    EmptyView()
                                }.opacity(0)
                                
                                TwitterRow(item: item)
                            }
                            .listRowInsets(EdgeInsets())
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    // ここでの自動スワイプ閉じを抑えるため、即座にアラートを表示
                                    transactionToDelete = item
                                    isShowingSwipeDeleteAlert = true
                                } label: {
                                    Text("削除")
                                }
                            }
                        }
                    }.listStyle(.plain)
                }
                Button(action: { inputText = ""; isShowingInputSheet = true }) {
                    Image(systemName: "plus").font(.system(size: 22, weight: .bold)).foregroundColor(.white).frame(width: 56, height: 56).background(Color.blue).clipShape(Circle())
                }.padding(20).padding(.bottom, 10)
            }
            .navigationTitle("ホーム").navigationBarTitleDisplayMode(.inline)
            .alert("投稿を削除しますか？", isPresented: $isShowingSwipeDeleteAlert) {
                Button("キャンセル", role: .cancel) { transactionToDelete = nil }
                Button("削除", role: .destructive) { 
                    if let t = transactionToDelete { 
                        // 削除時のみアニメーション
                        withAnimation(.easeOut) { deleteSpecificTransaction(t) } 
                    }
                    transactionToDelete = nil 
                }
            } message: { if let t = transactionToDelete { Text(t.cleanNote) } }
        }
    }
    
    private var calendarTab: some View {
        NavigationView {
            CalendarView(transactions: $transactions, accounts: $accounts)
        }
    }

    private var walletTab: some View {
        NavigationView {
            List {
                Section(header: Text("お財布の管理")) {
                    ForEach(Array(accounts.enumerated()), id: \.element.id) { index, acc in
                        NavigationLink(destination: AccountEditView(account: $accounts[index], transactions: $transactions, allAccounts: accounts)) {
                            HStack {
                                Image(systemName: acc.type.icon).foregroundColor(.secondary)
                                Text(acc.name)
                                Spacer()
                                Text("¥\(acc.balance)").foregroundColor(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                accountToDeleteIndex = IndexSet(integer: index)
                                isShowingAccountDeleteAlert = true
                            } label: {
                                Text("削除")
                            }
                        }
                    }
                    Button(action: { isShowingAccountCreator = true }) { Label("新しいお財布を追加", systemImage: "plus.circle") }
                }
                Section(header: Text("分析")) {
                    NavigationLink(destination: WalletAnalysisView(transactions: transactions)) { Label("今月の収支分析", systemImage: "chart.bar.xaxis") }
                }
            }
            .navigationTitle("お財布")
            .sheet(isPresented: $isShowingAccountCreator) { AccountCreateView(accounts: $accounts, transactions: $transactions) }
            .alert("お財布を削除しますか？", isPresented: $isShowingAccountDeleteAlert) {
                Button("キャンセル", role: .cancel) { accountToDeleteIndex = nil }
                Button("削除", role: .destructive) {
                    if let offsets = accountToDeleteIndex {
                        withAnimation { deleteAccount(at: offsets) }
                    }
                    accountToDeleteIndex = nil
                }
            } message: {
                Text("このお財布に関連付けられた投稿の金額計算ができなくなる可能性があります。")
            }
        }
    }

    private var settingTab: some View {
        NavigationView {
            List {
                Section(header: Text("予算設定")) { Stepper("今月の予算: ¥\(monthlyBudget)", value: $monthlyBudget, in: 1000...500000, step: 1000) }
                Section(header: Text("バックアップ管理")) {
                    Button("手動バックアップを作成") { backupDateString = BackupManager.getBackupDate(isManual: true); isShowingSaveConfirm = true }
                    Button("手動バックアップから復元") { isRestoringManual = true; backupDateString = BackupManager.getBackupDate(isManual: true); isShowingRestoreConfirm = true }
                    Button("自動保存から復元") { isRestoringManual = false; backupDateString = BackupManager.getBackupDate(isManual: false); isShowingRestoreConfirm = true }
                }
                Section(header: Text("データ管理")) { Button("全データをリセット", role: .destructive) { isShowingSwipeDeleteAlert = true } }
            }
            .navigationTitle("設定")
            .alert("バックアップの上書き", isPresented: $isShowingSaveConfirm) {
                Button("キャンセル", role: .cancel) { }
                Button("上書き保存") { 
                    BackupManager.saveAll(transactions: transactions, accounts: accounts, isManual: true)
                    completionMessage = "手動バックアップの保存が完了しました。"; isShowingCompletionAlert = true 
                }
            } message: { Text("前回の手動保存日時: \(backupDateString)\n現在のデータでお財布設定と投稿を上書きしますか？") }
            .alert("バックアップの復元", isPresented: $isShowingRestoreConfirm) {
                Button("キャンセル", role: .cancel) { }
                Button("復元する", role: .destructive) { 
                    if let t = BackupManager.loadTransactions(isManual: isRestoringManual), let a = BackupManager.loadAccounts(isManual: isRestoringManual) { 
                        transactions = t; accounts = a; recalculateBalances() 
                        completionMessage = "\(isRestoringManual ? "手動バックアップ" : "自動保存ファイル")からの復元が完了しました。"; isShowingCompletionAlert = true
                    } 
                }
            } message: { Text("\(isRestoringManual ? "手動" : "自動")保存日時: \(backupDateString)\n現在のデータを上書きしますか？") }
            .alert("完了", isPresented: $isShowingCompletionAlert) { Button("OK") { } } message: { Text(completionMessage) }
        }
    }

    func addTransaction(isInc: Bool, date: Date) {
        let amount = parseAmount(from: inputText)
        let sourceName = parseSourceName(from: inputText)
        transactions.append(Transaction(amount: amount, date: date, note: inputText, source: sourceName, isIncome: isInc))
    }
    
    func deleteSpecificTransaction(_ target: Transaction) { 
        if let index = transactions.firstIndex(where: { $0.id == target.id }) { 
            transactions.remove(at: index) 
        } 
    }
    
    func deleteAccount(at offsets: IndexSet) { 
        accounts.remove(atOffsets: offsets)
        recalculateBalances() 
    }
    
    func recalculateBalances() {
        for i in 0..<accounts.count {
            var current = 0
            for tx in transactions where tx.source == accounts[i].name { 
                current += (tx.isIncome ? tx.amount : -tx.amount) 
            }
            let diff = current - accounts[i].balance
            accounts[i].diffAmount = diff
            accounts[i].balance = current
        }
        BackupManager.saveAll(transactions: transactions, accounts: accounts, isManual: false)
    }
    
    func resetAll() { 
        transactions = []
        accounts = [
            Account(name: "お財布", balance: 0, type: .wallet),
            Account(name: "口座", balance: 0, type: .bank),
            Account(name: "ポイント", balance: 0, type: .point)
        ]
        monthlyBudget = 50000 
    }
    
    func parseAmount(from text: String) -> Int {
        let comps = text.components(separatedBy: .whitespacesAndNewlines)
        let yenValues = comps.filter { $0.contains("¥") }
        let total = yenValues.reduce(0) { sum, word in
            let cleaned = word.replacingOccurrences(of: "¥", with: "")
            return sum + (Int(cleaned) ?? 0)
        }
        return total
    }
    
    func parseSourceName(from text: String) -> String {
        for acc in accounts { 
            if text.contains("@\(acc.name)") { return acc.name } 
        }
        return accounts.first?.name ?? "お財布"
    }
}
