import SwiftUI

// --- データ構造 ---
struct Transaction: Identifiable, Codable {
    var id = UUID()
    let amount: Int
    let date: Date
    let note: String
    let source: String // お財布、口座、ポイントのどこから出たか
    
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

struct ContentView: View {
    @AppStorage("transactions") var transactions: [Transaction] = []
    @AppStorage("walletBalance") var walletBalance: Int = 0
    @AppStorage("bankBalance") var bankBalance: Int = 0
    @AppStorage("pointBalance") var pointBalance: Int = 0
    
    @State private var isShowingInputSheet = false
    @State private var inputText: String = ""

    var body: some View {
        TabView {
            // 【ホーム】
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

            // 【お財布（分析）】
            NavigationView {
                WalletAnalysisView(transactions: transactions)
                    .navigationTitle("お財布")
            }
            .tabItem { Label("お財布", systemImage: "wallet.pass") }

            // 【設定】
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
            PostView(inputText: $inputText, isPresented: $isShowingInputSheet) { addTransaction() }
        }
    }

    func addTransaction() {
        let components = inputText.components(separatedBy: .whitespacesAndNewlines)
        let amount = Int(components.filter { Int($0.replacingOccurrences(of: "¥", with: "")) != nil }.first?.replacingOccurrences(of: "¥", with: "") ?? "0") ?? 0
        
        // 支出先の判定（@お財布, @口座, @ポイント）
        var source = "お財布" // デフォルト
        if inputText.contains("@口座") { source = "口座" }
        else if inputText.contains("@ポイント") { source = "ポイント" }

        // 残高への反映
        switch source {
        case "口座": bankBalance -= amount
        case "ポイント": pointBalance -= amount
        default: walletBalance -= amount
        }
        
        // ローソンの自動ポイント付与
        if inputText.contains("ローソン") { pointBalance += (amount / 100) }

        transactions.append(Transaction(amount: amount, date: Date(), note: inputText, source: source))
        inputText = ""
    }
}

// --- キーボードツールバーの修正 ---
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

// TwitterRow 内に支出先バッジを表示
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
                HStack {
                    Text("¥\(item.amount)").fontWeight(.bold)
                    Text("from \(item.source)").font(.caption2).padding(4).background(Color.gray.opacity(0.1)).cornerRadius(4)
                }
                if !item.tags.isEmpty {
                    HStack {
                        ForEach(item.tags, id: \.self) { tag in Text(tag).font(.caption).foregroundColor(.blue) }
                    }
                }
            }
        }.padding()
    }
}

// 他のコンポーネント（BalanceView等）は前回と同じ

struct BalanceView: View {
    let title: String; let amount: Int; let color: Color
    var body: some View {
        VStack {
            Text(title).font(.caption).foregroundColor(.secondary)
            Text("¥\(amount)").font(.system(.subheadline, design: .monospaced)).fontWeight(.bold).foregroundColor(color)
        }.frame(maxWidth: .infinity)
    }
}
