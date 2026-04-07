import SwiftUI

struct TransactionDetailView: View {
    let item: Transaction
    @Binding var transactions: [Transaction]
    @Binding var accounts: [Account]
    
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_barBG") var themeBarBG: String = "#F8F8F8FF"
    @AppStorage("theme_barText") var themeBarText: String = "#FF000000"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    @AppStorage("user_profiles_v1") var profiles: [UserProfile] = []
    
    @Environment(\.dismiss) var dismiss
    @State private var isShowingEditSheet = false
    @State private var editLineText = ""
    @State private var isShowingDeleteConfirm = false
    
    var currentItem: Transaction {
        transactions.first(where: { $0.id == item.id }) ?? item
    }
    
    var body: some View {
        let profile = profiles.first(where: { $0.id == currentItem.profileId }) ?? profiles.first ?? UserProfile(name: "不明", userId: "unknown")
        let isPrivate = profile.isPrivate ?? false
        let isDeleted = profile.isDeleted ?? false
        let isLocked = !LockManager.shared.isUnlocked
        let hideContent = isPrivate && isLocked && LockManager.shared.privatePostDisplayMode == 1
        
        let displayName = isDeleted ? "削除されたユーザー" : profile.name
        let displayId = isDeleted ? "deleted_user" : profile.userId
        
        return ZStack {
            Color(hex: themeBG).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 12) {
                        if !isDeleted, let iconData = profile.iconData, let uiImage = UIImage(data: iconData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 56, height: 56)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 56, height: 56)
                                .foregroundColor(Color(hex: themeSubText))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(displayName).font(.headline).fontWeight(.bold).foregroundColor(Color(hex: themeBodyText))
                            Text("@\(displayId)").font(.subheadline).foregroundColor(Color(hex: themeSubText))
                        }
                        Spacer()
                        
                        if hideContent {
                            Text("---")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(hex: themeSubText).opacity(0.1))
                                .cornerRadius(5)
                                .foregroundColor(Color(hex: themeBodyText))
                        } else {
                            Text(currentItem.source)
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(hex: themeSubText).opacity(0.1))
                                .cornerRadius(5)
                                .foregroundColor(Color(hex: themeBodyText))
                        }
                    }
                    
                    if hideContent {
                        Text("鍵アカウントによる投稿です").font(.title3).foregroundColor(Color(hex: themeSubText))
                    } else {
                        HighlightedText(text: currentItem.cleanNote, isIncome: currentItem.isIncome)
                            .font(.title3)
                            .foregroundColor(Color(hex: themeBodyText))
                        
                        if !currentItem.tags.isEmpty {
                            HStack(spacing: 12) {
                                ForEach(currentItem.tags, id: \.self) { tag in
                                    Button(action: {
                                        NotificationCenter.default.post(name: NSNotification.Name("SearchTag"), object: tag)
                                    }) {
                                        Text(tag)
                                            .font(.subheadline)
                                            .foregroundColor(Color(hex: themeMain))
                                    }
                                }
                            }
                        }
                        
                        let displayMedias = currentItem.displayMediaItems
                        if !displayMedias.isEmpty {
                            TimelineMediaGrid(mediaItems: displayMedias, maxHeight: 260)
                                .padding(.vertical, 8)
                        }
                        
                        if let files = currentItem.attachedFiles, !files.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(files, id: \.id) { file in
                                    AttachedFileRowView(file: file, themeBodyText: themeBodyText, font: .subheadline, padding: 12)
                                }
                            }.padding(.vertical, 8)
                        }
                    }
                    
                    if currentItem.isExcludedFromBalance == true {
                        Label("この投稿は残高計算から除外されています", systemImage: "calculator.badge.minus")
                            .font(.caption)
                            .foregroundColor(Color(hex: themeSubText))
                    }

                    Text(currentItem.date, style: .date) + Text(" " ) + Text(currentItem.date, style: .time)
                    Divider().background(Color(hex: themeSubText).opacity(0.2))
                    HStack(spacing: 60) {
                        Image(systemName: "bubble.left")
                        Image(systemName: "arrow.2.squarepath")
                        Image(systemName: "heart")
                        Image(systemName: "shareplay")
                    }
                    .font(.subheadline)
                    .foregroundColor(Color(hex: themeSubText))
                    .frame(maxWidth: .infinity)
                }.padding().foregroundColor(Color(hex: themeSubText))
            }
        }
        .navigationTitle("投稿")
        .toolbarBackground(Color(hex: themeBarBG), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button(action: {
                        editLineText = currentItem.note
                        isShowingEditSheet = true
                    }) {
                        Image(systemName: "pencil.line")
                    }
                    Button(action: { isShowingDeleteConfirm = true }) {
                        Image(systemName: "trash")
                    }.foregroundColor(.red)
                }.foregroundColor(Color(hex: themeMain))
            }
        }
        .confirmationDialog("投稿を削除しますか？", isPresented: $isShowingDeleteConfirm, titleVisibility: .visible) {
            Button("削除", role: .destructive) {
                if let idx = transactions.firstIndex(where: { $0.id == item.id }) {
                    transactions.remove(at: idx)
                    dismiss()
                }
            }
            Button("キャンセル", role: .cancel) { }
        }
        .sheet(isPresented: $isShowingEditSheet) {
            PostView(
                inputText: $editLineText,
                isPresented: $isShowingEditSheet,
                initialDate: currentItem.date,
                isExcludedInitial: currentItem.isExcludedFromBalance ?? false,
                initialMedias: currentItem.displayMediaItems,
                initialFiles: currentItem.attachedFiles,
                onPost: handleEditTransaction,
                transactions: transactions,
                accounts: accounts
            )
        }
    }
    
    func handleEditTransaction(isInc: Bool, nDate: Date, isExc: Bool, profileId: UUID?, medias: [AttachedMediaItem]?, files: [AttachedFile]?) {
        if let idx = transactions.firstIndex(where: { $0.id == item.id }) {
            let nAmt = editLineText.components(separatedBy: .whitespacesAndNewlines)
                .filter { $0.contains("¥") }
                .reduce(0) { $0 + (Int($1.replacingOccurrences(of: "¥", with: "").replacingOccurrences(of: ",", with: "")) ?? 0) }
            
            var nSrc = currentItem.source
            for acc in accounts {
                if editLineText.contains("@\(acc.name)") { nSrc = acc.name }
            }
            
            transactions[idx] = Transaction(
                id: item.id, amount: nAmt, date: nDate, note: editLineText,
                source: nSrc, isIncome: isInc, isExcludedFromBalance: isExc,
                profileId: profileId ?? currentItem.profileId,
                attachedMediaItems: medias,
                attachedFiles: files
            )
        }
    }
}
