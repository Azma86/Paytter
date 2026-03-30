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

// 保存用の拡張
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

// --- ファイル保存管理クラス ---
class BackupManager {
    static let filename = "paytter_backup.json"
    
    static func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    static func saveToFile(transactions: [Transaction]) {
        let url = getDocumentsDirectory().appendingPathComponent(filename)
        do {
            let data = try JSONEncoder().encode(transactions)
            try data.write(to: url, options: [.atomicWrite, .completeFileProtection])
            print("Auto-backup saved to: \(url)")
        } catch {
            print("Failed to save backup: \(error.localizedDescription)")
        }
    }
    
    static func loadFromFile() -> [Transaction]? {
        let url = getDocumentsDirectory().appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([Transaction].self, from: data)
        } catch {
            print("Failed to load backup: \(error.localizedDescription)")
            return nil
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

struct ContentView: View {
    @AppStorage("transactions_v4") var transactions: [Transaction] = []
    @AppStorage("walletBalance") var walletBalance: Int = 0
    @AppStorage("bankBalance") var bankBalance: Int = 0
    @AppStorage("pointBalance") var pointBalance: Int = 0
    
    @State private var isShowingInputSheet = false
    @State private var inputText: String = ""
    @State private var isShowingDeleteAlert = false
    @State private var isShowingSwipeDeleteAlert = false
    @State private var indexSetToDelete: IndexSet?
    @State private var isShowingRestoreAlert = false
    @State private var restoreText: String = ""

    var body: some View {
        TabView {
            NavigationView {
                ZStack(alignment: .bottomTrailing) {
                    VStack(spacing: 0) {
                        BalanceHeaderView(wallet: walletBalance, bank: bankBalance, point: pointBalance)
                        List {
                            ForEach(transactions.reversed()) { item in
                                NavigationLink(destination: TransactionDetailView(item: item, transactions: $transactions, walletBalance: $walletBalance, bankBalance: $bankBalance, pointBalance: $pointBalance)) {
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
                            Button("削除", role: .destructive) { if let offsets = indexSetToDelete { deleteTransaction(at: offsets) } }
                        }
                    }
                    Button(action: { inputText = ""; isShowingInputSheet = true }) {
                        Image(systemName: "plus").font(.system(size: 22, weight: .bold)).foregroundColor(.white).frame(width: 56, height: 56).background(Color.blue).clipShape(Circle())
                    }.padding(20).padding(.bottom, 10)
                }
                .navigationTitle("ホーム")
                .navigationBarTitleDisplayMode(.inline)
            }.tabItem { Label("ホーム", systemImage: "house") }

            NavigationView {
                WalletAnalysisView(transactions: transactions).navigationTitle("お財布")
            }.tabItem { Label("お財布", systemImage: "wallet.pass") }

            NavigationView {
                List {
                    Section(header: Text("バックアップ")) {
                        Button("バックアップをコピー") { UIPasteboard.general.string = transactions.rawValue }
                        Button("バックアップから復元") { isShowingRestoreAlert = true }
                        Button("内蔵ファイルから強制読み込み") {
                            if let saved = BackupManager.loadFromFile() {
                                transactions = saved
                            }
                        }
                    }
                    Section(header: Text("データ管理")) {
                        Button("データを全削除する", role: .destructive) { isShowingDeleteAlert = true }
                    }
                }
                .navigationTitle("設定")
                .alert("テキストから復元", isPresented: $isShowingRestoreAlert) {
                    TextField("ここに貼り付け", text: $restoreText)
                    Button("キャンセル", role: .cancel) { restoreText = "" }
                    Button("復元実行") { if let restored = [Transaction](rawValue: restoreText) { transactions = restored; BackupManager.saveToFile(transactions: transactions); restoreText = "" } }
                }
                .alert("全削除", isPresented: $isShowingDeleteAlert) {
                    Button("キャンセル", role: .cancel) { }
                    Button("削除", role: .destructive) { 
                        transactions = []; walletBalance = 0; bankBalance = 0; pointBalance = 0 
                        BackupManager.saveToFile(transactions: [])
                    }
                }
            }.tabItem { Label("設定", systemImage: "gearshape") }
        }
        .onAppear {
            // アプリ起動時にファイルから自動リカバリを試みる
            if transactions.isEmpty {
                if let saved = BackupManager.loadFromFile() {
                    transactions = saved
                    print("Auto-recovered from file backup.")
                }
            }
        }
        .sheet(isPresented: $isShowingInputSheet) {
            PostView(inputText: $inputText, isPresented: $isShowingInputSheet) { isInc in addTransaction(isInc: isInc) }
        }
    }

    func addTransaction(isInc: Bool) {
        let amount = parseAmount(from: inputText)
        let source = parseSource(from: inputText)
        updateBalance(source: source, change: isInc ? amount : -amount)
        if !isInc && inputText.contains("ローソン") { pointBalance += (amount / 100) }
        transactions.append(Transaction(amount: amount, date: Date(), note: inputText, source: source, isIncome: isInc))
        BackupManager.saveToFile(transactions: transactions) // 保存
    }
    func deleteTransaction(at offsets: IndexSet) {
        for index in offsets {
            let revIndex = transactions.count - 1 - index
            let item = transactions[revIndex]
            updateBalance(source: item.source, change: item.isIncome ? -item.amount : item.amount)
            transactions.remove(at: revIndex)
        }
        BackupManager.saveToFile(transactions: transactions) // 保存
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
        let amt = components.filter { $0.contains("¥") || Int($0) != nil }.first?.replacingOccurrences(of: "¥", with: "") ?? "0"
        return Int(amt) ?? 0
    }
    func parseSource(from text: String) -> String {
        text.contains("@口座") ? "口座" : (text.contains("@ポイント") ? "ポイント" : "お財布")
    }
}

// --- 他のパーツはそのまま維持 ---
struct TransactionDetailView: View {
    let item: Transaction; @Binding var transactions: [Transaction]
    @Binding var walletBalance: Int; @Binding var bankBalance: Int; @Binding var pointBalance: Int
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
    func deleteThis() {
        if let idx = transactions.firstIndex(where: { $0.id == item.id }) {
            modifyBalance(source: item.source, change: item.isIncome ? -item.amount : item.amount)
            transactions.remove(at: idx); BackupManager.saveToFile(transactions: transactions); dismiss()
        }
    }
    func updateThis(newInc: Bool) {
        if let idx = transactions.firstIndex(where: { $0.id == item.id }) {
            modifyBalance(source: item.source, change: item.isIncome ? -item.amount : item.amount)
            let nAmt = parseAmount(from: editLineText); let nSrc = editLineText.contains("@口座") ? "口座" : (editLineText.contains("@ポイント") ? "ポイント" : "お財布")
            modifyBalance(source: nSrc, change: newInc ? nAmt : -nAmt)
            transactions[idx] = Transaction(id: item.id, amount: nAmt, date: item.date, note: editLineText, source: nSrc, isIncome: newInc)
            BackupManager.saveToFile(transactions: transactions)
        }
    }
    func parseAmount(from text: String) -> Int {
        let components = text.components(separatedBy: .whitespacesAndNewlines)
        let amtText = components.filter { $0.contains("¥") || Int($0) != nil }.first?.replacingOccurrences(of: "¥", with: "") ?? "0"
        return Int(amtText) ?? 0
    }
    func modifyBalance(source: String, change: Int) {
        switch source { case "口座": bankBalance += change; case "ポイント": pointBalance += change; default: walletBalance += change }
    }
}

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

extension UIView {
    func findTextView() -> UITextView? {
        if let tv = self as? UITextView { return tv }
        for sv in subviews { if let tv = sv.findTextView() { return tv } }
        return nil
    }
}

struct TwitterRow: View {
    let item: Transaction
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "person.circle.fill").resizable().frame(width: 48, height: 48).foregroundColor(.gray)
            VStack(alignment: .leading, spacing: 4) {
                HStack { Text("むつき").font(.subheadline).fontWeight(.bold); Text("@Mutsuki_dev · \(item.date, style: .time)").font(.caption).foregroundColor(.secondary); Spacer(); Text(item.source).font(.system(size: 9, weight: .bold)).padding(.horizontal, 6).padding(.vertical, 2).background(Color.gray.opacity(0.1)).cornerRadius(4) }
                HighlightedText(text: item.cleanNote, isIncome: item.isIncome).font(.subheadline)
                if !item.tags.isEmpty { HStack { ForEach(item.tags, id: \.self) { tag in Text(tag).font(.caption).foregroundColor(.blue) } } }
            }
        }.padding(.vertical, 8).padding(.horizontal, 16)
    }
}

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

struct WalletAnalysisView: View {
    let transactions: [Transaction]
    var monthlyTotal: Int { transactions.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount } }
    var body: some View {
        List {
            Section(header: Text("今月のサマリー")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("合計支出").font(.caption).foregroundColor(.secondary); Text("¥\(monthlyTotal)").font(.system(.title, design: .rounded).bold())
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
        HStack(spacing: 15) { BalanceView(title: "お財布", amount: wallet, color: .green); BalanceView(title: "口座", amount: bank, color: .blue); BalanceView(title: "ポイント", amount: point, color: .orange) }.padding().background(Color(.systemGray6)); Divider()
    }
}

struct BalanceView: View {
    let title: String; let amount: Int; let color: Color
    var body: some View { VStack { Text(title).font(.caption).foregroundColor(.secondary); Text("¥\(amount)").font(.system(.subheadline, design: .monospaced)).fontWeight(.bold).foregroundColor(color) }.frame(maxWidth: .infinity) }
}
