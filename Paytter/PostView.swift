import SwiftUI

struct PostView: View {
    @Binding var inputText: String; @Binding var isPresented: Bool
    var initialDate: Date = Date()
    var onPost: (Bool, Date) -> Void
    var transactions: [Transaction]; var accounts: [Account]
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_income") var themeIncome: String = "#FF19B219"
    @AppStorage("theme_expense") var themeExpense: String = "#FFFF3B30"
    
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
                        CustomTextEditor(text: $inputText) { sym in insertAtCursor(sym); DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { updateSuggestionsForCursor() } }
                        .frame(minHeight: 150).onChange(of: inputText) { _ in updateSuggestionsForCursor() }
                        if inputText.isEmpty { Text("どんな買い物をしましたか？").foregroundColor(.gray.opacity(0.7)).padding(.top, 8).padding(.leading, 5).allowsHitTesting(false) }
                    }
                }.padding()
                if !suggestions.isEmpty { ScrollView(.vertical) { VStack(alignment: .leading, spacing: 0) { ForEach(suggestions, id: \.self) { s in Button(action: { applySuggestion(s) }) { VStack(alignment: .leading) { Text(s).font(.body).foregroundColor(.primary).padding(.vertical, 12).padding(.horizontal, 20); Divider() } } } } }.frame(maxHeight: 150).background(Color(.systemBackground)) }
                HStack { Button(action: { isPickingTime = false; isShowingDatePicker = true }) { HStack(spacing: 4) { Image(systemName: "calendar.badge.clock"); Text(formatDate(postDate)) }.font(.footnote).padding(.horizontal, 12).padding(.vertical, 6).background(Color(hex: themeMain).opacity(0.1)).foregroundColor(Color(hex: themeMain)).cornerRadius(12) }; Spacer() }.padding(.horizontal)
                Spacer()
            }
            .navigationBarItems(leading: Button("キャンセル") { isPresented = false }, trailing: HStack(spacing: 12) {
                Button("支出") { onPost(false, postDate); isPresented = false }.padding(.horizontal, 12).padding(.vertical, 6).background(Color(hex: themeExpense).opacity(0.8)).foregroundColor(.white).cornerRadius(15)
                Button("収入") { onPost(true, postDate); isPresented = false }.padding(.horizontal, 12).padding(.vertical, 6).background(Color(hex: themeIncome)).foregroundColor(.white).cornerRadius(15)
            })
            .sheet(isPresented: $isShowingDatePicker) { NavigationView { VStack { DatePicker("日時を選択", selection: $postDate, displayedComponents: isPickingTime ? .hourAndMinute : .date).datePickerStyle(.wheel).labelsHidden().environment(\.locale, Locale(identifier: "ja_JP")) }.navigationTitle(isPickingTime ? "時刻の指定" : "日付の指定").navigationBarItems(leading: Button(isPickingTime ? "日付に切り替え" : "時刻に切り替え") { withAnimation { isPickingTime.toggle() } }, trailing: Button("完了") { isShowingDatePicker = false }) }.presentationDetents([.height(350)]) }
        }.onAppear { self.postDate = initialDate }
    }
    func formatDate(_ date: Date) -> String { let f = DateFormatter(); f.locale = Locale(identifier: "ja_JP"); f.dateFormat = "yyyy年MM月dd日 HH:mm"; return f.string(from: date) }
    func updateSuggestionsForCursor() { guard let sc = UIApplication.shared.connectedScenes.first as? UIWindowScene, let win = sc.windows.first, let tv = win.findTextView() else { return }; let cursorLoc = tv.selectedRange.location; let text = tv.text ?? ""; let prefixText = String(text.prefix(cursorLoc)); let currentWord = prefixText.components(separatedBy: CharacterSet.whitespacesAndNewlines).last ?? ""; if currentWord == "#" { suggestions = Array(Set(transactions.flatMap { $0.tags })).sorted() } else if currentWord.hasPrefix("#") { suggestions = Array(Set(transactions.flatMap { $0.tags }.filter { $0.hasPrefix(currentWord) && $0 != currentWord })).sorted() } else if currentWord == "@" { suggestions = accounts.map { "@" + $0.name }.sorted() } else if currentWord.hasPrefix("@") { suggestions = accounts.map { "@" + $0.name }.filter { $0.hasPrefix(currentWord) && $0 != currentWord }.sorted() } else { suggestions = [] } }
    func applySuggestion(_ suggestion: String) { guard let sc = UIApplication.shared.connectedScenes.first as? UIWindowScene, let win = sc.windows.first, let tv = win.findTextView() else { return }; let cursorLoc = tv.selectedRange.location; let text = tv.text ?? ""; let prefixText = String(text.prefix(cursorLoc)); let words = prefixText.components(separatedBy: CharacterSet.whitespacesAndNewlines); if let lastWord = words.last { let rangeStart = cursorLoc - lastWord.count; let startIdx = text.index(text.startIndex, offsetBy: rangeStart); let endIdx = text.index(text.startIndex, offsetBy: cursorLoc); inputText = text.replacingCharacters(in: startIdx..<endIdx, with: suggestion + " "); DispatchQueue.main.async { tv.selectedRange = NSRange(location: rangeStart + suggestion.count + 1, length: 0); suggestions = [] } } }
    func insertAtCursor(_ sym: String) { if let sc = UIApplication.shared.connectedScenes.first as? UIWindowScene, let win = sc.windows.first, let tv = win.findTextView() { let sel = tv.selectedRange; let cur = tv.text ?? ""; let lastChar: Character? = sel.location > 0 ? cur[cur.index(cur.startIndex, offsetBy: sel.location - 1)] : nil; let prefix = (lastChar == " " || lastChar == "　" || lastChar == "\n" || lastChar == nil) ? "" : " "; tv.becomeFirstResponder(); tv.insertText(prefix + sym) } }
}
