import SwiftUI
import PhotosUI

struct PostAttachedImage: Identifiable, Equatable {
    let id = UUID()
    let data: Data
    let image: UIImage
}

// 【新規】再描画を防ぐための「超軽量化された専用画像セル」
struct AttachedImageCell: View, Equatable {
    let id: UUID
    let image: UIImage
    let isDragged: Bool
    let dragOffset: CGFloat
    let onRemove: () -> Void
    
    // 【重要】ここで「IDとドラッグ状態だけ比較すればOK」と指示することで、
    // 重い画像データ自体の比較処理をスキップさせ、カクつきを完全排除します。
    static func == (lhs: AttachedImageCell, rhs: AttachedImageCell) -> Bool {
        lhs.id == rhs.id && lhs.isDragged == rhs.isDragged && lhs.dragOffset == rhs.dragOffset
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .drawingGroup() // さらにMetal描画を強制して高速化
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white)
                    .background(Circle().fill(Color.black.opacity(0.6)))
            }
            .padding(4)
        }
        .offset(x: isDragged ? dragOffset : 0)
        // ドラッグ中は少し浮かせることで、より直感的に
        .scaleEffect(isDragged ? 1.05 : 1.0)
        .shadow(color: isDragged ? Color.black.opacity(0.15) : Color.clear, radius: 4, y: 2)
        .zIndex(isDragged ? 100 : 0)
    }
}

// 画像のドラッグ専用の独立したView
struct AttachedImagesDragView: View {
    @Binding var attachedImages: [PostAttachedImage]
    
    @State private var draggedImageId: UUID?
    @State private var dragImageOffset: CGFloat = 0
    @State private var dragImageTotalJump: CGFloat = 0
    
    var body: some View {
        if !attachedImages.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(attachedImages) { item in
                        let isDragged = draggedImageId == item.id
                        
                        // 超軽量セルを呼び出し、.equatable() で保護する
                        AttachedImageCell(
                            id: item.id,
                            image: item.image,
                            isDragged: isDragged,
                            dragOffset: isDragged ? dragImageOffset : 0,
                            onRemove: { attachedImages.removeAll(where: { $0.id == item.id }) }
                        )
                        .equatable() // 魔法の修飾子：これで再描画負荷がゼロになります
                        .gesture(
                            DragGesture(coordinateSpace: .global)
                                .onChanged { val in handleImageDragChange(val, item: item) }
                                .onEnded { _ in handleImageDragEnded() }
                        )
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 8)
        }
    }
    
    private func handleImageDragChange(_ value: DragGesture.Value, item: PostAttachedImage) {
        if draggedImageId != item.id {
            draggedImageId = item.id
            dragImageTotalJump = 0
        }
        
        dragImageOffset = value.translation.width - dragImageTotalJump
        
        if let idx = attachedImages.firstIndex(where: { $0.id == item.id }) {
            let jumpDistance: CGFloat = 88 // 画像幅80 + 余白8
            let threshold = jumpDistance * 0.5
            
            // より滑らかで自然なスプリングアニメーションに調整
            if dragImageOffset > threshold && idx < attachedImages.count - 1 {
                withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.7, blendDuration: 0)) {
                    attachedImages.swapAt(idx, idx + 1)
                    dragImageTotalJump += jumpDistance
                    dragImageOffset -= jumpDistance
                }
            } else if dragImageOffset < -threshold && idx > 0 {
                withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.7, blendDuration: 0)) {
                    attachedImages.swapAt(idx, idx - 1)
                    dragImageTotalJump -= jumpDistance
                    dragImageOffset += jumpDistance
                }
            }
        }
    }
    
    private func handleImageDragEnded() {
        withAnimation(.interactiveSpring()) {
            draggedImageId = nil
            dragImageOffset = 0
            dragImageTotalJump = 0
        }
    }
}

struct PostView: View {
    @Binding var inputText: String; @Binding var isPresented: Bool
    var initialDate: Date = Date()
    var isExcludedInitial: Bool = false
    var initialImages: [Data]? = nil
    
    var onPost: (Bool, Date, Bool, UUID?, [Data]?) -> Void
    var transactions: [Transaction]; var accounts: [Account]
    
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_income") var themeIncome: String = "#FF19B219"
    @AppStorage("theme_expense") var themeExpense: String = "#FFFF3B30"
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_barText") var themeBarText: String = "#FF000000"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
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
    @State private var attachedImages: [PostAttachedImage] = []
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                Color(hex: themeBG).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    HStack(alignment: .top) {
                        Menu {
                            ForEach(profiles.filter { !($0.isPrivate ?? false) || lockManager.isUnlocked }.filter { !($0.isDeleted ?? false) }) { profile in
                                Button(action: { selectedProfileId = profile.id }) { Text(profile.name) }
                            }
                        } label: {
                            let currentProfile = profiles.first(where: { $0.id == selectedProfileId }) ?? profiles.first
                            if let iconData = currentProfile?.iconData, let uiImage = UIImage(data: iconData) {
                                Image(uiImage: uiImage).resizable().scaledToFill().frame(width: 40, height: 40).clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill").resizable().frame(width: 40, height: 40).foregroundColor(Color(hex: themeSubText))
                            }
                        }
                        
                        ZStack(alignment: .topLeading) {
                            CustomTextEditor(text: $inputText) { sym in 
                                insertAtCursor(sym)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { updateSuggestionsForCursor() }
                            }
                            .foregroundColor(Color(hex: themeBarText))
                            .onChange(of: inputText) { _ in updateSuggestionsForCursor() }
                            
                            if inputText.isEmpty { 
                                Text("どんな買い物をしましたか？").foregroundColor(.gray.opacity(0.7)).padding(.top, 8).padding(.leading, 5).allowsHitTesting(false) 
                            }
                        }
                    }
                    .padding()
                    .frame(maxHeight: .infinity)
                    
                    AttachedImagesDragView(attachedImages: $attachedImages)
                    
                    HStack {
                        PhotosPicker(selection: $selectedItems, maxSelectionCount: 4, matching: .images) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: themeMain))
                                .padding(.trailing, 8)
                        }
                        .onChange(of: selectedItems) { newItems in
                            Task {
                                for item in newItems {
                                    if let data = try? await item.loadTransferable(type: Data.self),
                                       let uiImage = UIImage(data: data),
                                       let compressed = compressImage(uiImage),
                                       let compressedImage = UIImage(data: compressed) {
                                        DispatchQueue.main.async {
                                            if attachedImages.count < 4 {
                                                attachedImages.append(PostAttachedImage(data: compressed, image: compressedImage))
                                            }
                                        }
                                    }
                                }
                                selectedItems.removeAll()
                            }
                        }
                        
                        Button(action: { isPickingTime = false; isShowingDatePicker = true }) {
                            HStack(spacing: 4) { Image(systemName: "calendar.badge.clock"); Text(formatDate(postDate)) }
                            .font(.footnote).padding(.horizontal, 12).padding(.vertical, 6).background(Color(hex: themeMain).opacity(0.1)).foregroundColor(Color(hex: themeMain)).cornerRadius(12)
                        }
                        Spacer()
                        Toggle("残高計算から除外", isOn: $isExcluded).labelsHidden()
                        Text("計算除外").font(.footnote).foregroundColor(isExcluded ? Color(hex: themeMain) : .gray)
                    }.padding(.horizontal).padding(.vertical, 8)
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
                leading: Button("キャンセル") { isPresented = false }.foregroundColor(Color(hex: themeBarText)), 
                trailing: HStack(spacing: 12) {
                    let imageDatas = attachedImages.map { $0.data }
                    Button(action: { onPost(false, postDate, isExcluded, selectedProfileId, imageDatas); isPresented = false }) { Text("支出").font(.subheadline).fontWeight(.bold).frame(width: 60, height: 34).background(Color(hex: themeExpense).opacity(0.8)).foregroundColor(.white).cornerRadius(17) }
                    Button(action: { onPost(true, postDate, isExcluded, selectedProfileId, imageDatas); isPresented = false }) { Text("収入").font(.subheadline).fontWeight(.bold).frame(width: 60, height: 34).background(Color(hex: themeIncome)).foregroundColor(.white).cornerRadius(17) }
                }
            )
            .sheet(isPresented: $isShowingDatePicker) {
                NavigationView {
                    ZStack { Color(hex: themeBG).ignoresSafeArea(); VStack { DatePicker("日時を選択", selection: $postDate, displayedComponents: isPickingTime ? .hourAndMinute : .date).datePickerStyle(.wheel).labelsHidden().environment(\.locale, Locale(identifier: "ja_JP")).background(Color.clear) } }
                    .navigationTitle(isPickingTime ? "時刻の指定" : "日付の指定").navigationBarTitleDisplayMode(.inline)
                    .navigationBarItems(leading: Button(isPickingTime ? "日付に切り替え" : "時刻に切り替え") { withAnimation { isPickingTime.toggle() } }.foregroundColor(Color(hex: themeMain)), trailing: Button("完了") { isShowingDatePicker = false }.foregroundColor(Color(hex: themeMain)))
                }.preferredColorScheme(isDarkMode ? .dark : .light).presentationDetents([.height(350)])
            }
        }.onAppear { 
            self.postDate = initialDate
            self.isExcluded = isExcludedInitial
            self.selectedProfileId = profiles.filter { !($0.isPrivate ?? false) || lockManager.isUnlocked }.first(where: { $0.isVisible })?.id ?? profiles.first?.id
            self.attachedImages = (initialImages ?? []).compactMap { data in
                if let img = UIImage(data: data) { return PostAttachedImage(data: data, image: img) }
                return nil
            }
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
    
    func formatDate(_ date: Date) -> String { let f = DateFormatter(); f.locale = Locale(identifier: "ja_JP"); f.dateFormat = "yyyy年MM月dd日 HH:mm"; return f.string(from: date) }
    func updateSuggestionsForCursor() { guard let sc = UIApplication.shared.connectedScenes.first as? UIWindowScene, let win = sc.windows.first, let tv = win.findTextView() else { return }; let cursorLoc = tv.selectedRange.location; let text = tv.text ?? ""; let prefixText = String(text.prefix(cursorLoc)); let currentWord = prefixText.components(separatedBy: CharacterSet.whitespacesAndNewlines).last ?? ""; if currentWord == "#" { suggestions = Array(Set(transactions.flatMap { $0.tags })).sorted() } else if currentWord.hasPrefix("#") { suggestions = Array(Set(transactions.flatMap { $0.tags }.filter { $0.hasPrefix(currentWord) && $0 != currentWord })).sorted() } else if currentWord == "@" { suggestions = accounts.map { "@" + $0.name }.sorted() } else if currentWord.hasPrefix("@") { suggestions = accounts.map { "@" + $0.name }.filter { $0.hasPrefix(currentWord) && $0 != currentWord }.sorted() } else { suggestions = [] } }
    func applySuggestion(_ suggestion: String) { guard let sc = UIApplication.shared.connectedScenes.first as? UIWindowScene, let win = sc.windows.first, let tv = win.findTextView() else { return }; let cursorLoc = tv.selectedRange.location; let text = tv.text ?? ""; let prefixText = String(text.prefix(cursorLoc)); let words = prefixText.components(separatedBy: CharacterSet.whitespacesAndNewlines); if let lastWord = words.last { let rangeStart = cursorLoc - lastWord.count; let startIdx = text.index(text.startIndex, offsetBy: rangeStart); let endIdx = text.index(text.startIndex, offsetBy: cursorLoc); inputText = text.replacingCharacters(in: startIdx..<endIdx, with: suggestion + " "); DispatchQueue.main.async { tv.selectedRange = NSRange(location: rangeStart + suggestion.count + 1, length: 0); suggestions = [] } } }
    func insertAtCursor(_ sym: String) { if let sc = UIApplication.shared.connectedScenes.first as? UIWindowScene, let win = sc.windows.first, let tv = win.findTextView() { let sel = tv.selectedRange; let cur = tv.text ?? ""; let lastChar: Character? = sel.location > 0 ? cur[cur.index(cur.startIndex, offsetBy: sel.location - 1)] : nil; let prefix = (lastChar == " " || lastChar == "　" || lastChar == "\n" || lastChar == nil) ? "" : " "; tv.becomeFirstResponder(); tv.insertText(prefix + sym) } }
}
