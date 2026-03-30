import SwiftUI

// --- データ構造 (保存できるように RawRepresentable に対応) ---
struct Transaction: Identifiable, Codable {
    var id = UUID()
    let amount: Int
    let date: Date
    let note: String
    
    var cleanNote: String {
        note.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.hasPrefix("#") }
            .joined(separator: " ")
    }
    
    var tags: [String] {
        note.components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.hasPrefix("#") }
    }
}

// 配列をAppStorageで保存するための拡張
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
    // --- データの保存 (AppStorage) ---
    @AppStorage("transactions") var transactions: [Transaction] = []
    @AppStorage("walletBalance") var walletBalance: Int = 0
    @AppStorage("bankBalance") var bankBalance: Int = 0
    @AppStorage("pointBalance") var pointBalance: Int = 0
    
    @State private var isShowingInputSheet = false
    @State private var inputText: String = ""

    var body: some View {
        TabView {
            // 【1. ホーム画面】
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

                    // ツイートボタン
                    Button(action: { isShowingInputSheet = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color(red: 0.11, green: 0.63, blue: 0.95))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 5)
                    }
                    .padding(20)
                    .padding(.bottom, 10) // タブバーに被らないよう調整
                }
                .navigationTitle("ホーム")
                .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Image(systemName: "house")
                Text("ホーム")
            }

            // 【2. お財布画面 (仮)】
            NavigationView {
                Text("お財布の分析画面（準備中）")
                    .navigationTitle("お財布")
            }
            .tabItem {
                Image(systemName: "wallet.pass")
                Text("お財布")
            }

            // 【3. 設定画面 (仮)】
            NavigationView {
                List {
                    Button("データをリセットする", role: .destructive) {
                        transactions = []
                        walletBalance = 0
                        bankBalance = 0
                        pointBalance = 0
                    }
                }
                .navigationTitle("設定")
            }
            .tabItem {
                Image(systemName: "gearshape")
                Text("設定")
            }
        }
        // シートはTabViewの外に置く
        .sheet(isPresented: $isShowingInputSheet) {
            PostView(inputText: $inputText, isPresented: $isShowingInputSheet) {
                addTransaction()
            }
        }
    }

    func addTransaction() {
        let components = inputText.components(separatedBy: .whitespacesAndNewlines)
        let amountStr = components.filter { Int($0.replacingOccurrences(of: "¥", with: "")) != nil }.first?.replacingOccurrences(of: "¥", with: "") ?? "0"
        let amount = Int(amountStr) ?? 0
        
        if inputText.contains("ローソン") {
            pointBalance += (amount / 100)
        }

        let newAction = Transaction(amount: amount, date: Date(), note: inputText)
        transactions.append(newAction)
        
        walletBalance -= amount
        inputText = ""
    }
}

// --- コンポーネント分離 ---
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

struct TwitterRow: View {
    let item: Transaction
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "person.circle.fill").resizable().frame(width: 48, height: 48).foregroundColor(.gray)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("むつき").font(.subheadline).fontWeight(.bold)
                    Image(systemName: "checkmark.seal.fill").foregroundColor(.blue).font(.caption)
                    Text("@Mutsuki_dev · ").font(.caption).foregroundColor(.secondary)
                    Text(item.date, style: .time).font(.caption).foregroundColor(.secondary)
                }
                Text(item.cleanNote).font(.subheadline)
                if !item.tags.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(item.tags, id: \.self) { tag in
                            Text(tag).font(.caption).foregroundColor(.blue)
                        }
                    }
                }
                HStack(spacing: 40) {
                    Image(systemName: "bubble.left")
                    Image(systemName: "arrow.2.squarepath")
                    Image(systemName: "heart")
                    Image(systemName: "chart.bar")
                }
                .font(.caption).foregroundColor(.secondary).padding(.top, 6)
            }
        }.padding()
    }
}

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
                    Button("# (タグ)") { inputText += "#" }.fontWeight(.bold)
                    Button("¥ (金額)") { inputText += "¥" }.fontWeight(.bold)
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
