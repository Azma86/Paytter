import SwiftUI
import UIKit
import AVKit

struct TimelineMediaGrid: View {
    let mediaItems: [AttachedMediaItem]
    var cornerRadius: CGFloat = 12
    var maxHeight: CGFloat = 160
    
    @State private var selectedMedia: AttachedMediaItem? = nil
    
    var body: some View {
        let count = mediaItems.count
        Group {
            if count == 1 {
                mediaView(mediaItems[0])
            } else if count == 2 {
                HStack(spacing: 4) {
                    mediaView(mediaItems[0])
                    mediaView(mediaItems[1])
                }
            } else if count == 3 {
                HStack(spacing: 4) {
                    mediaView(mediaItems[0])
                    VStack(spacing: 4) {
                        mediaView(mediaItems[1])
                        mediaView(mediaItems[2])
                    }
                }
            } else if count >= 4 {
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        mediaView(mediaItems[0])
                        mediaView(mediaItems[1])
                    }
                    HStack(spacing: 4) {
                        mediaView(mediaItems[2])
                        mediaView(mediaItems[3])
                    }
                }
            }
        }
        .frame(height: maxHeight)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(Color.gray.opacity(0.2), lineWidth: 1))
        .fullScreenCover(item: $selectedMedia) { media in
            MediaFullScreenView(media: media)
        }
    }
    
    @ViewBuilder func mediaView(_ item: AttachedMediaItem) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let data = item.thumbnailData, let uiImage = ImageCache.shared.image(for: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .clipped()
            } else {
                Color.black.opacity(0.8)
            }
            
            if item.type == .video {
                Color.black.opacity(0.2)
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                if let duration = item.durationText {
                    Text(duration)
                        .font(.caption2)
                        .bold()
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(4)
                        .padding(6)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedMedia = item
        }
    }
}

struct MediaFullScreenView: View {
    let media: AttachedMediaItem
    @Environment(\.presentationMode) var presentationMode
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showHeader: Bool = true
    
    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            
            GeometryReader { proxy in
                if media.type == .video {
                    let url = MediaManager.shared.getMediaURL(fileName: media.localFileName)
                    VideoPlayer(player: AVPlayer(url: url))
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .onTapGesture {
                            withAnimation { showHeader.toggle() }
                        }
                } else {
                    if let originalImage = MediaManager.shared.loadImage(fileName: media.localFileName) {
                        Image(uiImage: originalImage)
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { val in
                                        let delta = val / lastScale
                                        lastScale = val
                                        scale = min(max(scale * delta, 1), 5)
                                    }
                                    .onEnded { _ in
                                        lastScale = 1.0
                                        if scale <= 1.0 {
                                            withAnimation {
                                                offset = .zero
                                                lastOffset = .zero
                                            }
                                        }
                                    }
                            )
                            .simultaneousGesture(
                                DragGesture()
                                    .onChanged { val in
                                        if scale > 1.0 {
                                            offset = CGSize(
                                                width: lastOffset.width + val.translation.width,
                                                height: lastOffset.height + val.translation.height
                                            )
                                        }
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                            .onTapGesture(count: 2) {
                                withAnimation {
                                    if scale > 1.0 {
                                        scale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                    } else {
                                        scale = 2.0
                                        offset = .zero
                                        lastOffset = .zero
                                    }
                                }
                            }
                            .onTapGesture(count: 1) {
                                withAnimation { showHeader.toggle() }
                            }
                            .frame(width: proxy.size.width, height: proxy.size.height)
                    } else if let data = media.thumbnailData, let img = UIImage(data: data) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { val in
                                        let delta = val / lastScale
                                        lastScale = val
                                        scale = min(max(scale * delta, 1), 5)
                                    }
                                    .onEnded { _ in
                                        lastScale = 1.0
                                        if scale <= 1.0 {
                                            withAnimation {
                                                offset = .zero
                                                lastOffset = .zero
                                            }
                                        }
                                    }
                            )
                            .simultaneousGesture(
                                DragGesture()
                                    .onChanged { val in
                                        if scale > 1.0 {
                                            offset = CGSize(
                                                width: lastOffset.width + val.translation.width,
                                                height: lastOffset.height + val.translation.height
                                            )
                                        }
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                            .onTapGesture(count: 2) {
                                withAnimation {
                                    if scale > 1.0 {
                                        scale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                    } else {
                                        scale = 2.0
                                    }
                                }
                            }
                            .onTapGesture(count: 1) {
                                withAnimation { showHeader.toggle() }
                            }
                            .frame(width: proxy.size.width, height: proxy.size.height)
                    } else {
                        Text("画像を読み込めません")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .clipped()
            
            if showHeader {
                HStack(spacing: 16) {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(8)
                    }
                    
                    Text(media.localFileName.isEmpty ? "添付画像" : media.localFileName)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Button(action: shareMedia) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(8)
                    }
                    
                    Button(action: saveMedia) {
                        Image(systemName: "arrow.down.to.line")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(8)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, safeAreaTop)
                .padding(.bottom, 8)
                .background(Color.black.opacity(0.7))
                .ignoresSafeArea(edges: .top)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
    
    var safeAreaTop: CGFloat {
        UIApplication.shared.windows.first?.safeAreaInsets.top ?? 20
    }
    
    func shareMedia() {
        let url = MediaManager.shared.getMediaURL(fileName: media.localFileName)
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = scene.windows.first?.rootViewController {
            av.popoverPresentationController?.sourceView = rootVC.view
            rootVC.present(av, animated: true)
        }
    }
    
    func saveMedia() {
        let url = MediaManager.shared.getMediaURL(fileName: media.localFileName)
        if media.type == .image {
            if let image = UIImage(contentsOfFile: url.path) {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            }
        } else if media.type == .video {
            if UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(url.path) {
                UISaveVideoAtPathToSavedPhotosAlbum(url.path, nil, nil, nil)
            }
        }
    }
}

struct TimelineImageGrid: View {
    let images: [Data]
    var cornerRadius: CGFloat = 12
    var maxHeight: CGFloat = 160
    
    var body: some View {
        let count = images.count
        Group {
            if count == 1 {
                imgView(images[0])
            } else if count == 2 {
                HStack(spacing: 4) {
                    imgView(images[0])
                    imgView(images[1])
                }
            } else if count == 3 {
                HStack(spacing: 4) {
                    imgView(images[0])
                    VStack(spacing: 4) {
                        imgView(images[1])
                        imgView(images[2])
                    }
                }
            } else if count >= 4 {
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        imgView(images[0])
                        imgView(images[1])
                    }
                    HStack(spacing: 4) {
                        imgView(images[2])
                        imgView(images[3])
                    }
                }
            }
        }
        .frame(height: maxHeight)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(Color.gray.opacity(0.2), lineWidth: 1))
    }
    
    @ViewBuilder func imgView(_ data: Data) -> some View {
        if let uiImage = ImageCache.shared.image(for: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipped()
        } else {
            Color.gray.opacity(0.1)
        }
    }
}

struct BalanceView: View {
    let title: String
    let amount: Int
    let color: Color
    let diff: Int
    let isSilent: Bool
    
    @State private var showDiff = false
    @State private var lastAmount: Int = 0 
    @AppStorage("theme_income") var themeIncome: String = "#FF19B219"
    @AppStorage("theme_expense") var themeExpense: String = "#FFFF3B30"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    
    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
                .foregroundColor(Color(hex: themeSubText))
            
            ZStack(alignment: .topTrailing) {
                Text("¥\(amount)")
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(color)
                    .padding(.horizontal, 4)
                
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
                if isSilent {
                    showDiff = true
                    lastAmount = newValue
                } else {
                    showDiff = false
                    withAnimation(.easeOut(duration: 0.6)) { showDiff = true }
                    lastAmount = newValue
                }
            }
        }
        .onAppear { lastAmount = amount }
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
        
        let isPrivate = profile.isPrivate ?? false
        let isDeleted = profile.isDeleted ?? false
        let isLocked = !LockManager.shared.isUnlocked
        let hideContent = isPrivate && isLocked && LockManager.shared.privatePostDisplayMode == 1
        
        let displayName = isDeleted ? "削除されたユーザー" : profile.name
        let displayId = isDeleted ? "deleted_user" : profile.userId
        
        HStack(alignment: .top, spacing: 12) {
            if !isDeleted, let iconData = profile.iconData, let uiImage = ImageCache.shared.image(for: iconData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 48, height: 48)
                    .foregroundColor(.gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(displayName)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: themeBodyText))
                    
                    Text("@\(displayId) · \(item.date, style: .time)")
                        .font(.caption)
                        .foregroundColor(Color(hex: themeBodyText).opacity(0.6))
                    
                    Spacer()
                    
                    if item.isExcludedFromBalance == true {
                        Image(systemName: "calculator.badge.minus")
                            .font(.system(size: 8))
                            .foregroundColor(Color(hex: themeBodyText).opacity(0.4))
                    }
                    
                    if hideContent {
                        Text("---")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                            .foregroundColor(Color(hex: themeBodyText))
                    } else {
                        Text(item.source)
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                            .foregroundColor(Color(hex: themeBodyText))
                    }
                }
                
                if hideContent {
                    Text("鍵アカウントによる投稿です")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: themeSubText))
                } else {
                    HighlightedText(text: item.cleanNote, isIncome: item.isIncome)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(Color(hex: themeBodyText))
                    
                    if !item.tags.isEmpty {
                        HStack {
                            ForEach(item.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .foregroundColor(Color(hex: themeMain))
                            }
                        }
                    }
                    
                    let mediaItems = item.displayMediaItems
                    if !mediaItems.isEmpty {
                        TimelineMediaGrid(mediaItems: mediaItems, maxHeight: 160)
                            .padding(.top, 4)
                    }
                    
                    if let files = item.attachedFiles, !files.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(files, id: \.id) { file in
                                HStack {
                                    Image(systemName: "doc.fill")
                                        .foregroundColor(.gray)
                                    Text(file.originalFileName)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .foregroundColor(Color(hex: themeBodyText))
                                    Spacer()
                                    Text("\(file.fileExtension) · \(file.formattedSize)")
                                        .foregroundColor(.gray)
                                }
                                .font(.caption)
                                .padding(8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
    }
}

struct HighlightedText: View {
    let text: String
    let isIncome: Bool
    
    @AppStorage("theme_income") var themeIncome: String = "#FF19B219"
    @AppStorage("theme_expense") var themeExpense: String = "#FFFF3B30"
    
    var body: some View {
        let components = tokenize(text)
        return components.reduce(Text("")) { (res, token) in
            if token == "\n" {
                return res + Text("\n")
            } else if token.contains("¥") {
                let amountVal = Int(token.replacingOccurrences(of: "¥", with: "")) ?? 0
                let actuallyIncome = amountVal >= 0 ? isIncome : !isIncome
                return res + Text(token.replacingOccurrences(of: "-", with: ""))
                    .foregroundColor(actuallyIncome ? Color(hex: themeIncome) : Color(hex: themeExpense))
                    .fontWeight(.bold)
            } else {
                return res + Text(token)
            }
        }
    }
    
    func tokenize(_ input: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        for char in input {
            if char == " " || char == "　" || char == "\n" {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                tokens.append(String(char))
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }
}

struct CustomTextEditor: UIViewRepresentable {
    @Binding var text: String
    var onInsert: (String) -> Void
    
    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.font = .preferredFont(forTextStyle: .body)
        tv.backgroundColor = .clear
        tv.isScrollEnabled = true
        tv.isEditable = true
        tv.delegate = context.coordinator
        
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        toolbar.items = [
            UIBarButtonItem(title: "#", style: .plain, target: context.coordinator, action: #selector(context.coordinator.insertHash)),
            UIBarButtonItem(title: "¥", style: .plain, target: context.coordinator, action: #selector(context.coordinator.insertYen)),
            UIBarButtonItem(title: "@", style: .plain, target: context.coordinator, action: #selector(context.coordinator.insertAt)),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: "完了", style: .done, target: context.coordinator, action: #selector(context.coordinator.dismissKeyboard))
        ]
        tv.inputAccessoryView = toolbar
        return tv
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text { uiView.text = text }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: CustomTextEditor
        init(_ parent: CustomTextEditor) { self.parent = parent }
        func textViewDidChange(_ tv: UITextView) { parent.text = tv.text }
        @objc func insertHash() { parent.onInsert("#") }
        @objc func insertYen() { parent.onInsert("¥") }
        @objc func insertAt() { parent.onInsert("@") }
        @objc func dismissKeyboard() { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
    }
}

extension UIView {
    func findTextView() -> UITextView? {
        if let tv = self as? UITextView { return tv }
        for sv in subviews {
            if let tv = sv.findTextView() { return tv }
        }
        return nil
    }
}
