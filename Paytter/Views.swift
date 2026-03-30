import SwiftUI

// --- タイムラインの1行 ---
struct TwitterRow: View {
    let item: Transaction
    @AppStorage("accounts_v1") var accounts: [Account] = [] 

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "person.circle.fill").resizable().frame(width: 48, height: 48).foregroundColor(.gray)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("むつき").font(.subheadline).fontWeight(.bold)
                    Text("@Mutsuki_dev · \(item.date, style: .time)").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    
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

// --- 金額ハイライト ---
struct HighlightedText: View {
    let text: String; let isIncome: Bool
    var body: some View {
        let words = text.components(separatedBy: " ")
        return words.reduce(Text("")) { (res, word) in
            if word.contains("¥") || (Int(word.replacingOccurrences(of: "¥", with: "")) != nil) {
                return res + Text(word + " ").foregroundColor(isIncome ? .green : .red).fontWeight(.bold)
            } else { return res + Text(word + " ") }
        }
    }
}

// --- お財布作成・編集画面 ---
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

// --- 投稿画面 ---
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
                    ZStack(alignment: .topLeading) {
                        CustomTextEditor(text: $inputText) { symbol in
                            insertAtCursor(symbol)
                        }
                        .frame(minHeight: 150)
                        if inputText.isEmpty {
                            Text("どんな買い物をしましたか？").foregroundColor(.gray.opacity(0.7)).padding(.top, 8).padding(.leading, 5).allowsHitTesting(false)
                        }
                    }
                }.padding()
                Spacer()
            }
            .onAppear {
                if selectedAccountId == nil { selectedAccountId = accounts.first?.id }
            }
            .navigationBarItems(leading: Button("キャンセル") { isPresented = false }, trailing: HStack(spacing: 12) {
                Button("支出") { onPost(false, selectedAccountId); isPresented = false }.padding(.horizontal, 12).padding(.vertical, 6).background(Color.red.opacity(0.8)).foregroundColor(.white).cornerRadius(15)
                Button("収入") { onPost(true, selectedAccountId); isPresented = false }.padding(.horizontal, 12).padding(.vertical, 6).background(Color.blue).foregroundColor(.white).cornerRadius(15)
            })
        }
    }

    func insertAtCursor(_ symbol: String) {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first,
           let textView = window.findTextView() {
            let selectedRange = textView.selectedRange
            let insertionText = " " + symbol
            let currentText = textView.text ?? ""
            
            if let range = Range(selectedRange, in: currentText) {
                let newText = currentText.replacingCharacters(in: range, with: insertionText)
                inputText = newText
                DispatchQueue.main.async {
                    textView.selectedRange = NSRange(location: selectedRange.location + insertionText.count, length: 0)
                }
            }
        }
    }
}

// --- カスタムエディタ ---
struct CustomTextEditor: UIViewRepresentable {
    @Binding var text: String
    var onInsert: (String) -> Void
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.font = .preferredFont(forTextStyle: .body)
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let hashBtn = UIBarButtonItem(title: "#", style: .plain, target: context.coordinator, action: #selector(context.coordinator.insertHash))
        let yenBtn = UIBarButtonItem(title: "¥", style: .plain, target: context.coordinator, action: #selector(context.coordinator.insertYen))
        let atBtn = UIBarButtonItem(title: "@", style: .plain, target: context.coordinator, action: #selector(context.coordinator.insertAt))
        let doneBtn = UIBarButtonItem(title: "完了", style: .done, target: context.coordinator, action: #selector(context.coordinator.dismissKeyboard))
        toolbar.items = [hashBtn, yenBtn, atBtn, flexSpace, doneBtn]
        textView.inputAccessoryView = toolbar
        return textView
    }
    func updateUIView(_ uiView: UITextView, context: Context) { if uiView.text != text { uiView.text = text } }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: CustomTextEditor
        init(_ parent: CustomTextEditor) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) { parent.text = textView.text }
        @objc func insertHash() { parent.onInsert("#") }
        @objc func insertYen() { parent.onInsert("¥") }
        @objc func insertAt() { parent.onInsert("@") }
        @objc func dismissKeyboard() { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
    }
}

// --- ヘルパー ---
extension UIView {
    func findTextView() -> UITextView? {
        if let textView = self as? UITextView { return textView }
        for subview in subviews {
            if let textView = subview.findTextView() { return textView }
        }
        return nil
    }
}

// --- お財布分析画面 ---
struct WalletAnalysisView: View {
    let transactions: [Transaction]
    @AppStorage("monthlyBudget") var monthlyBudget: Int = 50000
    
    var monthlyTotal: Int { transactions.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount } }
    
    var body: some View {
        List {
            Section(header: Text("今月のサマリー")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("合計支出").font(.caption).foregroundColor(.secondary)
                    Text("¥\(monthlyTotal)").font(.system(.title, design: .rounded).bold())
                    ProgressView(value: min(Double(monthlyTotal), Double(monthlyBudget)), total: Double(monthlyBudget))
                        .accentColor(monthlyTotal > Int(Double(monthlyBudget) * 0.9) ? .red : .blue)
                    Text("予算 ¥\(monthlyBudget) まであと ¥\(max(0, monthlyBudget - monthlyTotal))").font(.caption2).foregroundColor(.secondary)
                }.padding(.vertical, 10)
            }
        }.listStyle(.insetGrouped)
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
        }.padding().background(Color(.systemGray6))
        Divider()
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

// --- 詳細画面 ---
struct TransactionDetailView: View {
    let item: Transaction
    @Binding var transactions: [Transaction]
    @Binding var accounts: [Account]
    
    @Environment(\.dismiss) var dismiss
    @State private var isShowingEditSheet = false
    @State private var editLineText = ""
    @State private var isShowingDeleteConfirm = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "person.circle.fill").resizable().frame(width: 56, height: 56).foregroundColor(.gray)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("むつき").font(.headline).fontWeight(.bold)
                        Text("@Mutsuki_dev").font(.subheadline).foregroundColor(.secondary)
                    }
                    Spacer()
                    if let accId = item.accountId, let acc = accounts.first(where: { $0.id == accId }) {
                        Text(acc.name).font(.system(size: 10, weight: .bold)).padding(.horizontal, 8).padding(.vertical, 3).background(Color.gray.opacity(0.1)).cornerRadius(5)
                    }
                }
                
                HighlightedText(text: item.cleanNote, isIncome: item.isIncome).font(.title3)
                if !item.tags.isEmpty {
                    HStack(spacing: 12) { ForEach(item.tags, id: \.self) { tag in Text(tag).font(.subheadline).foregroundColor(.blue) } }
                }
                Text(item.date, style: .date) + Text(" " ) + Text(item.date, style: .time)
                Divider()
                HStack(spacing: 60) {
                    Image(systemName: "bubble.left"); Image(systemName: "arrow.2.squarepath"); Image(systemName: "heart"); Image(systemName: "shareplay")
                }.font(.subheadline).foregroundColor(.secondary).frame(maxWidth: .infinity)
            }.padding()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button(action: { editLineText = item.note; isShowingEditSheet = true }) { Image(systemName: "pencil.line") }
                    Button(action: { isShowingDeleteConfirm = true }) { Image(systemName: "trash") }.foregroundColor(.red)
                }
            }
        }
        .alert("投稿を削除しますか？", isPresented: $isShowingDeleteConfirm) {
            Button("キャンセル", role: .cancel) { }; Button("削除", role: .destructive) { deleteThis() }
        }
        .sheet(isPresented: $isShowingEditSheet) {
            PostView(inputText: $editLineText, isPresented: $isShowingEditSheet, accounts: accounts) { isInc, accId in
                updateThis(newInc: isInc, newAccId: accId)
            }
        }
    }
    
    func deleteThis() {
        if let idx = transactions.firstIndex(where: { $0.id == item.id }) {
            if let accId = item.accountId, let accIdx = accounts.firstIndex(where: { $0.id == accId }) {
                accounts[accIdx].balance += (item.isIncome ? -item.amount : item.amount)
            }
            transactions.remove(at: idx)
            BackupManager.saveAll(transactions: transactions, accounts: accounts)
            dismiss()
        }
    }
    
    func updateThis(newInc: Bool, newAccId: UUID?) {
        if let idx = transactions.firstIndex(where: { $0.id == item.id }) {
            if let oldAccId = item.accountId, let oldAccIdx = accounts.firstIndex(where: { $0.id == oldAccId }) {
                accounts[oldAccIdx].balance += (item.isIncome ? -item.amount : item.amount)
            }
            let nAmt = parseAmount(from: editLineText)
            if let nAccId = newAccId, let nAccIdx = accounts.firstIndex(where: { $0.id == nAccId }) {
                accounts[nAccIdx].balance += (newInc ? nAmt : -nAmt)
            }
            transactions[idx] = Transaction(id: item.id, amount: nAmt, date: item.date, note: editLineText, accountId: newAccId, isIncome: newInc)
            BackupManager.saveAll(transactions: transactions, accounts: accounts)
        }
    }
    
    func parseAmount(from text: String) -> Int {
        let components = text.components(separatedBy: .whitespacesAndNewlines)
        let amtText = components.filter { $0.contains("¥") || Int($0) != nil }.first?.replacingOccurrences(of: "¥", with: "") ?? "0"
        return Int(amtText) ?? 0 // 修正：ここを 0 にしました
    }
}
