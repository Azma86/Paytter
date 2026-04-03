import SwiftUI

struct ThemeSettingView: View {
    @AppStorage("active_preset") var activePreset: String = "デフォルト"
    
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_income") var themeIncome: String = "#FF19B219"
    @AppStorage("theme_expense") var themeExpense: String = "#FFFF3B30"
    @AppStorage("theme_holiday") var themeHoliday: String = "#FFFF3B30"
    // 土曜日の色設定を保持
    @AppStorage("theme_saturday") var themeSaturday: String = "#FF007AFF"
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_barBG") var themeBarBG: String = "#F8F8F8FF"
    @AppStorage("theme_barText") var themeBarText: String = "#FF000000"
    @AppStorage("theme_tabAccent") var themeTabAccent: String = "#FF007AFF"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    
    struct PresetData {
        // 収入・支出・祝日・土曜日用のフィールドを追加
        let main, bg, barBG, barText, body, sub, tab, saturday, income, expense, holiday: String
        let isDark: Bool
    }
    
    // 各プリセットごとに、収入(緑)・支出(赤)・祝日(赤)のデフォルト値を定義
    let presets: [String: PresetData] = [
        "デフォルト": PresetData(main: "#FF007AFF", bg: "#FFFFFFFF", barBG: "#FFF8F8F8", barText: "#FF000000", body: "#FF000000", sub: "#FF8E8E93", tab: "#FF007AFF", saturday: "#FF007AFF", income: "#FF19B219", expense: "#FFFF3B30", holiday: "#FFFF3B30", isDark: false),
        "ダーク": PresetData(main: "#FF0A84FF", bg: "#FF111115", barBG: "#FF030305", barText: "#FFFFFFFF", body: "#FFFFFFFF", sub: "#FF8E8E93", tab: "#FF0A84FF", saturday: "#FF0A84FF", income: "#FF32D74B", expense: "#FFFF453A", holiday: "#FFFF453A", isDark: true),
        "ナチュラル": PresetData(main: "#FF6B8E23", bg: "#FFF5F5DC", barBG: "#FFE4E4D0", barText: "#FF4B3621", body: "#FF4B3621", sub: "#FF999988", tab: "#FF6B8E23", saturday: "#FF4169E1", income: "#FF19B219", expense: "#FFFF3B30", holiday: "#FFFF3B30", isDark: false),
        "カフェ": PresetData(main: "#FF8B4513", bg: "#FFFFF8DC", barBG: "#FFDEB887", barText: "#FF3E2723", body: "#FF3E2723", sub: "#FFA08878", tab: "#FF8B4513", saturday: "#FF4682B4", income: "#FF19B219", expense: "#FFFF3B30", holiday: "#FFFF3B30", isDark: false)
    ]

    var body: some View {
        ZStack {
            Color(hex: themeBG).ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(["デフォルト", "ダーク", "ナチュラル", "カフェ"], id: \.self) { name in
                            presetBtn(name)
                        }
                    }.padding()
                }.background(Color(hex: themeBarBG).opacity(0.3))
                
                Divider()
                List {
                    Section(header: Text("全体設定").foregroundColor(Color(hex: themeSubText))) {
                        colorRow(title: "背景色", hex: $themeBG, keyPath: \.bg)
                        colorRow(title: "メニュー背景", hex: $themeBarBG, keyPath: \.barBG)
                        colorRow(title: "メニュー文字", hex: $themeBarText, keyPath: \.barText)
                        colorRow(title: "タブ選択色", hex: $themeTabAccent, keyPath: \.tab)
                        colorRow(title: "本文文字", hex: $themeBodyText, keyPath: \.body)
                        colorRow(title: "サブ文字", hex: $themeSubText, keyPath: \.sub)
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    
                    Section(header: Text("パーツ設定").foregroundColor(Color(hex: themeSubText))) {
                        colorRow(title: "メインカラー", hex: $themeMain, keyPath: \.main)
                        // keyPathをそれぞれの色の項目に修正しました
                        colorRow(title: "収入色", hex: $themeIncome, keyPath: \.income)
                        colorRow(title: "支出色", hex: $themeExpense, keyPath: \.expense)
                        colorRow(title: "祝日・日曜色", hex: $themeHoliday, keyPath: \.holiday)
                        colorRow(title: "土曜日色", hex: $themeSaturday, keyPath: \.saturday)
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                }.scrollContentBackground(.hidden).listStyle(.insetGrouped)
            }
        }
        .navigationTitle("テーマ設定").navigationBarTitleDisplayMode(.inline)
    }

    func presetBtn(_ name: String) -> some View {
        let p = presets[name]!
        return Button(action: { 
            withAnimation {
                activePreset = name
                themeMain = p.main; themeBG = p.bg; themeBarBG = p.barBG; themeBarText = p.barText
                themeBodyText = p.body; themeSubText = p.sub; themeTabAccent = p.tab; isDarkMode = p.isDark
                // プリセット切り替え時にこれらの色も連動して変わるように修正
                themeSaturday = p.saturday
                themeIncome = p.income
                themeExpense = p.expense
                themeHoliday = p.holiday
                notify()
            }
        }) {
            VStack(spacing: 8) {
                Circle().fill(name == "ダーク" ? Color.black : Color(hex: p.main)).frame(width: 44, height: 44).overlay(Circle().stroke(Color(hex: themeBarText).opacity(0.2), lineWidth: 1))
                Text(name).font(.system(size: 10)).foregroundColor(Color(hex: themeSubText))
            }
        }.buttonStyle(.plain)
    }
    
    func colorRow(title: String, hex: Binding<String>, keyPath: KeyPath<PresetData, String>) -> some View {
        let defaultVal = presets[activePreset]![keyPath: keyPath]
        return HStack {
            ColorPicker(title, selection: Binding(get: { Color(hex: hex.wrappedValue) }, set: { hex.wrappedValue = $0.toHex(); notify() })).foregroundColor(Color(hex: themeBodyText))
            if hex.wrappedValue != defaultVal {
                Button(action: { withAnimation { hex.wrappedValue = defaultVal; notify() } }) {
                    Image(systemName: "arrow.counterclockwise.circle.fill").foregroundColor(Color(hex: themeSubText).opacity(0.7))
                }.buttonStyle(.plain)
            }
        }
    }

    func notify() { NotificationCenter.default.post(name: NSNotification.Name("UpdateAppearance"), object: nil) }
}
