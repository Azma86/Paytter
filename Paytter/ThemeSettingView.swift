import SwiftUI

struct ThemeSettingView: View {
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_income") var themeIncome: String = "#FF19B219"
    @AppStorage("theme_expense") var themeExpense: String = "#FFFF3B30"
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
                // プリセットボタン
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        presetBtn("デフォルト", "#FF007AFF", "#FFFFFFFF", "#F8F8F8FF", "#FF000000", "#FF000000", "#FF8E8E93")
                        presetBtn("ダーク", "#FF0A84FF", "#FF000000", "#FF1C1C1E", "#FFFFFFFF", "#FFFFFFFF", "#FF8E8E93")
                        presetBtn("カフェ", "#FF8B4513", "#FFFFF8DC", "#FFDEB887", "#FF3E2723", "#FF3E2723", "#FFA08878")
                    }.padding().padding(.top, 10)
                }
                Divider()
                List {
                    Section(header: Text("外観モード").foregroundColor(Color(hex: themeSubText))) {
                        Toggle("ダークモード有効", isOn: $isDarkMode)
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    
                    Section(header: Text("全体設定").foregroundColor(Color(hex: themeSubText))) {
                        colorRow(title: "背景色", hex: $themeBG)
                        colorRow(title: "メニュー背景", hex: $themeBarBG)
                        colorRow(title: "メニュー文字", hex: $themeBarText)
                        colorRow(title: "本文文字", hex: $themeBodyText)
                        colorRow(title: "サブ文字", hex: $themeSubText)
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                }.scrollContentBackground(.hidden).listStyle(.insetGrouped)
            }
        }
        .navigationTitle("テーマ設定")
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }

    func presetBtn(_ n: String, _ m: String, _ bg: String, _ bb: String, _ bt: String, _ body: String, _ sub: String) -> some View {
        Button(action: { themeMain = m; themeBG = bg; themeBarBG = bb; themeBarText = bt; themeBodyText = body; themeSubText = sub; isDarkMode = (bg == "#FF000000") }) {
            VStack(spacing: 8) {
                Circle().fill(Color(hex: m)).frame(width: 46, height: 46).overlay(Circle().stroke(Color(hex: themeBarText).opacity(0.2), lineWidth: 1))
                Text(n).font(.system(size: 10, weight: .medium)).foregroundColor(Color(hex: themeSubText))
            }
        }.buttonStyle(.plain)
    }
    
    func colorRow(title: String, hex: Binding<String>) -> some View {
        ColorPicker(title, selection: Binding(get: { Color(hex: hex.wrappedValue) }, set: { hex.wrappedValue = $0.toHex() })).foregroundColor(Color(hex: themeBodyText))
    }
}
