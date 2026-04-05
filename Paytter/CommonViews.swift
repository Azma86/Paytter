import SwiftUI
import UIKit
import AVKit

struct TimelineMediaGrid: View {
    let mediaItems: [AttachedMediaItem]
    var cornerRadius: CGFloat = 12
    var maxHeight: CGFloat = 160
    
    // 【変更】タップしたメディアのインデックスを保持してフルスクリーンに渡す
    @State private var selectedMediaIndex: Int? = nil
    @State private var isFullScreenPresented: Bool = false
    
    var body: some View {
        let count = mediaItems.count
        Group {
            if count == 1 {
                mediaView(mediaItems[0], index: 0)
            } else if count == 2 {
                HStack(spacing: 4) {
                    mediaView(mediaItems[0], index: 0)
                    mediaView(mediaItems[1], index: 1)
                }
            } else if count == 3 {
                HStack(spacing: 4) {
                    mediaView(mediaItems[0], index: 0)
                    VStack(spacing: 4) {
                        mediaView(mediaItems[1], index: 1)
                        mediaView(mediaItems[2], index: 2)
                    }
                }
            } else if count >= 4 {
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        mediaView(mediaItems[0], index: 0)
                        mediaView(mediaItems[1], index: 1)
                    }
                    HStack(spacing: 4) {
                        mediaView(mediaItems[2], index: 2)
                        mediaView(mediaItems[3], index: 3)
                    }
                }
            }
        }
        .frame(height: maxHeight)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(Color.gray.opacity(0.2), lineWidth: 1))
        .fullScreenCover(isPresented: $isFullScreenPresented) {
            // 【新規】全メディアの配列と、開始インデックスを渡す
            MediaFullScreenView(
                mediaItems: mediaItems,
                initialIndex: selectedMediaIndex ?? 0
            )
        }
    }
    
    @ViewBuilder func mediaView(_ item: AttachedMediaItem, index: Int) -> some View {
        Button(action: {
            selectedMediaIndex = index
            isFullScreenPresented = true
        }) {
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
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// 【新規】フルスクリーン時にスワイプで切り替えられるようにするための親ビュー
struct MediaFullScreenView: View {
    let mediaItems: [AttachedMediaItem]
    let initialIndex: Int
    @Environment(\.presentationMode) var presentationMode
    
    @State private var currentIndex: Int = 0
    @State private var showUI: Bool = true
    
    @State private var showSaveAlert = false
    @State private var saveAlertMessage = ""
    
    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            
            // TabViewを利用したスワイプでのページング機能
            TabView(selection: $currentIndex) {
                ForEach(0..<mediaItems.count, id: \.self) { index in
                    SingleMediaZoomView(media: mediaItems[index], showUI: $showUI)
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .ignoresSafeArea()
            
            if showUI && mediaItems.indices.contains(currentIndex) {
                let currentMedia = mediaItems[currentIndex]
                HStack(spacing: 16) {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.4).clipShape(Circle()))
                    }
                    
                    let displayName = currentMedia.originalFileName ?? (currentMedia.localFileName.isEmpty ? "添付画像" : currentMedia.localFileName)
                    Text(displayName)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Button(action: { shareMedia(media: currentMedia) }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.4).clipShape(Circle()))
                    }
                    
                    Button(action: { saveMedia(media: currentMedia) }) {
                        Image(systemName: "arrow.down.to.line")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.4).clipShape(Circle()))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, safeAreaTop)
                .padding(.bottom, 16)
                .background(
                    currentMedia.type == .video ?
                    LinearGradient(gradient: Gradient(colors: [Color.black.opacity(0.7), Color.clear]), startPoint: .top, endPoint: .bottom) : nil
                )
                .ignoresSafeArea(edges: .top)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear {
            currentIndex = initialIndex
        }
        .alert(isPresented: $showSaveAlert) {
            Alert(title: Text("保存"), message: Text(saveAlertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    var safeAreaTop: CGFloat {
        UIApplication.shared.windows.first?.safeAreaInsets.top ?? 20
    }
    
    // 【重要修正】不正なURL共有による謎のDocumentsフォルダ共有を防ぐ
    func shareMedia(media: AttachedMediaItem) {
        var itemToShare: Any?
        
        if media.localFileName.isEmpty {
            if let data = media.thumbnailData, let image = UIImage(data: data) {
                itemToShare = image
            }
        } else {
            let url = MediaManager.shared.getMediaURL(fileName: media.localFileName)
            if FileManager.default.fileExists(atPath: url.path) {
                itemToShare = url
            } else if let data = media.thumbnailData, let image = UIImage(data: data) {
                itemToShare = image // ファイルが存在しない場合はUIImageを直接共有
            }
        }
        
        guard let shareItem = itemToShare else { return }
        
        let av = UIActivityViewController(activityItems: [shareItem], applicationActivities: nil)
        if let topVC = UIApplication.shared.topViewController {
            av.popoverPresentationController?.sourceView = topVC.view
            topVC.present(av, animated: true)
        }
    }
    
    // 【重要修正】バックグラウンドスレッドで保存処理を行い、フリーズを防止
    func saveMedia(media: AttachedMediaItem) {
        let fileName = media.localFileName
        let type = media.type
        let thumbData = media.thumbnailData
        
        DispatchQueue.global(qos: .userInitiated).async {
            var saved = false
            
            if fileName.isEmpty {
                if let data = thumbData, let image = UIImage(data: data) {
                    DispatchQueue.main.async { UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil) }
                    saved = true
                }
            } else {
                let url = MediaManager.shared.getMediaURL(fileName: fileName)
                if type == .image {
                    if let image = UIImage(contentsOfFile: url.path) {
                        DispatchQueue.main.async { UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil) }
                        saved = true
                    } else if let data = thumbData, let image = UIImage(data: data) {
                        DispatchQueue.main.async { UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil) }
                        saved = true
                    }
                } else if type == .video {
                    if UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(url.path) {
                        DispatchQueue.main.async { UISaveVideoAtPathToSavedPhotosAlbum(url.path, nil, nil, nil) }
                        saved = true
                    }
                }
            }
            
            DispatchQueue.main.async {
                if saved {
                    saveAlertMessage = type == .video ? "動画をカメラロールに保存しました" : "画像をカメラロールに保存しました"
                } else {
                    saveAlertMessage = "保存に失敗しました。アクセス権限を確認してください。"
                }
                showSaveAlert = true
            }
        }
    }
}

// 【新規】1つ1つのメディアの拡大縮小と動画再生を担当する専用ビュー
struct SingleMediaZoomView: View {
    let media: AttachedMediaItem
    @Binding var showUI: Bool
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    @State private var loadedImage: UIImage? = nil
    
    @State private var player: AVPlayer?
    @State private var isPlaying: Bool = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var isEditingSlider: Bool = false
    @State private var isSeeking: Bool = false
    @State private var timeObserver: Any?
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if media.type == .video {
                    if let player = player {
                        CustomVideoPlayerLayer(player: player)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .onTapGesture {
                                withAnimation { showUI.toggle() }
                            }
                    }
                } else {
                    if let img = loadedImage {
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
                                        offset = .zero
                                        lastOffset = .zero
                                    }
                                }
                            }
                            .onTapGesture(count: 1) {
                                withAnimation { showUI.toggle() }
                            }
                            .frame(width: proxy.size.width, height: proxy.size.height)
                    } else {
                        ProgressView().tint(.white).frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                
                // 動画用カスタムボトムメニュー
                if showUI && media.type == .video {
                    VStack {
                        Spacer()
                        
                        HStack(alignment: .center, spacing: 12) {
                            Button(action: {
                                if isPlaying {
                                    player?.pause()
                                } else {
                                    if currentTime >= duration - 0.1 {
                                        player?.seek(to: .zero)
                                    }
                                    player?.play()
                                }
                                isPlaying.toggle()
                            }) {
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                            }
                            
                            Slider(value: $currentTime, in: 0...(duration > 0 ? duration : 1)) { editing in
                                isEditingSlider = editing
                                if !editing {
                                    isSeeking = true
                                    player?.seek(to: CMTime(seconds: currentTime, preferredTimescale: 600), completionHandler: { _ in
                                        isSeeking = false
                                        if isPlaying {
                                            player?.play()
                                        }
                                    })
                                } else {
                                    player?.pause()
                                }
                            }
                            .accentColor(.white)
                            
                            Text("-" + formatTime(duration - currentTime))
                                .font(.caption2)
                                .foregroundColor(.white)
                                .frame(width: 40, alignment: .trailing)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                        .padding(.bottom, safeAreaBottom > 0 ? safeAreaBottom : 16)
                        .background(
                            LinearGradient(gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.8)]), startPoint: .top, endPoint: .bottom)
                        )
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            if media.type == .video {
                setupPlayer()
            } else {
                DispatchQueue.global(qos: .userInitiated).async {
                    var imgToLoad: UIImage? = nil
                    if let originalImage = MediaManager.shared.loadImage(fileName: media.localFileName) {
                        imgToLoad = originalImage
                    } else if let data = media.thumbnailData, let img = UIImage(data: data) {
                        imgToLoad = img
                    }
                    DispatchQueue.main.async {
                        self.loadedImage = imgToLoad
                    }
                }
            }
        }
        .onDisappear {
            if let observer = timeObserver {
                player?.removeTimeObserver(observer)
            }
            player?.pause()
        }
    }
    
    func setupPlayer() {
        let url = MediaManager.shared.getMediaURL(fileName: media.localFileName)
        let newPlayer = AVPlayer(url: url)
        self.player = newPlayer
        
        timeObserver = newPlayer.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { [weak newPlayer] time in
            guard let currentPlayer = newPlayer else { return }
            
            if let currentItem = currentPlayer.currentItem {
                let dur = currentItem.duration.seconds
                if !dur.isNaN && !dur.isInfinite {
                    self.duration = dur
                }
                
                if !self.isEditingSlider && !self.isSeeking {
                    self.currentTime = time.seconds
                }
                
                if time.seconds >= dur && dur > 0 {
                    self.isPlaying = false
                }
            }
        }
        newPlayer.play()
        self.isPlaying = true
    }
    
    func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite && seconds >= 0 else { return "0:00" }
        let totalSeconds = Int(seconds)
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
    
    var safeAreaBottom: CGFloat {
        UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0
    }
}

struct CustomVideoPlayerLayer: UIViewRepresentable {
    var player: AVPlayer
    
    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.player = player
        view.playerLayer.videoGravity = .resizeAspect
        return view
    }
    
    func updateUIView(_ uiView: PlayerView, context: Context) {
        if uiView.player != player {
            uiView.player = player
        }
    }
}

class PlayerView: UIView {
    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }
    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }
    override static var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
}

extension UIApplication {
    var topViewController: UIViewController? {
        var top = connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap { $0.windows }.first { $0.isKeyWindow }?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

// -----------------------------------
// 以下、既存の構造体はそのままです
// -----------------------------------

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
