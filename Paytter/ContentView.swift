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
    
    @State private var isShowingRestoreConfirm = false
    @State private var isShowingSaveConfirm = false
    @State private var isRestoringManual = false
    @State private var backupDateString = ""
    @State private var isShowingCompletionAlert = false
    @State private var completionMessage = ""

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
                            .onDelete { indexSet in
                                // スワイプ後の「無駄な戻り」を防ぐため、即座にインデックスを保存
                                self.indexSetToDelete = indexSet
                                self.isShowingSwipeDeleteAlert = true
                            }
                        }
                        .listStyle(.plain)
                        .alert("投稿を削除しますか？", isPresented: $isShowingSwipeDeleteAlert) {
                            Button("キャンセル", role: .cancel) {
                                // キャンセル時はスワイプ状態を戻すためにインデックスをクリア
                                self.indexSetToDelete = nil
                            }
                            Button("削除", role: .destructive) {
                                if let offsets = indexSetToDelete {
                                    // アニメーションを明示的に指定して削除
                                    withAnimation {
                                        deleteTransaction(at: offsets)
                                    }
                                }
                                self.indexSetToDelete = nil
                            }
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
                            NavigationLink(destination: AccountEditView(account: $acc, transactions: $transactions, allAccounts: accounts)) {
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
                .sheet(isPresented: $isShowingAccountCreator) { AccountCreateView(accounts: $accounts, transactions: $transactions) }
            }.tabItem { Label("お財布", systemImage: "wallet.pass") }

            // 【設定】
            NavigationView {
                List {
                    Section(header: Text("予算設定")) { Stepper("今月の予算: ¥\(monthlyBudget)", value: $monthlyBudget, in: 1000...500000, step: 1000) }
                    Section(header: Text("バックアップ管理")) {
                        Button("手動バックアップを作成") {
                            backupDateString = BackupManager.getBackupDate(isManual: true)
                            isShowingSaveConfirm = true
                        }
                        Button("手動バックアップから復元") {
                            isRestoringManual = true; backupDateString = BackupManager.getBackupDate(isManual: true); isShowingRestoreConfirm = true
                        }
                        Button("自動保存から復元") {
                            isRestoringManual = false; backupDateString = BackupManager.getBackupDate(isManual: false); isShowingRestoreConfirm = true
                        }
                    }
                    Section(header: Text("データ管理")) { Button("全データをリセット", role: .destructive) { isShowingDeleteAlert = true } }
                }
                .navigationTitle("設定")
                .alert("バックアップの上書き", isPresented: $isShowingSaveConfirm) {
                    Button("キャンセル", role: .cancel) { }
                    Button("上書き保存", role: .none) {
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
                .alert("リセット", isPresented: $isShowingDeleteAlert) {
                    Button("キャンセル", role: .cancel) { }; Button("初期化する", role: .destructive) { 
                        resetAll(); completionMessage = "全てのデータを初期状態にリセットしました。"; isShowingCompletionAlert = true
                    }
                } message: { Text("全ての投稿、お財布設定、予算を初期状態に戻します。バックアップファイルは保護されます。") }
                .alert("完了", isPresented: $isShowingCompletionAlert) { Button("OK", role: .none) { } } message: { Text(completionMessage) }
            }.tabItem { Label("設定", systemImage: "gearshape") }
        }
        .onAppear { recalculateBalances() }
        .onChange(of: transactions.count) { _ in recalculateBalances() }
        .sheet(isPresented: $isShowingInputSheet) { 
            PostView(inputText: $inputText, isPresented: $isShowingInputSheet, onPost: { isInc in addTransaction(isInc: isInc) }, transactions: transactions, accounts: accounts) 
        }
    }

    func addTransaction(isInc: Bool) {
        let amount = parseAmount(from: inputText); let sourceName = parseSourceName(from: inputText)
        transactions.append(Transaction(amount: amount, date: Date(), note: inputText, source: sourceName, isIncome: isInc))
    }
    
    func deleteTransaction(at offsets: IndexSet) {
        for index in offsets {
            let revIndex = transactions.count - 1 - index
            transactions.remove(at: revIndex)
        }
        // 削除後に即座に残高を再計算して保存
        recalculateBalances()
    }
    
    func deleteAccount(at offsets: IndexSet) {
        accounts.remove(atOffsets: offsets)
        recalculateBalances()
    }
    
    func recalculateBalances() {
        for i in 0..<accounts.count {
            var current = 0
            for tx in transactions where tx.source == accounts[i].name { current += (tx.isIncome ? tx.amount : -tx.amount) }
            accounts[i].balance = current
        }
        BackupManager.saveAll(transactions: transactions, accounts: accounts, isManual: false)
    }
    
    func resetAll() { transactions = []; accounts = [Account(name: "お財布", balance: 0, type: .wallet), Account(name: "口座", balance: 0, type: .bank), Account(name: "ポイント", balance: 0, type: .point)]; monthlyBudget = 50000 }
    
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
