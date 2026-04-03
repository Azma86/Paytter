import SwiftUI
import Foundation
import UniformTypeIdentifiers

enum HomeItem: Identifiable, Equatable {
    case totalAssets; case account(Account); case group(AccountGroup)
    var id: String { switch self { case .totalAssets: return "TOTAL_ASSETS"; case .account(let a): return "ACCOUNT_\(a.id.uuidString)"; case .group(let g): return "GROUP_\(g.id.uuidString)" } }
}

struct ContentView: View {
    @AppStorage("transactions_v4") var transactions: [Transaction] = []
    @AppStorage("accounts_v2") var accounts: [Account] = [ Account(name: "お財布", balance: 0, type: .wallet), Account(name: "口座", balance: 0, type: .bank), Account(name: "ポイント", balance: 0, type: .point) ]
    @AppStorage("account_groups") var groups: [AccountGroup] = []
    @AppStorage("user_profiles_v1") var profiles: [UserProfile] = [UserProfile(name: "むつき", userId: "Mutsuki_dev")]
    
    @AppStorage("monthlyBudget") var monthlyBudget: Int = 50000; @AppStorage("isDarkMode") var isDarkMode: Bool = false
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"; @AppStorage("theme_income") var themeIncome: String = "#FF19B219"; @AppStorage("theme_expense") var themeExpense: String = "#FFFF3B30"; @AppStorage("theme_holiday") var themeHoliday: String = "#FFFF3B30"; @AppStorage("theme_saturday") var themeSaturday: String = "#FF007AFF"; @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"; @AppStorage("theme_barBG") var themeBarBG: String = "#F8F8F8FF"; @AppStorage("theme_barText") var themeBarText: String = "#FF000000"; @AppStorage("theme_tabAccent") var themeTabAccent: String = "#FF007AFF"; @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"; @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    @AppStorage("show_total_assets") var showTotalAssets: Bool = true; @AppStorage("home_display_order") var homeDisplayOrder: [String] = []

    @State private var selection = 0; @State private var isShowingInputSheet = false; @State private var inputText: String = ""; @State private var isShowingSwipeDeleteAlert = false; @State private var transactionToDelete: Transaction?; @State private var isShowingAccountCreator = false; @State private var isShowingGroupCreator = false; @State private var isShowingAccountDeleteAlert = false; @State private var isShowingGroupDeleteAlert = false; @State private var accountToDelete: Account?; @State private var groupToDelete: AccountGroup?
    
    @State private var isHomeEditMode = false; @State private var draggedItemId: String?; @State private var dragOffset: CGFloat = 0; @State private var dragLastX: CGFloat?; @State private var homeItems: [HomeItem] = []
    @State private var activeAlert: ActiveAlert?; @State private var isRestoringManual = false; @State private var isShowingImporter = false; @State private var pendingImportData: FullBackupData?

    let appearancePublisher = NotificationCenter.default.publisher(for: NSNotification.Name("UpdateAppearance"))

    var visibleTransactions: [Transaction] {
        transactions.filter { tx in
            let profile = profiles.first(where: { $0.id == tx.profileId }) ?? profiles.first
            return profile?.isVisible ?? true
        }.sorted(by: { $0.date > $1.date })
    }

    var body: some View {
        ZStack {
            Color(hex: themeBG).ignoresSafeArea()
            TabView(selection: $selection) {
                homeTab.tag(0).tabItem { Label("ホーム", systemImage: "house") }
                calendarTab.tag(1).tabItem { Label("カレンダー", systemImage: "calendar") }
                walletTab.tag(2).tabItem { Label("お財布", systemImage: "wallet.pass") }
                settingTab.tag(3).tabItem { Label("設定", systemImage: "gearshape") }
            }
            .accentColor(Color(hex: themeTabAccent))
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToHomeTab"))) { _ in self.selection = 0 }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .onAppear { recalculateBalances(); updateAppearance(); syncHomeItems() }
        .onReceive(appearancePublisher) { _ in updateAppearance() }
        .onChange(of: transactions) { _ in recalculateBalances() }
        .onChange(of: accounts) { _ in syncHomeItems() }
        .onChange(of: groups) { _ in syncHomeItems() }
        .onChange(of: showTotalAssets) { _ in syncHomeItems() }
        .onChange(of: themeBarBG) { _ in updateAppearance() }
        .onChange(of: isDarkMode) { _ in updateAppearance() }
        .alert(item: $activeAlert) { type in
            switch type {
            case .reset: return Alert(title: Text("全リセット"), message: Text("全てのデータとユーザー設定を初期化します。"), primaryButton: .destructive(Text("リセット")) { resetAll() }, secondaryButton: .cancel(Text("キャンセル")))
            case .restore: return Alert(title: Text("バックアップの復元"), message: Text("データを復元しますか？"), primaryButton: .destructive(Text("復元")) { if let b = BackupManager.loadFullBackup(isManual: isRestoringManual) { applyFullBackup(b); activeAlert = .completion("復元完了") } }, secondaryButton: .cancel(Text("キャンセル")))
            case .save: return Alert(title: Text("バックアップの保存"), message: Text("現在のすべてのデータで上書きしますか？"), primaryButton: .default(Text("保存")) { BackupManager.saveFullBackup(data: createFullBackupData(), isManual: true); activeAlert = .completion("保存完了") }, secondaryButton: .cancel(Text("キャンセル")))
            case .importConfirm: return Alert(title: Text("外部データの読込"), message: Text("保存日時: \(pendingImportData?.backupDate ?? "")\nデータを上書きしますか？"), primaryButton: .destructive(Text("読み込む")) { if let d = pendingImportData { applyFullBackup(d); activeAlert = .completion("読込完了") }; pendingImportData = nil }, secondaryButton: .cancel(Text("キャンセル")) { pendingImportData = nil })
            case .completion(let msg): return Alert(title: Text("完了"), message: Text(msg), dismissButton: .default(Text("OK")))
            }
        }
        .sheet(isPresented: $isShowingInputSheet) { PostView(inputText: $inputText, isPresented: $isShowingInputSheet, initialDate: Date(), isExcludedInitial: false, onPost: handlePostTransaction, transactions: transactions, accounts: accounts) }
    }

    private var homeTab: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                Color(hex: themeBG).ignoresSafeArea()
                VStack(spacing: 0) {
                    VStack(spacing: 8) {
                        HStack(spacing: 10) {
                            ForEach(homeItems) { item in
                                homeHeaderItem(for: item).background(draggedItemId == item.id ? Color(hex: themeMain).opacity(0.1) : Color.clear).cornerRadius(8).overlay(isHomeEditMode ? RoundedRectangle(cornerRadius: 8).stroke(Color(hex: themeMain).opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4])) : nil).offset(x: draggedItemId == item.id ? dragOffset : 0, y: 0).zIndex(draggedItemId == item.id ? 100 : 0).gesture(isHomeEditMode ? DragGesture(minimumDistance: 0, coordinateSpace: .global).onChanged { value in handleDragChange(value: value, item: item) }.onEnded { _ in handleDragEnded() } : nil)
                            }
                        }.padding()
                    }.background(Color(hex: themeBarBG).opacity(0.8))
                    Divider()
                    List {
                        ForEach(visibleTransactions) { item in
                            let isFuture = item.date > Date()
                            ZStack {
                                NavigationLink(destination: TransactionDetailView(item: item, transactions: $transactions, accounts: $accounts)) { EmptyView() }.opacity(0)
                                TwitterRow(item: item).opacity(isFuture ? 0.6 : 1.0)
                            }.listRowInsets(EdgeInsets()).listRowBackground(isFuture ? Color.black.opacity(0.06) : Color(hex: themeBG))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) { Button { transactionToDelete = item; isShowingSwipeDeleteAlert = true } label: { Text("削除") }.tint(.red) }
                        }
                    }.listStyle(.plain).scrollContentBackground(.hidden).refreshable { recalculateBalances() }
                }
                if !isHomeEditMode { Button(action: { inputText = ""; isShowingInputSheet = true }) { Image(systemName: "plus").font(.system(size: 22, weight: .bold)).foregroundColor(.white).frame(width: 56, height: 56).background(Color(hex: themeMain)).clipShape(Circle()) }.padding(20).padding(.bottom, 10) }
            }
            .navigationTitle("ホーム").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button(action: { withAnimation(.spring()) { isHomeEditMode.toggle() } }) { Image(systemName: isHomeEditMode ? "checkmark.circle.fill" : "arrow.left.and.right.circle").foregroundColor(isHomeEditMode ? .green : Color(hex: themeMain)) } } }
            .toolbarBackground(Color(hex: themeBarBG), for: .navigationBar, .tabBar).toolbarBackground(.visible, for: .navigationBar, .tabBar)
            .alert("投稿を削除しますか？", isPresented: $isShowingSwipeDeleteAlert) { Button("キャンセル", role: .cancel) {}; Button("削除", role: .destructive) { if let t = transactionToDelete { transactions.removeAll(where: { $0.id == t.id }); recalculateBalances() } } }
        }
    }
    
    private var calendarTab: some View { NavigationView { CalendarView(transactions: $transactions, accounts: $accounts).navigationTitle("カレンダー").navigationBarTitleDisplayMode(.inline).toolbarBackground(Color(hex: themeBarBG), for: .navigationBar, .tabBar).toolbarBackground(.visible, for: .navigationBar, .tabBar) } }

    private var walletTab: some View { 
        NavigationView { 
            ZStack {
                Color(hex: themeBG).ignoresSafeArea()
                List { 
                    Section(header: Text("お財布の管理").foregroundColor(Color(hex: themeSubText))) { 
                        ForEach(accounts) { acc in 
                            NavigationLink(destination: AccountEditView(account: binding(for: acc), transactions: $transactions, allAccounts: accounts)) { 
                                HStack { Image(systemName: acc.type.icon).foregroundColor(Color(hex: themeBodyText).opacity(0.6)); Text(acc.name).foregroundColor(Color(hex: themeBodyText)); Spacer(); Text("¥\(acc.balance)").foregroundColor(Color(hex: themeBodyText).opacity(0.6)) } 
                            }
                            // 【修正】リスト削除の変な動きを防ぐため、swipeActionsに変更
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) { accountToDelete = acc; isShowingAccountDeleteAlert = true } label: { Text("削除") }
                            }
                        }
                        Button(action: { isShowingAccountCreator = true }) { Label("新しいお財布を追加", systemImage: "plus.circle") }.foregroundColor(Color(hex: themeMain))
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))

                    Section(header: Text("グループ設定").foregroundColor(Color(hex: themeSubText))) {
                        NavigationLink(destination: TotalAssetEditView(isVisible: $showTotalAssets)) { HStack { Image(systemName: "sum").foregroundColor(Color(hex: themeBodyText).opacity(0.6)); Text("総資産").foregroundColor(Color(hex: themeBodyText)); Spacer(); let totalB = accounts.reduce(0) { $0 + $1.balance }; Text("¥\(totalB)").foregroundColor(Color(hex: themeBodyText).opacity(0.6)) } }
                        ForEach(groups) { group in
                            NavigationLink(destination: AccountGroupEditView(group: binding(for: group), accounts: $accounts)) {
                                HStack { Image(systemName: "folder").foregroundColor(Color(hex: themeBodyText).opacity(0.6)); Text(group.name).foregroundColor(Color(hex: themeBodyText)); Spacer(); let groupTotal = accounts.filter { group.accountIds.contains($0.id) }.reduce(0) { $0 + $1.balance }; Text("¥\(groupTotal)").foregroundColor(Color(hex: themeBodyText).opacity(0.6)) }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) { groupToDelete = group; isShowingGroupDeleteAlert = true } label: { Text("削除") }
                            }
                        }
                        Button(action: { isShowingGroupCreator = true }) { Label("新しいグループを追加", systemImage: "plus.circle") }.foregroundColor(Color(hex: themeMain))
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    Section(header: Text("分析").foregroundColor(Color(hex: themeSubText))) { NavigationLink(destination: WalletAnalysisView(transactions: transactions)) { Label("今月の収支分析", systemImage: "chart.bar.xaxis").foregroundColor(Color(hex: themeBodyText)) } }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                }.scrollContentBackground(.hidden).listStyle(.insetGrouped) 
            }
            .navigationTitle("お財布").navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: themeBarBG), for: .navigationBar, .tabBar).toolbarBackground(.visible, for: .navigationBar, .tabBar)
            .sheet(isPresented: $isShowingAccountCreator) { AccountCreateView(accounts: $accounts, transactions: $transactions) }
            .sheet(isPresented: $isShowingGroupCreator) { AccountGroupCreateView(groups: $groups, accounts: $accounts) }
            // 【修正】削除後の動きを安定化
            .alert("お財布の削除", isPresented: $isShowingAccountDeleteAlert) {
                Button("キャンセル", role: .cancel){ accountToDelete = nil }
                Button("削除", role: .destructive){ 
                    if let acc = accountToDelete {
                        for i in 0..<groups.count { groups[i].accountIds.removeAll(where: { $0 == acc.id }) }
                        accounts.removeAll(where: { $0.id == acc.id })
                        recalculateBalances()
                    }
                    accountToDelete = nil 
                }
            }
            .alert("グループの削除", isPresented: $isShowingGroupDeleteAlert) {
                Button("キャンセル", role: .cancel){ groupToDelete = nil }
                Button("削除", role: .destructive){ if let grp = groupToDelete { groups.removeAll(where: { $0.id == grp.id }) }; groupToDelete = nil }
            }
        } 
    }

    private var settingTab: some View { 
        NavigationView { 
            ZStack { 
                Color(hex: themeBG).ignoresSafeArea()
                List { 
                    Section(header: Text("カスタマイズ").foregroundColor(Color(hex: themeSubText))) { 
                        NavigationLink(destination: UserProfileSettingView()) { Label("表示ユーザー設定", systemImage: "person.2.circle").foregroundColor(Color(hex: themeBodyText)) }
                        NavigationLink(destination: ThemeSettingView()) { Label("テーマ設定", systemImage: "paintpalette").foregroundColor(Color(hex: themeBodyText)) } 
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    Section(header: Text("予算設定").foregroundColor(Color(hex: themeSubText))) { Stepper("今月の予算: ¥\(monthlyBudget)", value: $monthlyBudget, in: 1000...500000, step: 1000).foregroundColor(Color(hex: themeBodyText)) }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    Section(header: Text("バックアップ管理").foregroundColor(Color(hex: themeSubText))) { 
                        Button("手動保存") { activeAlert = .save }.foregroundColor(Color(hex: themeBodyText))
                        Button("手動保存から復元") { isRestoringManual = true; activeAlert = .restore }.foregroundColor(Color(hex: themeBodyText))
                        Button("自動保存から復元") { isRestoringManual = false; activeAlert = .restore }.foregroundColor(Color(hex: themeBodyText))
                        Button("すべてのデータを外部に書き出す") { exportBackup() }.foregroundColor(Color(hex: themeMain))
                        Button("外部から読み込む") { isShowingImporter = true }.foregroundColor(Color(hex: themeMain))
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    Section(header: Text("データ管理").foregroundColor(Color(hex: themeSubText))) { Button("全データをリセット", role: .destructive) { activeAlert = .reset } }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                }.scrollContentBackground(.hidden).listStyle(.insetGrouped) 
            }
            .navigationTitle("設定").navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: themeBarBG), for: .navigationBar, .tabBar).toolbarBackground(.visible, for: .navigationBar, .tabBar)
            .fileImporter(isPresented: $isShowingImporter, allowedContentTypes: [.json]) { r in if case .success(let u) = r { if u.startAccessingSecurityScopedResource() { handleImport(from: u); u.stopAccessingSecurityScopedResource() } } }
        } 
    }

    // MARK: - Logic functions

    func handlePostTransaction(isInc: Bool, date: Date, isExc: Bool, profileId: UUID?) {
        transactions.append(Transaction(amount: parseAmount(from: inputText), date: date, note: inputText, source: parseSourceName(from: inputText), isIncome: isInc, isExcludedFromBalance: isExc, profileId: profileId))
        recalculateBalances()
    }
    
    @ViewBuilder private func homeHeaderItem(for item: HomeItem) -> some View {
        Group {
            switch item {
            case .totalAssets: let b = accounts.reduce(0) { $0 + $1.balance }; let d = accounts.reduce(0) { $0 + $1.diffAmount }; BalanceView(title: "総資産", amount: b, color: Color(hex: themeBodyText), diff: d)
            case .account(let a): if let c = accounts.first(where: { $0.id == a.id }) { BalanceView(title: c.name, amount: c.balance, color: Color(hex: themeBodyText), diff: c.diffAmount) }
            case .group(let g): if let c = groups.first(where: { $0.id == g.id }) { let accs = accounts.filter { c.accountIds.contains($0.id) }; let b = accs.reduce(0) { $0 + $1.balance }; let d = accs.reduce(0) { $0 + $1.diffAmount }; BalanceView(title: c.name, amount: b, color: Color(hex: themeBodyText), diff: d) }
            }
        }
    }

    private func handleDragChange(value: DragGesture.Value, item: HomeItem) {
        if draggedItemId != item.id { draggedItemId = item.id; dragLastX = value.location.x; dragOffset = 0 }
        guard let lastX = dragLastX else { return }; dragOffset += value.location.x - lastX; dragLastX = value.location.x
        if let idx = homeItems.firstIndex(where: { $0.id == item.id }) {
            let space: CGFloat = 10; let w = (UIScreen.main.bounds.width - 32 - CGFloat(max(homeItems.count - 1, 0)) * space) / CGFloat(max(homeItems.count, 1)) + space
            if dragOffset > w * 0.5 && idx < homeItems.count - 1 { withAnimation(.easeInOut(duration: 0.2)) { homeItems.swapAt(idx, idx + 1); dragOffset -= w } }
            else if dragOffset < -w * 0.5 && idx > 0 { withAnimation(.easeInOut(duration: 0.2)) { homeItems.swapAt(idx, idx - 1); dragOffset += w } }
        }
    }
    private func handleDragEnded() { withAnimation(.easeInOut(duration: 0.2)) { draggedItemId = nil; dragOffset = 0; dragLastX = nil }; homeDisplayOrder = homeItems.map { $0.id } }

    private func binding(for account: Account) -> Binding<Account> { Binding(get: { self.accounts.first(where: { $0.id == account.id }) ?? account }, set: { if let i = self.accounts.firstIndex(where: { $0.id == account.id }) { self.accounts[i] = $0 } }) }
    private func binding(for group: AccountGroup) -> Binding<AccountGroup> { Binding(get: { self.groups.first(where: { $0.id == group.id }) ?? group }, set: { if let i = self.groups.firstIndex(where: { $0.id == group.id }) { self.groups[i] = $0 } }) }

    func syncHomeItems() {
        if draggedItemId != nil { return } 
        var items: [HomeItem] = []
        if showTotalAssets { items.append(.totalAssets) }
        items.append(contentsOf: accounts.filter({ $0.isVisible }).map { .account($0) })
        items.append(contentsOf: groups.filter({ $0.isVisible }).map { .group($0) })
        items.sort { i1, i2 in return (homeDisplayOrder.firstIndex(of: i1.id) ?? Int.max) < (homeDisplayOrder.firstIndex(of: i2.id) ?? Int.max) }
        homeItems = items
    }

    func createFullBackupData() -> FullBackupData {
        return FullBackupData(transactions: transactions, accounts: accounts, groups: groups, profiles: profiles, monthlyBudget: monthlyBudget, isDarkMode: isDarkMode, themeMain: themeMain, themeIncome: themeIncome, themeExpense: themeExpense, themeHoliday: themeHoliday, themeSaturday: themeSaturday, themeBG: themeBG, themeBarBG: themeBarBG, themeBarText: themeBarText, themeTabAccent: themeTabAccent, themeBodyText: themeBodyText, themeSubText: themeSubText, showTotalAssets: showTotalAssets, homeDisplayOrder: homeDisplayOrder, backupDate: BackupManager.currentDateString())
    }
    
    func applyFullBackup(_ backup: FullBackupData) {
        transactions = backup.transactions; accounts = backup.accounts; groups = backup.groups; profiles = backup.profiles
        monthlyBudget = backup.monthlyBudget; isDarkMode = backup.isDarkMode
        themeMain = backup.themeMain; themeIncome = backup.themeIncome; themeExpense = backup.themeExpense; themeHoliday = backup.themeHoliday; themeSaturday = backup.themeSaturday
        themeBG = backup.themeBG; themeBarBG = backup.themeBarBG; themeBarText = backup.themeBarText; themeTabAccent = backup.themeTabAccent; themeBodyText = backup.themeBodyText; themeSubText = backup.themeSubText
        showTotalAssets = backup.showTotalAssets; homeDisplayOrder = backup.homeDisplayOrder
        recalculateBalances(); updateAppearance()
    }

    func handleImport(from url: URL) {
        guard let data = try? Data(contentsOf: url) else { return }
        if let fd = try? JSONDecoder().decode(FullBackupData.self, from: data) { self.pendingImportData = fd; self.activeAlert = .importConfirm }
    }
    
    // 【修正】ユーザー設定もリセット
    func resetAll() { transactions = []; accounts = [Account(name: "お財布", balance: 0, type: .wallet), Account(name: "口座", balance: 0, type: .bank), Account(name: "ポイント", balance: 0, type: .point)]; groups = []; monthlyBudget = 50000; profiles = [UserProfile(name: "むつき", userId: "Mutsuki_dev")]; recalculateBalances(); activeAlert = .completion("リセット完了") }
    
    func recalculateBalances() { 
        var tempAccounts = accounts
        for i in 0..<tempAccounts.count { 
            var cur = 0; 
            for tx in transactions where tx.source == tempAccounts[i].name { 
                if tx.isExcludedFromBalance == true { continue }
                cur += (tx.isIncome ? tx.amount : -tx.amount) 
            }
            tempAccounts[i].diffAmount = cur - tempAccounts[i].balance; tempAccounts[i].balance = cur 
        }
        accounts = tempAccounts
        BackupManager.saveFullBackup(data: createFullBackupData(), isManual: false)
    }
    
    func parseAmount(from text: String) -> Int { text.components(separatedBy: .whitespacesAndNewlines).filter { $0.contains("¥") }.reduce(0) { $0 + (Int($1.replacingOccurrences(of: "¥", with: "")) ?? 0) } }
    func parseSourceName(from t: String) -> String { for acc in accounts { if t.contains("@\(acc.name)") { return acc.name } }; return accounts.first?.name ?? "お財布" }
    
    func exportBackup() {
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        let dict = createFullBackupData()
        guard let finalData = try? encoder.encode(dict) else { return }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Paytter_FullBackup.json")
        try? finalData.write(to: tempURL)
        let av = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene, let rootVC = scene.windows.first?.rootViewController { av.popoverPresentationController?.sourceView = rootVC.view; rootVC.present(av, animated: true) }
    }

    func updateAppearance() {
        let bgColor = UIColor(Color(hex: themeBarBG)); let textColor = UIColor(Color(hex: themeBarText))
        let appearance = UINavigationBarAppearance(); appearance.configureWithOpaqueBackground(); appearance.backgroundColor = bgColor; appearance.titleTextAttributes = [.foregroundColor: textColor]; appearance.largeTitleTextAttributes = [.foregroundColor: textColor]
        UINavigationBar.appearance().standardAppearance = appearance; UINavigationBar.appearance().scrollEdgeAppearance = appearance; UINavigationBar.appearance().compactAppearance = appearance
        let tabAppearance = UITabBarAppearance(); tabAppearance.configureWithOpaqueBackground(); tabAppearance.backgroundColor = bgColor
        UITabBar.appearance().standardAppearance = tabAppearance; UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene { windowScene.windows.forEach { window in updateViewHierarchy(window.rootViewController); window.setNeedsLayout(); window.layoutIfNeeded() } }
    }
    private func updateViewHierarchy(_ vc: UIViewController?) {
        guard let vc = vc else { return }
        if let nav = vc as? UINavigationController { nav.navigationBar.standardAppearance = UINavigationBar.appearance().standardAppearance; nav.navigationBar.scrollEdgeAppearance = UINavigationBar.appearance().standardAppearance; nav.navigationBar.setNeedsLayout(); nav.navigationBar.layoutIfNeeded() }
        if let tab = vc as? UITabBarController { tab.tabBar.standardAppearance = UITabBar.appearance().standardAppearance; if #available(iOS 15.0, *) { tab.tabBar.scrollEdgeAppearance = UITabBar.appearance().scrollEdgeAppearance } }
        vc.children.forEach { updateViewHierarchy($0) }
    }
}
