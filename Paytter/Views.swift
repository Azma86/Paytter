import SwiftUI

// --- タイムラインの1行 (元のデザインを維持) ---
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
                    Text(item.source).font(.system(size: 9, weight: .bold)).padding(.horizontal, 6).padding(.vertical, 2).background(Color.gray.opacity(0.1)).cornerRadius(4)
                }
                HighlightedText(text: item.cleanNote, isIncome: item.isIncome).font(.subheadline)
                if !item.tags.isEmpty {
                    HStack { ForEach(item.tags, id: \.self) { tag in Text(tag).font(.caption).foregroundColor(.blue) } }
                }
            }
        }.padding(.vertical, 8).padding(.horizontal, 16)
    }
}

// --- お財布編集画面 (設定内) ---
struct AccountEditView: View {
    @Binding var account: Account
    var body: some View {
        Form {
            TextField("名前", text: $account.name)
            TextField("金額", value: $account.balance, formatter: NumberFormatter())
            Toggle("ホームに表示", isOn: $account.isVisible)
        }.navigationTitle("編集")
    }
}

// (※詳細画面・投稿画面・ハイライト等は以前の「お気に入り」の状態を維持)
// 省略していますが、以前提供した CustomTextEditor 等のコードをここに含めます
