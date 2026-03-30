import SwiftUI

// --- データ構造 ---
struct Transaction: Identifiable, Codable {
    var id = UUID()
    let amount: Int
    let date: Date
    let note: String
    let source: String // お財布、口座、ポイント
    
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

// 配列保存用の拡張
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
    @AppStorage("transactions") var transactions: [Transaction] = []
    @AppStorage("walletBalance") var walletBalance: Int = 0
    @AppStorage("bankBalance") var bankBalance: Int = 0
    @AppStorage("pointBalance") var pointBalance: Int = 0
    
    @State private var isShowingInputSheet = false
    @State private var inputText: String = ""

    var body: some View {
        TabView {
            // 【1. ホーム】
            NavigationView {
                ZStack(alignment: .bottomTrailing) {
                    VStack(spacing: 0) {
                        BalanceHeaderView(wallet: walletBalance, bank: bankBalance, point: pointBalance)
                        List(transactions.reversed()) { item in
                            TwitterRow(item: item)
                                .listRowSeparator(.visible)
                                .listRowInsets(EdgeInsets())
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

            // 【2. お財布（分析）】
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
                            transactions = []; walletBalance = 0; bankBalance = 0; pointBalance = 0
                        }
                    }
                }
                .navigationTitle("設定")
            }
            .tabItem { Label("設定", systemImage: "gearshape") }
        }
        .sheet(isPresented: $isShowingInputSheet) {
            PostView(inputText: $inputText, isPresented: $isShowingInputSheet) {
                addTransaction()
            }
        }
    }

    func addTransaction() {
        let components = inputText.components(separatedBy: .whitespacesAndNewlines)
        let amount = Int(components.filter { Int($0.replacingOccurrences(of: "¥", with: "")) != nil }.first?.replacingOccurrences(of: "¥", with: "") ?? "0") ?? 0
        
        // 支出先の判定
        var source = "お財布"
        if inputText.contains("@口座") { source = "口座" }
        else if inputText.contains("@ポイント") { source = "ポイント" }

        switch source {
        case "口座": bankBalance -= amount
        case "ポイント": pointBalance -= amount
        default: walletBalance -= amount
        }
        
        if inputText.contains("ローソン") { pointBalance += (amount / 100) }

        transactions.append(Transaction(amount: amount, date: Date(), note: inputText, source: source))
        inputText = ""
    }
}

// --- お財布分析画面 ---
struct WalletAnalysisView: View {
    let transactions: [Transaction]
    var monthlyTotal: Int { transactions.reduce(0) { $0 + $1.amount } }

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

// --- ヘッダー ---
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

// --- タイムラインの1行 ---
struct TwitterRow: View {
    let item: Transaction
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "person.circle.fill").resizable().frame(width: 48, height: 48).foregroundColor(.gray)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("むつき").font(.subheadline).fontWeight(.bold)
                    Text("@Mutsuki_dev · \(item.date, style: .time)").font(.caption).foregroundColor(.secondary)
                }
                Text(item.cleanNote).font(.subheadline)
                HStack(spacing: 8) {
                    Text("¥\(item.amount)").fontWeight(.bold)
                    Text(item.source).font(.system(size: 10)).padding(.horizontal, 6).padding(.vertical, 2).background(Color.gray.opacity(0.1)).cornerRadius(4)
                }
                if !item.tags.isEmpty {
                    HStack {
                        ForEach(item.tags, id: \.self) { tag in Text(tag).font(.caption).foregroundColor(.blue) }
                    }
                }
                HStack(spacing: 40) {
                    Image(systemName: "bubble.left"); Image(systemName: "arrow.2.squarepath"); Image(systemName: "heart"); Image(systemName: "chart.bar")
                }
                .font(.caption).foregroundColor(.secondary).padding(.top, 6)
            }
        }.padding()
    }
}

// --- 投稿画面 ---
struct PostView: View {
    @Binding var inputText: String
    @Binding var isPresented: Bool
    var onPost: () -> Void
    var body: some View {
        NavigationView {
            VStack {
                HStack(alignment: .top) {
                    Image(systemName: "person.circle.fill").resizable().frame(width: 40, height: 40).foregroundColor(.gray)
                    TextEditor(text: $inputText).frame(minHeight: 150)
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
                trailing: Button("ツイート") { onPost(); isPresented = false }
                    .padding(.horizontal, 16).padding(.vertical, 8).background(Color.blue).foregroundColor(.white).cornerRadius(20)
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
