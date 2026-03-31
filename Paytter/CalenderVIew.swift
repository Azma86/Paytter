import SwiftUI

struct CalendarView: View {
    @Binding var transactions: [Transaction]
    @Binding var accounts: [Account]
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var isShowingInputSheet = false
    @State private var inputText = ""
    @State private var isShowingMonthPicker = false
    @State private var tempPickerDate = Date()
    @State private var dragOffset: CGFloat = 0
    @State private var isShowingDeleteAlert = false
    @State private var transactionToDelete: Transaction?

    let calendar = Calendar.current
    let daysOfWeek = ["日", "月", "火", "水", "木", "金", "土"]

    var filteredTransactions: [Transaction] {
        transactions.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted(by: { $0.date > $1.date })
    }

    var body: some View {
        VStack(spacing: 0) {
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

            HStack {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day).font(.system(size: 11, weight: .bold)).frame(maxWidth: .infinity)
                        .foregroundColor(day == "日" ? .red : (day == "土" ? .blue : .primary))
                }
            }.padding(.bottom, 5)

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
                        .onEnded { value in
                            let threshold = width * 0.3
                            if value.translation.width < -threshold {
                                withAnimation(.easeInOut(duration: 0.45)) { dragOffset = -width }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                                    currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth)!
                                    dragOffset = 0
                                }
                            } else if value.translation.width > threshold {
                                withAnimation(.easeInOut(duration: 0.45)) { dragOffset = width }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                                    currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth)!
                                    dragOffset = 0
                                }
                            } else {
                                withAnimation(.easeInOut(duration: 0.3)) { dragOffset = 0 }
                            }
                        }
                )
            }.frame(height: 280)

            Divider()

            List {
                if filteredTransactions.isEmpty {
                    HStack {
                        Spacer()
                        Text("投稿はありません").font(.caption).foregroundColor(.secondary).padding(.top, 40)
                        Spacer()
                    }.listRowSeparator(.hidden)
                } else {
                    ForEach(filteredTransactions) { item in
                        ZStack {
                            // 透明リンクでガタつき防止
                            NavigationLink(destination: TransactionDetailView(item: item, transactions: $transactions, accounts: $accounts)) {
                                EmptyView()
                            }.opacity(0)
                            
                            TwitterRow(item: item)
                        }
                        .listRowInsets(EdgeInsets())
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                transactionToDelete = item
                                isShowingDeleteAlert = true
                            } label: {
                                Text("削除")
                            }
                        }
                    }
                }
                
                Button(action: { self.inputText = ""; self.isShowingInputSheet = true }) {
                    HStack { Image(systemName: "plus"); Text("投稿を作成") }
                    .font(.subheadline).fontWeight(.bold).frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Color.white).foregroundColor(.blue)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.blue.opacity(0.3), lineWidth: 1))
                    .padding(.horizontal, 40).padding(.vertical, 20)
                }.listRowSeparator(.hidden)
            }
            .listStyle(.plain)
        }
        .navigationTitle("カレンダー")
        .navigationBarTitleDisplayMode(.inline)
        .alert("投稿を削除しますか？", isPresented: $isShowingDeleteAlert) {
            Button("キャンセル", role: .cancel) { transactionToDelete = nil }
            Button("削除", role: .destructive) { 
                if let t = transactionToDelete, let idx = transactions.firstIndex(where: { $0.id == t.id }) {
                    withAnimation { transactions.remove(at: idx) }
                }
                transactionToDelete = nil
            }
        } message: { if let t = transactionToDelete { Text(t.cleanNote) } }
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
                .navigationBarItems(leading: Button("キャンセル") { isShowingMonthPicker = false }, trailing: Button("移動") {
                    withAnimation(.easeInOut(duration: 0.4)) { currentMonth = tempPickerDate }
                    isShowingMonthPicker = false
                })
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
                let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                let isHoliday = checkIsHoliday(date)
                
                VStack(spacing: 2) {
                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(size: 13, design: .rounded))
                        .fontWeight(isSelected ? .bold : .regular)
                        .foregroundColor(isCurrentMonth ? (isSelected ? .white : (isHoliday ? .red : .primary)) : .gray.opacity(0.25))
                        .frame(width: 24, height: 24)
                        .background(isSelected && isCurrentMonth ? Color.blue : Color.clear)
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 1) {
                        let total = dayTransactions.count
                        if total > 0 {
                            HStack(spacing: 2) {
                                ForEach(dayTransactions.prefix(5)) { tx in
                                    Circle().fill(tx.isIncome ? Color.green : Color.red).frame(width: 4.5, height: 4.5)
                                }
                            }
                            if total > 5 {
                                HStack(spacing: 2) {
                                    if total > 8 {
                                        ForEach(dayTransactions.prefix(8).suffix(3)) { tx in
                                            Circle().fill(tx.isIncome ? Color.green : Color.red).frame(width: 4.5, height: 4.5)
                                        }
                                        Text("+\(total - 8)").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).offset(y: -1)
                                    } else {
                                        ForEach(dayTransactions.suffix(total - 5)) { tx in
                                            Circle().fill(tx.isIncome ? Color.green : Color.red).frame(width: 4.5, height: 4.5)
                                        }
                                    }
                                }
                            } else { Spacer().frame(height: 4.5) }
                        } else { Spacer().frame(height: 10) }
                    }.frame(height: 10).frame(maxWidth: .infinity, alignment: .center)
                }.frame(height: 45).frame(maxWidth: .infinity).contentShape(Rectangle())
                .onTapGesture { if isCurrentMonth { selectedDate = date } else { slideToDate(date) } }
            }
        }.frame(width: width)
    }

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
    func moveMonth(by v: Int) {
        let direction: CGFloat = v > 0 ? -1 : 1
        let width = UIScreen.main.bounds.width
        withAnimation(.easeInOut(duration: 0.45)) { dragOffset = direction * width }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            if let next = calendar.date(byAdding: .month, value: v, to: currentMonth) { currentMonth = next }
            dragOffset = 0
        }
    }
    func slideToDate(_ date: Date) { let isFuture = date > currentMonth; moveMonth(by: isFuture ? 1 : -1); selectedDate = date }
    func monthYearString(from d: Date) -> String { let f = DateFormatter(); f.dateFormat = "yyyy年 M月"; return f.string(from: d) }
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
        let total = comps.filter { $0.contains("¥") }.reduce(0) { sum, word in
            let cleaned = word.replacingOccurrences(of: "¥", with: "")
            return sum + (Int(cleaned) ?? 0)
        }
        return total
    }
    func parseSourceName(from t: String) -> String {
        for acc in accounts { if t.contains("@\(acc.name)") { return acc.name } }
        return accounts.first?.name ?? "お財布"
    }
}
