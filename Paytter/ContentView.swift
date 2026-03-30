import SwiftUI

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
    @State private var isShowingDeleteAlert = false
    @State private var isShowingSwipeDeleteAlert = false
    @State private var indexSetToDelete: IndexSet?
    @State private var isShowingAccountCreator = false

    var body: some View {
        TabView {
            // 【ホーム】
            NavigationView {
                ZStack(alignment: .bottomTrailing) {
                    VStack(spacing: 0) {
                        HStack(spacing: 15) {
                            ForEach(accounts.filter { $0.isVisible }) { acc in
                                VStack(spacing: 2) {
                                    Image(systemName: acc.type.icon).font(.system(size: 10)).foregroundColor(.secondary)
                                    BalanceView(title: acc.name, amount: acc.balance, color: .primary)
                                }
                            }
                        }.padding().background(Color(.systemGray6))
                        Divider()
                        List {
                            ForEach(transactions.reversed()) { item in
                                NavigationLink(destination: TransactionDetailView(item: item, transactions: $transactions, accounts: $accounts)) {
                                    TwitterRow(item: item).listRowInsets(EdgeInsets())
                                }
                            }
                            .onDelete { indexSet in self.indexSetToDelete = indexSet; self.isShowingSwipeDeleteAlert = true }
                        }
                        .listStyle(.plain)
                        .alert("投稿を削除しますか？", isPresented: $isShowingSwipeDeleteAlert) {
                            Button("キャンセル", role: .cancel) { }
                            Button("削除", role: .destructive) { if let offsets = indexSetToDelete { deleteTransaction(at: offsets) } }
                        }
                    }
                    Button(action: { inputText = ""; isShowingInputSheet = true }) {
                        Image(systemName: "plus").font(.system(size: 22, weight: .bold)).foregroundColor(.white).frame(width: 56, height: 56).background(Color.blue).clipShape(Circle())
                    }.padding(20).padding(.bottom, 10)
                }.navigationTitle("ホーム").navigationBarTitleDisplayMode(.inline)
            }.tabItem { Label("ホーム", systemImage: "house") }

            // 【お財布】
            NavigationView {
                List {
                    Section(header: Text("お財布の管理")) {
                        ForEach($accounts) { $acc in
                            NavigationLink(destination: AccountEditView(account: $acc, transactions: $transactions)) {
                                HStack { Image(systemName: acc.type.icon).foregroundColor(.secondary); Text(acc.name); Spacer(); Text("¥\(acc.balance)").foregroundColor(.secondary) }
                            }
                        }.onDelete(perform: deleteAccount)
                        Button(action: { isShowingAccountCreator = true }) { Label("新しいお財布を追加", systemImage: "plus.circle") }
                    }
                    Section(header: Text("分析")) {
                        NavigationLink(destination: WalletAnalysisView(transactions: transactions)) { Label("今月の収支分析", systemImage: "chart.bar.xaxis") }
                    }
                }
                .navigationTitle("お財布")
                .sheet(isPresented: $isShowingAccountCreator) { AccountCreateView(accounts: $accounts) }
            }.tabItem { Label("お財布", systemImage: "wallet.pass") }

            // 【設定】
            NavigationView {
                List {
                    Section(header: Text("予算設定")) { Stepper("今月の予算: ¥\(monthlyBudget)", value: $monthlyBudget, in: 1000...500000, step: 1000) }
                    Section(header: Text("バックアップ")) {
                        Button("内蔵ファイルから読み込む") {
                            if let t = BackupManager.loadTransactions(), let a = BackupManager.loadAccounts() {
                                transactions = t; accounts = a; recalculateBalances()
                            }
                        }
                    }
                    Section(header: Text("データ管理")) { Button("全データをリセット", role: .destructive) { isShowingDeleteAlert = true } }
                }
                .navigationTitle("設定")
                .alert("リセット", isPresented: $isShowingDeleteAlert) {
                    Button("キャンセル", role: .cancel) { }; Button("削除", role: .destructive) { resetAll() }
                }
            }.tabItem { Label("設定", systemImage: "gearshape") }
        }
        .onAppear { recalculateBalances() }
        .onChange(of: transactions.count) { _ in recalculateBalances() }
        .sheet(isPresented: $isShowingInputSheet) { PostView(inputText: $inputText, isPresented: $isShowingInputSheet) { isInc in addTransaction(isInc: isInc) } }
    }

    func addTransaction(isInc: Bool) {
        let amount = parseAmount(from: inputText); let sourceName = parseSourceName(from: inputText)
        transactions.append(Transaction(amount: amount, date: Date(), note: inputText, source: sourceName, isIncome: isInc))
    }
    func deleteTransaction(at offsets: IndexSet) { for index in offsets { let revIndex = transactions.count - 1 - index; transactions.remove(at: revIndex) } }
    func deleteAccount(at offsets: IndexSet) { accounts.remove(atOffsets: offsets) }
    func recalculateBalances() {
        for i in 0..<accounts.count {
            var current = 0
            for tx in transactions where tx.source == accounts[i].name { current += (tx.isIncome ? tx.amount : -tx.amount) }
            accounts[i].balance = current
        }
        BackupManager.saveAll(transactions: transactions, accounts: accounts)
    }
    func resetAll() {
        transactions = []; for i in 0..<accounts.count { accounts[i].balance = 0 }
        BackupManager.saveAll(transactions: transactions, accounts: accounts)
    }
    func parseAmount(from text: String) -> Int {
        let components = text.components(separatedBy: .whitespacesAndNewlines)
        let amt = components.filter { $0.contains("¥") || Int($0) != nil }.first?.replacingOccurrences(of: "¥", with: "") ?? "0"
        return Int(amt) ?? 0
    }
    func parseSourceName(from text: String) -> String {
        for acc in accounts { if text.contains("@\(acc.name)") { return acc.name } }
        return accounts.first?.name ?? "お財布"
    }
}
