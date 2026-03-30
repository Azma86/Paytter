import SwiftUI
import UIKit

// --- タイムラインの1行 ---
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

// --- 金額ハイライト ---
struct HighlightedText: View {
    let text: String; let isIncome: Bool
    var body: some View {
        let words = text.components(separatedBy: " ")
        return words.reduce(Text("")) { (res, word) in
            if word.contains("¥") || (Int(word.replacingOccurrences(of: "¥", with: "")) != nil) {
                return res + Text(word + " ").foregroundColor(isIncome ? Color(red: 0.1, green: 0.7, blue: 0.1) : .red).fontWeight(.bold)
            } else { return res + Text(word + " ") }
        }
    }
}

// --- 投稿画面 ---
struct PostView: View {
    @Binding var inputText: String; @Binding var isPresented: Bool; var onPost: (Bool) -> Void
    var body: some View {
        NavigationView {
            VStack {
                HStack(alignment: .top) {
                    Image(systemName: "person.circle.fill").resizable().frame(width: 40, height: 40).foregroundColor(.gray)
                    ZStack(alignment: .topLeading) {
                        CustomTextEditor(text: $inputText) { sym in insertAtCursor(sym) }.frame(minHeight: 150)
                        if inputText.isEmpty { Text("どんな買い物をしましたか？").foregroundColor(.gray.opacity(0.7)).padding(.top, 8).padding(.leading, 5).allowsHitTesting(false) }
                    }
                }.padding()
                Spacer()
            }
            .navigationBarItems(leading: Button("キャンセル") { isPresented = false }, trailing: HStack(spacing: 12) {
                Button("支出") { onPost(false); isPresented = false }.padding(.horizontal, 12).padding(.vertical, 6).background(Color.red.opacity(0.8)).foregroundColor(.white).cornerRadius(15)
                Button("収入") { onPost(true); isPresented = false }.padding(.horizontal, 12).padding(.vertical, 6).background(Color.blue).foregroundColor(.white).cornerRadius(15)
            })
        }
    }
    func insertAtCursor(_ sym: String) {
        if let sc = UIApplication.shared.connectedScenes.first as? UIWindowScene, let win = sc.windows.first, let tv = win.findTextView() {
            let sel = tv.selectedRange; let ins = " " + sym; let cur = tv.text ?? ""
            if let ran = Range(sel, in: cur) {
                let nText = cur.replacingCharacters(in: ran, with: ins)
                inputText = nText
                DispatchQueue.main.async { tv.selectedRange = NSRange(location: sel.location + ins.count, length: 0) }
            }
        }
    }
}

// --- 詳細画面 ---
struct TransactionDetailView: View {
    let item: Transaction; @Binding var transactions: [Transaction]; @Binding var accounts: [Account]
    @Environment(\.dismiss) var dismiss; @State private var isShowingEditSheet = false; @State private var editLineText = ""; @State private var isShowingDeleteConfirm = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "person.circle.fill").resizable().frame(width: 56, height: 56).foregroundColor(.gray)
                    VStack(alignment: .leading, spacing: 4) { Text("むつき").font(.headline).fontWeight(.bold); Text("@Mutsuki_dev").font(.subheadline).foregroundColor(.secondary) }
                    Spacer(); Text(item.source).font(.system(size: 10, weight: .bold)).padding(.horizontal, 8).padding(.vertical, 3).background(Color.gray.opacity(0.1)).cornerRadius(5)
                }
                HighlightedText(text: item.cleanNote, isIncome: item.isIncome).font(.title3)
                if !item.tags.isEmpty { HStack(spacing: 12) { ForEach(item.tags, id: \.self) { tag in Text(tag).font(.subheadline).foregroundColor(.blue) } } }
                Text(item.date, style: .date) + Text(" " ) + Text(item.date, style: .time)
                Divider()
                HStack(spacing: 60) { Image(systemName: "bubble.left"); Image(systemName: "arrow.2.squarepath"); Image(systemName: "heart"); Image(systemName: "shareplay") }.font(.subheadline).foregroundColor(.secondary).frame(maxWidth: .infinity)
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
        .alert("投稿を削除しますか？", isPresented: $isShowingDeleteConfirm) { Button("キャンセル", role: .cancel) { }; Button("削除", role: .destructive) { deleteThis() } }
        .sheet(isPresented: $isShowingEditSheet) { PostView(inputText: $editLineText, isPresented: $isShowingEditSheet) { isInc in updateThis(newInc: isInc) } }
    }
    func deleteThis() { if let idx = transactions.firstIndex(where: { $0.id == item.id }) { transactions.remove(at: idx); dismiss() } }
    func updateThis(newInc: Bool) {
        if let idx = transactions.firstIndex(where: { $0.id == item.id }) {
            let nAmt = parseAmount(from: editLineText); let nSrc = parseSourceName(from: editLineText)
            transactions[idx] = Transaction(id: item.id, amount: nAmt, date: item.date, note: editLineText, source: nSrc, isIncome: newInc)
        }
    }
    func parseAmount(from text: String) -> Int {
        let components = text.components(separatedBy: .whitespacesAndNewlines)
        let amtText = components.filter { $0.contains("¥") || Int($0) != nil }.first?.replacingOccurrences(of: "¥", with: "") ?? "0"
        return Int(amtText) ?? 0
    }
    func parseSourceName(from text: String) -> String {
        for acc in accounts { if text.contains("@\(acc.name)") { return acc.name } }
        return "お財布"
    }
}

// --- お財布追加画面 ---
struct AccountCreateView: View {
    @Binding var accounts: [Account]
    @Binding var transactions: [Transaction]
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var initial = ""
    @State private var selectedType: AccountType = .wallet
    @State private var payday: Int = 1
    @State private var withdrawalAccountId: UUID? = nil
    
    var bankAccounts: [Account] { accounts.filter { $0.type == .bank } }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基本情報")) {
                    TextField("お財布の名前", text: $name)
                    Picker(selection: $selectedType) {
                        ForEach(AccountType.allCases, id: \.self) { type in Label(type.rawValue, systemImage: type.icon).tag(type) }
                    } label: { Text("種類") }
                    TextField("現在の金額", text: $initial).keyboardType(.numberPad)
                }
                
                if selectedType == .credit {
                    Section(header: Text("クレジットカード設定")) {
                        Picker(selection: $payday) {
                            ForEach(1...31, id: \.self) { day in Text("\(day)日").tag(day) }
                            Text("月末").tag(32)
                        } label: { Text("引き落とし日") }.pickerStyle(.wheel)
                        
                        Picker(selection: $withdrawalAccountId) {
                            Text("指定なし").tag(nil as UUID?)
                            ForEach(bankAccounts) { acc in Text(acc.name).tag(acc.id as UUID?) }
                        } label: { Text("引き落とし口座") }
                    }
                }
            }
            .navigationTitle("新しいお財布")
            .navigationBarItems(leading: Button("キャンセル"){ dismiss() }, trailing: Button("追加") {
                let val = Int(initial) ?? 0
                let newAcc = Account(name: name, balance: val, type: selectedType, isVisible: true, payday: selectedType == .credit ? payday : nil, withdrawalAccountId: selectedType == .credit ? withdrawalAccountId : nil)
                accounts.append(newAcc)
                if val != 0 {
                    transactions.append(Transaction(amount: val, date: Date(), note: "お財布登録 @\(name) ¥\(val)", source: name, isIncome: true))
                }
                dismiss()
            }.disabled(name.isEmpty))
        }
    }
}

// --- お財布編集画面 ---
struct AccountEditView: View {
    @Binding var account: Account; @Binding var transactions: [Transaction]
    var allAccounts: [Account]
    @State private var editBalance: String = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        Form {
            Section(header: Text("基本設定")) {
                TextField("名前", text: $account.name)
                Picker(selection: $account.type) {
                    ForEach(AccountType.allCases, id: \.self) { type in Label(type.rawValue, systemImage: type.icon).tag(type) }
                } label: { Text("種類") }
                Toggle("ホーム上部に表示", isOn: $account.isVisible)
            }
            
            if account.type == .credit {
                Section(header: Text("クレジットカード設定")) {
                    Picker(selection: Binding(
                        get: { account.payday ?? 1 },
                        set: { account.payday = $0 }
                    )) {
                        ForEach(1...31, id: \.self) { day in Text("\(day)日").tag(day) }
                        Text("月末").tag(32)
                    } label: { Text("引き落とし日") }.pickerStyle(.wheel)
                    
                    Picker(selection: $account.withdrawalAccountId) {
                        Text("指定なし").tag(nil as UUID?)
                        ForEach(allAccounts.filter { $0.type == .bank }) { acc in
                            Text(acc.name).tag(acc.id as UUID?)
                        }
                    } label: { Text("引き落とし口座") }
                }
            }
            
            Section(header: Text("残高の調整")) {
                HStack {
                    TextField("新しい残高を入力", text: $editBalance).keyboardType(.numberPad)
                    Button("調整投稿") {
                        if let newVal = Int(editBalance) {
                            let diff = newVal - account.balance
                            if diff != 0 {
                                let isInc = diff > 0
                                let absDiff = abs(diff)
                                transactions.append(Transaction(amount: absDiff, date: Date(), note: "残額調整 @\(account.name) ¥\(absDiff)", source: account.name, isIncome: isInc))
                            }
                            editBalance = ""; dismiss()
                        }
                    }.buttonStyle(.borderedProminent)
                }
            }
        }.navigationTitle(account.name)
    }
}

// --- 分析画面 ---
struct WalletAnalysisView: View {
    let transactions: [Transaction]
    @AppStorage("monthlyBudget") var monthlyBudget: Int = 50000
    var monthlyTotal: Int { transactions.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount } }
    var body: some View {
        List {
            Section(header: Text("今月のサマリー")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("合計支出").font(.caption).foregroundColor(.secondary); Text("¥\(monthlyTotal)").font(.system(.title, design: .rounded).bold())
                    ProgressView(value: min(Double(monthlyTotal), Double(monthlyBudget)), total: Double(monthlyBudget)).accentColor(monthlyTotal > Int(Double(monthlyBudget) * 0.9) ? .red : .blue)
                    Text("予算 ¥\(monthlyBudget) まであと ¥\(max(0, monthlyBudget - monthlyTotal))").font(.caption2).foregroundColor(.secondary)
                }.padding(.vertical, 10)
            }
        }.listStyle(.insetGrouped).navigationTitle("分析")
    }
}

// --- 共通部品 ---
struct BalanceView: View {
    let title: String; let amount: Int; let color: Color
    var body: some View {
        VStack {
            Text(title).font(.caption).foregroundColor(.secondary)
            Text("¥\(amount)").font(.system(.subheadline, design: .monospaced)).fontWeight(.bold).foregroundColor(color)
        }.frame(maxWidth: .infinity)
    }
}

struct CustomTextEditor: UIViewRepresentable {
    @Binding var text: String; var onInsert: (String) -> Void
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView(); textView.font = .preferredFont(forTextStyle: .body); textView.backgroundColor = .clear; textView.delegate = context.coordinator
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let hashBtn = UIBarButtonItem(title: "#", style: .plain, target: context.coordinator, action: #selector(context.coordinator.insertHash))
        let yenBtn = UIBarButtonItem(title: "¥", style: .plain, target: context.coordinator, action: #selector(context.coordinator.insertYen))
        let atBtn = UIBarButtonItem(title: "@", style: .plain, target: context.coordinator, action: #selector(context.coordinator.insertAt))
        let doneBtn = UIBarButtonItem(title: "完了", style: .done, target: context.coordinator, action: #selector(context.coordinator.dismissKeyboard))
        toolbar.items = [hashBtn, yenBtn, atBtn, flexSpace, doneBtn]; textView.inputAccessoryView = toolbar; return textView
    }
    func updateUIView(_ uiView: UITextView, context: Context) { if uiView.text != text { uiView.text = text } }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: CustomTextEditor; init(_ parent: CustomTextEditor) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) { parent.text = textView.text }
        @objc func insertHash() { parent.onInsert("#") }; @objc func insertYen() { parent.onInsert("¥") }; @objc func insertAt() { parent.onInsert("@") }
        @objc func dismissKeyboard() { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
    }
}

extension UIView {
    func findTextView() -> UITextView? {
        if let tv = self as? UITextView { return tv }
        for sv in subviews { if let tv = sv.findTextView() { return tv } }
        return nil
    }
}
