import SwiftUI

// --- 1. 色の16進数変換サポート ---
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }

    func toHex() -> String {
        let uic = UIColor(self)
        var r: CGFloat = 0; var g: CGFloat = 0; var b: CGFloat = 0; var a: CGFloat = 0
        uic.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X%02X", Int(a * 255), Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

// --- 2. 残高表示のコンポーネント ---
struct BalanceView: View {
    let title: String
    let amount: Int
    let color: Color
    let diff: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 10, weight: .bold)).foregroundColor(color.opacity(0.6))
            HStack(alignment: .bottom, spacing: 2) {
                Text("¥").font(.system(size: 10, weight: .bold)).foregroundColor(color).padding(.bottom, 2)
                Text("\(amount)").font(.system(size: 16, weight: .black, design: .rounded)).foregroundColor(color)
            }
            if diff != 0 {
                Text(diff > 0 ? "+\(diff)" : "\(diff)")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundColor(diff > 0 ? .green : .red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// --- 3. Twitter風の行（投稿内容） ---
struct TwitterRow: View {
    let item: Transaction
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    @AppStorage("theme_income") var themeIncome: String = "#FF19B219"
    @AppStorage("theme_expense") var themeExpense: String = "#FFFF3B30"

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle().fill(Color(hex: themeMain)).frame(width: 44, height: 44)
                .overlay(Text("M").foregroundColor(.white).fontWeight(.bold))
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("むつき").font(.subheadline).fontWeight(.bold).foregroundColor(Color(hex: themeBodyText))
                    Text("@mitsuki").font(.caption).foregroundColor(Color(hex: themeSubText))
                    Spacer()
                    Text(timeString(from: item.date)).font(.caption).foregroundColor(Color(hex: themeSubText))
                }
                
                Text(item.note).font(.body).foregroundColor(Color(hex: themeBodyText)).padding(.vertical, 2)
                
                HStack(spacing: 16) {
                    Label("\(item.amount)", systemImage: item.isIncome ? "arrow.up.right.circle" : "arrow.down.left.circle")
                        .foregroundColor(item.isIncome ? Color(hex: themeIncome) : Color(hex: themeExpense))
                    Label(item.source, systemImage: "wallet.pass")
                }
                .font(.caption).foregroundColor(Color(hex: themeSubText)).padding(.top, 2)
            }
        }
        .padding()
    }
    
    func timeString(from date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "H:mm"; return f.string(from: date)
    }
}

// --- 4. 投稿用シート ---
struct PostView: View {
    @Binding var inputText: String
    @Binding var isPresented: Bool
    let initialDate: Date
    let onPost: (Bool, Date) -> Void
    var transactions: [Transaction]
    var accounts: [Account]
    
    @State private var postDate: Date = Date()
    
    var body: some View {
        NavigationView {
            VStack {
                TextField("今何してる？ (¥1000 @口座 #食費)", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain).padding().font(.body)
                DatePicker("日時", selection: $postDate).padding()
                Spacer()
            }
            .navigationTitle("投稿する").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("キャンセル") { isPresented = false } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button("収入") { onPost(true, postDate); isPresented = false }.fontWeight(.bold)
                        Button("支出") { onPost(false, postDate); isPresented = false }.fontWeight(.bold)
                    }
                }
            }
        }.onAppear { postDate = initialDate }
    }
}
