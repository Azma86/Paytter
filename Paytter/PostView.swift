import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers

struct PostAttachedMedia: Identifiable, Equatable {
    let id: UUID
    let type: MediaType
    let localFileName: String
    let originalFileName: String
    let thumbnailData: Data
    let thumbnailImage: UIImage
    let durationText: String?
    
    static func == (lhs: PostAttachedMedia, rhs: PostAttachedMedia) -> Bool {
        return lhs.id == rhs.id
    }
}

struct AttachedMediaCell: View, Equatable {
    let media: PostAttachedMedia
    let isDragged: Bool
    let dragOffset: CGFloat
    let onRemove: () -> Void
    
    static func == (lhs: AttachedMediaCell, rhs: AttachedMediaCell) -> Bool {
        lhs.media.id == rhs.media.id && lhs.isDragged == rhs.isDragged && lhs.dragOffset == rhs.dragOffset
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack(alignment: .bottomLeading) {
                Image(uiImage: media.thumbnailImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                if media.type == .video {
                    Color.black.opacity(0.2)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(.white.opacity(0.8))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    if let dur = media.durationText {
                        Text(dur)
                            .font(.caption2)
                            .bold()
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(4)
                            .padding(4)
                    }
                }
            }
            .frame(width: 80, height: 80)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white)
                    .background(Circle().fill(Color.black.opacity(0.6)))
            }
            .padding(4)
        }
        .offset(x: isDragged ? dragOffset : 0, y: 0)
        .zIndex(isDragged ? 100 : 0)
    }
}

struct AttachedMediasDragView: View {
    @Binding var attachedMedias: [PostAttachedMedia]
    
    @State private var draggedMediaId: UUID?
    @State private var dragOffset: CGFloat = 0
    @State private var dragLastX: CGFloat?
    
    var body: some View {
        if !attachedMedias.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(attachedMedias) { item in
                        let isDragged = draggedMediaId == item.id
                        AttachedMediaCell(
                            media: item,
                            isDragged: isDragged,
                            dragOffset: isDragged ? dragOffset : 0,
                            onRemove: {
                                attachedMedias.removeAll(where: { $0.id == item.id })
                            }
                        )
                        .equatable()
                        .gesture(
                            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                                .onChanged { val in handleDragChange(val, item: item) } // 【修正】value: を削除しました
                                .onEnded { _ in handleDragEnded() }
                        )
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 8)
        }
    }
    
    private func handleDragChange(_ value: DragGesture.Value, item: PostAttachedMedia) {
        if draggedMediaId != item.id {
            draggedMediaId = item.id
            dragLastX = value.location.x
            dragOffset = 0
        }
        
        guard let lastX = dragLastX else { return }
        dragOffset += value.location.x - lastX
        dragLastX = value.location.x
        
        if let idx = attachedMedias.firstIndex(where: { $0.id == item.id }) {
            let jumpDistance: CGFloat = 88
            let threshold = jumpDistance * 0.5
            
            if dragOffset > threshold && idx < attachedMedias.count - 1 {
                withAnimation(.easeInOut(duration: 0.2)) {
                    attachedMedias.swapAt(idx, idx + 1)
                    dragOffset -= jumpDistance
                }
            } else if dragOffset < -threshold && idx > 0 {
                withAnimation(.easeInOut(duration: 0.2)) {
                    attachedMedias.swapAt(idx, idx - 1)
                    dragOffset += jumpDistance
                }
            }
        }
    }
    
    private func handleDragEnded() {
        withAnimation(.easeInOut(duration: 0.2)) {
            draggedMediaId = nil
            dragOffset = 0
            dragLastX = nil
        }
    }
}

struct ImageTransferable: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            let fileName = received.file.lastPathComponent
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: copy)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return ImageTransferable(url: copy)
        }
    }
}

struct MovieTransferable: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let fileName = received.file.lastPathComponent
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: copy)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return MovieTransferable(url: copy)
        }
    }
}

struct PostView: View {
    @Binding var inputText: String
    @Binding var isPresented: Bool
    
    var initialDate: Date = Date()
    var isExcludedInitial: Bool = false
    var initialMedias: [AttachedMediaItem]? = nil
    var initialFiles: [AttachedFile]? = nil
    
    var onPost: (Bool, Date, Bool, UUID?, [AttachedMediaItem]?, [AttachedFile]?) -> Void
    var transactions: [Transaction]
    var accounts: [Account]
    
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_income") var themeIncome: String = "#FF19B219"
    @AppStorage("theme_expense") var themeExpense: String = "#FFFF3B30"
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_barText") var themeBarText: String = "#FF000000"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    @AppStorage("user_profiles_v1") var profiles: [UserProfile] = []
    
    @ObservedObject var lockManager = LockManager.shared
    
    @State private var postDate = Date()
    @State private var isShowingDatePicker = false
    @State private var isPickingTime = false
    @State private var suggestions: [String] = []
    @State private var isExcluded = false
    
    @State private var selectedProfileId: UUID?
    
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var isShowingFileImporter = false
    
    @State private var attachedMedias: [PostAttachedMedia] = []
    @State private var attachedFiles: [AttachedFile] = []
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                Color(hex: themeBG).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    HStack(alignment: .top) {
                        Menu {
                            ForEach(profiles.filter { !($0.isPrivate ?? false) || lockManager.isUnlocked }.filter { !($0.isDeleted ?? false) }) { profile in
                                Button(action: { selectedProfileId = profile.id }) {
                                    Text(profile.name)
                                }
                            }
                        } label: {
                            let currentProfile = profiles.first(where: { $0.id == selectedProfileId }) ?? profiles.first
                            if let iconData = currentProfile?.iconData, let uiImage = UIImage(data: iconData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(Color(hex: themeSubText))
                            }
                        }
                        
                        ZStack(alignment: .topLeading) {
                            CustomTextEditor(text: $inputText) { sym in
                                insertAtCursor(sym)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    updateSuggestionsForCursor()
                                }
                            }
                            .foregroundColor(Color(hex: themeBarText))
                            .onChange(of: inputText) { _ in
                                updateSuggestionsForCursor()
                            }
                            
                            if inputText.isEmpty {
                                Text("どんな買い物をしましたか？")
                                    .foregroundColor(.gray.opacity(0.7))
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                    .padding()
                    .frame(maxHeight: .infinity)
                    
                    AttachedMediasDragView(attachedMedias: $attachedMedias)
                    
                    if !attachedFiles.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(attachedFiles, id: \.id) { file in
                                HStack {
                                    Image(systemName: "doc.fill")
                                        .foregroundColor(.gray)
                                    Text(file.originalFileName)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .foregroundColor(Color(hex: themeBodyText))
                                    Spacer()
                                    Text(file.formattedSize)
                                        .foregroundColor(.gray)
                                    Button(action: {
                                        attachedFiles.removeAll(where: { $0.id == file.id })
                                    }) {
                                        Image(systemName: "xmark")
                                            .foregroundColor(.gray)
                                    }
                                }
                                .font(.caption)
                                .padding(8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                                .padding(.horizontal)
                            }
                        }
                        .padding(.bottom, 8)
                    }
                    
                    HStack {
                        PhotosPicker(selection: $selectedItems, maxSelectionCount: 4, matching: .any(of: [.images, .videos])) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: themeMain))
                                .padding(.trailing, 8)
                        }
                        .onChange(of: selectedItems, perform: { newItems in
                            Task {
                                for item in newItems {
                                    if item.supportedContentTypes.contains(where: { $0.conforms(to: UTType.movie) }) {
                                        if let movie = try? await item.loadTransferable(type: MovieTransferable.self) {
                                            let tempURL = movie.url
                                            let originalName = tempURL.lastPathComponent
                                            DispatchQueue.main.async {
                                                if let savedName = MediaManager.shared.saveMedia(from: tempURL),
                                                   let thumb = generateVideoThumbnail(for: tempURL),
                                                   let thumbData = compressImage(thumb) {
                                                    let duration = getVideoDuration(url: tempURL)
                                                    attachedMedias.append(PostAttachedMedia(id: UUID(), type: .video, localFileName: savedName, originalFileName: originalName, thumbnailData: thumbData, thumbnailImage: thumb, durationText: duration))
                                                }
                                            }
                                        }
                                    } else {
                                        if let imageFile = try? await item.loadTransferable(type: ImageTransferable.self) {
                                            let tempURL = imageFile.url
                                            let originalName = tempURL.lastPathComponent
                                            if let originalData = try? Data(contentsOf: tempURL),
                                               let uiImage = UIImage(data: originalData),
                                               let thumbData = compressImage(uiImage),
                                               let thumbImage = UIImage(data: thumbData) {
                                                
                                                if let savedName = MediaManager.shared.saveData(originalData, extension: tempURL.pathExtension) {
                                                    DispatchQueue.main.async {
                                                        if attachedMedias.count < 4 {
                                                            attachedMedias.append(PostAttachedMedia(id: UUID(), type: .image, localFileName: savedName, originalFileName: originalName, thumbnailData: thumbData, thumbnailImage: thumbImage, durationText: nil))
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                selectedItems.removeAll()
                            }
                        })
                        
                        Button(action: { isShowingFileImporter = true }) {
                            Image(systemName: "doc.badge.plus")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: themeMain))
                                .padding(.trailing, 8)
                        }
                        
                        Button(action: {
                            isPickingTime = false
                            isShowingDatePicker = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar.badge.clock")
                                Text(formatDate(postDate))
                            }
                            .font(.footnote)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(hex: themeMain).opacity(0.1))
                            .foregroundColor(Color(hex: themeMain))
                            .cornerRadius(12)
                        }
                        
                        Spacer()
                        
                        Toggle("残高計算から除外", isOn: $isExcluded).labelsHidden()
                        Text("計算除外")
                            .font(.footnote)
                            .foregroundColor(isExcluded ? Color(hex: themeMain) : .gray)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                
                if !suggestions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(suggestions, id: \.self) { suggestion in
                                Button(action: { applySuggestion(suggestion) }) {
                                    Text(suggestion)
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(Color(hex: themeMain))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(Color(hex: themeBG))
                                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: themeMain).opacity(0.5), lineWidth: 1))
                                        .cornerRadius(20)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .background(Color(hex: themeBG).opacity(0.95))
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: -2)
                    .offset(y: -44)
                    .zIndex(10)
                }
            }
            .navigationBarItems(
                leading: Button("キャンセル") { isPresented = false }
                    .foregroundColor(Color(hex: themeBarText)),
                trailing: HStack(spacing: 12) {
                    let finalMedias = attachedMedias.map { AttachedMediaItem(id: $0.id, type: $0.type, localFileName: $0.localFileName, originalFileName: $0.originalFileName, thumbnailData: $0.thumbnailData, durationText: $0.durationText) }
                    Button(action: {
                        onPost(false, postDate, isExcluded, selectedProfileId, finalMedias, attachedFiles)
                        isPresented = false
                    }) {
                        Text("支出")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .frame(width: 60, height: 34)
                            .background(Color(hex: themeExpense).opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(17)
                    }
                    Button(action: {
                        onPost(true, postDate, isExcluded, selectedProfileId, finalMedias, attachedFiles)
                        isPresented = false
                    }) {
                        Text("収入")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .frame(width: 60, height: 34)
                            .background(Color(hex: themeIncome))
                            .foregroundColor(.white)
                            .cornerRadius(17)
                    }
                }
            )
            .sheet(isPresented: $isShowingDatePicker) {
                NavigationView {
                    ZStack {
                        Color(hex: themeBG).ignoresSafeArea()
                        VStack {
                            DatePicker(
                                "日時を選択",
                                selection: $postDate,
                                displayedComponents: isPickingTime ? .hourAndMinute : .date
                            )
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "ja_JP"))
                            .background(Color.clear)
                        }
                    }
                    .navigationTitle(isPickingTime ? "時刻の指定" : "日付の指定")
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarItems(
                        leading: Button(isPickingTime ? "日付に切り替え" : "時刻に切り替え") {
                            withAnimation { isPickingTime.toggle() }
                        }
                        .foregroundColor(Color(hex: themeMain)),
                        trailing: Button("完了") {
                            isShowingDatePicker = false
                        }
                        .foregroundColor(Color(hex: themeMain))
                    )
                }
                .preferredColorScheme(isDarkMode ? .dark : .light)
                .presentationDetents([.height(350)])
            }
            .fileImporter(isPresented: $isShowingFileImporter, allowedContentTypes: [UTType.data], allowsMultipleSelection: true) { result in
                if case .success(let urls) = result {
                    for url in urls {
                        let isSecured = url.startAccessingSecurityScopedResource()
                        defer { if isSecured { url.stopAccessingSecurityScopedResource() } }
                        if let savedName = MediaManager.shared.saveMedia(from: url) {
                            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
                            let size = attrs?[.size] as? Int64 ?? 0
                            attachedFiles.append(AttachedFile(originalFileName: url.lastPathComponent, localFileName: savedName, fileSize: size))
                        }
                    }
                }
            }
        }
        .onAppear {
            self.postDate = initialDate
            self.isExcluded = isExcludedInitial
            self.selectedProfileId = profiles.filter { !($0.isPrivate ?? false) || lockManager.isUnlocked }.first(where: { $0.isVisible })?.id ?? profiles.first?.id
            
            self.attachedMedias = (initialMedias ?? []).compactMap { item in
                if let data = item.thumbnailData, let img = UIImage(data: data) {
                    return PostAttachedMedia(id: item.id, type: item.type, localFileName: item.localFileName, originalFileName: item.originalFileName ?? "", thumbnailData: data, thumbnailImage: img, durationText: item.durationText)
                }
                return nil
            }
            self.attachedFiles = initialFiles ?? []
        }
    }
    
    func getVideoDuration(url: URL) -> String? {
        let asset = AVAsset(url: url)
        let seconds = CMTimeGetSeconds(asset.duration)
        guard !seconds.isNaN && !seconds.isInfinite else { return nil }
        let min = Int(seconds) / 60
        let sec = Int(seconds) % 60
        return String(format: "%d:%02d", min, sec)
    }
    
    func generateVideoThumbnail(for url: URL) -> UIImage? {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        do {
            let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }
    
    func compressImage(_ image: UIImage) -> Data? {
        let maxSize: CGFloat = 800
        var targetSize = image.size
        if targetSize.width > maxSize || targetSize.height > maxSize {
            let ratio = min(maxSize / targetSize.width, maxSize / targetSize.height)
            targetSize = CGSize(width: targetSize.width * ratio, height: targetSize.height * ratio)
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: targetSize)) }
        return resized.jpegData(compressionQuality: 0.5)
    }
    
    func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年MM月dd日 HH:mm"
        return f.string(from: date)
    }
    
    func updateSuggestionsForCursor() {
        guard let sc = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let win = sc.windows.first,
              let tv = win.findTextView() else { return }
        
        let cursorLoc = tv.selectedRange.location
        let text = tv.text ?? ""
        let prefixText = String(text.prefix(cursorLoc))
        let currentWord = prefixText.components(separatedBy: CharacterSet.whitespacesAndNewlines).last ?? ""
        
        if currentWord == "#" {
            suggestions = Array(Set(transactions.flatMap { $0.tags })).sorted()
        } else if currentWord.hasPrefix("#") {
            suggestions = Array(Set(transactions.flatMap { $0.tags }.filter { $0.hasPrefix(currentWord) && $0 != currentWord })).sorted()
        } else if currentWord == "@" {
            suggestions = accounts.map { "@" + $0.name }.sorted()
        } else if currentWord.hasPrefix("@") {
            suggestions = accounts.map { "@" + $0.name }.filter { $0.hasPrefix(currentWord) && $0 != currentWord }.sorted()
        } else {
            suggestions = []
        }
    }
    
    func applySuggestion(_ suggestion: String) {
        guard let sc = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let win = sc.windows.first,
              let tv = win.findTextView() else { return }
        
        let cursorLoc = tv.selectedRange.location
        let text = tv.text ?? ""
        let prefixText = String(text.prefix(cursorLoc))
        let words = prefixText.components(separatedBy: CharacterSet.whitespacesAndNewlines)
        
        if let lastWord = words.last {
            let rangeStart = cursorLoc - lastWord.count
            let startIdx = text.index(text.startIndex, offsetBy: rangeStart)
            let endIdx = text.index(text.startIndex, offsetBy: cursorLoc)
            
            inputText = text.replacingCharacters(in: startIdx..<endIdx, with: suggestion + " ")
            
            DispatchQueue.main.async {
                tv.selectedRange = NSRange(location: rangeStart + suggestion.count + 1, length: 0)
                suggestions = []
            }
        }
    }
    
    func insertAtCursor(_ sym: String) {
        if let sc = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let win = sc.windows.first,
           let tv = win.findTextView() {
            let sel = tv.selectedRange
            let cur = tv.text ?? ""
            let lastChar: Character? = sel.location > 0 ? cur[cur.index(cur.startIndex, offsetBy: sel.location - 1)] : nil
            let prefix = (lastChar == " " || lastChar == "　" || lastChar == "\n" || lastChar == nil) ? "" : " "
            
            tv.becomeFirstResponder()
            tv.insertText(prefix + sym)
        }
    }
}
