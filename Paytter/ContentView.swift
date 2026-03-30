import SwiftUI

struct ContentView: View {
    @AppStorage("transactions_v4") var transactions: [Transaction] = []
    @AppStorage("walletBalance") var walletBalance: Int = 0
    @AppStorage("bankBalance") var bankBalance: Int = 0
    @AppStorage("pointBalance") var pointBalance: Int = 0
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
                        BalanceHeaderView(wallet: walletBalance, bank: bankBalance, point: pointBalance)
                        List {
                            ForEach(transactions.reversed()) { item in
                                NavigationLink(destination: TransactionDetailView(item: item, transactions: $transactions, walletBalance: $walletBalance, bankBalance: $bankBalance, pointBalance: $pointBalance)) {
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
                            Button("キャンセル", role: .cancel) { indexSetToDelete = nil }
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
                    Section(header: Text("予算設定")) {
                        Stepper("今月の予算: ¥\(monthlyBudget)", value: $monthlyBudget, in: 1000...500000, step: 1000)
                    }
                    Section(header: Text("バックアップ")) {
                        Button("バックアップをコピー") { UIPasteboard.general.string = transactions.rawValue }
                        Button("バックアップから復元") { isShowingRestoreAlert = true }
                        Button("内蔵ファイルから強制読み込み") { if let saved = BackupManager.loadFromFile() { transactions = saved } }
                    }
                    Section(header: Text("データ管理")) {
                        Button("データを全削除する", role: .destructive) { isShowingDeleteAlert = true }
                    }
                }
                .navigationTitle("設定")
                .alert("テキストから復元", isPresented: $isShowingRestoreAlert) {
                    TextField("ここに貼り付け", text: $restoreText)
                    Button("キャンセル", role: .cancel) { restoreText = "" }
                    Button("復元実行") { if let restored = [Transaction](rawValue: restoreText) { transactions = restored; BackupManager.saveToFile(transactions: transactions); restoreText = "" } }
                }
                .alert("全削除", isPresented: $isShowingDeleteAlert) {
                    Button("キャンセル", role: .cancel) { }
                    Button("削除する", role: .destructive) { transactions = []; walletBalance = 0; bankBalance = 0; pointBalance = 0; BackupManager.saveToFile(transactions: []) }
                }
            }.tabItem { Label("設定", systemImage: "gearshape") }
        }
        .onAppear {
            if transactions.isEmpty {
                if let saved = BackupManager.loadFromFile() { transactions = saved }
            }
        }
        .sheet(isPresented: $isShowingInputSheet) {
            PostView(inputText: $inputText, isPresented: $isShowingInputSheet) { isInc in addTransaction(isInc: isInc) }
        }
    }

    func addTransaction(isInc: Bool) {
        let amount = parseAmount(from: inputText); let source = parseSource(from: inputText)
        updateBalance(source: source, change: isInc ? amount : -amount)
        if !isInc && inputText.contains("ローソン") { pointBalance += (amount / 100) }
        transactions.append(Transaction(amount: amount, date: Date(), note: inputText, source: source, isIncome: isInc))
        BackupManager.saveToFile(transactions: transactions)
    }
    func deleteTransaction(at offsets: IndexSet) {
        for index in offsets {
            let revIndex = transactions.count - 1 - index; let item = transactions[revIndex]
            updateBalance(source: item.source, change: item.isIncome ? -item.amount : item.amount)
            transactions.remove(at: revIndex)
        }
        BackupManager.saveToFile(transactions: transactions)
    }
    func updateBalance(source: String, change: Int) {
        switch source { case "口座": bankBalance += change; case "ポイント": pointBalance += change; default: walletBalance += change }
    }
    func parseAmount(from text: String) -> Int {
        let components = text.components(separatedBy: .whitespacesAndNewlines)
        let amt = components.filter { $0.contains("¥") || Int($0) != nil }.first?.replacingOccurrences(of: "¥", with: "") ?? "0"
        return Int(amt) ?? 0
    }
    func parseSource(from text: String) -> String { text.contains("@口座") ? "口座" : (text.contains("@ポイント") ? "ポイント" : "お財布") }
}
