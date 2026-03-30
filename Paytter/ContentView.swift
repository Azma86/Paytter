import SwiftUI

// --- データ構造 ---
struct Transaction: Identifiable, Codable {
    var id = UUID()
    let amount: Int
    let date: Date
    let note: String
    let source: String
    let isIncome: Bool
    
    var cleanNote: String {
        note.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.hasPrefix("#") && !$0.hasPrefix("@") }
            .joined(separator: " ")
    }
    
    var tags: [String] {
        note.components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.hasPrefix("#") }
    }
}

extension Array: RawRepresentable where Element: Codable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode([Element].self, from: data)
        else { return nil }
        self = result
    }
    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else { return "[]" }
        return result
    }
}

struct ContentView: View {
    @AppStorage("transactions_v2") var transactions: [Transaction] = []
    @AppStorage("walletBalance") var walletBalance: Int = 0
    @AppStorage("bankBalance") var bankBalance: Int = 0
    @AppStorage("pointBalance") var pointBalance: Int = 0
    
    @State private var isShowingInputSheet = false
    @State private var inputText: String = ""
    @State private var isShowingDeleteAlert = false

    var body: some View {
        TabView {
            // 【1. ホーム】
            NavigationView {
                ZStack(alignment: .bottomTrailing) {
                    VStack(spacing: 0) {
                        BalanceHeaderView(wallet: walletBalance, bank: bankBalance, point: pointBalance)
                        
                        // タイムラインのList（スワイプ削除を実装）
                        List {
                            ForEach(transactions.reversed()) { item in
                                // タップで詳細画面へ遷移
                                NavigationLink(destination: TransactionDetailView(item: item)) {
                                    TwitterRow(item: item)
                                        .listRowInsets(EdgeInsets()) // 余計な空白をなくす
                                }
                            }
                            .onDelete(perform: deleteTransaction) // スワイプ削除
                        }
                        .listStyle(.plain)
                    }

                    Button(action: { isShowingInputSheet = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color(red: 0.11, green: 0.63, blue: 0.95))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 5)
                    }
                    .padding(20).padding(.bottom, 10)
                }
                .navigationTitle("ホーム")
                .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem { Label("ホーム", systemImage: "house") }

            // 【2. お財布】
            NavigationView {
                WalletAnalysisView(transactions: transactions)
                    .navigationTitle("お財布")
            }
            .tabItem { Label("お財布", systemImage: "wallet.pass") }

            // 【3. 設定】
            NavigationView {
                List {
                    Section(header: Text("データ管理")) {
                        Button("データを全削除する", role: .destructive) {
                            isShowingDeleteAlert = true
                        }
                    }
                }
                .navigationTitle("設定")
                .alert("データの全削除", isPresented: $isShowingDeleteAlert) {
                    Button("キャンセル", role: .cancel) { }
                    Button("削除する", role: .destructive) {
                        transactions = []; walletBalance = 0; bankBalance = 0; pointBalance = 0
                    }
                } message: {
                    Text("これまでの投稿と残高がすべて消去されます。よろしいですか？")
                }
            }
            .tabItem { Label("設定", systemImage: "gearshape") }
        }
        .sheet(isPresented: $isShowingInputSheet) {
            PostView(inputText: $inputText, isPresented: $isShowingInputSheet) { isIncome in
                addTransaction(isIncome: isIncome)
            }
        }
    }

    // 投稿の追加ロジック
    func addTransaction(isIncome: Bool) {
        let components = inputText.components(separatedBy: .whitespacesAndNewlines)
        let amountText = components.filter { $0.contains("¥") || Int($0) != nil }.first?.replacingOccurrences(of: "¥", with: "") ?? "0"
        let amount = Int(amountText) ?? 0
        
        var source = "お財布"
        if inputText.contains("@口座") { source = "口座" }
        else if inputText.contains("@ポイント") { source = "ポイント" }

        let change = isIncome ? amount : -amount

        updateBalance(source: source, change: change)
        
        if !isIncome && inputText.contains("ローソン") { pointBalance += (amount / 100) }

        let newTransaction = Transaction(amount: amount, date: Date(), note: inputText, source: source, isIncome: isIncome)
        transactions.append(newTransaction)
        inputText = ""
    }
    
    // スワイプ削除のロジック
    func deleteTransaction(at offsets: IndexSet) {
        // reversed()したListに対応させるため、インデックスを調整
        for index in offsets {
            let reversedIndex = transactions.count - 1 - index
            let item = transactions[reversedIndex]
            
            // 残高を元に戻す（支出なら足し、収入なら引く）
            let change = item.isIncome ? -item.amount : item.amount
            updateBalance(source: item.source, change: change)
            
            // ローソンのポイントも取り消す（簡易実装：支出の場合のみ）
            if !item.isIncome && item.note.contains("ローソン") {
                pointBalance -= (item.amount / 100)
            }
            
            // データを削除
            transactions.remove(at: reversedIndex)
        }
    }
    
    // 残高を更新する共通ロジック
    func updateBalance(source: String, change: Int) {
        switch source {
        case "口座": bankBalance += change
        case "ポイント": pointBalance += change
        default: walletBalance += change
        }
    }
}

// タイムラインの1行（バッジ色を統一）
struct TwitterRow: View {
    let item: Transaction
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "person.circle.fill").resizable().frame(width: 48, height: 48).foregroundColor(.gray)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("むつき").font(.subheadline).fontWeight(.bold)
                    Text("@Mutsuki_dev · \(item.date, style: .time)").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    // 右上のソースバッジ（グレーに統一）
                    Text(item.source)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.1)) // 色を統一
                        .foregroundColor(.primary)
                        .cornerRadius(4)
                }
                
                // 本文（cleanNote）に色付けを適用
                HighlightedText(text: item.cleanNote, isIncome: item.isIncome)
                    .font(.subheadline)
                
                if !item.tags.isEmpty {
                    HStack {
                        ForEach(item.tags, id: \.self) { tag in 
                            Text(tag).font(.caption).foregroundColor(.blue) 
                        }
                    }
                }
                HStack(spacing: 40) {
                    Image(systemName: "bubble.left"); Image(systemName: "arrow.2.squarepath"); Image(systemName: "heart"); Image(systemName: "chart.bar")
                }
                .font(.caption).foregroundColor(.secondary).padding(.top, 6)
            }
        }.padding(.vertical, 8).padding(.horizontal, 16) // NavigationLinkに対応するための余白調整
    }
}

// 金額やタグをハイライトするコンポーネント
struct HighlightedText: View {
    let text: String
    let isIncome: Bool
    
    var body: some View {
        let words = text.components(separatedBy: " ")
        return words.reduce(Text("")) { (result, word) in
            if word.contains("¥") || (Int(word.replacingOccurrences(of: "¥", with: "")) != nil) {
                // 金額部分は支出なら赤、収入なら緑（少し濃いめの緑）
                return result + Text(word + " ").foregroundColor(isIncome ? Color(red: 0.1, green: 0.7, blue: 0.1) : .red).fontWeight(.bold)
            } else {
                return result + Text(word + " ")
            }
        }
    }
}

struct WalletAnalysisView: View {
    let transactions: [Transaction]
    var monthlyTotal: Int { transactions.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount } }

    var body: some View {
        List {
            Section(header: Text("今月のサマリー")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("合計支出").font(.caption).foregroundColor(.secondary)
                    Text("¥\(monthlyTotal)").font(.system(.title, design: .rounded).bold())
                    ProgressView(value: min(Double(monthlyTotal), 50000), total: 50000)
                        .accentColor(monthlyTotal > 45000 ? .red : .blue)
                    Text("予算 ¥50,000 まであと ¥\(max(0, 50000 - monthlyTotal))").font(.caption2).foregroundColor(.secondary)
                }
                .padding(.vertical, 10)
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct BalanceHeaderView: View {
    let wallet: Int; let bank: Int; let point: Int
    var body: some View {
        HStack(spacing: 15) {
            BalanceView(title: "お財布", amount: wallet, color: .green)
            BalanceView(title: "口座", amount: bank, color: .blue)
            BalanceView(title: "ポイント", amount: point, color: .orange)
        }
        .padding()
        .background(Color(.systemGray6))
        Divider()
    }
}

// 投稿詳細画面
struct TransactionDetailView: View {
    let item: Transaction
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // タイムラインとほぼ同じレイアウトで大きく表示
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "person.circle.fill").resizable().frame(width: 56, height: 56).foregroundColor(.gray)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("むつき").font(.headline).fontWeight(.bold)
                        Text("@Mutsuki_dev").font(.subheadline).foregroundColor(.secondary)
                    }
                    Spacer()
                    // ソースバッジ（グレー）
                    Text(item.source)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.gray.opacity(0.1))
                        .foregroundColor(.primary)
                        .cornerRadius(5)
                }
                
                // 本文（色付け付きで大きく）
                HighlightedText(text: item.cleanNote, isIncome: item.isIncome)
                    .font(.title3)
                
                // タグ
                if !item.tags.isEmpty {
                    HStack(spacing: 12) {
                        ForEach(item.tags, id: \.self) { tag in 
                            Text(tag).font(.subheadline).foregroundColor(.blue) 
                        }
                    }
                }
                
                Text(item.date, style: .date) + Text(" " ) + Text(item.date, style: .time)
                    .font(.caption).foregroundColor(.secondary)
                
                Divider()
                
                // Twitterっぽいアクションアイコン
                HStack(spacing: 60) {
                    Image(systemName: "bubble.left"); Image(systemName: "arrow.2.squarepath"); Image(systemName: "heart"); Image(systemName: "shareplay")
                }
                .font(.subheadline).foregroundColor(.secondary).padding(.top, 8).frame(maxWidth: .infinity)
                
                Spacer()
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // 右上に編集と削除のボタンを配置（UIのみ）
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button(action: { /* 編集アクション（今後実装） */ }) {
                        Image(systemName: "pencil.line")
                    }
                    Button(action: { /* 削除アクション（今後実装） */ }) {
                        Image(systemName: "trash")
                    }
                    .foregroundColor(.red)
                }
            }
        }
    }
}

struct PostView: View {
    @Binding var inputText: String
    @Binding var isPresented: Bool
    var onPost: (Bool) -> Void
    
    var body: some View {
        NavigationView {
            VStack {
                HStack(alignment: .top) {
                    Image(systemName: "person.circle.fill").resizable().frame(width: 40, height: 40).foregroundColor(.gray)
                    ZStack(alignment: .topLeading) {
                        if inputText.isEmpty {
                            Text("どんな買い物をしましたか？")
                                .foregroundColor(.gray.opacity(0.7))
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }
                        TextEditor(text: $inputText)
                            .frame(minHeight: 150)
                    }
                }.padding()
                Spacer()
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    HStack {
                        Button("#") { inputText += " #" }.fontWeight(.bold)
                        Button("¥") { inputText += " ¥" }.fontWeight(.bold)
                        Button("@") { inputText += " @" }.fontWeight(.bold)
                        Spacer()
                        Button("完了") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                    }
                }
            }
            .navigationBarItems(
                leading: Button("キャンセル") { isPresented = false },
                trailing: HStack(spacing: 12) {
                    Button("支出") { onPost(false); isPresented = false }
                        .padding(.horizontal, 12).padding(.vertical, 6).background(Color.red.opacity(0.8)).foregroundColor(.white).cornerRadius(15)
                    Button("収入") { onPost(true); isPresented = false }
                        .padding(.horizontal, 12).padding(.vertical, 6).background(Color.blue).foregroundColor(.white).cornerRadius(15)
                }
            )
        }
    }
}

struct BalanceView: View {
    let title: String; let amount: Int; let color: Color
    var body: some View {
        VStack {
            Text(title).font(.caption).foregroundColor(.secondary)
            Text("¥\(amount)").font(.system(.subheadline, design: .monospaced)).fontWeight(.bold).foregroundColor(color)
        }.frame(maxWidth: .infinity)
    }
}
