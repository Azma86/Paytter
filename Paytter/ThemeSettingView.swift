import SwiftUI

struct ThemeSettingView: View {
    // ダークモード切替のステータスを保存
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    
    // 各パーツの色設定（ContentViewと共通のキーを使用）
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_income") var themeIncome: String = "#FF19B219"
    @AppStorage("theme_expense") var themeExpense: String = "#FFFF3B30"
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_barBG") var themeBarBG: String = "#F8F8F8FF"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"

    var body: some View {
        ZStack {
            Color(hex: themeBG).ignoresSafeArea()
            List {
                Section(header: Text("外観モード").foregroundColor(Color(hex: themeSubText))) {
                    HStack {
                        Label(isDarkMode ? "ダークモード" : "ライトモード", systemImage: isDarkMode ? "moon.fill" : "sun.max.fill")
                            .foregroundColor(Color(hex: themeBodyText))
                        Spacer()
                        Toggle("", isOn: $isDarkMode)
                            .labelsHidden()
                            .onChange(of: isDarkMode) { newValue in
                                applyMode(newValue)
                            }
                    }
                }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                
                Section(header: Text("全体設定").foregroundColor(Color(hex: themeSubText))) {
                    colorRow(title: "背景色", hex: $themeBG)
                    colorRow(title: "メニュー背景", hex: $themeBarBG)
                    colorRow(title: "本文文字色", hex: $themeBodyText)
                    colorRow(title: "サブ文字色", hex: $themeSubText)
                }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                
                Section(header: Text("個別パーツ").foregroundColor(Color(hex: themeSubText))) {
                    colorRow(title: "メインカラー", hex: $themeMain)
                    colorRow(title: "収入の色", hex: $themeIncome)
                    colorRow(title: "支出の色", hex: $themeExpense)
                }.listRowBackground(Color(hex: themeBG).opacity(0.5))
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
        }
        .navigationTitle("テーマ設定")
        // OS側の色設定（時計やステータスバーなど）に反映させる
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }

    // モード切替時に色を一括でセットする
    func applyMode(_ dark: Bool) {
        withAnimation(.easeInOut(duration: 0.3)) {
            if dark {
                themeBG = "#000000FF"
                themeBarBG = "#1C1C1EFF"
                themeBodyText = "#FFFFFFFF"
                themeSubText = "#8E8E93FF"
            } else {
                themeBG = "#FFFFFFFF"
                themeBarBG = "#F8F8F8FF"
                themeBodyText = "#000000FF"
                themeSubText = "#8E8E93FF"
            }
        }
    }
    
    // カラーピッカー付きの行
    func colorRow(title: String, hex: Binding<String>) -> some View {
        ColorPicker(title, selection: Binding(get: { Color(hex: hex.wrappedValue) }, set: { hex.wrappedValue = $0.toHex() }))
            .foregroundColor(Color(hex: themeBodyText))
    }
}
