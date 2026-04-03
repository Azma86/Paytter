import SwiftUI
import UIKit

// 共通の残高表示パーツ
struct BalanceView: View {
    let title: String; let amount: Int; let color: Color; let diff: Int
    @State private var showDiff = false; @State private var lastAmount: Int = 0 
    @AppStorage("theme_income") var themeIncome: String = "#FF19B219"
    @AppStorage("theme_expense") var themeExpense: String = "#FFFF3B30"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    var body: some View {
        VStack {
            Text(title).font(.caption).foregroundColor(Color(hex: themeSubText))
            ZStack(alignment: .topTrailing) {
                Text("¥\(amount)").font(.system(.subheadline, design: .monospaced)).fontWeight(.bold).foregroundColor(color).padding(.horizontal, 4)
                if diff != 0 { 
                    Text(diff > 0 ? "+\(diff)" : "\(diff)")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(diff > 0 ? Color(hex: themeIncome) : Color(hex: themeExpense))
                        .offset(x: 20, y: showDiff ? -15 : 0)
                        .opacity(showDiff ? 0 : 1) 
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onChange(of: amount) { newValue in 
            if newValue != lastAmount { 
                showDiff = false; withAnimation(.easeOut(duration: 0.6)) { showDiff = true }
                lastAmount = newValue 
            } 
        }
        .onAppear { lastAmount = amount }
    }
}

struct TwitterRow: View {
    let item: Transaction
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    @AppStorage("userName") var userName: String = "むつき"
    @AppStorage("userId") var userId: String = "Mutsuki_dev"
    @AppStorage("userIconData") var userIconData: Data = Data()
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let uiImage = UIImage(data: userIconData) {
                Image(uiImage: uiImage).resizable().scaledToFill().frame(width: 48, height: 48).clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill").resizable().frame(width: 48, height: 48).foregroundColor(.gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(userName).font(.subheadline).fontWeight(.bold).foregroundColor(Color(hex: themeBodyText))
                    Text("@\(userId) · \(item.date, style: .time)").font(.caption).foregroundColor(Color(hex: themeBodyText).opacity(0.6))
                    Spacer()
                    
                    // 【追加】計算除外アイコンの表示
                    if item.isExcludedFromBalance {
                        Image(systemName: "calculator.badge.minus")
                            .font(.system(size: 8))
                            .foregroundColor(Color(hex: themeBodyText).opacity(0.4))
                    }
                    
                    Text(item.source).font(.system(size: 9, weight: .bold)).padding(.horizontal, 6).padding(.vertical, 2).background(Color.gray.opacity(0.1)).cornerRadius(4).foregroundColor(Color(hex: themeBodyText))
                }
                HighlightedText(text: item.cleanNote, isIncome: item.isIncome)
                    .font(.subheadline).fixedSize(horizontal: false, vertical: true).foregroundColor(Color(hex: themeBodyText))
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
