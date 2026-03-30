import SwiftUI

struct AccountEditView: View {
    @Binding var account: Account?
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String = ""
    @State private var type: AccountType = .wallet
    @State private var balance: String = ""
    @State private var isVisible: Bool = true
    @State private var payday: String = ""
    
    var onSave: (Account) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基本情報")) {
                    TextField("名前（例：三菱UFJ）", text: $name)
                    Picker("種類", selection: $type) {
                        ForEach(AccountType.allCases, id: \.self) { t in
                            Text("\(t.icon) \(t.rawValue)").tag(t)
                        }
                    }
                    TextField("現在の金額", text: $balance).keyboardType(.numberPad)
                }
                
                if type == .card {
                    Section(header: Text("カード設定")) {
                        TextField("引き落とし日（1〜31）", text: $payday).keyboardType(.numberPad)
                    }
                }
                
                Section {
                    Toggle("ホーム上部に表示", isOn: $isVisible)
                }
            }
            .navigationTitle(account == nil ? "お財布の作成" : "お財布の編集")
            .navigationBarItems(leading: Button("キャンセル") { dismiss() }, trailing: Button("保存") {
                let newAcc = Account(
                    id: account?.id ?? UUID(),
                    name: name,
                    type: type,
                    balance: Int(balance) ?? 0,
                    isVisible: isVisible,
                    payday: Int(payday)
                )
                onSave(newAcc)
                dismiss()
            })
            .onAppear {
                if let acc = account {
                    name = acc.name
                    type = acc.type
                    balance = String(acc.balance)
                    isVisible = acc.isVisible
                    payday = acc.payday != nil ? String(acc.payday!) : ""
                }
            }
        }
    }
}

// PostViewも修正（どのお財布か選べるように）
struct PostView: View {
    @Binding var inputText: String
    @Binding var isPresented: Bool
    var accounts: [Account]
    @State private var selectedAccountId: UUID?
    var onPost: (Bool, UUID?) -> Void
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("支出元", selection: $selectedAccountId) {
                    Text("指定なし").tag(UUID?.none)
                    ForEach(accounts) { acc in
                        Text("\(acc.type.icon) \(acc.name)").tag(UUID?.some(acc.id))
                    }
                }.pickerStyle(.menu).padding()
                
                HStack(alignment: .top) {
                    Image(systemName: "person.circle.fill").resizable().frame(width: 40, height: 40).foregroundColor(.gray)
                    CustomTextEditor(text: $inputText) { _ in }.frame(minHeight: 150)
                }.padding()
                Spacer()
            }
            .onAppear { selectedAccountId = accounts.first?.id }
            .navigationBarItems(leading: Button("キャンセル") { isPresented = false }, trailing: HStack {
                Button("支出") { onPost(false, selectedAccountId); isPresented = false }
                Button("収入") { onPost(true, selectedAccountId); isPresented = false }
            })
        }
    }
}
// (※HighlightedTextなどは既存のものを維持してください)
