import SwiftUI

struct CalendarView: View {
    @Binding var transactions: [Transaction]
    @Binding var accounts: [Account]
    
    // テーマ設定
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_income") var themeIncome: String = "#FF19B219"
    @AppStorage("theme_expense") var themeExpense: String = "#FFFF3B30"
    @AppStorage("theme_holiday") var themeHoliday: String = "#FFFF3B30"
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_barText") var themeBarText: String = "#FF000000"
    @AppStorage("theme_barBG") var themeBarBG: String = "#F8F8F8FF"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var isShowingInputSheet = false
    @State private var inputText = ""
    @State private var isShowingMonthPicker = false 
    @State private var dragOffset: CGFloat = 0
    @State private var isShowingDeleteAlert = false
    @State private var transactionToDelete: Transaction?

    // ドラムロール用の変数
    @State private var pickerYear: Int = Calendar.current.component(.year, from: Date())
    @State private var pickerMonth: Int = Calendar.current.component(.month, from: Date())

    let calendar = Calendar.current
    let daysOfWeek = ["日", "月", "火", "水", "木", "金", "土"]

    var filteredTransactions: [Transaction] {
        transactions.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }.sorted(by: { $0.date > $1.date })
    }

    var body: some View {
        ZStack {
            // 画面全体の背景をテーマ色にする
            Color(hex: themeBG).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // ヘッダー：年月表示と移動
                VStack(spacing: 0) {
                    HStack {
                        Button(action: { moveMonth(by: -1) }) { 
                            Image(systemName: "chevron.left").foregroundColor(Color(hex: themeMain)) 
                        }
                        Spacer()
                        Button(action: { 
                            pickerYear = calendar.component(.year, from: currentMonth)
                            pickerMonth = calendar.component(.month, from: currentMonth)
                            isShowingMonthPicker = true 
                        }) {
                            HStack(spacing: 4) {
                                Text(monthYearString(from: currentMonth))
                                    .font(.headline)
                                    .foregroundColor(Color(hex: themeBarText))
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(Color(hex: themeBarText).opacity(0.6))
                            }
                        }
                        Spacer()
                        Button(action: { moveMonth(by: 1) }) { 
                            Image(systemName: "chevron.right").foregroundColor(Color(hex: themeMain)) 
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)

                    // 曜日ラベル
                    HStack {
                        ForEach(daysOfWeek, id: \.self) { day in
                            Text(day)
                                .font(.system(size: 11, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .foregroundColor(day == "日" ? Color(hex: themeHoliday) : (day == "土" ? .blue : Color(hex: themeBodyText).opacity(0.8)))
                        }
                    }
                    .padding(.bottom, 8)
                }
                .background(Color(hex: themeBarBG).opacity(0.4))

                // カレンダーグリッド（スワイプ対応）
                GeometryReader { geometry in
                    let width = geometry.size.width
                    HStack(spacing: 0) {
                        monthGrid(for: calendar.date(byAdding: .month, value: -1, to: currentMonth)!, width: width)
                        monthGrid(for: currentMonth, width: width)
                        monthGrid(for: calendar.date(byAdding: .month, value: 1, to: currentMonth)!, width: width)
                    }
                    .offset(x: -width + dragOffset)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture().onChanged { dragOffset = $0.translation.width }.onEnded { value in
                            let threshold = width * 0.3
                            if value.translation.width < -threshold {
                                withAnimation(.easeInOut(duration: 0.4)) { dragOffset = -width }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth)!; dragOffset = 0 }
                            } else if value.translation.width > threshold {
                                withAnimation(.easeInOut(duration: 0.4)) { dragOffset = width }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth)!; dragOffset = 0 }
                            } else { withAnimation(.easeInOut(duration: 0.2)) { dragOffset = 0 } }
                        }
                    )
                }
                .frame(height: 280)
                .background(Color(hex: themeBG)) // グリッドの背景を統一
                
                Divider()
                
                // 選択した日のタイムライン
                List {
                    if filteredTransactions.isEmpty {
                        HStack {
                            Spacer()
                            Text("投稿はありません").font(.caption).foregroundColor(Color(hex: themeSubText)).padding(.top, 40)
                            Spacer()
                        }.listRowSeparator(.hidden).listRowBackground(Color.clear)
                    } else {
                        ForEach(filteredTransactions) { item in
                            ZStack {
                                NavigationLink(destination: TransactionDetailView(item: item, transactions: $transactions, accounts: $accounts)) { EmptyView() }.opacity(0)
                                TwitterRow(item: item)
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color(hex: themeBG))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button { transactionToDelete = item; isShowingDeleteAlert = true } label: { Text("削除") }.tint(.red)
                            }
                        }
                    }
                    // 投稿作成ボタン
                    Button(action: { self.inputText = ""; self.isShowingInputSheet = true }) {
                        HStack { Image(systemName: "plus"); Text("投稿を作成") }
                        .font(.subheadline).fontWeight(.bold).frame(maxWidth: .infinity).padding(.vertical, 12).background(Color(hex: themeBG)).foregroundColor(Color(hex: themeMain)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: themeMain).opacity(0.3), lineWidth: 1)).padding(.horizontal, 40).padding(.vertical, 20)
                    }.listRowSeparator(.hidden).listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden) // デフォルト背景を透過
            }
        }
        .navigationTitle("カレンダー").navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(hex: themeBarBG), for: .navigationBar, .tabBar)
        .toolbarBackground(.visible, for: .navigationBar, .tabBar)
        .alert("投稿を削除しますか？", isPresented: $isShowingDeleteAlert) {
            Button("キャンセル", role: .cancel) { }; Button("削除", role: .destructive) { if let t = transactionToDelete, let idx = transactions.firstIndex(where: { $0.id == t.id }) { transactions.remove(at: idx) } }
        }
        // 年月選択ドラムロール
        .sheet(isPresented: $isShowingMonthPicker) {
            NavigationView {
                ZStack {
                    // ドラムロール画面の背景をテーマ色に
                    Color(hex: themeBG).ignoresSafeArea()
                    
                    HStack(spacing: 0) {
                        Picker("年", selection: $pickerYear) {
                            ForEach(2000...2100, id: \.self) { year in
                                Text("\(String(year))年").tag(year)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        
                        Picker("月", selection: $pickerMonth) {
                            ForEach(1...12, id: \.self) { month in
                                Text("\(month)月").tag(month)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                    }
                    .background(Color.clear)
                }
                .navigationTitle("年月を選択")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(
                    leading: Button("キャンセル") { isShowingMonthPicker = false }.foregroundColor(Color(hex: themeMain)),
                    trailing: Button("移動") {
                        if let newDate = calendar.date(from: DateComponents(year: pickerYear, month: pickerMonth)) {
                            currentMonth = newDate
                        }
                        isShowingMonthPicker = false
                    }.foregroundColor(Color(hex: themeMain))
                )
            }
            .preferredColorScheme(isDarkMode ? .dark : .light) // 文字色を背景に合わせる
            .presentationDetents([.height(300)])
        }
        .sheet(isPresented: $isShowingInputSheet) {
            PostView(inputText: $inputText, isPresented: $isShowingInputSheet, initialDate: combinedDate(), onPost: { isInc, nDate in addTransaction(isInc: isInc, date: nDate) }, transactions: transactions, accounts: accounts)
        }
    }

    // --- カレンダー描画ロジック ---
    @ViewBuilder func monthGrid(for month: Date, width: CGFloat) -> some View {
        let allDays = generateFullGrid(for: month)
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 0) {
            ForEach(0..<allDays.count, id: \.self) { index in
                let date = allDays[index]
                let isCurrentMonth = calendar.isDate(date, equalTo: month, toGranularity: .month)
                let dayTransactions = transactions.filter { calendar.isDate($0.date, inSameDayAs: date) }
                let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                let isHoliday = checkIsHoliday(date)
                
                VStack(spacing: 2) {
                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(size: 13, design: .rounded))
                        .fontWeight(isSelected ? .bold : .regular)
                        .foregroundColor(isCurrentMonth ? (isSelected ? .white : (isHoliday ? Color(hex: themeHoliday) : Color(hex: themeBodyText))) : Color(hex: themeSubText).opacity(0.4))
                        .frame(width: 24, height: 24)
                        .background(isSelected && isCurrentMonth ? Color(hex: themeMain) : Color.clear)
                        .clipShape(Circle())
                    
                    // 収支ドット
                    VStack(alignment: .leading, spacing: 1) {
                        let total = dayTransactions.count
                        if total > 0 {
                            HStack(spacing: 2) {
                                ForEach(dayTransactions.prefix(5)) { tx in
                                    Circle().fill(tx.isIncome ? Color(hex: themeIncome) : Color(hex: themeExpense)).frame(width: 4.5, height: 4.5)
                                }
                            }
                        } else { Spacer().frame(height: 4.5) }
                    }.frame(height: 10)
                }
                .frame(height: 45)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    if isCurrentMonth { selectedDate = date } 
                    else { slideToDate(date) }
                }
            }
        }.frame(width: width).background(Color(hex: themeBG))
    }

    // ヘルパー関数群
    func monthYearString(from d: Date) -> String { let f = DateFormatter(); f.dateFormat = "yyyy年 M月"; return f.string(from: d) }
    func generateFullGrid(for date: Date) -> [Date] { guard let first = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else { return [] }; let firstWeekday = calendar.component(.weekday, from: first); let startDate = calendar.date(byAdding: .day, value: -(firstWeekday - 1), to: first)!; return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: startDate) } }
    func moveMonth(by v: Int) { if let next = calendar.date(byAdding: .month, value: v, to: currentMonth) { withAnimation { currentMonth = next } } }
    func slideToDate(_ date: Date) { let isFuture = date > currentMonth; moveMonth(by: isFuture ? 1 : -1); selectedDate = date }
    func combinedDate() -> Date { let now = Date(); var c = calendar.dateComponents([.year, .month, .day], from: selectedDate); let tc = calendar.dateComponents([.hour, .minute], from: now); c.hour = tc.hour; c.minute = tc.minute; return calendar.date(from: c) ?? selectedDate }
    func addTransaction(isInc: Bool, date: Date) { transactions.append(Transaction(amount: parseAmount(from: inputText), date: date, note: inputText, source: parseSourceName(from: inputText), isIncome: isInc)) }
    func parseAmount(from t: String) -> Int { t.components(separatedBy: .whitespacesAndNewlines).filter { $0.contains("¥") }.reduce(0) { $0 + (Int($1.replacingOccurrences(of: "¥", with: "")) ?? 0) } }
    func parseSourceName(from t: String) -> String { for acc in accounts { if t.contains("@\(acc.name)") { return acc.name } }; return accounts.first?.name ?? "お財布" }
    func checkIsHoliday(_ date: Date) -> Bool {
        let comps = calendar.dateComponents([.month, .day, .year, .weekday], from: date)
        guard let month = comps.month, let day = comps.day, let year = comps.year, let weekday = comps.weekday else { return false }
        if month == 1 && day == 1 { return true }
        if month == 2 && day == 11 { return true }
        if month == 2 && day == 23 { return true }
        if month == 4 && day == 29 { return true }
        if month == 5 && day == 3 { return true }
        if month == 5 && day == 4 { return true }
        if month == 5 && day == 5 { return true }
        if month == 8 && day == 11 { return true }
        if month == 11 && day == 3 { return true }
        if month == 11 && day == 23 { return true }
        let weekOfMonth = (day - 1) / 7 + 1
        if weekday == 2 {
            if month == 1 && weekOfMonth == 2 { return true }
            if month == 7 && weekOfMonth == 3 { return true }
            if month == 9 && weekOfMonth == 3 { return true }
            if month == 10 && weekOfMonth == 2 { return true }
        }
        if month == 3 && day == (year % 4 == 0 || year % 4 == 1 ? 20 : 21) { return true }
        if month == 9 && day == (year % 4 == 0 ? 22 : 23) { return true }
        return false
    }
}
