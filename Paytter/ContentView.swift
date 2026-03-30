import SwiftUI
import UIKit

// --- データ構造 ---
struct Transaction: Identifiable, Codable {
    var id = UUID()
    var amount: Int
    var date: Date
    var note: String
    var source: String
    var isIncome: Bool
    
    var cleanNote: String {
        note.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.hasPrefix("#") && !$0.hasPrefix("@") }
            .joined(separator: " ")
    }
    
    var tags: [String] {
        note.components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.hasPrefix("#") }
    }
}

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

// --- カーソル位置入力を可能にするカスタムエディタ (ツールバー対応版) ---
struct CustomTextEditor: UIViewRepresentable {
    @Binding var text: String
    var onInsert: (String) -> Void // 記号挿入用のクロージャ
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.font = .preferredFont(forTextStyle: .body)
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator
        
        // ツールバーの作成
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
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: CustomTextEditor
        init(_ parent: CustomTextEditor) { self.parent = parent }
        
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
        
        @objc func insertHash() { parent.onInsert("#") }
        @objc func insertYen() { parent.onInsert("¥") }
        @objc func insertAt() { parent.onInsert("@") }
        @objc func dismissKeyboard() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}

struct ContentView: View {
    @AppStorage("transactions_v3") var transactions: [Transaction] = []
    @AppStorage("walletBalance") var walletBalance: Int = 0
    @AppStorage("bankBalance") var bankBalance: Int = 0
    @AppStorage("pointBalance") var pointBalance: Int = 0
    
    @State private var isShowingInputSheet = false
    @State private var inputText: String = ""
    @State private var isShowingDeleteAlert = false
    @State private var isShowingSwipeDeleteAlert = false
    @State private var indexSetToDelete: IndexSet?

    var body: some View {
        TabView {
            NavigationView {
                ZStack(alignment: .bottomTrailing) {
                    VStack(spacing: 0) {
                        BalanceHeaderView(wallet: walletBalance, bank: bankBalance, point: pointBalance)
                        List {
                            ForEach(transactions.reversed()) { item in
                                NavigationLink(destination: TransactionDetailView(item: item, 
                                                                                transactions: $transactions,
                                                                                walletBalance: $walletBalance,
                                                                                bankBalance: $bankBalance,
                                                                                pointBalance: $pointBalance)) {
                                    TwitterRow(item: item)
                                        .listRowInsets(EdgeInsets())
                                }
                            }
                            .onDelete { indexSet in
                                self.indexSetToDelete = indexSet
                                self.isShowingSwipeDeleteAlert = true
                            }
                        }
                        .listStyle(.plain)
                        .alert("投稿を削除しますか？", isPresented: $isShowingSwipeDeleteAlert) {
                            Button("キャンセル", role: .cancel) { indexSetToDelete = nil }
                            Button("削除", role: .destructive) {
                                if let offsets = indexSetToDelete { deleteTransaction(at: offsets) }
                            }
                        }
                    }

                    Button(action: { inputText = ""; isShowingInputSheet = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color(red: 0.11, green: 0.63, blue: 0.95))
                            .clipShape(Circle())
                    }
                    .padding(20).padding(.bottom, 10)
                }
                .navigationTitle("ホーム")
                .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem { Label("ホーム", systemImage: "house") }

            NavigationView {
                WalletAnalysisView(transactions: transactions)
                    .navigationTitle("お財布")
            }
            .tabItem { Label("お財布", systemImage: "wallet.pass") }

            NavigationView {
                List {
                    Section(header: Text("データ管理")) {
                        Button("データを全削除する", role: .destructive) { isShowingDeleteAlert = true }
                    }
                }
                .navigationTitle("設定")
                .alert("データの全削除", isPresented: $isShowingDeleteAlert) {
                    Button("キャンセル", role: .cancel) { }
                    Button("削除する", role: .destructive) {
                        transactions = []; walletBalance = 0; bankBalance = 0; pointBalance = 0
                    }
                } message: { Text("これまでの投稿と残高がすべて消去されます。よろしいですか？") }
            }
            .tabItem { Label("設定", systemImage: "gearshape") }
        }
        .sheet(isPresented: $isShowingInputSheet) {
            PostView(inputText: $inputText, isPresented: $isShowingInputSheet) { isIncome in
                addTransaction(isIncome: isIncome)
            }
        }
    }

    func addTransaction(isIncome: Bool) {
        let amount = parseAmount(from: inputText)
        let source = parseSource(from: inputText)
        let change = isIncome ? amount : -amount
        updateBalance(source: source, change: change)
        if !isIncome && inputText.contains("ローソン") { pointBalance += (amount / 100) }
        transactions.append(Transaction(amount: amount, date: Date(), note: inputText, source: source, isIncome: isIncome))
        inputText = ""
    }
    
    func deleteTransaction(at offsets: IndexSet) {
        for index in offsets {
            let reversedIndex = transactions.count - 1 - index
            let item = transactions[reversedIndex]
            updateBalance(source: item.source, change: item.isIncome ? -item.amount : item.amount)
            if !item.isIncome && item.note.contains("ローソン") { pointBalance -= (item.amount / 100) }
            transactions.remove(at: reversedIndex)
        }
    }
    
    func updateBalance(source: String, change: Int) {
        switch source {
        case "口座": bankBalance += change
        case "ポイント": pointBalance += change
        default: walletBalance += change
        }
    }
    
    func parseAmount(from text: String) -> Int {
        let components = text.components(separatedBy: .whitespacesAndNewlines)
        let amountText = components.filter { $0.contains("¥") || Int($0) != nil }.first?.replacingOccurrences(of: "¥", with: "") ?? "0"
        return Int(amountText) ?? 0
    }
    
    func parseSource(from text: String) -> String {
        if text.contains("@口座") { return "口座" }
        if text.contains("@ポイント") { return "ポイント" }
        return "お財布"
    }
}

// --- 詳細画面 ---
struct TransactionDetailView: View {
    let item: Transaction
    @Binding var transactions: [Transaction]
    @Binding var walletBalance: Int
    @Binding var bankBalance: Int
    @Binding var pointBalance: Int
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
                    Text(item.source).font(.system(size: 10, weight: .bold)).padding(.horizontal, 8).padding(.vertical, 3).background(Color.gray.opacity(0.1)).cornerRadius(5)
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
            Button("キャンセル", role: .cancel) { }
            Button("削除", role: .destructive) { deleteThis() }
        }
        .sheet(isPresented: $isShowingEditSheet) {
            PostView(inputText: $editLineText, isPresented: $isShowingEditSheet) { isIncome in updateThis(newIncome: isIncome) }
        }
    }
    
    func deleteThis() {
        if let index = transactions.firstIndex(where: { $0.id == item.id }) {
            let change = item.isIncome ? -item.amount : item.amount
            modifyBalance(source: item.source, change: change)
            transactions.remove(at: index)
            dismiss()
        }
    }
    
    func updateThis(newIncome: Bool) {
        if let index = transactions.firstIndex(where: { $0.id == item.id }) {
            modifyBalance(source: item.source, change: item.isIncome ? -item.amount : item.amount)
            let newAmount = parseAmount(from: editLineText)
            let newSource = editLineText.contains("@口座") ? "口座" : (editLineText.contains("@ポイント") ? "ポイント" : "お財布")
            modifyBalance(source: newSource, change: newIncome ? newAmount : -newAmount)
            transactions[index] = Transaction(id: item.id, amount: newAmount, date: item.date, note: editLineText, source: newSource, isIncome: newIncome)
        }
    }
    
    func parseAmount(from text: String) -> Int {
        let components = text.components(separatedBy: .whitespacesAndNewlines)
        let amountText = components.filter { $0.contains("¥") || Int($0) != nil }.first?.replacingOccurrences(of: "¥", with: "") ?? "0"
        return Int(amountText) ?? 0
    }

    func modifyBalance(source: String, change: Int) {
        switch source {
        case "口座": bankBalance += change
        case "ポイント": pointBalance += change
        default: walletBalance += change
        }
    }
}

// --- 投稿画面 ---
struct PostView: View {
    @Binding var inputText: String
    @Binding var isPresented: Bool
    var onPost: (Bool) -> Void
    
    var body: some View {
        NavigationView {
            VStack {
                HStack(alignment: .top) {
                    Image(systemName: "person.circle.fill").resizable().frame(width: 40, height: 40).foregroundColor(.gray)
                    ZStack(alignment: .topLeading) {
                        // カスタムエディタ側に記号挿入ロジックを渡す
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
            .navigationBarItems(
                leading: Button("キャンセル") { isPresented = false },
                trailing: HStack(spacing: 12) {
                    Button("支出") { onPost(false); isPresented = false }.padding(.horizontal, 12).padding(.vertical, 6).background(Color.red.opacity(0.8)).foregroundColor(.white).cornerRadius(15)
                    Button("収入") { onPost(true); isPresented = false }.padding(.horizontal, 12).padding(.vertical, 6).background(Color.blue).foregroundColor(.white).cornerRadius(15)
                }
            )
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

// UITextViewを見つけるためのヘルパー
extension UIView {
    func findTextView() -> UITextView? {
        if let textView = self as? UITextView { return textView }
        for subview in subviews {
            if let textView = subview.findTextView() { return textView }
        }
        return nil
    }
}

// --- 共通部品 ---
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

struct HighlightedText: View {
    let text: String; let isIncome: Bool
    var body: some View {
        let words = text.components(separatedBy: " ")
        return words.reduce(Text("")) { (result, word) in
            if word.contains("¥") || (Int(word.replacingOccurrences(of: "¥", with: "")) != nil) {
                return result + Text(word + " ").foregroundColor(isIncome ? Color(red: 0.1, green: 0.7, blue: 0.1) : .red).fontWeight(.bold)
            } else { return result + Text(word + " ") }
        }
    }
}

struct WalletAnalysisView: View {
    let transactions: [Transaction]
    var monthlyTotal: Int { transactions.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount } }
    var body: some View {
        List {
            Section(header: Text("今月のサマリー")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("合計支出").font(.caption).foregroundColor(.secondary)
                    Text("¥\(monthlyTotal)").font(.system(.title, design: .rounded).bold())
                    ProgressView(value: min(Double(monthlyTotal), 50000), total: 50000).accentColor(monthlyTotal > 45000 ? .red : .blue)
                    Text("予算 ¥50,000 まであと ¥\(max(0, 50000 - monthlyTotal))").font(.caption2).foregroundColor(.secondary)
                }.padding(.vertical, 10)
            }
        }.listStyle(.insetGrouped)
    }
}

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
