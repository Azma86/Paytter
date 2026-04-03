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
    
    var body: some View {
        ZStack {
            Color(hex: themeBG).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 12) {
                        let profile = profiles.first(where: { $0.id == item.profileId }) ?? profiles.first ?? UserProfile(name: "不明", userId: "unknown")
                        
                        if let iconData = profile.iconData, let uiImage = UIImage(data: iconData) {
                            Image(uiImage: uiImage).resizable().scaledToFill().frame(width: 56, height: 56).clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill").resizable().frame(width: 56, height: 56).foregroundColor(Color(hex: themeSubText))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.name).font(.headline).fontWeight(.bold).foregroundColor(Color(hex: themeBodyText))
                            Text("@\(profile.userId)").font(.subheadline).foregroundColor(Color(hex: themeSubText))
                        }
                        Spacer()
                        Text(item.source)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(hex: themeSubText).opacity(0.1))
                            .cornerRadius(5)
                            .foregroundColor(Color(hex: themeBodyText))
                    }
                    
                    HighlightedText(text: item.cleanNote, isIncome: item.isIncome)
                        .font(.title3)
                        .foregroundColor(Color(hex: themeBodyText))
                    
                    if !item.tags.isEmpty {
                        HStack(spacing: 12) {
                            ForEach(item.tags, id: \.self) { tag in
                                Text(tag).font(.subheadline).foregroundColor(Color(hex: themeMain))
                            }
                        }
                    }
                    
                    if item.isExcludedFromBalance == true {
                        Label("この投稿は残高計算から除外されています", systemImage: "calculator.badge.minus")
                            .font(.caption)
                            .foregroundColor(Color(hex: themeSubText))
                    }

                    Text(item.date, style: .date) + Text(" " ) + Text(item.date, style: .time)
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
                        editLineText = item.note
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
                initialDate: item.date,
                isExcludedInitial: item.isExcludedFromBalance ?? false,
                onPost: handleEditTransaction,
                transactions: transactions,
                accounts: accounts
            )
        }
    }
    
    func handleEditTransaction(isInc: Bool, nDate: Date, isExc: Bool, profileId: UUID?) {
        if let idx = transactions.firstIndex(where: { $0.id == item.id }) {
            let nAmt = editLineText.components(separatedBy: .whitespacesAndNewlines)
                .filter { $0.contains("¥") }
                .reduce(0) { $0 + (Int($1.replacingOccurrences(of: "¥", with: "")) ?? 0) }
            
            var nSrc = item.source
            for acc in accounts {
                if editLineText.contains("@\(acc.name)") { nSrc = acc.name }
            }
            
            transactions[idx] = Transaction(
                id: item.id, amount: nAmt, date: nDate, note: editLineText,
                source: nSrc, isIncome: isInc, isExcludedFromBalance: isExc,
                profileId: profileId ?? item.profileId
            )
        }
    }
}

// 【新規追加】各ユーザーの設定ブロックを独立させるためのView
// これにより、画像選択時の状態が他ユーザーと混ざらず、確実に更新されます。
struct UserProfileEditSection: View {
    @Binding var profile: UserProfile
    let themeMain: String
    let themeBodyText: String
    let themeSubText: String
    let themeBG: String
    let onDelete: () -> Void
    
    @State private var selectedItem: PhotosPickerItem? = nil

    var body: some View {
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
                            DispatchQueue.main.async {
                                selectedItem = nil
                            }
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
            
            Toggle("タイムラインに表示", isOn: $profile.isVisible)
                .foregroundColor(Color(hex: themeBodyText))
            
            Button(action: onDelete) {
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

struct UserProfileSettingView: View {
    @AppStorage("user_profiles_v1") var profiles: [UserProfile] = []
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    
    @State private var profileToDelete: UserProfile?
    @State private var isShowingDeleteAlert = false
    
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
                        onDelete: {
                            profileToDelete = profile
                            isShowingDeleteAlert = true
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
            if profiles.isEmpty {
                profiles.append(UserProfile(name: "むつき", userId: "Mutsuki_dev"))
            }
        }
        .alert("ユーザーの削除", isPresented: $isShowingDeleteAlert) {
            Button("キャンセル", role: .cancel) { profileToDelete = nil }
            Button("削除", role: .destructive) {
                if let p = profileToDelete {
                    profiles.removeAll(where: { $0.id == p.id })
                    if profiles.isEmpty {
                        profiles.append(UserProfile(name: "新規ユーザー", userId: "new_user"))
                    }
                    profileToDelete = nil
                }
            }
        } message: {
            Text("このユーザーを削除してもよろしいですか？")
        }
    }
}

struct AccountCreateView: View {
    @Binding var accounts: [Account]
    @Binding var transactions: [Transaction]
    @Environment(\.dismiss) var dismiss
    
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
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
                    Section(header: Text("基本情報")) {
                        TextField("お財布の名前", text: $name)
                        Picker(selection: $selectedType) {
                            ForEach(AccountType.allCases, id: \.self) { type in
                                Label(type.rawValue, systemImage: type.icon).tag(type)
                            }
                        } label: { Text("種類") }
                        TextField("現在の金額", text: $initial).keyboardType(.numbersAndPunctuation)
                        Toggle("ホーム上部に表示", isOn: $isVisible)
                    }
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

struct WalletAnalysisView: View {
    let transactions: [Transaction]
    @AppStorage("monthlyBudget") var monthlyBudget: Int = 50000
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_expense") var themeExpense: String = "#FFFF3B30"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    
    var monthlyTotal: Int {
        transactions.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        List {
            Section(header: Text("今月のサマリー").foregroundColor(Color(hex: themeSubText))) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("合計支出").font(.caption).foregroundColor(Color(hex: themeSubText))
                    Text("¥\(monthlyTotal)").font(.system(.title, design: .rounded).bold()).foregroundColor(Color(hex: themeBodyText))
                    
                    ProgressView(value: min(Double(monthlyTotal), Double(monthlyBudget)), total: Double(monthlyBudget))
                        .accentColor(monthlyTotal > Int(Double(monthlyBudget) * 0.9) ? Color(hex: themeExpense) : Color(hex: themeMain))
                    
                    Text("予算 ¥\(monthlyBudget) まであと ¥\(max(0, monthlyBudget - monthlyTotal))")
                        .font(.caption2).foregroundColor(Color(hex: themeSubText))
                }.padding(.vertical, 10)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("分析")
    }
}
