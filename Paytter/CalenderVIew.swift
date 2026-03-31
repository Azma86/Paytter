import SwiftUI

struct CalendarView: View {
    @Binding var transactions: [Transaction]
    @Binding var accounts: [Account]
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_barText") var themeBarText: String = "#FF000000"
    @AppStorage("theme_barBG") var themeBarBG: String = "#F8F8F8FF"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var isShowingMonthPicker = false 
    @State private var pickerYear: Int = Calendar.current.component(.year, from: Date())
    @State private var pickerMonth: Int = Calendar.current.component(.month, from: Date())
    // その他の既存State変数はそのまま...

    let calendar = Calendar.current

    var body: some View {
        ZStack {
            Color(hex: themeBG).ignoresSafeArea()
            VStack(spacing: 0) {
                // ヘッダー部分
                HStack {
                    Button(action: { moveMonth(by: -1) }) { Image(systemName: "chevron.left").foregroundColor(Color(hex: themeMain)) }
                    Spacer()
                    Button(action: { 
                        pickerYear = calendar.component(.year, from: currentMonth)
                        pickerMonth = calendar.component(.month, from: currentMonth)
                        isShowingMonthPicker = true 
                    }) {
                        HStack(spacing: 4) {
                            Text(monthYearString(from: currentMonth)).font(.headline).foregroundColor(Color(hex: themeBarText))
                            Image(systemName: "chevron.down").font(.caption).foregroundColor(Color(hex: themeBarText).opacity(0.6))
                        }
                    }
                    Spacer()
                    Button(action: { moveMonth(by: 1) }) { Image(systemName: "chevron.right").foregroundColor(Color(hex: themeMain)) }
                }.padding().background(Color(hex: themeBarBG).opacity(0.4))
                
                // カレンダー表示部分は省略（前回から変更なし）
                // ... (monthGridなど) ...
            }
        }
        .sheet(isPresented: $isShowingMonthPicker) {
            NavigationView {
                HStack(spacing: 0) {
                    // 年の選択
                    Picker("年", selection: $pickerYear) {
                        ForEach(2000...2100, id: \.self) { year in
                            Text("\(String(year))年").tag(year)
                        }
                    }
                    .pickerStyle(.wheel)
                    
                    // 月の選択
                    Picker("月", selection: $pickerMonth) {
                        ForEach(1...12, id: \.self) { month in
                            Text("\(month)月").tag(month)
                        }
                    }
                    .pickerStyle(.wheel)
                }
                .padding()
                .navigationTitle("年月を選択")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(
                    leading: Button("キャンセル") { isShowingMonthPicker = false }.foregroundColor(Color(hex: themeMain)),
                    trailing: Button("決定") {
                        if let newDate = calendar.date(from: DateComponents(year: pickerYear, month: pickerMonth)) {
                            currentMonth = newDate
                        }
                        isShowingMonthPicker = false
                    }.foregroundColor(Color(hex: themeMain))
                )
            }
            .presentationDetents([.height(280)])
        }
    }
    
    // ... その他の関数 ...
    func monthYearString(from d: Date) -> String { let f = DateFormatter(); f.dateFormat = "yyyy年 M月"; return f.string(from: d) }
    func moveMonth(by v: Int) { if let next = calendar.date(byAdding: .month, value: v, to: currentMonth) { withAnimation { currentMonth = next } } }
}
