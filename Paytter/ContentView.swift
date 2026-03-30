import SwiftUI

struct ContentView: View {
    @AppStorage("transactions_v5") var transactions: [Transaction] = []
    @AppStorage("accounts_v1") var accounts: [Account] = []
    @AppStorage("monthlyBudget") var monthlyBudget: Int = 50000
    
    @State private var isShowingInputSheet = false
    @State private var inputText: String = ""
    @State private var isShowingAccountEditor = false
    @State private var selectedAccount: Account? = nil

    var body: some View {
        TabView {
            NavigationView {
                ZStack(alignment: .bottomTrailing) {
                    VStack(spacing: 0) {
                        // --- 動的なヘッダー ---
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 15) {
                                ForEach(accounts.filter { $0.isVisible }) { acc in
                                    VStack {
                                        Text(acc.name).font(.caption).foregroundColor(.secondary)
                                        Text("¥\(acc.balance)").font(.system(.subheadline, design: .monospaced)).bold()
                                    }
                                    .padding(.horizontal, 10)
                                }
                            }.padding()
                        }.background(Color(.systemGray6))
                        
                        Divider()
                        
                        List {
                            // --- ContentView.swift の List 内 ---
                            ForEach(transactions.reversed()) { item in
                                NavigationLink(destination: TransactionDetailView(
                                    item: item, 
                                    transactions: $transactions, 
                                    accounts: $accounts // ここが Binding になっているので $ が必要です
                                )) {
                                    TwitterRow(item: item).listRowInsets(EdgeInsets())
                                }
                            }
                        }.listStyle(.plain)
                    }
                    
                    Button(action: { inputText = ""; isShowingInputSheet = true }) {
                        Image(systemName: "plus").font(.system(size: 22, weight: .bold)).foregroundColor(.white).frame(width: 56, height: 56).background(Color.blue).clipShape(Circle())
                    }.padding(20).padding(.bottom, 10)
                }
                .navigationTitle("ホーム")
                .navigationBarTitleDisplayMode(.inline)
            }.tabItem { Label("ホーム", systemImage: "house") }

            NavigationView {
                List {
                    Section(header: Text("お財布・口座の管理")) {
                        ForEach(accounts) { acc in
                            Button(action: { selectedAccount = acc; isShowingAccountEditor = true }) {
                                HStack {
                                    Text(acc.type.icon)
                                    Text(acc.name)
                                    Spacer()
                                    Text("¥\(acc.balance)").foregroundColor(.secondary)
                                }
                            }
                        }
                        Button(action: { selectedAccount = nil; isShowingAccountEditor = true }) {
                            Label("新しいお財布を追加", systemImage: "plus.circle")
                        }
                    }
                    Section(header: Text("設定")) {
                        Stepper("今月の予算: ¥\(monthlyBudget)", value: $monthlyBudget, in: 1000...500000, step: 1000)
                    }
                }
                .navigationTitle("お財布・設定")
                .sheet(isPresented: $isShowingAccountEditor) {
                    AccountEditView(account: $selectedAccount) { newAcc in
                        saveAccount(newAcc)
                    }
                }
            }.tabItem { Label("お財布", systemImage: "wallet.pass") }
        }
        .onAppear {
            if accounts.isEmpty {
                if let saved = BackupManager.loadAccounts() { accounts = saved }
                else { accounts = [Account(name: "お財布", type: .wallet, balance: 0, isVisible: true)] }
            }
            if transactions.isEmpty {
                if let saved = BackupManager.loadTransactions() { transactions = saved }
            }
        }
        .sheet(isPresented: $isShowingInputSheet) {
            PostView(inputText: $inputText, isPresented: $isShowingInputSheet, accounts: accounts) { isInc, accId in
                addTransaction(isInc: isInc, accId: accId)
            }
        }
    }

    func saveAccount(_ acc: Account) {
        if let idx = accounts.firstIndex(where: { $0.id == acc.id }) {
            accounts[idx] = acc
        } else {
            accounts.append(acc)
        }
        BackupManager.saveAll(transactions: transactions, accounts: accounts)
    }

    func addTransaction(isInc: Bool, accId: UUID?) {
        let amount = parseAmount(from: inputText)
        if let id = accId, let idx = accounts.firstIndex(where: { $0.id == id }) {
            accounts[idx].balance += (isInc ? amount : -amount)
        }
        transactions.append(Transaction(amount: amount, date: Date(), note: inputText, accountId: accId, isIncome: isInc))
        BackupManager.saveAll(transactions: transactions, accounts: accounts)
    }

    func deleteTransaction(at offsets: IndexSet) {
        // 削除ロジック（簡略化のため一旦省略、必要なら追加します）
        transactions.remove(atOffsets: offsets)
        BackupManager.saveAll(transactions: transactions, accounts: accounts)
    }
    
    func parseAmount(from text: String) -> Int {
        let components = text.components(separatedBy: .whitespacesAndNewlines)
        let amt = components.filter { $0.contains("¥") || Int($0) != nil }.first?.replacingOccurrences(of: "¥", with: "") ?? "0"
        return Int(amt) ?? 0
    }
}
