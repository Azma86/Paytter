import SwiftUI

// --- お財布作成画面 ---
struct AccountCreateView: View {
    @Binding var accounts: [Account]
    @Binding var transactions: [Transaction]
    @Environment(\.dismiss) var dismiss
    
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    
    @State private var name = ""
    @State private var balance = ""
    @State private var type = AccountType.wallet
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: themeBG).ignoresSafeArea()
                Form {
                    Section(header: Text("基本情報").foregroundColor(Color(hex: themeSubText))) {
                        TextField("お財布の名前（銀行名など）", text: $name)
                            .foregroundColor(Color(hex: themeBodyText))
                        Picker("種類", selection: $type) {
                            ForEach(AccountType.allCases, id: \.self) { t in
                                Label(t.rawValue, systemImage: t.icon).tag(t)
                            }
                        }.foregroundColor(Color(hex: themeBodyText))
                    }
                    .listRowBackground(Color(hex: themeBG).opacity(0.5))
                    
                    Section(header: Text("初期残高").foregroundColor(Color(hex: themeSubText))) {
                        TextField("¥0", text: $balance)
                            .keyboardType(.numbersAndPunctuation)
                            .foregroundColor(Color(hex: themeBodyText))
                    }
                    .listRowBackground(Color(hex: themeBG).opacity(0.5))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("新しいお財布").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { 
                    Button("キャンセル") { dismiss() }.foregroundColor(Color(hex: themeMain)) 
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("作成") {
                        let initialBalance = Int(balance) ?? 0
                        let newAcc = Account(name: name, balance: initialBalance, type: type)
                        accounts.append(newAcc)
                        // 【修正】初期残高も投稿（履歴）として反映
                        if initialBalance != 0 {
                            let tx = Transaction(amount: abs(initialBalance), date: Date(), note: "初期残高設定", source: name, isIncome: initialBalance > 0)
                            transactions.append(tx)
                        }
                        dismiss()
                    }.disabled(name.isEmpty).foregroundColor(Color(hex: themeMain)).fontWeight(.bold)
                }
            }
            .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }
}

// --- お財布編集画面 ---
struct AccountEditView: View {
    @Binding var account: Account
    @Binding var transactions: [Transaction]
    var allAccounts: [Account]
    @Environment(\.dismiss) var dismiss
    
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    
    @State private var diffAmount = ""
    
    var body: some View {
        ZStack {
            Color(hex: themeBG).ignoresSafeArea()
            Form {
                Section(header: Text("お財布の設定").foregroundColor(Color(hex: themeSubText))) {
                    TextField("名前", text: $account.name)
                        .foregroundColor(Color(hex: themeBodyText))
                    Picker("種類", selection: $account.type) {
                        ForEach(AccountType.allCases, id: \.self) { t in 
                            Text(t.rawValue).tag(t).foregroundColor(Color(hex: themeBodyText)) 
                        }
                    }
                    Toggle("ホームに表示", isOn: $account.isVisible)
                        .foregroundColor(Color(hex: themeBodyText))
                }
                .listRowBackground(Color(hex: themeBG).opacity(0.5))
                
                Section(header: Text("残高調整").foregroundColor(Color(hex: themeSubText)), 
                        footer: Text("現在の残高: ¥\(account.balance)\n金額を入力して確定すると、差額分が自動的に投稿されます。").foregroundColor(Color(hex: themeSubText))) {
                    HStack {
                        Text("実際のお金:").foregroundColor(Color(hex: themeBodyText))
                        TextField("¥\(account.balance)", text: $diffAmount)
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(Color(hex: themeBodyText))
                    }
                    
                    Button(action: {
                        if let newBalance = Int(diffAmount) {
                            let diff = newBalance - account.balance
                            if diff != 0 {
                                // 【修正】差額分を新しい投稿として作成
                                let tx = Transaction(
                                    amount: abs(diff),
                                    date: Date(),
                                    note: "残高調整 (@\(account.name))",
                                    source: account.name,
                                    isIncome: diff > 0
                                )
                                transactions.append(tx)
                                // 残高も即時同期
                                account.balance = newBalance
                            }
                            diffAmount = ""
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            dismiss()
                        }
                    }) {
                        Text("残高を確定して投稿する")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(diffAmount.isEmpty)
                    .foregroundColor(Color(hex: themeMain))
                }
                .listRowBackground(Color(hex: themeBG).opacity(0.5))
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
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    
    var body: some View {
        ZStack {
            Color(hex: themeBG).ignoresSafeArea()
            Form {
                Section(header: Text("内容").foregroundColor(Color(hex: themeSubText))) {
                    TextField("メモ", text: $item.note, axis: .vertical)
                        .foregroundColor(Color(hex: themeBodyText))
                    HStack {
                        Text("金額").foregroundColor(Color(hex: themeBodyText))
                        TextField("金額", value: $item.amount, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(Color(hex: themeBodyText))
                    }
                    Toggle("収入として記録", isOn: $item.isIncome)
                        .foregroundColor(Color(hex: themeBodyText))
                }
                .listRowBackground(Color(hex: themeBG).opacity(0.5))
                
                Section {
                    Button("変更を保存する") {
                        if let idx = transactions.firstIndex(where: { $0.id == item.id }) {
                            transactions[idx] = item
                            dismiss()
                        }
                    }.foregroundColor(Color(hex: themeMain)).fontWeight(.bold)
                    
                    Button("この投稿を削除", role: .destructive) {
                        transactions.removeAll(where: { $0.id == item.id })
                        dismiss()
                    }
                }
                .listRowBackground(Color(hex: themeBG).opacity(0.5))
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("投稿の詳細")
        .navigationBarTitleDisplayMode(.inline)
    }
}
