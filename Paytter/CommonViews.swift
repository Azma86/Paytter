import SwiftUI
import UIKit

struct TwitterRow: View {
    let item: Transaction
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_barText") var themeBarText: String = "#FF000000"
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "person.circle.fill").resizable().frame(width: 48, height: 48).foregroundColor(.gray)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("むつき").font(.subheadline).fontWeight(.bold).foregroundColor(Color(hex: themeBarText))
                    Text("@Mutsuki_dev · \(item.date, style: .time)").font(.caption).foregroundColor(Color(hex: themeBarText).opacity(0.6))
                    Spacer()
                    Text(item.source).font(.system(size: 9, weight: .bold)).padding(.horizontal, 6).padding(.vertical, 2).background(Color.gray.opacity(0.1)).cornerRadius(4).foregroundColor(Color(hex: themeBarText))
                }
                HighlightedText(text: item.cleanNote, isIncome: item.isIncome)
                    .font(.subheadline).fixedSize(horizontal: false, vertical: true).foregroundColor(Color(hex: themeBarText))
                if !item.tags.isEmpty {
                    HStack { ForEach(item.tags, id: \.self) { tag in Text(tag).font(.caption).foregroundColor(Color(hex: themeMain)) } }
                }
            }
        }.padding(.vertical, 8).padding(.horizontal, 16)
    }
}

struct HighlightedText: View {
    let text: String; let isIncome: Bool
    @AppStorage("theme_income") var themeIncome: String = "#FF19B219"
    @AppStorage("theme_expense") var themeExpense: String = "#FFFF3B30"
    var body: some View {
        let components = tokenize(text)
        return components.reduce(Text("")) { (res, token) in
            if token == "\n" { return res + Text("\n") }
            else if token.contains("¥") {
                let amountVal = Int(token.replacingOccurrences(of: "¥", with: "")) ?? 0
                let actuallyIncome = amountVal >= 0 ? isIncome : !isIncome
                return res + Text(token.replacingOccurrences(of: "-", with: "")).foregroundColor(actuallyIncome ? Color(hex: themeIncome) : Color(hex: themeExpense)).fontWeight(.bold)
            } else { return res + Text(token) }
        }
    }
    func tokenize(_ input: String) -> [String] {
        var tokens: [String] = []; var current = ""
        for char in input {
            if char == " " || char == "　" || char == "\n" {
                if !current.isEmpty { tokens.append(current); current = "" }
                tokens.append(String(char))
            } else { current.append(char) }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }
}

struct CustomTextEditor: UIViewRepresentable {
    @Binding var text: String; var onInsert: (String) -> Void
    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView(); tv.font = .preferredFont(forTextStyle: .body); tv.backgroundColor = .clear; tv.isScrollEnabled = true; tv.isEditable = true; tv.delegate = context.coordinator
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        toolbar.items = [UIBarButtonItem(title: "#", style: .plain, target: context.coordinator, action: #selector(context.coordinator.insertHash)), UIBarButtonItem(title: "¥", style: .plain, target: context.coordinator, action: #selector(context.coordinator.insertYen)), UIBarButtonItem(title: "@", style: .plain, target: context.coordinator, action: #selector(context.coordinator.insertAt)), UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil), UIBarButtonItem(title: "完了", style: .done, target: context.coordinator, action: #selector(context.coordinator.dismissKeyboard))]
        tv.inputAccessoryView = toolbar; return tv
    }
    func updateUIView(_ uiView: UITextView, context: Context) { if uiView.text != text { uiView.text = text } }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: CustomTextEditor; init(_ parent: CustomTextEditor) { self.parent = parent }
        func textViewDidChange(_ tv: UITextView) { parent.text = tv.text }
        @objc func insertHash() { parent.onInsert("#") }; @objc func insertYen() { parent.onInsert("¥") }; @objc func insertAt() { parent.onInsert("@") }
        @objc func dismissKeyboard() { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
    }
}

extension UIView { func findTextView() -> UITextView? { if let tv = self as? UITextView { return tv }; for sv in subviews { if let tv = sv.findTextView() { return tv } }; return nil } }
