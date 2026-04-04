import SwiftUI

struct CalendarView: View {
    @Binding var transactions: [Transaction]
    @Binding var accounts: [Account]
    
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_income") var themeIncome: String = "#FF19B219"
    @AppStorage("theme_expense") var themeExpense: String = "#FFFF3B30"
    @AppStorage("theme_holiday") var themeHoliday: String = "#FFFF3B30"
    @AppStorage("theme_saturday") var themeSaturday: String = "#FF007AFF"
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_barText") var themeBarText: String = "#FF000000"
    @AppStorage("theme_barBG") var themeBarBG: String = "#F8F8F8FF"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    @AppStorage("user_profiles_v1") var profiles: [UserProfile] = []
    
    @ObservedObject var lockManager = LockManager.shared
    
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var isShowingInputSheet = false
    @State private var inputText = ""
    @State private var isShowingMonthPicker = false 
    @State private var dragOffset: CGFloat = 0
    @State private var isShowingDeleteAlert = false
    @State private var transactionToDelete: Transaction?
    
    // 【新規】カレンダー用計算をO(1)にするためのキャッシュ辞書
    @State private var monthlyTransactionsDict: [String: [Transaction]] = [:]

    @State private var pickerYear: Int = Calendar.current.component(.year, from: Date())
    @State private var pickerMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var holidayDict: [String: String] = [:]

    let calendar = Calendar.current
    let daysOfWeek = ["日", "月", "火", "水", "木", "金", "土"]
    
    let dateKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var validTransactionsForCalendar: [Transaction] {
        transactions.filter { tx in
            let profile = profiles.first(where: { $0.id == tx.profileId }) ?? profiles.first
            let isVisible = profile?.isVisible ?? true
            let isPrivate = profile?.isPrivate ?? false
            
            if !isVisible { return false }
            if isPrivate && !lockManager.isUnlocked && lockManager.privatePostDisplayMode == 0 {
                return false
            }
            return true
        }
    }
    
    // 【新規】データ更新時に辞書を作り直す
    func updateCalendarDict() {
        var dict: [String: [Transaction]] = [:]
        for tx in validTransactionsForCalendar {
            let key = dateKeyFormatter.string(from: tx.date)
            dict[key, default: []].append(tx)
        }
        monthlyTransactionsDict = dict
    }
    
    var filteredTransactions: [Transaction] {
        let key = dateKeyFormatter.string(from: selectedDate)
        return (monthlyTransactionsDict[key] ?? []).sorted(by: { $0.date > $1.date })
    }

    var body: some View {
        ZStack {
            Color(hex: themeBG).ignoresSafeArea()
            VStack(spacing: 0) {
                headerView
                
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
                        DragGesture()
                            .onChanged { dragOffset = $0.translation.width }
                            .onEnded { value in handleDragEnded(value: value, width: width) }
                    )
                }
                .frame(height: 280)
                .background(Color(hex: themeBG))
                
                Divider()
                
                dateHeaderView
                transactionListView
            }
        }
        .navigationTitle("カレンダー")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if !lockManager.passcode.isEmpty {
                    Button(action: {
                        if lockManager.isUnlocked {
                            lockManager.lock()
                        } else {
                            lockManager.promptUnlock()
                        }
                    }) {
                        Image(systemName: lockManager.isUnlocked ? "lock.open.fill" : "lock.fill")
                            .foregroundColor(Color(hex: themeMain))
                    }
                }
            }
        }
        .toolbarBackground(Color(hex: themeBarBG), for: .navigationBar, .tabBar)
        .toolbarBackground(.visible, for: .navigationBar, .tabBar)
        .alert("投稿を削除しますか？", isPresented: $isShowingDeleteAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("削除", role: .destructive) { deleteTransaction() }
        }
        .sheet(isPresented: $isShowingMonthPicker) { monthPickerSheet }
        .sheet(isPresented: $isShowingInputSheet) {
            PostView(
                inputText: $inputText,
                isPresented: $isShowingInputSheet,
                initialDate: combinedDate(),
                isExcludedInitial: false,
                initialImages: nil,
                onPost: handlePostTransaction,
                transactions: transactions,
                accounts: accounts
            )
        }
        // 【変更】データ更新時に辞書を再構築
        .onAppear { loadHolidays(); updateCalendarDict() }
        .onChange(of: transactions) { _ in updateCalendarDict() }
        .onChange(of: lockManager.isUnlocked) { _ in updateCalendarDict() }
    }

    private var headerView: some View { VStack(spacing: 0) { HStack { Button(action: { moveMonth(by: -1) }) { Image(systemName: "chevron.left").foregroundColor(Color(hex: themeMain)) }; Spacer(); Button(action: { pickerYear = calendar.component(.year, from: currentMonth); pickerMonth = calendar.component(.month, from: currentMonth); isShowingMonthPicker = true }) { HStack(spacing: 4) { Text(monthYearString(from: currentMonth)).font(.headline).foregroundColor(Color(hex: themeBarText)); Image(systemName: "chevron.down").font(.caption).foregroundColor(Color(hex: themeBarText).opacity(0.6)) } }; Spacer(); Button(action: { moveMonth(by: 1) }) { Image(systemName: "chevron.right").foregroundColor(Color(hex: themeMain)) } }.padding(.horizontal).padding(.vertical, 12); HStack { ForEach(daysOfWeek, id: \.self) { day in Text(day).font(.system(size: 11, weight: .bold)).frame(maxWidth: .infinity).foregroundColor(day == "日" ? Color(hex: themeHoliday) : (day == "土" ? Color(hex: themeSaturday) : Color(hex: themeBodyText).opacity(0.8))) } }.padding(.bottom, 8) }.background(Color(hex: themeBarBG).opacity(0.4)) }
    private var dateHeaderView: some View { HStack(spacing: 4) { let holidayName = getHolidayName(selectedDate); let isSunday = calendar.component(.weekday, from: selectedDate) == 1; let isSaturday = calendar.component(.weekday, from: selectedDate) == 7; let isHoliday = holidayName != nil; let dayColor: Color = (isHoliday || isSunday) ? Color(hex: themeHoliday) : (isSaturday ? Color(hex: themeSaturday) : Color(hex: themeBodyText)); Text(formatDate(selectedDate, format: "yyyy年M月d日")).foregroundColor(Color(hex: themeBodyText)); (Text("(").foregroundColor(Color(hex: themeBodyText)) + Text(formatDate(selectedDate, format: "EEE")).foregroundColor(dayColor) + Text(")").foregroundColor(Color(hex: themeBodyText))); if let name = holidayName { Text(name).foregroundColor(Color(hex: themeBodyText)).padding(.leading, 4) }; Spacer() }.font(.footnote).fontWeight(.bold).padding(.horizontal).padding(.vertical, 6).background(Color(hex: themeBarBG).opacity(0.2)) }
    private var transactionListView: some View { List { if filteredTransactions.isEmpty { HStack { Spacer(); Text("投稿はありません").font(.caption).foregroundColor(Color(hex: themeSubText)).padding(.top, 40); Spacer() }.listRowSeparator(.hidden).listRowBackground(Color.clear) } else { ForEach(filteredTransactions) { item in ZStack { NavigationLink(destination: TransactionDetailView(item: item, transactions: $transactions, accounts: $accounts)) { EmptyView() }.opacity(0); TwitterRow(item: item) }.listRowInsets(EdgeInsets()).listRowBackground(Color(hex: themeBG)).swipeActions(edge: .trailing, allowsFullSwipe: false) { Button { transactionToDelete = item; isShowingDeleteAlert = true } label: { Text("削除") }.tint(.red) } } }; Button(action: { self.inputText = ""; self.isShowingInputSheet = true }) { HStack { Image(systemName: "plus"); Text("投稿を作成") }.font(.subheadline).fontWeight(.bold).frame(maxWidth: .infinity).padding(.vertical, 12).background(Color(hex: themeBG)).foregroundColor(Color(hex: themeMain)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: themeMain).opacity(0.3), lineWidth: 1)).padding(.horizontal, 40).padding(.vertical, 20) }.listRowSeparator(.hidden).listRowBackground(Color.clear) }.listStyle(.plain).scrollContentBackground(.hidden) }
    private var monthPickerSheet: some View { NavigationView { ZStack { Color(hex: themeBG).ignoresSafeArea(); HStack(spacing: 0) { Picker("年", selection: $pickerYear) { ForEach(2000...2100, id: \.self) { year in Text("\(String(year))年").tag(year) } }.pickerStyle(.wheel).frame(maxWidth: .infinity); Picker("月", selection: $pickerMonth) { ForEach(1...12, id: \.self) { month in Text("\(month)月").tag(month) } }.pickerStyle(.wheel).frame(maxWidth: .infinity) }.background(Color.clear) }.navigationTitle("年月を選択").navigationBarTitleDisplayMode(.inline).navigationBarItems(leading: Button("キャンセル") { isShowingMonthPicker = false }.foregroundColor(Color(hex: themeMain)), trailing: Button("移動") { if let newDate = calendar.date(from: DateComponents(year: pickerYear, month: pickerMonth)) { currentMonth = newDate }; isShowingMonthPicker = false }.foregroundColor(Color(hex: themeMain))) }.preferredColorScheme(isDarkMode ? .dark : .light).presentationDetents([.height(300)]) }

    @ViewBuilder func monthGrid(for month: Date, width: CGFloat) -> some View { let allDays = generateFullGrid(for: month); LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 0) { ForEach(0..<allDays.count, id: \.self) { index in dayCell(date: allDays[index], month: month) } }.frame(width: width).background(Color(hex: themeBG)) }
    
    @ViewBuilder func dayCell(date: Date, month: Date) -> some View {
        let isCurrentMonth = calendar.isDate(date, equalTo: month, toGranularity: .month)
        // 【変更】辞書からO(1)で直接取り出すので負荷ゼロ
        let dayKey = dateKeyFormatter.string(from: date)
        let dayTransactions = monthlyTransactionsDict[dayKey] ?? []
        
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isHoliday = checkIsHoliday(date)
        let weekday = calendar.component(.weekday, from: date)
        
        let dayBaseColor: Color = {
            if isHoliday || weekday == 1 { return Color(hex: themeHoliday) }
            if weekday == 7 { return Color(hex: themeSaturday) }
            return Color(hex: themeBodyText)
        }()
        
        VStack(spacing: 2) {
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 13, design: .rounded))
                .fontWeight(isSelected ? .bold : .regular)
                .foregroundColor(isCurrentMonth ? (isSelected ? .white : dayBaseColor) : dayBaseColor.opacity(0.4))
                .frame(width: 24, height: 24)
                .background(isSelected && isCurrentMonth ? Color(hex: themeMain) : Color.clear)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 1) {
                if dayTransactions.count > 0 {
                    HStack(spacing: 2) {
                        ForEach(dayTransactions.prefix(5)) { tx in
                            Circle()
                                .fill(tx.isIncome ? Color(hex: themeIncome) : Color(hex: themeExpense))
                                .frame(width: 4.5, height: 4.5)
                        }
                    }
                } else {
                    Spacer().frame(height: 4.5)
                }
            }
            .frame(height: 10)
        }
        .frame(height: 45)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            if isCurrentMonth {
                selectedDate = date
            } else {
                slideToDate(date)
            }
        }
    }

    private func handleDragEnded(value: DragGesture.Value, width: CGFloat) { let threshold = width * 0.3; if value.translation.width < -threshold { withAnimation(.easeInOut(duration: 0.4)) { dragOffset = -width }; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth)!; dragOffset = 0 } } else if value.translation.width > threshold { withAnimation(.easeInOut(duration: 0.4)) { dragOffset = width }; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth)!; dragOffset = 0 } } else { withAnimation(.easeInOut(duration: 0.2)) { dragOffset = 0 } } }
    func deleteTransaction() { if let t = transactionToDelete, let idx = transactions.firstIndex(where: { $0.id == t.id }) { transactions.remove(at: idx) } }
    func monthYearString(from d: Date) -> String { let f = DateFormatter(); f.dateFormat = "yyyy年 M月"; return f.string(from: d) }
    func formatDate(_ d: Date, format: String) -> String { let f = DateFormatter(); f.locale = Locale(identifier: "ja_JP"); f.dateFormat = format; return f.string(from: d) }
    func generateFullGrid(for date: Date) -> [Date] { guard let first = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else { return [] }; let firstWeekday = calendar.component(.weekday, from: first); let startDate = calendar.date(byAdding: .day, value: -(firstWeekday - 1), to: first)!; return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: startDate) } }
    func moveMonth(by v: Int) { if let next = calendar.date(byAdding: .month, value: v, to: currentMonth) { withAnimation { currentMonth = next } } }
    func slideToDate(_ date: Date) { let isFuture = date > currentMonth; moveMonth(by: isFuture ? 1 : -1); selectedDate = date }
    func combinedDate() -> Date { let now = Date(); var c = calendar.dateComponents([.year, .month, .day], from: selectedDate); let tc = calendar.dateComponents([.hour, .minute], from: now); c.hour = tc.hour; c.minute = tc.minute; return calendar.date(from: c) ?? selectedDate }
    
    func handlePostTransaction(isInc: Bool, date: Date, isExc: Bool, profileId: UUID?, images: [Data]?) {
        transactions.append(Transaction(amount: parseAmount(from: inputText), date: date, note: inputText, source: parseSourceName(from: inputText), isIncome: isInc, isExcludedFromBalance: isExc, profileId: profileId, attachedImageDatas: images))
    }
    
    func parseAmount(from t: String) -> Int { t.components(separatedBy: CharacterSet.whitespacesAndNewlines).filter { $0.contains("¥") }.reduce(0) { $0 + (Int($1.replacingOccurrences(of: "¥", with: "")) ?? 0) } }
    func parseSourceName(from t: String) -> String { for acc in accounts { if t.contains("@\(acc.name)") { return acc.name } }; return accounts.first?.name ?? "お財布" }
    func getHolidayName(_ date: Date) -> String? { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy/M/d"; let d1 = f.string(from: date); f.dateFormat = "yyyy/MM/dd"; let d2 = f.string(from: date); return holidayDict[d1] ?? holidayDict[d2] }
    func checkIsHoliday(_ date: Date) -> Bool { return getHolidayName(date) != nil }
    func loadHolidays() { guard let url = URL(string: "https://www8.cao.go.jp/chosei/shukujitsu/syukujitsu.csv") else { return }; URLSession.shared.dataTask(with: url) { data, response, error in guard let data = data, error == nil else { return }; let encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.shiftJIS.rawValue))); guard let csvString = String(data: data, encoding: encoding) else { return }; var dict: [String: String] = [:]; csvString.components(separatedBy: .newlines).forEach { line in let columns = line.components(separatedBy: ","); if columns.count >= 2 { let dStr = columns[0].trimmingCharacters(in: .whitespaces); let name = columns[1].trimmingCharacters(in: .whitespaces); if dStr.contains("/") { dict[dStr] = name } } }; DispatchQueue.main.async { self.holidayDict = dict } }.resume() }
}
