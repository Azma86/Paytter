import SwiftUI

struct TwitterRow: View {
    let item: Transaction
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    
    // ユーザー情報の即時反映用
    @AppStorage("userName") var userName: String = "むつき"
    @AppStorage("userId") var userId: String = "Mutsuki_dev"
    @AppStorage("userIconData") var userIconData: Data = Data()
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let uiImage = UIImage(data: userIconData) {
                Image(uiImage: uiImage).resizable().scaledToFill().frame(width: 48, height: 48).clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill").resizable().frame(width: 48, height: 48).foregroundColor(Color(hex: themeSubText))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(userName).font(.subheadline).fontWeight(.bold).foregroundColor(Color(hex: themeBodyText))
                    Text("@\(userId)").font(.caption).foregroundColor(Color(hex: themeSubText)).lineLimit(1)
                    Spacer()
                    Text(item.source).font(.system(size: 8, weight: .bold)).padding(.horizontal, 6).padding(.vertical, 2).background(Color(hex: themeSubText).opacity(0.1)).cornerRadius(4).foregroundColor(Color(hex: themeBodyText))
                }
                HighlightedText(text: item.cleanNote, isIncome: item.isIncome).font(.subheadline).foregroundColor(Color(hex: themeBodyText))
                if !item.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) { ForEach(item.tags, id: \.self) { tag in Text(tag).font(.caption).foregroundColor(Color(hex: themeMain)) } }
                    }
                }
                HStack(spacing: 40) {
                    Image(systemName: "bubble.left"); Image(systemName: "arrow.2.squarepath"); Image(systemName: "heart"); Image(systemName: "shareplay")
                }.font(.caption).foregroundColor(Color(hex: themeSubText)).padding(.top, 4)
            }
        }.padding(12)
    }
}

struct HighlightedText: View {
    let text: String; let isIncome: Bool
    @AppStorage("theme_income") var themeIncome: String = "#FF19B219"
    @AppStorage("theme_expense") var themeExpense: String = "#FFFF3B30"
    var body: some View {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        return words.reduce(Text("")) { (res, word) in
            if word.contains("¥") { return res + Text(word).foregroundColor(isIncome ? Color(hex: themeIncome) : Color(hex: themeExpense)).fontWeight(.bold) + Text(" ") }
            else { return res + Text(word) + Text(" ") }
        }
    }
}
