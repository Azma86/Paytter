import SwiftUI
import UIKit

// --- タイムラインの1行 ---
struct TwitterRow: View {
    let item: Transaction
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "person.circle.fill").resizable().frame(width: 48, height: 48).foregroundColor(.gray)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("むつき").font(.subheadline).fontWeight(.bold).foregroundColor(.primary)
                    Text("@Mutsuki_dev · \(item.date, style: .time)").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Text(item.source).font(.system(size: 9, weight: .bold)).padding(.horizontal, 6).padding(.vertical, 2).background(Color.gray.opacity(0.1)).cornerRadius(4).foregroundColor(.primary)
                }
                // ここで改行を含むハイライトテキストを表示
                HighlightedText(text: item.cleanNote, isIncome: item.isIncome).font(.subheadline)
                if !item.tags.isEmpty {
                    HStack { ForEach(item.tags, id: \.self) { tag in Text(tag).font(.caption).foregroundColor(.blue) } }
                }
            }
        }.padding(.vertical, 8).padding(.horizontal, 16)
    }
}

// --- 金額ハイライト (改行・マイナス非表示対応) ---
struct HighlightedText: View {
    let text: String; let isIncome: Bool
    
    var body: some View {
        // 正規表現的に「スペース」か「改行」で分割し、その区切り文字自体も保持するロジック
        let components = tokenize(text)
        
        return components.reduce(Text("")) { (res, token) in
            if token == "\n" {
                return res + Text("\n")
            } else if token.contains("¥") {
                // 金額部分の数値を抽出
                let amountStr = token.replacingOccurrences(of: "¥", with: "")
                let amountVal = Int(amountStr) ?? 0
                
                // 表示用のテキストを作成 (マイナス記号を除去)
                let displayWord = token.replacingOccurrences(of: "-", with: "")
                
                // 表示色の決定ロジック
                let actuallyIncome = amountVal >= 0 ? isIncome : !isIncome
                let highlightColor = actuallyIncome ? Color(red: 0.1, green: 0.7, blue: 0.1) : .red
                
                return res + Text(displayWord).foregroundColor(highlightColor).fontWeight(.bold)
            } else {
                return res + Text(token).foregroundColor(.primary)
            }
        }
    }
    
    // テキストを単語、スペース、改行に分解する補助関数
    func tokenize(_ input: String) -> [String] {
        var tokens: [String] = []
        var currentToken = ""
        
        for char in input {
            if char == " " || char == "　" || char == "\n" {
                if !currentToken.isEmpty {
                    tokens.append(currentToken)
                    currentToken = ""
                }
                tokens.append(String(char))
            } else {
                currentToken.append(char)
            }
        }
        if !currentToken.isEmpty {
            tokens.append(currentToken)
        }
        return tokens
    }
}

// --- エディタ部品 ---
struct CustomTextEditor: UIViewRepresentable {
    @Binding var text: String; var onInsert: (String) -> Void
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView(); textView.font = .preferredFont(forTextStyle: .body); textView.backgroundColor = .clear; textView.delegate = context.coordinator
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        let items = [UIBarButtonItem(title: "#", style: .plain, target: context.coordinator, action: #selector(context.coordinator.insertHash)), UIBarButtonItem(title: "¥", style: .plain, target: context.coordinator, action: #selector(context.coordinator.insertYen)), UIBarButtonItem(title: "@", style: .plain, target: context.coordinator, action: #selector(context.coordinator.insertAt)), UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil), UIBarButtonItem(title: "完了", style: .done, target: context.coordinator, action: #selector(context.coordinator.dismissKeyboard))]
        toolbar.items = items; textView.inputAccessoryView = toolbar; return textView
    }
    func updateUIView(_ uiView: UITextView, context: Context) { if uiView.text != text { uiView.text = text } }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: CustomTextEditor; init(_ parent: CustomTextEditor) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) { parent.text = textView.text }
        @objc func insertHash() { parent.onInsert("#") }; @objc func insertYen() { parent.onInsert("¥") }; @objc func insertAt() { parent.onInsert("@") }
        @objc func dismissKeyboard() { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
    }
}

extension UIView { 
    func findTextView() -> UITextView? { 
        if let tv = self as? UITextView { return tv }
        for sv in subviews { if let tv = sv.findTextView() { return tv } }
        return nil 
    } 
}
