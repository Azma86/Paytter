import SwiftUI

struct ThemeSettingView: View {
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_income") var themeIncome: String = "#FF19B219"
    @AppStorage("theme_expense") var themeExpense: String = "#FFFF3B30"
    @AppStorage("theme_holiday") var themeHoliday: String = "#FFFF3B30"
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_barBG") var themeBarBG: String = "#F8F8F8FF"
    @AppStorage("theme_barText") var themeBarText: String = "#FF000000"
    @AppStorage("theme_tabAccent") var themeTabAccent: String = "#FF007AFF"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"

    var body: some View {
        ZStack {
            Color(hex: themeBG).ignoresSafeArea()
            VStack(spacing: 0) {
                // プリセットボタン（5種類復活）
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        presetBtn("デフォルト", "#FF007AFF", "#FFFFFFFF", "#F8F8F8FF", "#FF000000", "#FF000000", "#FF8E8E93", false)
                        presetBtn("ダーク", "#FF0A84FF", "#FF000000", "#FF1C1C1E", "#FFFFFFFF", "#FFFFFFFF", "#FF8E8E93", true)
                        presetBtn("ナチュラル", "#FF6B8E23", "#FFF5F5DC", "#FFE4E4D0", "#FF4B3621", "#FF4B3621", "#FF999988", false)
                        presetBtn("モノクロ", "#FF333333", "#FFFFFFFF", "#FFF2F2F2", "#FF000000", "#FF000000", "#FF999999", false)
                        presetBtn("カフェ", "#FF8B4513", "#FFFFF8DC", "#FFDEB887", "#FF3E2723", "#FF3E2723", "#FFA08878", false)
                    }.padding()
                }.background(Color(hex: themeBarBG).opacity(0.3))
                
                Divider()
                List {
                    Section(header: Text("外観").foregroundColor(Color(hex: themeSubText))) {
                        Toggle("ダークモード", isOn: $isDarkMode)
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    
                    Section(header: Text("全体設定").foregroundColor(Color(hex: themeSubText))) {
                        colorRow(title: "背景色", hex: $themeBG)
                        colorRow(title: "メニュー背景", hex: $themeBarBG)
                        colorRow(title: "メニュー文字", hex: $themeBarText)
                        colorRow(title: "タブ選択色", hex: $themeTabAccent)
                        colorRow(title: "本文文字", hex: $themeBodyText)
                        colorRow(title: "サブ文字", hex: $themeSubText)
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    
                    Section(header: Text("パーツ設定").foregroundColor(Color(hex: themeSubText))) {
                        colorRow(title: "メインカラー", hex: $themeMain)
                        colorRow(title: "収入色", hex: $themeIncome)
                        colorRow(title: "支出色", hex: $themeExpense)
                        colorRow(title: "祝日色", hex: $themeHoliday)
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                }.scrollContentBackground(.hidden).listStyle(.insetGrouped)
            }
        }
        .navigationTitle("テーマ設定")
        .navigationBarTitleDisplayMode(.inline)
    }

    func presetBtn(_ n: String, _ m: String, _ bg: String, _ bb: String, _ bt: String, _ body: String, _ sub: String, _ dark: Bool) -> some View {
        Button(action: { 
            withAnimation {
                themeMain = m; themeBG = bg; themeBarBG = bb; themeBarText = bt; themeBodyText = body; themeSubText = sub; isDarkMode = dark 
            }
        }) {
            VStack(spacing: 8) {
                Circle().fill(Color(hex: m)).frame(width: 44, height: 44).overlay(Circle().stroke(Color(hex: themeBarText).opacity(0.2), lineWidth: 1))
                Text(n).font(.system(size: 10)).foregroundColor(Color(hex: themeSubText))
            }
        }.buttonStyle(.plain)
    }
    
    func colorRow(title: String, hex: Binding<String>) -> some View {
        ColorPicker(title, selection: Binding(get: { Color(hex: hex.wrappedValue) }, set: { hex.wrappedValue = $0.toHex() })).foregroundColor(Color(hex: themeBodyText))
    }
}
