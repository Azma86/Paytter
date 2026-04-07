import SwiftUI
import PhotosUI

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
        
        ZStack {
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
        .alert("投稿を削除しますか？", isPresented: $isShowingDeleteConfirm) {
            Button("キャンセル", role: .cancel) { }
            Button("削除", role: .destructive) {
                if let idx = transactions.firstIndex(where: { $0.id == item.id }) {
                    transactions.remove(at: idx)
                    dismiss()
                }
            }
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
                .reduce(0) { $0 + (Int($1.replacingOccurrences(of: "¥", with: "")) ?? 0) }
            
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

struct UserProfileEditSection: View {
    @Binding var profile: UserProfile
    let themeMain: String
    let themeBodyText: String
    let themeSubText: String
    let themeBG: String
    
    let onDeleteRequest: () -> Void
    @State private var selectedItem: PhotosPickerItem? = nil

    var body: some View {
        if profile.isDeleted == true {
            Section(header: Text("削除されたユーザー").foregroundColor(Color(hex: themeSubText))) {
                Text("このユーザーは削除されていますが、過去の投稿は残っています。")
                    .font(.caption)
                    .foregroundColor(Color(hex: themeSubText))
                Button(action: onDeleteRequest) {
                    HStack {
                        Spacer()
                        Text("投稿ごと完全に削除する").foregroundColor(.red)
                        Spacer()
                    }
                }
            }
            .listRowBackground(Color(hex: themeBG).opacity(0.5))
        } else {
            Section(header: Text("ユーザー情報").foregroundColor(Color(hex: themeSubText))) {
                HStack {
                    Spacer()
                    PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                        if let iconData = profile.iconData, let uiImage = UIImage(data: iconData) {
                            Image(uiImage: uiImage).resizable().scaledToFill().frame(width: 80, height: 80).clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill").resizable().frame(width: 80, height: 80).foregroundColor(Color(hex: themeSubText))
                        }
                    }
                    .onChange(of: selectedItem) { newItem in
                        guard let item = newItem else { return }
                        Task {
                            if let data = try? await item.loadTransferable(type: Data.self),
                               let uiImage = UIImage(data: data),
                               let compressedData = uiImage.jpegData(compressionQuality: 0.5) {
                                DispatchQueue.main.async {
                                    profile.iconData = compressedData
                                    selectedItem = nil
                                }
                            } else {
                                DispatchQueue.main.async { selectedItem = nil }
                            }
                        }
                    }
                    Spacer()
                }.padding(.vertical, 8)
                
                HStack {
                    Text("名前").foregroundColor(Color(hex: themeBodyText)).frame(width: 80, alignment: .leading)
                    TextField("ユーザー名", text: $profile.name).foregroundColor(Color(hex: themeBodyText))
                }
                HStack {
                    Text("ID").foregroundColor(Color(hex: themeBodyText)).frame(width: 80, alignment: .leading)
                    Text("@").foregroundColor(Color(hex: themeSubText))
                    TextField("ユーザーID", text: $profile.userId).foregroundColor(Color(hex: themeBodyText)).autocapitalization(.none)
                }
                
                Toggle("タイムラインに表示", isOn: $profile.isVisible).foregroundColor(Color(hex: themeBodyText))
                Toggle("鍵アカウントにする（ロック時非表示）", isOn: Binding(get: { profile.isPrivate ?? false }, set: { profile.isPrivate = $0 })).foregroundColor(Color(hex: themeBodyText))
                
                Button(action: onDeleteRequest) {
                    HStack {
                        Spacer()
                        Text("このユーザーを削除").foregroundColor(.red)
                        Spacer()
                    }
                }
            }
            .listRowBackground(Color(hex: themeBG).opacity(0.5))
        }
    }
}

struct UserProfileSettingView: View {
    @Binding var transactions: [Transaction]
    @AppStorage("user_profiles_v1") var profiles: [UserProfile] = []
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    
    @State private var profileToDelete: UserProfile?
    @State private var isShowingDeleteActionSheet = false
    
    var body: some View {
        ZStack {
            Color(hex: themeBG).ignoresSafeArea()
            List {
                ForEach($profiles) { $profile in
                    UserProfileEditSection(
                        profile: $profile,
                        themeMain: themeMain,
                        themeBodyText: themeBodyText,
                        themeSubText: themeSubText,
                        themeBG: themeBG,
                        onDeleteRequest: {
                            profileToDelete = profile
                            isShowingDeleteActionSheet = true
                        }
                    )
                }
                
                Button(action: {
                    profiles.append(UserProfile(name: "新規ユーザー", userId: "new_user"))
                }) {
                    Label("ユーザーを追加", systemImage: "person.badge.plus").foregroundColor(Color(hex: themeMain))
                }
                .listRowBackground(Color(hex: themeBG).opacity(0.5))
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
        }
        .navigationTitle("表示ユーザー設定")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .onAppear {
            if profiles.isEmpty { profiles.append(UserProfile(name: "むつき", userId: "Mutsuki_dev")) }
        }
        .actionSheet(isPresented: $isShowingDeleteActionSheet) {
            ActionSheet(
                title: Text("ユーザーの削除"),
                message: Text("ユーザーを削除します。過去の投稿はどうしますか？"),
                buttons: [
                    .destructive(Text("投稿もすべて削除する")) {
                        if let p = profileToDelete {
                            transactions.removeAll(where: { $0.profileId == p.id })
                            profiles.removeAll(where: { $0.id == p.id })
                            ensureAtLeastOneProfile()
                        }
                    },
                    .default(Text("投稿は残してユーザーのみ削除")) {
                        if let p = profileToDelete {
                            if let idx = profiles.firstIndex(where: { $0.id == p.id }) {
                                profiles[idx].isDeleted = true
                            }
                            ensureAtLeastOneProfile()
                        }
                    },
                    .cancel(Text("キャンセル")) {
                        profileToDelete = nil
                    }
                ]
            )
        }
    }
    
    func ensureAtLeastOneProfile() {
        if profiles.filter({ !($0.isDeleted ?? false) }).isEmpty {
            profiles.append(UserProfile(name: "新規ユーザー", userId: "new_user"))
        }
        profileToDelete = nil
    }
}

struct PasscodeSettingView: View {
    @ObservedObject var lockManager = LockManager.shared
    @State private var newPasscode = ""
    @State private var selectedType = 0
    @State private var useBiometrics = false
    
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color(hex: themeBG).ignoresSafeArea()
            Form {
                if lockManager.passcode.isEmpty {
                    Section(header: Text("新しいパスコード").foregroundColor(Color(hex: themeSubText))) {
                        Picker("形式", selection: $selectedType) {
                            Text("4桁の数字").tag(0)
                            Text("6桁の数字").tag(1)
                            Text("自由入力").tag(2)
                        }.pickerStyle(.segmented)
                        
                        SecureField("パスコードを入力", text: $newPasscode)
                            .keyboardType(selectedType == 2 ? .default : .numberPad)
                            .foregroundColor(Color(hex: themeBodyText))
                        
                        Toggle("生体認証(TouchID/FaceID)を使用", isOn: $useBiometrics)
                            .foregroundColor(Color(hex: themeBodyText))
                        
                        Button("設定する") {
                            if validate() {
                                lockManager.passcodeType = selectedType
                                lockManager.useBiometrics = useBiometrics
                                lockManager.passcode = newPasscode
                                lockManager.isUnlocked = true
                                dismiss()
                            }
                        }
                        .foregroundColor(Color(hex: themeMain))
                        .disabled(!validate())
                    }
                    .listRowBackground(Color(hex: themeBG).opacity(0.5))
                } else {
                    Section(header: Text("パスコード設定").foregroundColor(Color(hex: themeSubText))) {
                        Text("パスコードは設定済みです").foregroundColor(Color(hex: themeBodyText))
                        Button("パスコードをオフにする", role: .destructive) {
                            lockManager.passcode = ""
                            lockManager.isUnlocked = true
                        }
                    }
                    .listRowBackground(Color(hex: themeBG).opacity(0.5))
                    
                    Section(header: Text("ロックの動作").foregroundColor(Color(hex: themeSubText))) {
                        Picker("ロック時の制限", selection: $lockManager.lockBehavior) {
                            Text("全画面をロック").tag(0)
                            Text("鍵アカウントのみ非表示").tag(1)
                        }.pickerStyle(.menu)
                        
                        Picker("鍵投稿の非表示方法", selection: $lockManager.privatePostDisplayMode) {
                            Text("完全に非表示").tag(0)
                            Text("内容のみ隠す").tag(1)
                        }.pickerStyle(.menu)
                        
                        Toggle("ロック時も鍵投稿を残額に反映", isOn: $lockManager.reflectPrivateBalanceWhenLocked)
                            .foregroundColor(Color(hex: themeBodyText))
                    }
                    .listRowBackground(Color(hex: themeBG).opacity(0.5))
                }
            }.scrollContentBackground(.hidden)
        }
        .navigationTitle("パスコードロック")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    func validate() -> Bool {
        if selectedType == 0 && newPasscode.count != 4 { return false }
        if selectedType == 1 && newPasscode.count != 6 { return false }
        if newPasscode.isEmpty { return false }
        return true
    }
}

struct PasscodeLockOverlay: View {
    @ObservedObject var lockManager = LockManager.shared
    @State private var inputCode = ""
    @State private var isError = false
    
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    
    var body: some View {
        ZStack {
            Color(hex: themeBG).ignoresSafeArea()
            VStack(spacing: 30) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Color(hex: themeMain))
                
                Text("パスコードを入力")
                    .font(.title2).bold()
                    .foregroundColor(Color(hex: themeBodyText))
                
                SecureField("パスコード", text: $inputCode)
                    .keyboardType(lockManager.passcodeType == 2 ? .default : .numberPad)
                    .multilineTextAlignment(.center)
                    .font(.title)
                    .foregroundColor(Color(hex: themeBodyText))
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal, 40)
                    .onChange(of: inputCode) { newValue in
                        isError = false
                        if lockManager.passcodeType == 0 && newValue.count == 4 { submit() }
                        else if lockManager.passcodeType == 1 && newValue.count == 6 { submit() }
                    }
                
                if isError {
                    Text("パスコードが違います").foregroundColor(.red).font(.footnote)
                }
                
                if lockManager.passcodeType == 2 {
                    Button("解除") { submit() }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(hex: themeMain))
                }
                
                if lockManager.useBiometrics {
                    Button(action: { lockManager.authenticateWithBiometrics() }) {
                        Image(systemName: "faceid")
                            .font(.largeTitle)
                            .foregroundColor(Color(hex: themeMain))
                    }
                    .padding(.top, 20)
                }
                
                Spacer()
                
                if lockManager.lockBehavior == 1 {
                    Button("キャンセルして鍵アカウントを非表示") {
                        lockManager.cancelUnlock()
                    }
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .padding(.bottom, 30)
                }
            }.padding(.top, 80)
        }
        .onAppear {
            if lockManager.useBiometrics {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    lockManager.authenticateWithBiometrics()
                }
            }
        }
    }
    
    func submit() {
        if !lockManager.unlock(with: inputCode) {
            isError = true
            inputCode = ""
        }
    }
}

struct AccountCreateView: View {
    @Binding var accounts: [Account]
    @Binding var transactions: [Transaction]
    @Environment(\.dismiss) var dismiss
    
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    
    @State private var name = ""
    @State private var initial = ""
    @State private var selectedType: AccountType = .wallet
    @State private var isVisible = true
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: themeBG).ignoresSafeArea()
                Form {
                    Section(header: Text("基本情報").foregroundColor(Color(hex: themeSubText))) {
                        TextField("お財布の名前", text: $name).foregroundColor(Color(hex: themeBodyText))
                        Picker(selection: $selectedType) {
                            ForEach(AccountType.allCases, id: \.self) { type in
                                Label(type.rawValue, systemImage: type.icon).tag(type)
                            }
                        } label: { Text("種類").foregroundColor(Color(hex: themeBodyText)) }
                        TextField("現在の金額", text: $initial).keyboardType(.numbersAndPunctuation).foregroundColor(Color(hex: themeBodyText))
                        Toggle("ホーム上部に表示", isOn: $isVisible).foregroundColor(Color(hex: themeBodyText))
                    }
                    .listRowBackground(Color(hex: themeBG).opacity(0.5))
                }.scrollContentBackground(.hidden)
            }
            .navigationTitle("新しいお財布")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("キャンセル") { dismiss() }.foregroundColor(Color(hex: themeMain)),
                trailing: Button("追加") {
                    let val = Int(initial) ?? 0
                    let newAcc = Account(name: name, balance: val, type: selectedType, isVisible: isVisible)
                    accounts.append(newAcc)
                    if val != 0 {
                        transactions.append(Transaction(amount: val, date: Date(), note: "お財布登録 @\(name) ¥\(val)", source: name, isIncome: true))
                    }
                    dismiss()
                }.disabled(name.isEmpty).foregroundColor(Color(hex: themeMain)).fontWeight(.bold)
            )
            .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }
}

struct AccountEditView: View {
    @Binding var account: Account
    @Binding var transactions: [Transaction]
    var allAccounts: [Account]
    
    @AppStorage("account_groups") var groups: [AccountGroup] = []
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    
    @State private var editBalance: String = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color(hex: themeBG).ignoresSafeArea()
            Form {
                Section(header: Text("基本設定").foregroundColor(Color(hex: themeSubText))) {
                    TextField("名前", text: $account.name).foregroundColor(Color(hex: themeBodyText))
                    Picker(selection: $account.type) {
                        ForEach(AccountType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon).tag(type)
                        }
                    } label: { Text("種類") }
                    Toggle("ホーム上部に表示", isOn: $account.isVisible).foregroundColor(Color(hex: themeBodyText))
                }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                
                Section(header: Text("残高の調整").foregroundColor(Color(hex: themeSubText))) {
                    HStack {
                        TextField("新しい残高を入力", text: $editBalance)
                            .keyboardType(.numbersAndPunctuation)
                            .foregroundColor(Color(hex: themeBodyText))
                        Button("調整投稿") {
                            if let newVal = Int(editBalance) {
                                let diff = newVal - account.balance
                                if diff != 0 {
                                    transactions.append(Transaction(amount: abs(diff), date: Date(), note: "残額調整 @\(account.name) ¥\(abs(diff))", source: account.name, isIncome: diff > 0))
                                }
                                editBalance = ""
                                NotificationCenter.default.post(name: NSNotification.Name("SwitchToHomeTab"), object: nil)
                                dismiss()
                            }
                        }.buttonStyle(.borderedProminent).tint(Color(hex: themeMain))
                    }
                }.listRowBackground(Color(hex: themeBG).opacity(0.5))

                Section(header: Text("所属グループ").foregroundColor(Color(hex: themeSubText))) {
                    let belongedGroups = groups.filter { $0.accountIds.contains(account.id) }
                    if belongedGroups.isEmpty {
                        Text("未設定").foregroundColor(Color(hex: themeSubText)).font(.subheadline)
                    } else {
                        ForEach(belongedGroups) { group in
                            HStack {
                                Image(systemName: "folder").foregroundColor(Color(hex: themeMain))
                                Text(group.name).foregroundColor(Color(hex: themeBodyText))
                            }
                        }
                    }
                }.listRowBackground(Color(hex: themeBG).opacity(0.5))
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(account.name)
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}

struct TotalAssetEditView: View {
    @Binding var isVisible: Bool
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    
    var body: some View {
        ZStack {
            Color(hex: themeBG).ignoresSafeArea()
            Form {
                Section(header: Text("グループ設定").foregroundColor(Color(hex: themeSubText))) {
                    Toggle("ホーム上部に表示", isOn: $isVisible)
                }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                Section(footer: Text("「総資産」グループは自動的にすべてのお財布を合算します。").foregroundColor(Color(hex: themeSubText))) {
                    EmptyView()
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("総資産")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}

struct AccountGroupEditView: View {
    @Binding var group: AccountGroup
    @Binding var accounts: [Account]
    
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color(hex: themeBG).ignoresSafeArea()
            Form {
                Section(header: Text("グループ設定").foregroundColor(Color(hex: themeSubText))) {
                    TextField("グループ名", text: $group.name).foregroundColor(Color(hex: themeBodyText))
                    Toggle("ホーム上部に表示", isOn: $group.isVisible).foregroundColor(Color(hex: themeBodyText))
                }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                
                Section(header: Text("対象のお財布を選択").foregroundColor(Color(hex: themeSubText))) {
                    ForEach(accounts) { acc in
                        Button(action: {
                            if group.accountIds.contains(acc.id) {
                                group.accountIds.removeAll(where: { $0 == acc.id })
                            } else {
                                group.accountIds.append(acc.id)
                            }
                        }) {
                            HStack {
                                Image(systemName: acc.type.icon).foregroundColor(Color(hex: themeBodyText).opacity(0.6))
                                Text(acc.name).foregroundColor(Color(hex: themeBodyText))
                                Spacer()
                                if group.accountIds.contains(acc.id) {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(Color(hex: themeMain))
                                } else {
                                    Image(systemName: "circle").foregroundColor(Color(hex: themeSubText))
                                }
                            }
                        }
                    }
                }.listRowBackground(Color(hex: themeBG).opacity(0.5))
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}

struct AccountGroupCreateView: View {
    @Binding var groups: [AccountGroup]
    @Binding var accounts: [Account]
    @Environment(\.dismiss) var dismiss
    
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    
    @State private var name = ""
    @State private var isVisible = true
    @State private var selectedAccountIds: [UUID] = []
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: themeBG).ignoresSafeArea()
                Form {
                    Section(header: Text("基本情報").foregroundColor(Color(hex: themeSubText))) {
                        TextField("グループ名（例：銀行まとめなど）", text: $name).foregroundColor(Color(hex: themeBodyText))
                        Toggle("ホーム上部に表示", isOn: $isVisible)
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    
                    Section(header: Text("お財布を紐付ける").foregroundColor(Color(hex: themeSubText))) {
                        ForEach(accounts) { acc in
                            Button(action: {
                                if selectedAccountIds.contains(acc.id) {
                                    selectedAccountIds.removeAll(where: { $0 == acc.id })
                                } else {
                                    selectedAccountIds.append(acc.id)
                                }
                            }) {
                                 HStack {
                                    Image(systemName: acc.type.icon).foregroundColor(Color(hex: themeBodyText).opacity(0.6))
                                    Text(acc.name).foregroundColor(Color(hex: themeBodyText))
                                    Spacer()
                                    if selectedAccountIds.contains(acc.id) {
                                        Image(systemName: "checkmark.circle.fill").foregroundColor(Color(hex: themeMain))
                                    } else {
                                        Image(systemName: "circle").foregroundColor(Color(hex: themeSubText))
                                    }
                                }
                            }
                        }
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("新しいグループ")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("キャンセル") { dismiss() }.foregroundColor(Color(hex: themeMain)),
                trailing: Button("追加") {
                    let newGroup = AccountGroup(name: name, isVisible: isVisible, accountIds: selectedAccountIds)
                    groups.append(newGroup)
                    dismiss()
                }.disabled(name.isEmpty).foregroundColor(Color(hex: themeMain)).fontWeight(.bold)
            )
            .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }
}

// 【変更】締め日を考慮した「今期のサマリー」に変更
struct WalletAnalysisView: View {
    let transactions: [Transaction]
    @AppStorage("monthlyBudget") var monthlyBudget: Int = 50000
    @AppStorage("closingDay") var closingDay: Int = 0 // 締め日
    
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_expense") var themeExpense: String = "#FFFF3B30"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("user_profiles_v1") var profiles: [UserProfile] = []
    @ObservedObject var lockManager = LockManager.shared
    
    var validTransactions: [Transaction] {
        if lockManager.isUnlocked || lockManager.reflectPrivateBalanceWhenLocked {
            return transactions
        } else {
            return transactions.filter { tx in
                let profile = profiles.first(where: { $0.id == tx.profileId }) ?? profiles.first
                return !(profile?.isPrivate ?? false)
            }
        }
    }
    
    // 【新規】現在の締め日に基づく期間（開始日・終了日）を計算
    var currentPeriodRange: (start: Date, end: Date) {
        let cal = Calendar.current
        let now = Date()
        let currentDay = cal.component(.day, from: now)
        
        if closingDay == 0 { // 月末締め
            let comps = cal.dateComponents([.year, .month], from: now)
            let start = cal.date(from: comps)!
            let end = cal.date(byAdding: DateComponents(month: 1, day: -1), to: start)!
            return (start, cal.date(bySettingHour: 23, minute: 59, second: 59, of: end)!)
        } else { // 指定日締め
            var startComps = cal.dateComponents([.year, .month], from: now)
            if currentDay <= closingDay { startComps.month! -= 1 }
            startComps.day = closingDay + 1
            let start = cal.date(from: startComps)!
            
            let endMonth = cal.date(byAdding: .month, value: 1, to: start)!
            let end = cal.date(byAdding: .day, value: -1, to: endMonth)!
            return (start, cal.date(bySettingHour: 23, minute: 59, second: 59, of: end)!)
        }
    }
    
    var monthlyTotal: Int {
        let range = currentPeriodRange
        return validTransactions.filter { !$0.isIncome && $0.date >= range.start && $0.date <= range.end }.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        ZStack {
            Color(hex: themeBG).ignoresSafeArea()
            List {
                let df = DateFormatter()
                df.dateFormat = "M/d"
                let rangeText = "\(df.string(from: currentPeriodRange.start)) 〜 \(df.string(from: currentPeriodRange.end))"
                
                Section(header: Text("今期のサマリー (\(rangeText))").foregroundColor(Color(hex: themeSubText))) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("合計支出").font(.caption).foregroundColor(Color(hex: themeSubText))
                        Text("¥\(monthlyTotal)").font(.system(.title, design: .rounded).bold()).foregroundColor(Color(hex: themeBodyText))
                        
                        ProgressView(value: min(Double(monthlyTotal), Double(monthlyBudget)), total: Double(monthlyBudget))
                            .accentColor(monthlyTotal > Int(Double(monthlyBudget) * 0.9) ? Color(hex: themeExpense) : Color(hex: themeMain))
                        
                        Text("予算 ¥\(monthlyBudget) まであと ¥\(max(0, monthlyBudget - monthlyTotal))")
                            .font(.caption2).foregroundColor(Color(hex: themeSubText))
                    }.padding(.vertical, 10)
                }
                .listRowBackground(Color(hex: themeBG).opacity(0.5))
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("分析")
    }
}

struct RecurringPaymentCreateView: View {
    @Binding var recurringPayments: [RecurringPayment]
    let accounts: [Account]
    let profiles: [UserProfile]
    @Environment(\.dismiss) var dismiss
    
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    
    @State private var name = ""
    @State private var amountStr = ""
    @State private var startDate = Date()
    @State private var hasEndDate = false
    @State private var endDate = Date()
    @State private var paymentDay = 1
    @State private var selectedProfileId: UUID?
    @State private var selectedSourceName = ""
    @State private var fractionType = 0
    @State private var fractionAmountStr = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: themeBG).ignoresSafeArea()
                Form {
                    Section(header: Text("基本情報").foregroundColor(Color(hex: themeSubText))) {
                        TextField("名前（例：Apple Music）", text: $name).foregroundColor(Color(hex: themeBodyText))
                        TextField("毎月の金額", text: $amountStr).keyboardType(.numberPad).foregroundColor(Color(hex: themeBodyText))
                        
                        Picker(selection: $selectedSourceName) {
                            ForEach(accounts, id: \.name) { acc in Text(acc.name).tag(acc.name) }
                        } label: { Text("お財布").foregroundColor(Color(hex: themeBodyText)) }
                        
                        Picker(selection: $selectedProfileId) {
                            Text("未選択").tag(UUID?(nil))
                            ForEach(profiles) { prof in Text(prof.name).tag(UUID?(prof.id)) }
                        } label: { Text("ユーザー").foregroundColor(Color(hex: themeBodyText)) }
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    
                    Section(header: Text("スケジュール").foregroundColor(Color(hex: themeSubText))) {
                        DatePicker("開始月", selection: $startDate, displayedComponents: .date).environment(\.locale, Locale(identifier: "ja_JP"))
                        Picker("支払日", selection: $paymentDay) {
                            ForEach(1...31, id: \.self) { day in Text("\(day)日").tag(day) }
                        }
                        Toggle("終了月を設定する", isOn: $hasEndDate).foregroundColor(Color(hex: themeBodyText))
                        if hasEndDate {
                            DatePicker("終了月", selection: $endDate, displayedComponents: .date).environment(\.locale, Locale(identifier: "ja_JP"))
                        }
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    
                    Section(header: Text("端数調整").foregroundColor(Color(hex: themeSubText))) {
                        Picker("調整のタイミング", selection: $fractionType) {
                            Text("なし").tag(0)
                            Text("初回").tag(1)
                            Text("最終回").tag(2)
                        }.pickerStyle(.segmented)
                        if fractionType != 0 {
                            TextField("調整月の金額", text: $fractionAmountStr).keyboardType(.numberPad).foregroundColor(Color(hex: themeBodyText))
                        }
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                }.scrollContentBackground(.hidden)
            }
            .navigationTitle("新規登録")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button("キャンセル") { dismiss() }.foregroundColor(Color(hex: themeMain)), trailing: Button("追加") {
                let rp = RecurringPayment(name: name, amount: Int(amountStr) ?? 0, startDate: startDate, hasEndDate: hasEndDate, endDate: endDate, paymentDay: paymentDay, profileId: selectedProfileId, source: selectedSourceName.isEmpty ? (accounts.first?.name ?? "お財布") : selectedSourceName, isIncome: false, fractionType: fractionType, fractionAmount: Int(fractionAmountStr) ?? 0)
                recurringPayments.append(rp)
                
                // 【追加】新規登録直後に自動投稿の条件を満たしているかチェックする
                NotificationCenter.default.post(name: NSNotification.Name("CheckRecurringPayments"), object: nil)
                
                dismiss()
            }.disabled(name.isEmpty || amountStr.isEmpty).foregroundColor(Color(hex: themeMain)).fontWeight(.bold))
            .preferredColorScheme(isDarkMode ? .dark : .light)
            .onAppear {
                if selectedSourceName.isEmpty { selectedSourceName = accounts.first?.name ?? "お財布" }
            }
        }
    }
}

struct RecurringPaymentEditView: View {
    @Binding var payment: RecurringPayment
    @Binding var recurringPayments: [RecurringPayment]
    let accounts: [Account]
    let profiles: [UserProfile]
    
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    
    @Environment(\.dismiss) var dismiss
    @State private var amountStr = ""
    @State private var fractionAmountStr = ""
    
    var body: some View {
        ZStack {
            Color(hex: themeBG).ignoresSafeArea()
            Form {
                let info = payment.paymentInfo()
                Section(header: Text("状況").foregroundColor(Color(hex: themeSubText))) {
                    HStack { Text("支払った金額").foregroundColor(Color(hex: themeBodyText)); Spacer(); Text("¥\(info.paid)").foregroundColor(Color(hex: themeBodyText)).bold() }
                    if payment.hasEndDate {
                        HStack { Text("残りの金額").foregroundColor(Color(hex: themeBodyText)); Spacer(); Text("¥\(info.remaining)").foregroundColor(Color(hex: themeBodyText)).bold() }
                        HStack { Text("合計金額").foregroundColor(Color(hex: themeBodyText)); Spacer(); Text("¥\(info.total)").foregroundColor(Color(hex: themeBodyText)).bold() }
                        if info.total > 0 {
                            ProgressView(value: min(Double(info.paid), Double(info.total)), total: Double(info.total)).accentColor(Color(hex: themeMain))
                        }
                    } else {
                        HStack { Text("合計金額").foregroundColor(Color(hex: themeBodyText)); Spacer(); Text("無限").foregroundColor(Color(hex: themeSubText)) }
                    }
                }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                
                Section(header: Text("基本情報").foregroundColor(Color(hex: themeSubText))) {
                    TextField("名前", text: $payment.name).foregroundColor(Color(hex: themeBodyText))
                    TextField("毎月の金額", text: $amountStr).keyboardType(.numberPad).foregroundColor(Color(hex: themeBodyText)).onChange(of: amountStr) { val in payment.amount = Int(val) ?? 0 }
                    Picker(selection: $payment.source) { ForEach(accounts, id: \.name) { acc in Text(acc.name).tag(acc.name) } } label: { Text("お財布").foregroundColor(Color(hex: themeBodyText)) }
                    Picker(selection: $payment.profileId) { Text("未選択").tag(UUID?(nil)); ForEach(profiles) { prof in Text(prof.name).tag(UUID?(prof.id)) } } label: { Text("ユーザー").foregroundColor(Color(hex: themeBodyText)) }
                }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                
                Section(header: Text("スケジュール").foregroundColor(Color(hex: themeSubText))) {
                    DatePicker("開始月", selection: $payment.startDate, displayedComponents: .date).environment(\.locale, Locale(identifier: "ja_JP"))
                    Picker("支払日", selection: $payment.paymentDay) { ForEach(1...31, id: \.self) { day in Text("\(day)日").tag(day) } }
                    Toggle("終了月を設定する", isOn: $payment.hasEndDate).foregroundColor(Color(hex: themeBodyText))
                    if payment.hasEndDate {
                        DatePicker("終了月", selection: $payment.endDate, displayedComponents: .date).environment(\.locale, Locale(identifier: "ja_JP"))
                    }
                }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                
                Section(header: Text("端数調整").foregroundColor(Color(hex: themeSubText))) {
                    Picker("調整のタイミング", selection: $payment.fractionType) { Text("なし").tag(0); Text("初回").tag(1); Text("最終回").tag(2) }.pickerStyle(.segmented)
                    if payment.fractionType != 0 {
                        TextField("調整月の金額", text: $fractionAmountStr).keyboardType(.numberPad).foregroundColor(Color(hex: themeBodyText)).onChange(of: fractionAmountStr) { val in payment.fractionAmount = Int(val) ?? 0 }
                    }
                }.listRowBackground(Color(hex: themeBG).opacity(0.5))
            }.scrollContentBackground(.hidden)
        }
        .navigationTitle(payment.name)
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .onAppear { amountStr = String(payment.amount); fractionAmountStr = String(payment.fractionAmount) }
        .onDisappear {
            // 【追加】編集画面を閉じた時にも、条件が変わっていれば自動投稿をチェックする
            NotificationCenter.default.post(name: NSNotification.Name("CheckRecurringPayments"), object: nil)
        }
    }
}
