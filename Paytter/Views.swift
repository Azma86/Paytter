import SwiftUI

// --- 詳細画面 ---
struct TransactionDetailView: View {
    let item: Transaction; @Binding var transactions: [Transaction]; @Binding var accounts: [Account]
    @Environment(\.dismiss) var dismiss; @State private var isShowingEditSheet = false; @State private var editLineText = ""; @State private var isShowingDeleteConfirm = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "person.circle.fill").resizable().frame(width: 56, height: 56).foregroundColor(.gray)
                    VStack(alignment: .leading, spacing: 4) { Text("むつき").font(.headline).fontWeight(.bold).foregroundColor(.primary); Text("@Mutsuki_dev").font(.subheadline).foregroundColor(.secondary) }
                    Spacer(); Text(item.source).font(.system(size: 10, weight: .bold)).padding(.horizontal, 8).padding(.vertical, 3).background(Color.gray.opacity(0.1)).cornerRadius(5).foregroundColor(.primary)
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
        .sheet(isPresented: $isShowingEditSheet) { PostView(inputText: $editLineText, isPresented: $isShowingEditSheet, initialDate: item.date, onPost: { isInc, nDate in updateThis(newInc: isInc, newDate: nDate) }, transactions: transactions, accounts: accounts) }
    }
    func deleteThis() { if let idx = transactions.firstIndex(where: { $0.id == item.id }) { transactions.remove(at: idx); dismiss() } }
    func updateThis(newInc: Bool, newDate: Date) {
        if let idx = transactions.firstIndex(where: { $0.id == item.id }) {
            let nAmt = parseAmount(from: editLineText); let nSrc = parseSourceName(from: editLineText)
            transactions[idx] = Transaction(id: item.id, amount: nAmt, date: newDate, note: editLineText, source: nSrc, isIncome: newInc)
        }
    }
    func parseAmount(from t: String) -> Int {
        let comps = t.components(separatedBy: .whitespacesAndNewlines)
        let amtT = comps.filter { $0.contains("¥") }.first?.replacingOccurrences(of: "¥", with: "") ?? "0"
        return Int(amtT) ?? 0
    }
    func parseSourceName(from t: String) -> String {
        for acc in accounts { if t.contains("@\(acc.name)") { return acc.name } }
        return item.source
    }
}

// --- お財布設定 ---
struct AccountCreateView: View {
    @Binding var accounts: [Account]; @Binding var transactions: [Transaction]; @Environment(\.dismiss) var dismiss
    @State private var name = ""; @State private var initial = ""; @State private var selectedType: AccountType = .wallet
    @State private var payday: Int = 1; @State private var withdrawalAccountId: UUID? = nil
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基本情報")) {
                    TextField("お財布の名前", text: $name)
                    Picker(selection: $selectedType) { ForEach(AccountType.allCases, id: \.self) { Label($0.rawValue, systemImage: $0.icon).tag($0) } } label: { Text("種類") }
                    TextField("現在の金額", text: $initial).keyboardType(.numberPad)
                }
                if selectedType == .credit {
                    Section(header: Text("クレジットカード設定")) {
                        Picker(selection: $payday) { ForEach(1...31, id: \.self) { Text("\($0)日").tag($0) }; Text("月末").tag(32) } label: { Text("引き落とし日") }.pickerStyle(.menu)
                        Picker(selection: $withdrawalAccountId) { Text("指定なし").tag(nil as UUID?); ForEach(accounts.filter { $0.type == .bank }) { Text($0.name).tag($0.id as UUID?) } } label: { Text("引き落とし口座") }.pickerStyle(.menu)
                    }
                }
            }.navigationTitle("新しいお財布").navigationBarItems(leading: Button("キャンセル"){ dismiss() }, trailing: Button("追加") {
                let val = Int(initial) ?? 0
                let newAcc = Account(name: name, balance: val, type: selectedType, isVisible: true, payday: selectedType == .credit ? payday : nil, withdrawalAccountId: selectedType == .credit ? withdrawalAccountId : nil)
                accounts.append(newAcc)
                if val != 0 { transactions.append(Transaction(amount: val, date: Date(), note: "お財布登録 @\(name) ¥\(val)", source: name, isIncome: true)) }
                dismiss()
            }.disabled(name.isEmpty))
        }
    }
}

struct AccountEditView: View {
    @Binding var account: Account; @Binding var transactions: [Transaction]; var allAccounts: [Account]
    @State private var editBalance: String = ""; @Environment(\.dismiss) var dismiss
    var body: some View {
        Form {
            Section(header: Text("基本設定")) {
                TextField("名前", text: $account.name)
                Picker(selection: $account.type) { ForEach(AccountType.allCases, id: \.self) { Label($0.rawValue, systemImage: $0.icon).tag($0) } } label: { Text("種類") }
                Toggle("ホーム上部に表示", isOn: $account.isVisible)
            }
            if account.type == .credit {
                Section(header: Text("クレジットカード設定")) {
                    Picker(selection: Binding(get: { account.payday ?? 1 }, set: { account.payday = $0 })) { ForEach(1...31, id: \.self) { Text("\($0)日").tag($0) }; Text("月末").tag(32) } label: { Text("引き落とし日") }.pickerStyle(.menu)
                    Picker(selection: $account.withdrawalAccountId) { Text("指定なし").tag(nil as UUID?); ForEach(allAccounts.filter { $0.type == .bank }) { Text($0.name).tag($0.id as UUID?) } } label: { Text("引き落とし口座") }.pickerStyle(.menu)
                }
            }
            Section(header: Text("残高の調整")) {
                HStack {
                    TextField("新しい残高を入力", text: $editBalance).keyboardType(.numberPad)
                    Button("調整投稿") {
                        if let newVal = Int(editBalance) {
                            let diff = newVal - account.balance
                            if diff != 0 { transactions.append(Transaction(amount: abs(diff), date: Date(), note: "残額調整 @\(account.name) ¥\(abs(diff))", source: account.name, isIncome: diff > 0)) }
                            editBalance = ""; dismiss()
                        }
                    }.buttonStyle(.borderedProminent)
                }
            }
        }.navigationTitle(account.name)
    }
}

struct WalletAnalysisView: View {
    let transactions: [Transaction]; @AppStorage("monthlyBudget") var monthlyBudget: Int = 50000
    var monthlyTotal: Int { transactions.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount } }
    var body: some View {
        List { Section(header: Text("今月のサマリー")) { VStack(alignment: .leading, spacing: 10) { Text("合計支出").font(.caption).foregroundColor(.secondary); Text("¥\(monthlyTotal)").font(.system(.title, design: .rounded).bold()); ProgressView(value: min(Double(monthlyTotal), Double(monthlyBudget)), total: Double(monthlyBudget)).accentColor(monthlyTotal > Int(Double(monthlyBudget) * 0.9) ? .red : .blue); Text("予算 ¥\(monthlyBudget) まであと ¥\(max(0, monthlyBudget - monthlyTotal))").font(.caption2).foregroundColor(.secondary) }.padding(.vertical, 10) } }.listStyle(.insetGrouped).navigationTitle("分析")
    }
}

struct BalanceView: View {
    let title: String; let amount: Int; let color: Color; let diff: Int
    @State private var showDiff = false
    @State private var lastAmount: Int = 0 
    var body: some View {
        VStack {
            Text(title).font(.caption).foregroundColor(.secondary)
            ZStack(alignment: .topTrailing) {
                Text("¥\(amount)").font(.system(.subheadline, design: .monospaced)).fontWeight(.bold).foregroundColor(color).padding(.horizontal, 4)
                if diff != 0 {
                    Text(diff > 0 ? "+\(diff)" : "\(diff)").font(.system(size: 8, weight: .bold, design: .rounded)).foregroundColor(diff > 0 ? .green : .red).offset(x: 20, y: showDiff ? -15 : 0).opacity(showDiff ? 0 : 1)
                }
            }
        }.frame(maxWidth: .infinity).onChange(of: amount) { newValue in if newValue != lastAmount { showDiff = false; withAnimation(.easeOut(duration: 1.5)) { showDiff = true }; lastAmount = newValue } }.onAppear { lastAmount = amount }
    }
}
