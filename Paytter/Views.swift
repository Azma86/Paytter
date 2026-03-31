import SwiftUI
import UIKit

// --- 1. タイムラインの1行 ---
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

// --- 2. 金額ハイライト ---
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

// --- 3. 自作カレンダー画面 (滑らかなリニアスライド対応) ---
struct CalendarView: View {
    @Binding var transactions: [Transaction]
    @Binding var accounts: [Account]
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var isShowingInputSheet = false
    @State private var inputText = ""
    @State private var isShowingMonthPicker = false
    @State private var tempPickerDate = Date()
    
    // スライド用
    @State private var dragOffset: CGFloat = 0

    let calendar = Calendar.current
    let daysOfWeek = ["日", "月", "火", "水", "木", "金", "土"]

    var filteredTransactions: [Transaction] {
        transactions.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted(by: { $0.date > $1.date })
    }

    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            HStack {
                Button(action: { moveMonth(by: -1) }) { Image(systemName: "chevron.left") }
                Spacer()
                Button(action: { tempPickerDate = currentMonth; isShowingMonthPicker = true }) {
                    HStack(spacing: 4) {
                        Text(monthYearString(from: currentMonth)).font(.headline).foregroundColor(.primary)
                        Image(systemName: "chevron.down").font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button(action: { moveMonth(by: 1) }) { Image(systemName: "chevron.right") }
            }.padding(.horizontal).padding(.vertical, 8)

            // 曜日
            HStack {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day).font(.system(size: 11, weight: .bold)).frame(maxWidth: .infinity)
                        .foregroundColor(day == "日" ? .red : (day == "土" ? .blue : .primary))
                }
            }.padding(.bottom, 5)

            // カレンダーグリッド（滑らかなリニアスライド）
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // 前の月
                    monthGrid(for: calendar.date(byAdding: .month, value: -1, to: currentMonth)!, width: geometry.size.width)
                    // 今の月
                    monthGrid(for: currentMonth, width: geometry.size.width)
                    // 次の月
                    monthGrid(for: calendar.date(byAdding: .month, value: 1, to: currentMonth)!, width: geometry.size.width)
                }
                .offset(x: -geometry.size.width + dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in dragOffset = value.translation.width }
                        .onEnded { value in
                            let threshold = geometry.size.width * 0.3
                            if value.translation.width < -threshold {
                                moveMonth(by: 1)
                            } else if value.translation.width > threshold {
                                moveMonth(by: -1)
                            } else {
                                // キャンセル時の動きをリニアに
                                withAnimation(.easeOut(duration: 0.2)) { dragOffset = 0 }
                            }
                        }
                )
            }
            .frame(height: 240)

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    if filteredTransactions.isEmpty {
                        Text("投稿はありません").font(.caption).foregroundColor(.secondary).padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredTransactions) { item in
                                NavigationLink(destination: TransactionDetailView(item: item, transactions: $transactions, accounts: $accounts)) {
                                    TwitterRow(item: item).listRowInsets(EdgeInsets())
                                }
                                Divider()
                            }
                        }
                    }
                    Button(action: { self.inputText = ""; self.isShowingInputSheet = true }) {
                        HStack { Image(systemName: "plus"); Text("投稿を作成") }
                        .font(.subheadline).fontWeight(.bold).frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color.white).foregroundColor(.blue)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.blue.opacity(0.3), lineWidth: 1))
                        .padding(.horizontal, 40).padding(.vertical, 30)
                    }
                }
            }
        }
        .navigationTitle("カレンダー")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingInputSheet) {
            PostView(inputText: $inputText, isPresented: $isShowingInputSheet, initialDate: combinedDate(), onPost: { isInc, nDate in addTransaction(isInc: isInc, date: nDate) }, transactions: transactions, accounts: accounts)
        }
        .sheet(isPresented: $isShowingMonthPicker) {
            NavigationView {
                VStack {
                    DatePicker("年月を選択", selection: $tempPickerDate, displayedComponents: .date)
                        .datePickerStyle(.wheel).labelsHidden().environment(\.locale, Locale(identifier: "ja_JP"))
                }
                .navigationTitle("年月を選択")
                .navigationBarItems(leading: Button("キャンセル") { isShowingMonthPicker = false }, trailing: Button("移動") { currentMonth = tempPickerDate; isShowingMonthPicker = false })
            }.presentationDetents([.height(300)])
        }
    }

    @ViewBuilder
    func monthGrid(for month: Date, width: CGFloat) -> some View {
        let allDays = generateFullGrid(for: month)
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 0) {
            ForEach(0..<allDays.count, id: \.self) { index in
                let date = allDays[index]
                let isCurrentMonth = calendar.isDate(date, equalTo: month, toGranularity: .month)
                let dayTransactions = transactions.filter { calendar.isDate($0.date, inSameDayAs: date) }
                
                VStack(spacing: 2) {
                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(size: 13, design: .rounded))
                        .fontWeight(calendar.isDate(date, inSameDayAs: selectedDate) ? .bold : .regular)
                        .foregroundColor(isCurrentMonth ? (calendar.isDate(date, inSameDayAs: selectedDate) ? .white : .primary) : .gray.opacity(0.25))
                        .frame(width: 24, height: 24)
                        .background(calendar.isDate(date, inSameDayAs: selectedDate) && isCurrentMonth ? Color.blue : Color.clear)
                        .clipShape(Circle())
                    
                    HStack(spacing: 2) {
                        ForEach(dayTransactions.prefix(4)) { tx in
                            Circle()
                                .fill(tx.isIncome ? Color.green : Color.red)
                                .frame(width: 3.5, height: 3.5)
                        }
                    }
                    .frame(height: 4)
                }
                .frame(height: 40)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { if isCurrentMonth { selectedDate = date } else { slideToDate(date) } }
            }
        }
        .frame(width: width)
    }

    func moveMonth(by v: Int) {
        // バネ感のない滑らかなeaseInOutアニメーションに変更
        withAnimation(.easeInOut(duration: 0.25)) {
            if let next = calendar.date(byAdding: .month, value: v, to: currentMonth) {
                currentMonth = next
            }
            dragOffset = 0
        }
    }
    
    func slideToDate(_ date: Date) {
        let isFuture = date > currentMonth
        moveMonth(by: isFuture ? 1 : -1)
        selectedDate = date
    }

    func monthYearString(from d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy年 M月"; return f.string(from: d)
    }

    func generateFullGrid(for date: Date) -> [Date] {
        guard let first = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: first)
        let startDate = calendar.date(byAdding: .day, value: -(firstWeekday - 1), to: first)!
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: startDate) }
    }

    func combinedDate() -> Date {
        let now = Date(); var c = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        let tc = calendar.dateComponents([.hour, .minute], from: now)
        c.hour = tc.hour; c.minute = tc.minute; return calendar.date(from: c) ?? selectedDate
    }

    func addTransaction(isInc: Bool, date: Date) {
        let amt = parseAmount(from: inputText); let src = parseSourceName(from: inputText)
        transactions.append(Transaction(amount: amt, date: date, note: inputText, source: src, isIncome: isInc))
    }

    func parseAmount(from t: String) -> Int {
        let comps = t.components(separatedBy: .whitespacesAndNewlines)
        let amt = comps.filter { $0.contains("¥") || Int($0) != nil }.first?.replacingOccurrences(of: "¥", with: "") ?? "0"
        return Int(amt) ?? 0
    }

    func parseSourceName(from t: String) -> String {
        for acc in accounts { if t.contains("@\(acc.name)") { return acc.name } }
        return accounts.first?.name ?? "お財布"
    }
}

// --- 4. 投稿画面 ---
struct PostView: View {
    @Binding var inputText: String; @Binding var isPresented: Bool
    var initialDate: Date = Date()
    var onPost: (Bool, Date) -> Void
    var transactions: [Transaction]; var accounts: [Account]
    
    @State private var postDate = Date()
    @State private var isShowingDatePicker = false
    @State private var isPickingTime = false
    @State private var suggestions: [String] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    Image(systemName: "person.circle.fill").resizable().frame(width: 40, height: 40).foregroundColor(.gray)
                    ZStack(alignment: .topLeading) {
                        CustomTextEditor(text: $inputText) { sym in 
                            insertAtCursor(sym)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { updateSuggestionsForCursor() }
                        }
                        .frame(minHeight: 150)
                        .onChange(of: inputText) { _ in updateSuggestionsForCursor() }
                        if inputText.isEmpty { Text("どんな買い物をしましたか？").foregroundColor(.gray.opacity(0.7)).padding(.top, 8).padding(.leading, 5).allowsHitTesting(false) }
                    }
                }.padding()
                
                if !suggestions.isEmpty {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(suggestions, id: \.self) { suggestion in
                                Button(action: { applySuggestion(suggestion) }) {
                                    VStack(alignment: .leading) {
                                        Text(suggestion).font(.body).foregroundColor(.primary).padding(.vertical, 12).padding(.horizontal, 20); Divider()
                                    }
                                }
                            }
                        }
                    }.frame(maxHeight: 150).background(Color(.systemBackground)).transition(.move(edge: .bottom))
                }
                
                HStack {
                    Button(action: { isPickingTime = false; isShowingDatePicker = true }) {
                        HStack(spacing: 4) { Image(systemName: "calendar.badge.clock"); Text(formatDate(postDate)) }
                        .font(.footnote).padding(.horizontal, 12).padding(.vertical, 6).background(Color.blue.opacity(0.1)).foregroundColor(.blue).cornerRadius(12)
                    }
                    Spacer()
                }.padding(.horizontal)
                Spacer()
            }
            .navigationBarItems(leading: Button("キャンセル") { isPresented = false }, trailing: HStack(spacing: 12) {
                Button("支出") { onPost(false, postDate); isPresented = false }.padding(.horizontal, 12).padding(.vertical, 6).background(Color.red.opacity(0.8)).foregroundColor(.white).cornerRadius(15)
                Button("収入") { onPost(true, postDate); isPresented = false }.padding(.horizontal, 12).padding(.vertical, 6).background(Color.blue).foregroundColor(.white).cornerRadius(15)
            })
            .sheet(isPresented: $isShowingDatePicker) {
                NavigationView {
                    VStack { DatePicker("日時を選択", selection: $postDate, displayedComponents: isPickingTime ? .hourAndMinute : .date).datePickerStyle(.wheel).labelsHidden().environment(\.locale, Locale(identifier: "ja_JP")) }
                    .navigationTitle(isPickingTime ? "時刻の指定" : "日付の指定")
                    .navigationBarItems(leading: Button(isPickingTime ? "日付に切り替え" : "時刻に切り替え") { withAnimation { isPickingTime.toggle() } }, trailing: Button("完了") { isShowingDatePicker = false })
                }.presentationDetents([.height(350)])
            }
        }
        .onAppear { self.postDate = initialDate }
    }
    
    func formatDate(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "ja_JP"); f.dateFormat = "yyyy年MM月dd日 HH:mm"; return f.string(from: date)
    }
    func updateSuggestionsForCursor() {
        guard let sc = UIApplication.shared.connectedScenes.first as? UIWindowScene, let win = sc.windows.first, let tv = win.findTextView() else { return }
        let cursorLoc = tv.selectedRange.location; let text = tv.text ?? ""
        let prefixText = String(text.prefix(cursorLoc)); let currentWord = prefixText.components(separatedBy: .whitespacesAndNewlines).last ?? ""
        if currentWord == "#" { suggestions = Array(Set(transactions.flatMap { $0.tags })).sorted() }
        else if currentWord.hasPrefix("#") { suggestions = Array(Set(transactions.flatMap { $0.tags }.filter { $0.hasPrefix(currentWord) && $0 != currentWord })).sorted() }
        else if currentWord == "@" { suggestions = accounts.map { "@" + $0.name }.sorted() }
        else if currentWord.hasPrefix("@") { suggestions = accounts.map { "@" + $0.name }.filter { $0.hasPrefix(currentWord) && $0 != currentWord }.sorted() }
        else { suggestions = [] }
    }
    func applySuggestion(_ suggestion: String) {
        guard let sc = UIApplication.shared.connectedScenes.first as? UIWindowScene, let win = sc.windows.first, let tv = win.findTextView() else { return }
        let cursorLoc = tv.selectedRange.location; let text = tv.text ?? ""
        let prefixText = String(text.prefix(cursorLoc)); let words = prefixText.components(separatedBy: .whitespacesAndNewlines)
        if let lastWord = words.last {
            let rangeStart = cursorLoc - lastWord.count; let startIdx = text.index(text.startIndex, offsetBy: rangeStart); let endIdx = text.index(text.startIndex, offsetBy: cursorLoc)
            inputText = text.replacingCharacters(in: startIdx..<endIdx, with: suggestion + " ")
            DispatchQueue.main.async { tv.selectedRange = NSRange(location: rangeStart + suggestion.count + 1, length: 0); suggestions = [] }
        }
    }
    func insertAtCursor(_ sym: String) {
        if let sc = UIApplication.shared.connectedScenes.first as? UIWindowScene, let win = sc.windows.first, let tv = win.findTextView() {
            let sel = tv.selectedRange; let cur = tv.text ?? ""
            let lastChar: Character? = sel.location > 0 ? cur[cur.index(cur.startIndex, offsetBy: sel.location - 1)] : nil
            let prefix = (lastChar == " " || lastChar == "　" || lastChar == "\n" || lastChar == nil) ? "" : " "
            tv.becomeFirstResponder(); tv.insertText(prefix + sym)
        }
    }
}

// --- 5. 詳細画面 ---
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
        .sheet(isPresented: $isShowingEditSheet) { 
            PostView(inputText: $editLineText, isPresented: $isShowingEditSheet, initialDate: item.date, onPost: { isInc, nDate in updateThis(newInc: isInc, newDate: nDate) }, transactions: transactions, accounts: accounts) 
        }
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
        let amtT = comps.filter { $0.contains("¥") || Int($0) != nil }.first?.replacingOccurrences(of: "¥", with: "") ?? "0"
        return Int(amtT) ?? 0
    }
    func parseSourceName(from t: String) -> String {
        for acc in accounts { if t.contains("@\(acc.name)") { return acc.name } }
        return item.source
    }
}

// --- 6. お財布設定 ---
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

struct CustomTextEditor: UIViewRepresentable {
    @Binding var text: String; var onInsert: (String) -> Void
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView(); textView.font = .preferredFont(forTextStyle: .body); textView.backgroundColor = .clear; textView.delegate = context.coordinator
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        let items = [UIBarButtonItem(title: "#", style: .plain, target: context.coordinator, action: #selector(context.coordinator.insertHash)), UIBarButtonItem(title: "¥", style: .plain, target: context.coordinator, action: #selector(context.coordinator.insertYen)), UIBarButtonItem(title: "@", style: .plain, target: context.coordinator, action: #selector(context.coordinator.insertAt)), UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil), UIBarButtonItem(title: "完了", style: .done, target: context.coordinator, action: #selector(context.coordinator.dismissKeyboard))]
        toolbar.items = items; textView.inputAccessoryView = toolbar; return textView
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
