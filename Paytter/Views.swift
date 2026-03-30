// --- タイムラインの1行 ---
struct TwitterRow: View {
    let item: Transaction
    @AppStorage("accounts_v1") var accounts: [Account] = [] // お財布データを読み込む

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "person.circle.fill").resizable().frame(width: 48, height: 48).foregroundColor(.gray)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("むつき").font(.subheadline).fontWeight(.bold)
                    Text("@Mutsuki_dev · \(item.date, style: .time)").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    
                    // --- 修正ポイント：accountId からお財布の名前を探して表示 ---
                    if let accountId = item.accountId,
                       let account = accounts.first(where: { $0.id == accountId }) {
                        Text(account.name)
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                HighlightedText(text: item.cleanNote, isIncome: item.isIncome).font(.subheadline)
                if !item.tags.isEmpty {
                    HStack { ForEach(item.tags, id: \.self) { tag in Text(tag).font(.caption).foregroundColor(.blue) } }
                }
            }
        }.padding(.vertical, 8).padding(.horizontal, 16)
    }
}
