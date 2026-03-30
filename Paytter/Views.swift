import SwiftUI
import UIKit

// --- カーソル位置入力を可能にするカスタムエディタ ---
struct CustomTextEditor: UIViewRepresentable {
    @Binding var text: String
    var onInsert: (String) -> Void = { _ in } // デフォルト値を追加
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.font = .preferredFont(forTextStyle: .body)
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator
        
        // ツールバーの作成
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        let hashBtn = UIBarButtonItem(title: "#", style: .plain, target: context.coordinator, action: #selector(context.coordinator.insertHash))
        let yenBtn = UIBarButtonItem(title: "¥", style: .plain, target: context.coordinator, action: #selector(context.coordinator.insertYen))
        let atBtn = UIBarButtonItem(title: "@", style: .plain, target: context.coordinator, action: #selector(context.coordinator.insertAt))
        let doneBtn = UIBarButtonItem(title: "完了", style: .done, target: context.coordinator, action: #selector(context.coordinator.dismissKeyboard))
        
        toolbar.items = [hashBtn, yenBtn, atBtn, flexSpace, doneBtn]
        textView.inputAccessoryView = toolbar
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: CustomTextEditor
        init(_ parent: CustomTextEditor) { self.parent = parent }
        
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
        
        @objc func insertHash() { parent.onInsert("#") }
        @objc func insertYen() { parent.onInsert("¥") }
        @objc func insertAt() { parent.onInsert("@") }
        @objc func dismissKeyboard() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}

// UITextViewを見つけるためのヘルパー（これも必要です）
extension UIView {
    func findTextView() -> UITextView? {
        if let textView = self as? UITextView { return textView }
        for subview in subviews {
            if let textView = subview.findTextView() { return textView }
        }
        return nil
    }
}
