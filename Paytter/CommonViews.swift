import SwiftUI
import UIKit

struct TimelineImageGrid: View {
    let images: [Data]
    var cornerRadius: CGFloat = 12
    var maxHeight: CGFloat = 160
    
    var body: some View {
        let count = images.count
        Group {
            if count == 1 { imgView(images[0]) }
            else if count == 2 { HStack(spacing: 4) { imgView(images[0]); imgView(images[1]) } }
            else if count == 3 { HStack(spacing: 4) { imgView(images[0]); VStack(spacing: 4) { imgView(images[1]); imgView(images[2]) } } }
            else if count >= 4 { VStack(spacing: 4) { HStack(spacing: 4) { imgView(images[0]); imgView(images[1]) }; HStack(spacing: 4) { imgView(images[2]); imgView(images[3]) } } }
        }
        .frame(height: maxHeight)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(Color.gray.opacity(0.2), lineWidth: 1))
    }
    
    @ViewBuilder func imgView(_ data: Data) -> some View {
        if let uiImage = ImageCache.shared.image(for: data) {
            Image(uiImage: uiImage).resizable().scaledToFill().frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity).clipped()
        } else { Color.gray.opacity(0.1) }
    }
}

// 【新規】動画用のグリッド表示（再生マーク付き）
struct TimelineVideoGrid: View {
    let videos: [AttachedVideo]
    var cornerRadius: CGFloat = 12
    var maxHeight: CGFloat = 160
    
    var body: some View {
        let count = videos.count
        Group {
            if count == 1 { vidView(videos[0]) }
            else if count == 2 { HStack(spacing: 4) { vidView(videos[0]); vidView(videos[1]) } }
            else if count == 3 { HStack(spacing: 4) { vidView(videos[0]); VStack(spacing: 4) { vidView(videos[1]); vidView(videos[2]) } } }
            else if count >= 4 { VStack(spacing: 4) { HStack(spacing: 4) { vidView(videos[0]); vidView(videos[1]) }; HStack(spacing: 4) { vidView(videos[2]); vidView(videos[3]) } } }
        }
        .frame(height: maxHeight)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(Color.gray.opacity(0.2), lineWidth: 1))
    }
    
    @ViewBuilder func vidView(_ video: AttachedVideo) -> some View {
        ZStack {
            if let data = video.thumbnailData, let uiImage = ImageCache.shared.image(for: data) {
                Image(uiImage: uiImage).resizable().scaledToFill().frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity).clipped()
            } else {
                Color.black.opacity(0.8)
            }
            Image(systemName: "play.circle.fill").font(.system(size: 30)).foregroundColor(.white.opacity(0.8))
        }
    }
}

struct BalanceView: View {
    let title: String; let amount: Int; let color: Color; let diff: Int; let isSilent: Bool
    @State private var showDiff = false; @State private var lastAmount: Int = 0 
    @AppStorage("theme_income") var themeIncome: String = "#FF19B219"
    @AppStorage("theme_expense") var themeExpense: String = "#FFFF3B30"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    
    var body: some View {
        VStack {
            Text(title).font(.caption).foregroundColor(Color(hex: themeSubText))
            ZStack(alignment: .topTrailing) {
                Text("¥\(amount)").font(.system(.subheadline, design: .monospaced)).fontWeight(.bold).foregroundColor(color).padding(.horizontal, 4)
                if diff != 0 { Text(diff > 0 ? "+\(diff)" : "\(diff)").font(.system(size: 8, weight: .bold, design: .rounded)).foregroundColor(diff > 0 ? Color(hex: themeIncome) : Color(hex: themeExpense)).offset(x: 20, y: showDiff ? -15 : 0).opacity(showDiff ? 0 : 1) }
            }
        }.frame(maxWidth: .infinity).onChange(of: amount) { newValue in if newValue != lastAmount { if isSilent { showDiff = true; lastAmount = newValue } else { showDiff = false; withAnimation(.easeOut(duration: 0.6)) { showDiff = true }; lastAmount = newValue } } }.onAppear { lastAmount = amount }
    }
}

struct TwitterRow: View {
    let item: Transaction
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    @AppStorage("user_profiles_v1") var profiles: [UserProfile] = []
    
    var body: some View {
        let profile = profiles.first(where: { $0.id == item.profileId }) ?? profiles.first ?? UserProfile(name: "不明", userId: "unknown")
        let isPrivate = profile.isPrivate ?? false; let isDeleted = profile.isDeleted ?? false; let isLocked = !LockManager.shared.isUnlocked; let hideContent = isPrivate && isLocked && LockManager.shared.privatePostDisplayMode == 1
        let displayName = isDeleted ? "削除されたユーザー" : profile.name; let displayId = isDeleted ? "deleted_user" : profile.userId
        
        HStack(alignment: .top, spacing: 12) {
            if !isDeleted, let iconData = profile.iconData, let uiImage = ImageCache.shared.image(for: iconData) { Image(uiImage: uiImage).resizable().scaledToFill().frame(width: 48, height: 48).clipShape(Circle()) } else { Image(systemName: "person.circle.fill").resizable().frame(width: 48, height: 48).foregroundColor(.gray) }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(displayName).font(.subheadline).fontWeight(.bold).foregroundColor(Color(hex: themeBodyText))
                    Text("@\(displayId) · \(item.date, style: .time)").font(.caption).foregroundColor(Color(hex: themeBodyText).opacity(0.6))
                    Spacer()
                    if item.isExcludedFromBalance == true { Image(systemName: "calculator.badge.minus").font(.system(size: 8)).foregroundColor(Color(hex: themeBodyText).opacity(0.4)) }
                    if hideContent { Text("---").font(.system(size: 9, weight: .bold)).padding(.horizontal, 6).padding(.vertical, 2).background(Color.gray.opacity(0.1)).cornerRadius(4).foregroundColor(Color(hex: themeBodyText)) } else { Text(item.source).font(.system(size: 9, weight: .bold)).padding(.horizontal, 6).padding(.vertical, 2).background(Color.gray.opacity(0.1)).cornerRadius(4).foregroundColor(Color(hex: themeBodyText)) }
                }
                
                if hideContent {
                    Text("鍵アカウントによる投稿です").font(.subheadline).foregroundColor(Color(hex: themeSubText))
                } else {
                    HighlightedText(text: item.cleanNote, isIncome: item.isIncome).font(.subheadline).fixedSize(horizontal: false, vertical: true).foregroundColor(Color(hex: themeBodyText))
                    if !item.tags.isEmpty { HStack { ForEach(item.tags, id: \.self) { tag in Text(tag).font(.caption).foregroundColor(Color(hex: themeMain)) } } }
                    
                    // 【新規】各種添付ファイルの表示
                    if let images = item.attachedImageDatas, !images.isEmpty {
                        TimelineImageGrid(images: images, maxHeight: 160).padding(.top, 4)
                    }
                    if let videos = item.attachedVideos, !videos.isEmpty {
                        TimelineVideoGrid(videos: videos, maxHeight: 160).padding(.top, 4)
                    }
                    if let files = item.attachedFiles, !files.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(files, id: \.id) { file in
                                HStack {
                                    Image(systemName: "doc.fill").foregroundColor(.gray)
                                    Text(file.originalFileName).lineLimit(1).truncationMode(.middle).foregroundColor(Color(hex: themeBodyText))
                                    Spacer()
                                    Text("\(file.fileExtension) · \(file.formattedSize)").foregroundColor(.gray)
                                }
                                .font(.caption)
                                .padding(8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }.padding(.top, 4)
                    }
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
            else if token.contains("¥") { let amountVal = Int(token.replacingOccurrences(of: "¥", with: "")) ?? 0; let actuallyIncome = amountVal >= 0 ? isIncome : !isIncome; return res + Text(token.replacingOccurrences(of: "-", with: "")).foregroundColor(actuallyIncome ? Color(hex: themeIncome) : Color(hex: themeExpense)).fontWeight(.bold) } else { return res + Text(token) }
        }
    }
    func tokenize(_ input: String) -> [String] { var tokens: [String] = []; var current = ""; for char in input { if char == " " || char == "　" || char == "\n" { if !current.isEmpty { tokens.append(current); current = "" }; tokens.append(String(char)) } else { current.append(char) } }; if !current.isEmpty { tokens.append(current) }; return tokens }
}

struct CustomTextEditor: UIViewRepresentable {
    @Binding var text: String; var onInsert: (String) -> Void
    func makeUIView(context: Context) -> UITextView { let tv = UITextView(); tv.font = .preferredFont(forTextStyle: .body); tv.backgroundColor = .clear; tv.isScrollEnabled = true; tv.isEditable = true; tv.delegate = context.coordinator; let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44)); toolbar.items = [UIBarButtonItem(title: "#", style: .plain, target: context.coordinator, action: #selector(context.coordinator.insertHash)), UIBarButtonItem(title: "¥", style: .plain, target: context.coordinator, action: #selector(context.coordinator.insertYen)), UIBarButtonItem(title: "@", style: .plain, target: context.coordinator, action: #selector(context.coordinator.insertAt)), UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil), UIBarButtonItem(title: "完了", style: .done, target: context.coordinator, action: #selector(context.coordinator.dismissKeyboard))]; tv.inputAccessoryView = toolbar; return tv }
    func updateUIView(_ uiView: UITextView, context: Context) { if uiView.text != text { uiView.text = text } }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    class Coordinator: NSObject, UITextViewDelegate { var parent: CustomTextEditor; init(_ parent: CustomTextEditor) { self.parent = parent }; func textViewDidChange(_ tv: UITextView) { parent.text = tv.text }; @objc func insertHash() { parent.onInsert("#") }; @objc func insertYen() { parent.onInsert("¥") }; @objc func insertAt() { parent.onInsert("@") }; @objc func dismissKeyboard() { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } }
}
extension UIView { func findTextView() -> UITextView? { if let tv = self as? UITextView { return tv }; for sv in subviews { if let tv = sv.findTextView() { return tv } }; return nil } }
