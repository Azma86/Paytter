import SwiftUI

// --- お財布作成画面 ---
struct AccountCreateView: View {
    @Binding var accounts: [Account]
    @Binding var transactions: [Transaction]
    @Environment(\.dismiss) var dismiss
    
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    
    @State private var name = ""
    @State private var balance = ""
    @State private var type = AccountType.wallet
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: themeBG).ignoresSafeArea()
                Form {
                    Section(header: Text("基本情報")) {
                        TextField("名前", text: $name)
                        Picker("種類", selection: $type) {
                            ForEach(AccountType.allCases, id: \.self) { t in
                                Label(t.rawValue, systemImage: t.icon).tag(t)
                            }
                        }
                    }
                    Section(header: Text("初期残高")) {
                        // 【修正】かな英数の数値キーボード
                        TextField("¥0", text: $balance)
                            .keyboardType(.numbersAndPunctuation)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("新しいお財布").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("キャンセル") { dismiss() }.foregroundColor(Color(hex: themeMain)) }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("作成") {
                        let initialBalance = Int(balance) ?? 0
                        let newAcc = Account(name: name, balance: initialBalance, type: type)
                        accounts.append(newAcc)
                        if initialBalance != 0 {
                            let tx = Transaction(amount: abs(initialBalance), date: Date(), note: "初期残高調整", source: name, isIncome: initialBalance > 0)
                            transactions.append(tx)
                        }
                        dismiss()
                    }.disabled(name.isEmpty).foregroundColor(Color(hex: themeMain))
                }
            }
            .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }
}

// --- お財布編集画面 ---
struct AccountEditView: View {
    @Binding var account: Account; @Binding var transactions: [Transaction]; var allAccounts: [Account]
    @Environment(\.dismiss) var dismiss
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    @State private var diffAmount = ""
    
    var body: some View {
        ZStack {
            Color(hex: themeBG).ignoresSafeArea()
            Form {
                Section(header: Text("お財布の設定")) {
                    TextField("名前", text: $account.name)
                    Picker("種類", selection: $account.type) {
                        ForEach(AccountType.allCases, id: \.self) { t in Text(t.rawValue).tag(t) }
                    }
                    Toggle("ホームに表示", isOn: $account.isVisible)
                }
                Section(header: Text("残高調整"), footer: Text("現在の残高: ¥\(account.balance)\n確定すると差額が自動投稿されます。")) {
                    HStack {
                        Text("実残高:")
                        // 【修正】かな英数の数値キーボード
                        TextField("¥\(account.balance)", text: $diffAmount)
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                    }
                    Button("残高を確定する") {
                        if let newBalance = Int(diffAmount) {
                            let diff = newBalance - account.balance
                            if diff != 0 {
                                let tx = Transaction(amount: abs(diff), date: Date(), note: "残高調整", source: account.name, isIncome: diff > 0)
                                transactions.append(tx)
                                account.balance = newBalance
                            }
                            diffAmount = ""; dismiss()
                        }
                    }.disabled(diffAmount.isEmpty).foregroundColor(Color(hex: themeMain))
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(account.name)
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}

// --- 残高表示（ホームで使用） ---
struct BalanceView: View {
    let title: String; let amount: Int; let color: Color; let diff: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 10, weight: .bold)).foregroundColor(color.opacity(0.6))
            HStack(alignment: .bottom, spacing: 2) {
                Text("¥").font(.system(size: 10, weight: .bold)).foregroundColor(color).padding(.bottom, 2)
                Text("\(amount)").font(.system(size: 16, weight: .black, design: .rounded)).foregroundColor(color)
            }
            if diff != 0 { Text(diff > 0 ? "+\(diff)" : "\(diff)").font(.system(size: 8, weight: .bold, design: .rounded)).foregroundColor(diff > 0 ? .green : .red) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

// --- 投稿詳細・編集画面 ---
struct TransactionDetailView: View {
    @State var item: Transaction; @Binding var transactions: [Transaction]; @Binding var accounts: [Account]
    @Environment(\.dismiss) var dismiss
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_barText") var themeBarText: String = "#FF000000"
    
    var body: some View {
        ZStack {
            Color(hex: themeBG).ignoresSafeArea()
            Form {
                Section(header: Text("内容")) {
                    TextField("メモ", text: $item.note, axis: .vertical)
                    TextField("金額", value: $item.amount, format: .number).keyboardType(.numberPad)
                    Toggle("収入として記録", isOn: $item.isIncome)
                }
                Section {
                    Button("保存する") {
                        if let idx = transactions.firstIndex(where: { $0.id == item.id }) {
                            transactions[idx] = item
                            dismiss()
                        }
                    }
                    Button("この投稿を削除", role: .destructive) {
                        transactions.removeAll(where: { $0.id == item.id })
                        dismiss()
                    }
                }
            }.scrollContentBackground(.hidden)
        }
        .navigationTitle("投稿の詳細")
    }
}
