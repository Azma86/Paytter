import SwiftUI

struct ContentView: View {
    @AppStorage("transactions_v4") var transactions: [Transaction] = []
    @AppStorage("accounts_v2") var accounts: [Account] = [
        Account(name: "お財布", balance: 0, isVisible: true),
        Account(name: "口座", balance: 0, isVisible: true),
        Account(name: "ポイント", balance: 0, isVisible: true)
    ]
    @AppStorage("monthlyBudget") var monthlyBudget: Int = 50000
    
    @State private var isShowingInputSheet = false
    @State private var inputText: String = ""
    @State private var isShowingDeleteAlert = false
    @State private var isShowingSwipeDeleteAlert = false
    @State private var indexSetToDelete: IndexSet?
    @State private var isShowingRestoreAlert = false
    @State private var restoreText: String = ""

    var body: some View {
        TabView {
            NavigationView {
                ZStack(alignment: .bottomTrailing) {
                    VStack(spacing: 0) {
                        // --- 元の見た目のヘッダー ---
                        HStack(spacing: 15) {
                            ForEach(accounts.filter { $0.isVisible }) { acc in
                                BalanceView(title: acc.name, amount: acc.balance, color: .primary)
                            }
                        }
                        .padding().background(Color(.systemGray6))
                        Divider()
                        
                        List {
                            ForEach(transactions.reversed()) { item in
                                NavigationLink(destination: TransactionDetailView(item: item, transactions: $transactions, accounts: $accounts)) {
                                    TwitterRow(item: item).listRowInsets(EdgeInsets())
                                }
                            }
                            .onDelete { indexSet in
                                self.indexSetToDelete = indexSet
                                self.isShowingSwipeDeleteAlert = true
                            }
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
                }
                .navigationTitle("ホーム")
                .navigationBarTitleDisplayMode(.inline)
            }.tabItem { Label("ホーム", systemImage: "house") }

            NavigationView {
                WalletAnalysisView(transactions: transactions).navigationTitle("お財布")
            }.tabItem { Label("お財布", systemImage: "wallet.pass") }

            NavigationView {
                List {
                    Section(header: Text("お財布の管理")) {
                        ForEach($accounts) { $acc in
                            NavigationLink(destination: AccountEditView(account: $acc)) {
                                HStack {
                                    Text(acc.name)
                                    Spacer()
                                    Text("¥\(acc.balance)").foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    Section(header: Text("予算設定")) {
                        Stepper("今月の予算: ¥\(monthlyBudget)", value: $monthlyBudget, in: 1000...500000, step: 1000)
                    }
                    Section(header: Text("データ管理")) {
                        Button("データを全削除する", role: .destructive) { isShowingDeleteAlert = true }
                    }
                }
                .navigationTitle("設定")
                .alert("全削除", isPresented: $isShowingDeleteAlert) {
                    Button("キャンセル", role: .cancel) { }
                    Button("削除する", role: .destructive) { 
                        transactions = []; for i in 0..<accounts.count { accounts[i].balance = 0 }
                    }
                }
            }.tabItem { Label("設定", systemImage: "gearshape") }
        }
        .sheet(isPresented: $isShowingInputSheet) {
            PostView(inputText: $inputText, isPresented: $isShowingInputSheet) { isInc in addTransaction(isInc: isInc) }
        }
    }

    func addTransaction(isInc: Bool) {
        let amount = parseAmount(from: inputText)
        let sourceName = parseSourceName(from: inputText)
        
        if let idx = accounts.firstIndex(where: { sourceName.contains($0.name) }) {
            accounts[idx].balance += (isInc ? amount : -amount)
        } else if let firstIdx = accounts.firstIndex(where: { $0.name == "お財布" }) {
            accounts[firstIdx].balance += (isInc ? amount : -amount)
        }

        transactions.append(Transaction(amount: amount, date: Date(), note: inputText, source: sourceName, isIncome: isInc))
        BackupManager.saveAll(transactions: transactions, accounts: accounts)
    }

    func deleteTransaction(at offsets: IndexSet) {
        for index in offsets {
            let revIndex = transactions.count - 1 - index
            let item = transactions[revIndex]
            if let idx = accounts.firstIndex(where: { item.source.contains($0.name) }) {
                accounts[idx].balance += (item.isIncome ? -item.amount : item.amount)
            }
            transactions.remove(at: revIndex)
        }
        BackupManager.saveAll(transactions: transactions, accounts: accounts)
    }

    func parseAmount(from text: String) -> Int {
        let components = text.components(separatedBy: .whitespacesAndNewlines)
        let amt = components.filter { $0.contains("¥") || Int($0) != nil }.first?.replacingOccurrences(of: "¥", with: "") ?? "0"
        return Int(amt) ?? 0
    }

    func parseSourceName(from text: String) -> String {
        for acc in accounts { if text.contains("@\(acc.name)") { return acc.name } }
        return "お財布"
    }
}
