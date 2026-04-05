import SwiftUI
import Foundation
import UniformTypeIdentifiers

struct DisplayHomeItem: Identifiable, Equatable {
    let id: String
    let title: String
    let amount: Int
    let diffAmount: Int
}

struct HomeHeaderCell: View, Equatable {
    let item: DisplayHomeItem; let themeMain: String; let themeBodyText: String; let isSilentUpdate: Bool; let isDragged: Bool; let dragOffset: CGFloat
    static func == (lhs: HomeHeaderCell, rhs: HomeHeaderCell) -> Bool { lhs.item.id == rhs.item.id && lhs.item.amount == rhs.item.amount && lhs.isDragged == rhs.isDragged && lhs.dragOffset == rhs.dragOffset }
    var body: some View { BalanceView(title: item.title, amount: item.amount, color: Color(hex: themeBodyText), diff: item.diffAmount, isSilent: isSilentUpdate).background(isDragged ? Color(hex: themeMain).opacity(0.1) : Color.clear).cornerRadius(8).offset(x: isDragged ? dragOffset : 0, y: 0).zIndex(isDragged ? 100 : 0) }
}

struct HomeHeaderView: View {
    @Binding var homeItems: [DisplayHomeItem]
    @Binding var isHomeEditMode: Bool
    @Binding var homeDisplayOrder: [String]
    let themeMain: String; let themeBodyText: String; let isSilentUpdate: Bool
    
    @State private var localItems: [DisplayHomeItem] = []
    @State private var draggedItemId: String?
    @State private var dragOffset: CGFloat = 0
    @State private var dragHomeTotalJump: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 10) {
            ForEach(localItems) { item in let isDragged = draggedItemId == item.id; HomeHeaderCell(item: item, themeMain: themeMain, themeBodyText: themeBodyText, isSilentUpdate: isSilentUpdate, isDragged: isDragged, dragOffset: isDragged ? dragOffset : 0).equatable().overlay(isHomeEditMode ? RoundedRectangle(cornerRadius: 8).stroke(Color(hex: themeMain).opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4])) : nil).gesture(isHomeEditMode ? DragGesture(coordinateSpace: .global).onChanged { value in handleDragChange(value: value, item: item) }.onEnded { _ in handleDragEnded() } : nil) }
        }.padding().onAppear { localItems = homeItems }.onChange(of: homeItems) { newItems in if draggedItemId == nil { localItems = newItems } }
    }
    private func handleDragChange(value: DragGesture.Value, item: DisplayHomeItem) { if draggedItemId != item.id { draggedItemId = item.id; dragHomeTotalJump = 0 }; dragOffset = value.translation.width - dragHomeTotalJump; if let idx = localItems.firstIndex(where: { $0.id == item.id }) { let jumpDistance: CGFloat = 88; let threshold = jumpDistance * 0.5; if dragOffset > threshold && idx < localItems.count - 1 { withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.8, blendDuration: 0)) { localItems.swapAt(idx, idx + 1); dragHomeTotalJump += jumpDistance; dragOffset -= jumpDistance } } else if dragOffset < -threshold && idx > 0 { withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.8, blendDuration: 0)) { localItems.swapAt(idx, idx - 1); dragHomeTotalJump -= jumpDistance; dragOffset += jumpDistance } } } }
    private func handleDragEnded() { withAnimation(.interactiveSpring()) { draggedItemId = nil; dragOffset = 0; dragHomeTotalJump = 0 }; homeDisplayOrder = localItems.map { $0.id }; homeItems = localItems }
}

struct ContentView: View {
    @AppStorage("transactions_v4") var transactions: [Transaction] = []
    @AppStorage("accounts_v2") var accounts: [Account] = [ Account(name: "お財布", balance: 0, type: .wallet), Account(name: "口座", balance: 0, type: .bank), Account(name: "ポイント", balance: 0, type: .point) ]
    @AppStorage("account_groups") var groups: [AccountGroup] = []; @AppStorage("user_profiles_v1") var profiles: [UserProfile] = [UserProfile(name: "むつき", userId: "Mutsuki_dev")]
    
    @AppStorage("monthlyBudget") var monthlyBudget: Int = 50000; @AppStorage("isDarkMode") var isDarkMode: Bool = false; @AppStorage("theme_main") var themeMain: String = "#FF007AFF"; @AppStorage("theme_income") var themeIncome: String = "#FF19B219"; @AppStorage("theme_expense") var themeExpense: String = "#FFFF3B30"; @AppStorage("theme_holiday") var themeHoliday: String = "#FFFF3B30"; @AppStorage("theme_saturday") var themeSaturday: String = "#FF007AFF"; @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"; @AppStorage("theme_barBG") var themeBarBG: String = "#F8F8F8FF"; @AppStorage("theme_barText") var themeBarText: String = "#FF000000"; @AppStorage("theme_tabAccent") var themeTabAccent: String = "#FF007AFF"; @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"; @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    @AppStorage("show_total_assets") var showTotalAssets: Bool = true; @AppStorage("home_display_order") var homeDisplayOrder: [String] = []

    @State private var selection = 0; @State private var isShowingInputSheet = false; @State private var inputText: String = ""; @State private var isShowingSwipeDeleteAlert = false; @State private var transactionToDelete: Transaction?; @State private var isShowingAccountCreator = false; @State private var isShowingGroupCreator = false; @State private var isShowingAccountDeleteAlert = false; @State private var isShowingGroupDeleteAlert = false; @State private var accountToDelete: Account?; @State private var groupToDelete: AccountGroup?
    
    @State private var isHomeEditMode = false; @State private var homeItems: [DisplayHomeItem] = []; @State private var cachedVisibleTransactions: [Transaction] = []
    @State private var activeAlert: ActiveAlert?; @State private var isRestoringManual = false; @State private var isShowingImporter = false; @State private var pendingImportData: FullBackupData?
    
    // 【新規】検索用のキーワードを保持する変数
    @State private var searchText = ""

    let appearancePublisher = NotificationCenter.default.publisher(for: NSNotification.Name("UpdateAppearance"))
    @ObservedObject var lockManager = LockManager.shared; @Environment(\.scenePhase) var scenePhase

    func updateVisibleTransactions() { let currentTx = transactions; let currentProf = profiles; let isUn = lockManager.isUnlocked; let hidePriv = lockManager.privatePostDisplayMode == 0; DispatchQueue.global(qos: .userInitiated).async { let profileDict = Dictionary(uniqueKeysWithValues: currentProf.map { ($0.id, $0) }); let defaultProfile = currentProf.first; let filtered = currentTx.filter { tx in let profile = profileDict[tx.profileId ?? UUID()] ?? defaultProfile; let isVisible = profile?.isVisible ?? true; let isPrivate = profile?.isPrivate ?? false; let isDeleted = profile?.isDeleted ?? false; if isDeleted { return true }; if !isVisible { return false }; if isPrivate && !isUn && hidePriv { return false }; return true }; let sorted = filtered.sorted(by: { $0.date > $1.date }); DispatchQueue.main.async { self.cachedVisibleTransactions = sorted } } }
    
    // 【新規】検索キーワードに基づいて絞り込んだ投稿リストを返す
    var filteredSearchTransactions: [Transaction] {
        if searchText.isEmpty { return [] }
        let lower = searchText.lowercased()
        return cachedVisibleTransactions.filter { tx in
            // テキスト、ソース（お財布名）、タグのいずれかに部分一致すれば表示
            tx.note.lowercased().contains(lower) || 
            tx.source.lowercased().contains(lower) || 
            tx.tags.contains(where: { $0.lowercased().contains(lower) })
        }
    }

    var body: some View {
        ZStack {
            Color(hex: themeBG).ignoresSafeArea()
            
            // 【変更】タブメニューの2番目に「検索（searchTab）」を追加
            TabView(selection: $selection) { 
                homeTab.tag(0).tabItem { Label("ホーム", systemImage: "house") }; 
                searchTab.tag(1).tabItem { Label("検索", systemImage: "magnifyingglass") }; 
                calendarTab.tag(2).tabItem { Label("カレンダー", systemImage: "calendar") }; 
                walletTab.tag(3).tabItem { Label("お財布", systemImage: "wallet.pass") }; 
                settingTab.tag(4).tabItem { Label("設定", systemImage: "gearshape") } 
            }
            .accentColor(Color(hex: themeTabAccent))
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToHomeTab"))) { _ in self.selection = 0 }
            
            if lockManager.isShowingLockScreen { PasscodeLockOverlay().zIndex(200).transition(.opacity) }
        }.preferredColorScheme(isDarkMode ? .dark : .light)
        .onAppear { recalculateBalances(saveBackup: false); updateVisibleTransactions(); updateAppearance(); syncHomeItems(); if !lockManager.isUnlocked && !lockManager.passcode.isEmpty && lockManager.lockBehavior == 0 { lockManager.promptUnlock() } }
        .onReceive(appearancePublisher) { _ in updateAppearance() }
        .onChange(of: transactions) { _ in recalculateBalances(); updateVisibleTransactions() }
        .onChange(of: lockManager.isUnlocked) { _ in DispatchQueue.global(qos: .userInitiated).async { recalculateBalances(saveBackup: false); DispatchQueue.main.async { updateVisibleTransactions() } } }
        .onChange(of: profiles) { _ in updateVisibleTransactions() }.onChange(of: accounts) { _ in syncHomeItems() }.onChange(of: groups) { _ in syncHomeItems() }.onChange(of: showTotalAssets) { _ in syncHomeItems() }.onChange(of: themeBarBG) { _ in updateAppearance() }.onChange(of: isDarkMode) { _ in updateAppearance() }
        .onChange(of: scenePhase) { newPhase in if newPhase == .background { lockManager.lock() } else if newPhase == .active { if !lockManager.isUnlocked && !lockManager.passcode.isEmpty && lockManager.lockBehavior == 0 { lockManager.promptUnlock() } } }
        .alert(item: $activeAlert) { type in switch type { case .reset: return Alert(title: Text("全リセット"), message: Text("初期化します。"), primaryButton: .destructive(Text("リセット")) { resetAll() }, secondaryButton: .cancel()); case .restore: return Alert(title: Text("復元"), message: Text("データを復元しますか？"), primaryButton: .destructive(Text("復元")) { if let b = BackupManager.loadFullBackup(isManual: isRestoringManual) { applyFullBackup(b); activeAlert = .completion("完了") } }, secondaryButton: .cancel()); case .save: return Alert(title: Text("保存"), message: Text("上書きしますか？"), primaryButton: .default(Text("保存")) { BackupManager.saveFullBackup(data: createFullBackupData(), isManual: true); activeAlert = .completion("完了") }, secondaryButton: .cancel()); case .importConfirm: return Alert(title: Text("読込"), message: Text("上書きしますか？"), primaryButton: .destructive(Text("読込")) { if let d = pendingImportData { applyFullBackup(d); activeAlert = .completion("完了") }; pendingImportData = nil }, secondaryButton: .cancel() { pendingImportData = nil }); case .completion(let msg): return Alert(title: Text("完了"), message: Text(msg), dismissButton: .default(Text("OK"))) } }
        .sheet(isPresented: $isShowingInputSheet) {
            PostView(inputText: $inputText, isPresented: $isShowingInputSheet, initialDate: Date(), isExcludedInitial: false, initialMedias: nil, initialFiles: nil, onPost: handlePostTransaction, transactions: transactions, accounts: accounts)
        }
    }

    private var homeTab: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                Color(hex: themeBG).ignoresSafeArea()
                VStack(spacing: 0) {
                    VStack(spacing: 8) { HomeHeaderView(homeItems: $homeItems, isHomeEditMode: $isHomeEditMode, homeDisplayOrder: $homeDisplayOrder, themeMain: themeMain, themeBodyText: themeBodyText, isSilentUpdate: lockManager.isSilentUpdate); if isHomeEditMode { Text("横にスライドして並べ替えられます").font(.caption2).foregroundColor(Color(hex: themeMain)).padding(.bottom, 4) } }.background(Color(hex: themeBarBG).opacity(0.8))
                    Divider()
                    List { ForEach(cachedVisibleTransactions) { item in let isFuture = item.date > Date(); ZStack { NavigationLink(destination: TransactionDetailView(item: item, transactions: $transactions, accounts: $accounts)) { EmptyView() }.opacity(0); TwitterRow(item: item).opacity(isFuture ? 0.6 : 1.0) }.listRowInsets(EdgeInsets()).listRowBackground(isFuture ? Color.black.opacity(0.06) : Color(hex: themeBG)).swipeActions(edge: .trailing, allowsFullSwipe: false) { Button { transactionToDelete = item; isShowingSwipeDeleteAlert = true } label: { Text("削除") }.tint(.red) } } }.listStyle(.plain).scrollContentBackground(.hidden).refreshable { NotificationCenter.default.post(name: NSNotification.Name("UpdateAppearance"), object: nil) }
                }
                if !isHomeEditMode { Button(action: { inputText = ""; isShowingInputSheet = true }) { Image(systemName: "plus").font(.system(size: 22, weight: .bold)).foregroundColor(.white).frame(width: 56, height: 56).background(Color(hex: themeMain)).clipShape(Circle()) }.padding(20).padding(.bottom, 10) }
            }.navigationTitle("ホーム").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .navigationBarLeading) { if !lockManager.passcode.isEmpty { Button(action: { if lockManager.isUnlocked { lockManager.lock() } else { lockManager.promptUnlock() } }) { Image(systemName: lockManager.isUnlocked ? "lock.open.fill" : "lock.fill").foregroundColor(Color(hex: themeMain)) } } }; ToolbarItem(placement: .navigationBarTrailing) { Button(action: { withAnimation(.spring()) { isHomeEditMode.toggle() } }) { Image(systemName: isHomeEditMode ? "checkmark.circle.fill" : "arrow.left.and.right.circle").foregroundColor(isHomeEditMode ? .green : Color(hex: themeMain)) } } }.toolbarBackground(Color(hex: themeBarBG), for: .navigationBar, .tabBar).toolbarBackground(.visible, for: .navigationBar, .tabBar).alert("投稿を削除しますか？", isPresented: $isShowingSwipeDeleteAlert) { Button("キャンセル", role: .cancel) {}; Button("削除", role: .destructive) { if let t = transactionToDelete { transactions.removeAll(where: { $0.id == t.id }) } } }
        }
    }
    
    // 【新規】検索用のタブ画面（検索バーと検索結果のリスト表示）
    private var searchTab: some View {
        NavigationView {
            ZStack {
                Color(hex: themeBG).ignoresSafeArea()
                VStack(spacing: 0) {
                    // 検索バー
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(Color(hex: themeSubText))
                        TextField("キーワード、タグ、お財布を検索", text: $searchText)
                            .foregroundColor(Color(hex: themeBodyText))
                        if !searchText.isEmpty { 
                            Button(action: { searchText = "" }) { 
                                Image(systemName: "xmark.circle.fill").foregroundColor(Color(hex: themeSubText)) 
                            } 
                        }
                    }
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .padding()
                    
                    // 検索結果の表示エリア
                    if searchText.isEmpty {
                        Spacer()
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(Color(hex: themeSubText).opacity(0.5))
                            .padding(.bottom, 16)
                        Text("検索したいキーワードを入力してください")
                            .foregroundColor(Color(hex: themeSubText))
                        Spacer()
                    } else if filteredSearchTransactions.isEmpty {
                        Spacer()
                        Text("見つかりませんでした")
                            .foregroundColor(Color(hex: themeSubText))
                        Spacer()
                    } else {
                        List {
                            ForEach(filteredSearchTransactions) { item in
                                let isFuture = item.date > Date()
                                ZStack {
                                    NavigationLink(destination: TransactionDetailView(item: item, transactions: $transactions, accounts: $accounts)) { EmptyView() }.opacity(0)
                                    TwitterRow(item: item).opacity(isFuture ? 0.6 : 1.0)
                                }
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(isFuture ? Color.black.opacity(0.06) : Color(hex: themeBG))
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) { 
                                    Button { 
                                        transactionToDelete = item; isShowingSwipeDeleteAlert = true 
                                    } label: { Text("削除") }.tint(.red) 
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("検索").navigationBarTitleDisplayMode(.inline)
            .toolbar { 
                ToolbarItem(placement: .navigationBarLeading) { 
                    if !lockManager.passcode.isEmpty { 
                        Button(action: { 
                            if lockManager.isUnlocked { lockManager.lock() } else { lockManager.promptUnlock() } 
                        }) { 
                            Image(systemName: lockManager.isUnlocked ? "lock.open.fill" : "lock.fill").foregroundColor(Color(hex: themeMain)) 
                        } 
                    } 
                } 
            }
            .toolbarBackground(Color(hex: themeBarBG), for: .navigationBar, .tabBar)
            .toolbarBackground(.visible, for: .navigationBar, .tabBar)
            .alert("投稿を削除しますか？", isPresented: $isShowingSwipeDeleteAlert) { 
                Button("キャンセル", role: .cancel) {}
                Button("削除", role: .destructive) { 
                    if let t = transactionToDelete { transactions.removeAll(where: { $0.id == t.id }) } 
                } 
            }
        }
    }
    
    private var calendarTab: some View { NavigationView { CalendarView(transactions: $transactions, accounts: $accounts).navigationTitle("カレンダー").navigationBarTitleDisplayMode(.inline).toolbarBackground(Color(hex: themeBarBG), for: .navigationBar, .tabBar).toolbarBackground(.visible, for: .navigationBar, .tabBar) } }

    private var walletTab: some View { 
        NavigationView { 
            ZStack {
                Color(hex: themeBG).ignoresSafeArea()
                List { 
                    Section(header: Text("お財布の管理").foregroundColor(Color(hex: themeSubText))) { ForEach(accounts) { acc in NavigationLink(destination: AccountEditView(account: binding(for: acc), transactions: $transactions, allAccounts: accounts)) { HStack { Image(systemName: acc.type.icon).foregroundColor(Color(hex: themeBodyText).opacity(0.6)); Text(acc.name).foregroundColor(Color(hex: themeBodyText)); Spacer(); Text("¥\(acc.balance)").foregroundColor(Color(hex: themeBodyText).opacity(0.6)) } }.swipeActions(edge: .trailing, allowsFullSwipe: false) { Button(role: .destructive) { accountToDelete = acc; isShowingAccountDeleteAlert = true } label: { Text("削除") } } }; Button(action: { isShowingAccountCreator = true }) { Label("新しいお財布を追加", systemImage: "plus.circle") }.foregroundColor(Color(hex: themeMain)) }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    Section(header: Text("グループ設定").foregroundColor(Color(hex: themeSubText))) { NavigationLink(destination: TotalAssetEditView(isVisible: $showTotalAssets)) { HStack { Image(systemName: "sum").foregroundColor(Color(hex: themeBodyText).opacity(0.6)); Text("総資産").foregroundColor(Color(hex: themeBodyText)); Spacer(); let totalB = accounts.reduce(0) { $0 + $1.balance }; Text("¥\(totalB)").foregroundColor(Color(hex: themeBodyText).opacity(0.6)) } }; ForEach(groups) { group in NavigationLink(destination: AccountGroupEditView(group: binding(for: group), accounts: $accounts)) { HStack { Image(systemName: "folder").foregroundColor(Color(hex: themeBodyText).opacity(0.6)); Text(group.name).foregroundColor(Color(hex: themeBodyText)); Spacer(); let groupTotal = accounts.filter { group.accountIds.contains($0.id) }.reduce(0) { $0 + $1.balance }; Text("¥\(groupTotal)").foregroundColor(Color(hex: themeBodyText).opacity(0.6)) } }.swipeActions(edge: .trailing, allowsFullSwipe: false) { Button(role: .destructive) { groupToDelete = group; isShowingGroupDeleteAlert = true } label: { Text("削除") } } }; Button(action: { isShowingGroupCreator = true }) { Label("新しいグループを追加", systemImage: "plus.circle") }.foregroundColor(Color(hex: themeMain)) }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    Section(header: Text("分析").foregroundColor(Color(hex: themeSubText))) { NavigationLink(destination: WalletAnalysisView(transactions: transactions)) { Label("今月の収支分析", systemImage: "chart.bar.xaxis").foregroundColor(Color(hex: themeBodyText)) } }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                }.scrollContentBackground(.hidden).listStyle(.insetGrouped) 
            }.navigationTitle("お財布").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .navigationBarLeading) { if !lockManager.passcode.isEmpty { Button(action: { if lockManager.isUnlocked { lockManager.lock() } else { lockManager.promptUnlock() } }) { Image(systemName: lockManager.isUnlocked ? "lock.open.fill" : "lock.fill").foregroundColor(Color(hex: themeMain)) } } } }.toolbarBackground(Color(hex: themeBarBG), for: .navigationBar, .tabBar).toolbarBackground(.visible, for: .navigationBar, .tabBar).sheet(isPresented: $isShowingAccountCreator) { AccountCreateView(accounts: $accounts, transactions: $transactions) }.sheet(isPresented: $isShowingGroupCreator) { AccountGroupCreateView(groups: $groups, accounts: $accounts) }.alert("お財布の削除", isPresented: $isShowingAccountDeleteAlert) { Button("キャンセル", role: .cancel) { accountToDelete = nil }; Button("削除", role: .destructive) { if let acc = accountToDelete { for i in 0..<groups.count { groups[i].accountIds.removeAll(where: { $0 == acc.id }) }; accounts.removeAll(where: { $0.id == acc.id }); recalculateBalances() }; accountToDelete = nil } }.alert("グループの削除", isPresented: $isShowingGroupDeleteAlert) { Button("キャンセル", role: .cancel) { groupToDelete = nil }; Button("削除", role: .destructive) { if let grp = groupToDelete { groups.removeAll(where: { $0.id == grp.id }) }; groupToDelete = nil } }
        } 
    }

    private var settingTab: some View { 
        NavigationView { 
            ZStack { 
                Color(hex: themeBG).ignoresSafeArea()
                List { 
                    Section(header: Text("カスタマイズ").foregroundColor(Color(hex: themeSubText))) { NavigationLink(destination: UserProfileSettingView(transactions: $transactions)) { Label("表示ユーザー設定", systemImage: "person.2.circle").foregroundColor(Color(hex: themeBodyText)) }; NavigationLink(destination: ThemeSettingView()) { Label("テーマ設定", systemImage: "paintpalette").foregroundColor(Color(hex: themeBodyText)) } }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    Section(header: Text("セキュリティ").foregroundColor(Color(hex: themeSubText))) { NavigationLink(destination: PasscodeSettingView()) { Label("パスコードロック設定", systemImage: "lock.shield").foregroundColor(Color(hex: themeBodyText)) } }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    Section(header: Text("予算設定").foregroundColor(Color(hex: themeSubText))) { Stepper("今月の予算: ¥\(monthlyBudget)", value: $monthlyBudget, in: 1000...500000, step: 1000).foregroundColor(Color(hex: themeBodyText)) }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    Section(header: Text("バックアップ管理").foregroundColor(Color(hex: themeSubText))) { Button("手動保存") { activeAlert = .save }.foregroundColor(Color(hex: themeBodyText)); Button("手動保存から復元") { isRestoringManual = true; activeAlert = .restore }.foregroundColor(Color(hex: themeBodyText)); Button("自動保存から復元") { isRestoringManual = false; activeAlert = .restore }.foregroundColor(Color(hex: themeBodyText)); Button("すべてのデータを外部に書き出す") { exportBackup() }.foregroundColor(Color(hex: themeMain)); Button("外部から読み込む") { isShowingImporter = true }.foregroundColor(Color(hex: themeMain)) }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    Section(header: Text("データ管理").foregroundColor(Color(hex: themeSubText))) { Button("全データをリセット", role: .destructive) { activeAlert = .reset } }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                }.scrollContentBackground(.hidden).listStyle(.insetGrouped) 
            }.navigationTitle("設定").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .navigationBarLeading) { if !lockManager.passcode.isEmpty { Button(action: { if lockManager.isUnlocked { lockManager.lock() } else { lockManager.promptUnlock() } }) { Image(systemName: lockManager.isUnlocked ? "lock.open.fill" : "lock.fill").foregroundColor(Color(hex: themeMain)) } } } }.toolbarBackground(Color(hex: themeBarBG), for: .navigationBar, .tabBar).toolbarBackground(.visible, for: .navigationBar, .tabBar).fileImporter(isPresented: $isShowingImporter, allowedContentTypes: [.json]) { result in if case .success(let url) = result { if url.startAccessingSecurityScopedResource() { handleImport(from: url); url.stopAccessingSecurityScopedResource() } } }
        } 
    }

    private func binding(for account: Account) -> Binding<Account> { Binding( get: { self.accounts.first(where: { $0.id == account.id }) ?? account }, set: { if let i = self.accounts.firstIndex(where: { $0.id == account.id }) { self.accounts[i] = $0 } } ) }
    private func binding(for group: AccountGroup) -> Binding<AccountGroup> { Binding( get: { self.groups.first(where: { $0.id == group.id }) ?? group }, set: { if let i = self.groups.firstIndex(where: { $0.id == group.id }) { self.groups[i] = $0 } } ) }

    func handlePostTransaction(isInc: Bool, date: Date, isExc: Bool, profileId: UUID?, medias: [AttachedMediaItem]?, files: [AttachedFile]?) {
        transactions.append(Transaction(amount: parseAmount(from: inputText), date: date, note: inputText, source: parseSourceName(from: inputText), isIncome: isInc, isExcludedFromBalance: isExc, profileId: profileId, attachedMediaItems: medias, attachedFiles: files))
    }

    func syncHomeItems() { var items: [DisplayHomeItem] = []; if showTotalAssets { let totalB = accounts.reduce(0) { $0 + $1.balance }; let totalD = accounts.reduce(0) { $0 + $1.diffAmount }; items.append(DisplayHomeItem(id: "TOTAL_ASSETS", title: "総資産", amount: totalB, diffAmount: totalD)) }; for acc in accounts where acc.isVisible { items.append(DisplayHomeItem(id: "ACCOUNT_\(acc.id.uuidString)", title: acc.name, amount: acc.balance, diffAmount: acc.diffAmount)) }; for g in groups where g.isVisible { let accs = accounts.filter { g.accountIds.contains($0.id) }; let b = accs.reduce(0) { $0 + $1.balance }; let d = accs.reduce(0) { $0 + $1.diffAmount }; items.append(DisplayHomeItem(id: "GROUP_\(g.id.uuidString)", title: g.name, amount: b, diffAmount: d)) }; items.sort { i1, i2 in let idx1 = homeDisplayOrder.firstIndex(of: i1.id) ?? Int.max; let idx2 = homeDisplayOrder.firstIndex(of: i2.id) ?? Int.max; return idx1 < idx2 }; self.homeItems = items }
    func createFullBackupData() -> FullBackupData { return FullBackupData( transactions: transactions, accounts: accounts, groups: groups, profiles: profiles, monthlyBudget: monthlyBudget, isDarkMode: isDarkMode, themeMain: themeMain, themeIncome: themeIncome, themeExpense: themeExpense, themeHoliday: themeHoliday, themeSaturday: themeSaturday, themeBG: themeBG, themeBarBG: themeBarBG, themeBarText: themeBarText, themeTabAccent: themeTabAccent, themeBodyText: themeBodyText, themeSubText: themeSubText, showTotalAssets: showTotalAssets, homeDisplayOrder: homeDisplayOrder, backupDate: BackupManager.currentDateString() ) }
    func applyFullBackup(_ backup: FullBackupData) { transactions = backup.transactions; accounts = backup.accounts; groups = backup.groups; profiles = backup.profiles; monthlyBudget = backup.monthlyBudget; isDarkMode = backup.isDarkMode; themeMain = backup.themeMain; themeIncome = backup.themeIncome; themeExpense = backup.themeExpense; themeHoliday = backup.themeHoliday; themeSaturday = backup.themeSaturday; themeBG = backup.themeBG; themeBarBG = themeBarBG; themeBarText = backup.themeBarText; themeTabAccent = backup.themeTabAccent; themeBodyText = backup.themeBodyText; themeSubText = backup.themeSubText; showTotalAssets = backup.showTotalAssets; homeDisplayOrder = backup.homeDisplayOrder; recalculateBalances(); updateAppearance(); updateVisibleTransactions() }
    func handleImport(from url: URL) { guard let data = try? Data(contentsOf: url) else { return }; if let fd = try? JSONDecoder().decode(FullBackupData.self, from: data) { self.pendingImportData = fd; self.activeAlert = .importConfirm } else if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let txStr = json["transactions"] as? String, let accStr = json["accounts"] as? String, let dec = try? JSONDecoder().decode([Transaction].self, from: txStr.data(using: .utf8)!), let aDec = try? JSONDecoder().decode([Account].self, from: accStr.data(using: .utf8)!) { let fd = createFullBackupData(); self.pendingImportData = FullBackupData( transactions: dec, accounts: aDec, groups: fd.groups, profiles: fd.profiles, monthlyBudget: fd.monthlyBudget, isDarkMode: fd.isDarkMode, themeMain: fd.themeMain, themeIncome: fd.themeIncome, themeExpense: fd.themeExpense, themeHoliday: fd.themeHoliday, themeSaturday: fd.themeSaturday, themeBG: fd.themeBG, themeBarBG: fd.themeBarBG, themeBarText: fd.themeBarText, themeTabAccent: fd.themeTabAccent, themeBodyText: fd.themeBodyText, themeSubText: fd.themeSubText, showTotalAssets: fd.showTotalAssets, homeDisplayOrder: fd.homeDisplayOrder, backupDate: "以前の形式" ); self.activeAlert = .importConfirm } }
    func resetAll() { transactions = []; accounts = [ Account(name: "お財布", balance: 0, type: .wallet), Account(name: "口座", balance: 0, type: .bank), Account(name: "ポイント", balance: 0, type: .point) ]; groups = []; monthlyBudget = 50000; profiles = [UserProfile(name: "むつき", userId: "Mutsuki_dev")]; recalculateBalances(); updateVisibleTransactions(); activeAlert = .completion("リセット完了") }
    
    func recalculateBalances(saveBackup: Bool = true) { let currentAccounts = accounts; let currentTransactions = transactions; let currentProfiles = profiles; let isUn = lockManager.isUnlocked; let reflectPriv = lockManager.reflectPrivateBalanceWhenLocked; DispatchQueue.global(qos: .userInitiated).async { var tempAccounts = currentAccounts; for i in 0..<tempAccounts.count { var cur = 0; for tx in currentTransactions where tx.source == tempAccounts[i].name { if tx.isExcludedFromBalance == true { continue }; let profile = currentProfiles.first(where: { $0.id == tx.profileId }) ?? currentProfiles.first; let isPrivate = profile?.isPrivate ?? false; let isDeleted = profile?.isDeleted ?? false; if isDeleted { cur += (tx.isIncome ? tx.amount : -tx.amount); continue }; if isPrivate && !isUn && !reflectPriv { continue }; cur += (tx.isIncome ? tx.amount : -tx.amount) }; tempAccounts[i].diffAmount = cur - tempAccounts[i].balance; tempAccounts[i].balance = cur }; DispatchQueue.main.async { self.accounts = tempAccounts; if saveBackup { let backupData = self.createFullBackupData(); DispatchQueue.global(qos: .background).async { BackupManager.saveFullBackup(data: backupData, isManual: false) } } } } }
    func parseAmount(from text: String) -> Int { text.components(separatedBy: .whitespacesAndNewlines).filter { $0.contains("¥") }.reduce(0) { $0 + (Int($1.replacingOccurrences(of: "¥", with: "")) ?? 0) } }
    func parseSourceName(from t: String) -> String { for acc in accounts { if t.contains("@\(acc.name)") { return acc.name } }; return accounts.first?.name ?? "お財布" }
    func exportBackup() { let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted; let dict = createFullBackupData(); guard let finalData = try? encoder.encode(dict) else { return }; let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Paytter_FullBackup.json"); try? finalData.write(to: tempURL); let av = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil); if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene, let rootVC = scene.windows.first?.rootViewController { av.popoverPresentationController?.sourceView = rootVC.view; rootVC.present(av, animated: true) } }
    func updateAppearance() { let bgColor = UIColor(Color(hex: themeBarBG)); let textColor = UIColor(Color(hex: themeBarText)); let appearance = UINavigationBarAppearance(); appearance.configureWithOpaqueBackground(); appearance.backgroundColor = bgColor; appearance.titleTextAttributes = [.foregroundColor: textColor]; appearance.largeTitleTextAttributes = [.foregroundColor: textColor]; UINavigationBar.appearance().standardAppearance = appearance; UINavigationBar.appearance().scrollEdgeAppearance = appearance; UINavigationBar.appearance().compactAppearance = appearance; let tabAppearance = UITabBarAppearance(); tabAppearance.configureWithOpaqueBackground(); tabAppearance.backgroundColor = bgColor; UITabBar.appearance().standardAppearance = tabAppearance; UITabBar.appearance().scrollEdgeAppearance = tabAppearance; if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene { windowScene.windows.forEach { window in updateViewHierarchy(window.rootViewController); window.setNeedsLayout(); window.layoutIfNeeded() } } }
    private func updateViewHierarchy(_ vc: UIViewController?) { guard let vc = vc else { return }; if let nav = vc as? UINavigationController { nav.navigationBar.standardAppearance = UINavigationBar.appearance().standardAppearance; nav.navigationBar.scrollEdgeAppearance = UINavigationBar.appearance().standardAppearance; nav.navigationBar.setNeedsLayout(); nav.navigationBar.layoutIfNeeded() }; if let tab = vc as? UITabBarController { tab.tabBar.standardAppearance = UITabBar.appearance().standardAppearance; if #available(iOS 15.0, *) { tab.tabBar.scrollEdgeAppearance = UITabBar.appearance().scrollEdgeAppearance } }; vc.children.forEach { updateViewHierarchy($0) } }
}
