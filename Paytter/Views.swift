import SwiftUI

// --- お財布追加画面 ---
struct AccountCreateView: View {
    @Binding var accounts: [Account]
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var initial = ""
    @State private var selectedType: AccountType = .wallet
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基本情報")) {
                    TextField("お財布の名前", text: $name)
                    Picker("種類", selection: $selectedType) {
                        ForEach(AccountType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon).tag(type)
                        }
                    }
                    TextField("現在の金額（初期残高）", text: $initial).keyboardType(.numberPad)
                }
            }
            .navigationTitle("新しいお財布")
            .navigationBarItems(leading: Button("キャンセル"){ dismiss() }, trailing: Button("追加") {
                let val = Int(initial) ?? 0
                accounts.append(Account(name: name, balance: val, type: selectedType))
                dismiss()
            }.disabled(name.isEmpty))
        }
    }
}

// --- お財布編集画面 (残高調整投稿機能付き) ---
struct AccountEditView: View {
    @Binding var account: Account
    @Binding var transactions: [Transaction] // 投稿を追加するために必要
    @State private var editBalance: String = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        Form {
            Section(header: Text("基本設定")) {
                TextField("名前", text: $account.name)
                Picker("種類", selection: $account.type) {
                    ForEach(AccountType.allCases, id: \.self) { type in
                        Label(type.rawValue, systemImage: type.icon).tag(type)
                    }
                }
                Toggle("ホーム上部に表示", isOn: $account.isVisible)
            }
            
            Section(header: Text("残高の調整"), footer: Text("現在の正しい金額を入力すると、「残額調整」としてタイムラインに投稿されます。")) {
                HStack {
                    TextField("新しい残高を入力", text: $editBalance).keyboardType(.numberPad)
                    Button("調整投稿") {
                        if let newVal = Int(editBalance) {
                            let diff = newVal - account.balance
                            if diff != 0 {
                                let isInc = diff > 0
                                let absDiff = abs(diff)
                                // タイムラインへ「残額調整」として投稿
                                let note = "残額調整 @\(account.name) ¥\(absDiff)"
                                transactions.append(Transaction(amount: absDiff, date: Date(), note: note, source: account.name, isIncome: isInc))
                                // account.balance は ContentView の recalculateBalances で自動更新されるため、ここではあえて書き換えない
                            }
                            editBalance = ""
                            dismiss()
                        }
                    }.buttonStyle(.borderedProminent)
                }
            }
        }.navigationTitle(account.name)
    }
}

// --- 他のView(TwitterRow, HighlightedText等)は「指示以外の変更なし」を維持 ---
