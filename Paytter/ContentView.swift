import SwiftUI
import Foundation
import UniformTypeIdentifiers

enum ActiveAlert: Identifiable {
    case reset, restore, save, importConfirm, completion(String)
    var id: String {
        switch self {
        case .reset: return "reset"
        case .restore: return "restore"
        case .save: return "save"
        case .importConfirm: return "import"
        case .completion(let m): return m
        }
    }
}

enum HomeItem: Identifiable, Equatable {
    case totalAssets
    case account(Account)
    case group(AccountGroup)
    var id: String {
        switch self {
        case .totalAssets: return "TOTAL_ASSETS"
        case .account(let a): return "ACCOUNT_\(a.id.uuidString)"
        case .group(let g): return "GROUP_\(g.id.uuidString)"
        }
    }
}

struct ContentView: View {
    // 全てのAppStorageをContentViewで管理する（保存と復元のため）
    @AppStorage("transactions_v4") var transactions: [Transaction] = []
    @AppStorage("accounts_v2") var accounts: [Account] = [
        Account(name: "お財布", balance: 0, type: .wallet),
        Account(name: "口座", balance: 0, type: .bank),
        Account(name: "ポイント", balance: 0, type: .point)
    ]
    @AppStorage("account_groups") var groups: [AccountGroup] = []
    
    @AppStorage("monthlyBudget") var monthlyBudget: Int = 50000
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_income") var themeIncome: String = "#FF19B219"
    @AppStorage("theme_expense") var themeExpense: String = "#FFFF3B30"
    @AppStorage("theme_holiday") var themeHoliday: String = "#FFFF3B30"
    @AppStorage("theme_saturday") var themeSaturday: String = "#FF007AFF"
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_barBG") var themeBarBG: String = "#F8F8F8FF"
    @AppStorage("theme_barText") var themeBarText: String = "#FF000000"
    @AppStorage("theme_tabAccent") var themeTabAccent: String = "#FF007AFF"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    @AppStorage("userName") var userName: String = "むつき"
    @AppStorage("userId") var userId: String = "Mutsuki_dev"
    @AppStorage("userIconData") var userIconData: Data = Data()
    @AppStorage("show_total_assets") var showTotalAssets: Bool = true
    @AppStorage("home_display_order") var homeDisplayOrder: [String] = []

    @State private var selection = 0
    @State private var activeAlert: ActiveAlert?
    @State private var isRestoringManual = false
    @State private var pendingImportDataV2: FullBackupData?
    @State private var backupDateString = ""

    let appearancePublisher = NotificationCenter.default.publisher(for: NSNotification.Name("UpdateAppearance"))

    var body: some View {
        ZStack {
            Color(hex: themeBG).ignoresSafeArea()
            TabView(selection: $selection) {
                // コンパイラ負荷を下げるため独立したViewを呼び出す
                HomeTabView(transactions: $transactions, accounts: $accounts, groups: $groups)
                    .tag(0).tabItem { Label("ホーム", systemImage: "house") }
                
                NavigationView { CalendarView(transactions: $transactions, accounts: $accounts) }
                    .tag(1).tabItem { Label("カレンダー", systemImage: "calendar") }
                
                WalletTabView(transactions: $transactions, accounts: $accounts, groups: $groups)
                    .tag(2).tabItem { Label("お財布", systemImage: "wallet.pass") }
                
                // 設定タブに全データを渡す
                SettingTabView(transactions: $transactions, accounts: $accounts, groups: $groups, activeAlert: $activeAlert, isRestoringManual: $isRestoringManual, backupDateString: $backupDateString, pendingImportDataV2: $pendingImportDataV2, createFullBackup: createFullBackupData, applyFullBackup: applyFullBackup)
                    .tag(3).tabItem { Label("設定", systemImage: "gearshape") }
            }
            .accentColor(Color(hex: themeTabAccent))
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToHomeTab"))) { _ in self.selection = 0 }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .onAppear { recalculateBalances(); updateAppearance() }
        .onReceive(appearancePublisher) { _ in updateAppearance() }
        // 【重要】配列が変更されたときのみ、1回だけ計算を走らせる（2重計算を防ぎ、増減エフェクトを復活させる）
        .onChange(of: transactions) { _ in recalculateBalances() }
        .onChange(of: themeBarBG) { _ in updateAppearance() }
        .onChange(of: isDarkMode) { _ in updateAppearance() }
        .alert(item: $activeAlert) { type in createAlert(type: type) }
    }
    
    // 計算除外フラグを考慮した残高計算
    func recalculateBalances() { 
        var tempAccounts = accounts
        for i in 0..<tempAccounts.count { 
            var cur = 0; 
            for tx in transactions where tx.source == tempAccounts[i].name { 
                if tx.isExcludedFromBalance == true { continue }
                cur += (tx.isIncome ? tx.amount : -tx.amount) 
            }
            tempAccounts[i].diffAmount = cur - tempAccounts[i].balance; 
            tempAccounts[i].balance = cur 
        }
        accounts = tempAccounts
        BackupManager.saveFullBackup(data: createFullBackupData(), isManual: false)
    }

    func createFullBackupData() -> FullBackupData {
        return FullBackupData(
            transactions: transactions, accounts: accounts, groups: groups,
            monthlyBudget: monthlyBudget, isDarkMode: isDarkMode, themeMain: themeMain, themeIncome: themeIncome,
            themeExpense: themeExpense, themeHoliday: themeHoliday, themeSaturday: themeSaturday, themeBG: themeBG,
            themeBarBG: themeBarBG, themeBarText: themeBarText, themeTabAccent: themeTabAccent, themeBodyText: themeBodyText,
            themeSubText: themeSubText, userName: userName, userId: userId, userIconData: userIconData,
            showTotalAssets: showTotalAssets, homeDisplayOrder: homeDisplayOrder, backupDate: BackupManager.currentDateString()
        )
    }
    
    func applyFullBackup(_ backup: FullBackupData) {
        transactions = backup.transactions; accounts = backup.accounts; groups = backup.groups
        monthlyBudget = backup.monthlyBudget; isDarkMode = backup.isDarkMode
        themeMain = backup.themeMain; themeIncome = backup.themeIncome; themeExpense = backup.themeExpense
        themeHoliday = backup.themeHoliday; themeSaturday = backup.themeSaturday; themeBG = backup.themeBG
        themeBarBG = backup.themeBarBG; themeBarText = backup.themeBarText; themeTabAccent = backup.themeTabAccent
        themeBodyText = backup.themeBodyText; themeSubText = backup.themeSubText
        userName = backup.userName; userId = backup.userId
        if let icon = backup.userIconData { userIconData = icon }
        showTotalAssets = backup.showTotalAssets; homeDisplayOrder = backup.homeDisplayOrder
        recalculateBalances()
        updateAppearance()
    }

    func createAlert(type: ActiveAlert) -> Alert {
        switch type {
        case .reset: return Alert(title: Text("全リセット"), message: Text("全てのデータを初期化します。"), primaryButton: .destructive(Text("リセット")) { transactions = []; accounts = [Account(name: "お財布", balance: 0, type: .wallet), Account(name: "口座", balance: 0, type: .bank), Account(name: "ポイント", balance: 0, type: .point)]; groups = []; monthlyBudget = 50000; activeAlert = .completion("リセット完了") }, secondaryButton: .cancel(Text("キャンセル")))
        case .restore: return Alert(title: Text("バックアップの復元"), message: Text("\(isRestoringManual ? "手動":"自動")保存日時: \(backupDateString)\nデータを復元しますか？"), primaryButton: .destructive(Text("復元")) {
            if let b = BackupManager.loadFullBackup(isManual: isRestoringManual) { applyFullBackup(b); activeAlert = .completion("復元完了") }
            else if let t = BackupManager.loadTransactions(isManual: isRestoringManual), let a = BackupManager.loadAccounts(isManual: isRestoringManual) { transactions = t; accounts = a; recalculateBalances(); activeAlert = .completion("復元完了(旧形式)") }
        }, secondaryButton: .cancel(Text("キャンセル")))
        case .save: return Alert(title: Text("バックアップの保存"), message: Text("現在の手動保存日時: \(backupDateString)\n現在のデータで上書きしますか？"), primaryButton: .default(Text("保存")) { BackupManager.saveFullBackup(data: createFullBackupData(), isManual: true); activeAlert = .completion("保存完了") }, secondaryButton: .cancel(Text("キャンセル")))
        case .importConfirm: return Alert(title: Text("外部データの読込"), message: Text("保存日時: \(pendingImportDataV2?.backupDate ?? "")\nデータを上書きしますか？"), primaryButton: .destructive(Text("読み込む")) { if let d = pendingImportDataV2 { applyFullBackup(d); activeAlert = .completion("読込完了") }; pendingImportDataV2 = nil }, secondaryButton: .cancel(Text("キャンセル")) { pendingImportDataV2 = nil })
        case .completion(let msg): return Alert(title: Text("完了"), message: Text(msg), dismissButton: .default(Text("OK")))
        }
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

// MARK: - 分離されたタブビュー群（コンパイラ負荷軽減のため）

struct HomeTabView: View {
    @Binding var transactions: [Transaction]; @Binding var accounts: [Account]; @Binding var groups: [AccountGroup]
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"; @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"; @AppStorage("theme_barBG") var themeBarBG: String = "#F8F8F8FF"; @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"; @AppStorage("show_total_assets") var showTotalAssets: Bool = true; @AppStorage("home_display_order") var homeDisplayOrder: [String] = []
    
    @State private var isShowingInputSheet = false; @State private var inputText: String = ""; @State private var isShowingSwipeDeleteAlert = false; @State private var transactionToDelete: Transaction?; @State private var isHomeEditMode = false; @State private var draggedItemId: String?; @State private var dragOffset: CGFloat = 0; @State private var dragLastX: CGFloat?
    @State private var homeItems: [HomeItem] = []
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                Color(hex: themeBG).ignoresSafeArea()
                VStack(spacing: 0) {
                    VStack(spacing: 8) {
                        HStack(spacing: 10) { ForEach(homeItems) { item in DraggableHomeItem(item: item, accounts: accounts, groups: groups, draggedItemId: $draggedItemId, dragOffset: $dragOffset, dragLastX: $dragLastX, homeItems: $homeItems, homeDisplayOrder: $homeDisplayOrder, isHomeEditMode: isHomeEditMode, themeMain: themeMain, themeBodyText: themeBodyText) } }.padding()
                        if isHomeEditMode { Text("横にスライドして並べ替えられます").font(.caption2).foregroundColor(Color(hex: themeMain)).padding(.bottom, 4) }
                    }.background(Color(hex: themeBarBG).opacity(0.8))
                    Divider()
                    List {
                        ForEach(transactions.sorted(by: { $0.date > $1.date })) { item in
                            TransactionRowView(item: item, transactions: $transactions, accounts: $accounts, transactionToDelete: $transactionToDelete, isShowingSwipeDeleteAlert: $isShowingSwipeDeleteAlert, themeBG: themeBG)
                        }
                    }.listStyle(.plain).scrollContentBackground(.hidden)
                }
                if !isHomeEditMode { Button(action: { inputText = ""; isShowingInputSheet = true }) { Image(systemName: "plus").font(.system(size: 22, weight: .bold)).foregroundColor(.white).frame(width: 56, height: 56).background(Color(hex: themeMain)).clipShape(Circle()) }.padding(20).padding(.bottom, 10) }
            }.navigationTitle("ホーム").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button(action: { withAnimation(.spring()) { isHomeEditMode.toggle() } }) { Image(systemName: isHomeEditMode ? "checkmark.circle.fill" : "arrow.left.and.right.circle").foregroundColor(isHomeEditMode ? .green : Color(hex: themeMain)) } } }.toolbarBackground(Color(hex: themeBarBG), for: .navigationBar, .tabBar).toolbarBackground(.visible, for: .navigationBar, .tabBar).alert("削除しますか？", isPresented: $isShowingSwipeDeleteAlert) { Button("キャンセル", role: .cancel) {}; Button("削除", role: .destructive) { if let t = transactionToDelete { transactions.removeAll(where: { $0.id == t.id }) } } }
        }.onAppear { syncHomeItems() }.onChange(of: accounts) { _ in syncHomeItems() }.onChange(of: groups) { _ in syncHomeItems() }.onChange(of: showTotalAssets) { _ in syncHomeItems() }.sheet(isPresented: $isShowingInputSheet) { PostView(inputText: $inputText, isPresented: $isShowingInputSheet, initialDate: Date(), isExcludedInitial: false, onPost: { isInc, nDate, isExc in transactions.append(Transaction(amount: parseAmount(from: inputText), date: nDate, note: inputText, source: parseSourceName(from: inputText), isIncome: isInc, isExcludedFromBalance: isExc)) }, transactions: transactions, accounts: accounts) }
    }
    func syncHomeItems() { if draggedItemId != nil { return }; var items: [HomeItem] = []; if showTotalAssets { items.append(.totalAssets) }; items.append(contentsOf: accounts.filter({ $0.isVisible }).map { .account($0) }); items.append(contentsOf: groups.filter({ $0.isVisible }).map { .group($0) }); items.sort { i1, i2 in let idx1 = homeDisplayOrder.firstIndex(of: i1.id) ?? Int.max; let idx2 = homeDisplayOrder.firstIndex(of: i2.id) ?? Int.max; return idx1 < idx2 }; homeItems = items }
    func parseAmount(from t: String) -> Int { t.components(separatedBy: .whitespacesAndNewlines).filter { $0.contains("¥") }.reduce(0) { $0 + (Int($1.replacingOccurrences(of: "¥", with: "")) ?? 0) } }
    func parseSourceName(from t: String) -> String { for acc in accounts { if t.contains("@\(acc.name)") { return acc.name } }; return accounts.first?.name ?? "お財布" }
}

struct DraggableHomeItem: View {
    let item: HomeItem; let accounts: [Account]; let groups: [AccountGroup]
    @Binding var draggedItemId: String?; @Binding var dragOffset: CGFloat; @Binding var dragLastX: CGFloat?; @Binding var homeItems: [HomeItem]; @Binding var homeDisplayOrder: [String]
    let isHomeEditMode: Bool; let themeMain: String; let themeBodyText: String
    var body: some View {
        Group {
            switch item {
            case .totalAssets: let b = accounts.reduce(0) { $0 + $1.balance }; let d = accounts.reduce(0) { $0 + $1.diffAmount }; BalanceView(title: "総資産", amount: b, color: Color(hex: themeBodyText), diff: d)
            case .account(let a): if let c = accounts.first(where: { $0.id == a.id }) { BalanceView(title: c.name, amount: c.balance, color: Color(hex: themeBodyText), diff: c.diffAmount) }
            case .group(let g): if let c = groups.first(where: { $0.id == g.id }) { let accs = accounts.filter { c.accountIds.contains($0.id) }; let b = accs.reduce(0) { $0 + $1.balance }; let d = accs.reduce(0) { $0 + $1.diffAmount }; BalanceView(title: c.name, amount: b, color: Color(hex: themeBodyText), diff: d) }
            }
        }.background(draggedItemId == item.id ? Color(hex: themeMain).opacity(0.1) : Color.clear).cornerRadius(8).overlay(isHomeEditMode ? RoundedRectangle(cornerRadius: 8).stroke(Color(hex: themeMain).opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4])) : nil).offset(x: draggedItemId == item.id ? dragOffset : 0).zIndex(draggedItemId == item.id ? 100 : 0).gesture(isHomeEditMode ? DragGesture(minimumDistance: 0, coordinateSpace: .global).onChanged { value in if draggedItemId != item.id { draggedItemId = item.id; dragLastX = value.location.x; dragOffset = 0 }; guard let lastX = dragLastX else { return }; dragOffset += value.location.x - lastX; dragLastX = value.location.x; if let idx = homeItems.firstIndex(where: { $0.id == item.id }) { let jumpDistance = (UIScreen.main.bounds.width - 32 - CGFloat(max(homeItems.count - 1, 0)) * 10) / CGFloat(max(homeItems.count, 1)) + 10; let threshold = jumpDistance * 0.5; if dragOffset > threshold && idx < homeItems.count - 1 { withAnimation(.easeInOut(duration: 0.2)) { homeItems.swapAt(idx, idx + 1); dragOffset -= jumpDistance } } else if dragOffset < -threshold && idx > 0 { withAnimation(.easeInOut(duration: 0.2)) { homeItems.swapAt(idx, idx - 1); dragOffset += jumpDistance } } } }.onEnded { _ in withAnimation(.easeInOut(duration: 0.2)) { draggedItemId = nil; dragOffset = 0; dragLastX = nil }; homeDisplayOrder = homeItems.map { $0.id } } : nil)
    }
}

struct TransactionRowView: View {
    let item: Transaction; @Binding var transactions: [Transaction]; @Binding var accounts: [Account]; @Binding var transactionToDelete: Transaction?; @Binding var isShowingSwipeDeleteAlert: Bool; let themeBG: String
    var body: some View {
        let isFuture = item.date > Date()
        ZStack { NavigationLink(destination: TransactionDetailView(item: item, transactions: $transactions, accounts: $accounts)) { EmptyView() }.opacity(0); TwitterRow(item: item).opacity(isFuture ? 0.6 : 1.0) }.listRowInsets(EdgeInsets()).listRowBackground(isFuture ? Color.black.opacity(0.06) : Color(hex: themeBG)).swipeActions(edge: .trailing, allowsFullSwipe: false) { Button { transactionToDelete = item; isShowingSwipeDeleteAlert = true } label: { Text("削除") }.tint(.red) }
    }
}

struct WalletTabView: View {
    @Binding var transactions: [Transaction]; @Binding var accounts: [Account]; @Binding var groups: [AccountGroup]
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"; @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"; @AppStorage("theme_barBG") var themeBarBG: String = "#F8F8F8FF"; @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"; @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"; @AppStorage("show_total_assets") var showTotalAssets: Bool = true
    @State private var isShowingAccountCreator = false; @State private var isShowingGroupCreator = false; @State private var isShowingAccountDeleteAlert = false; @State private var isShowingGroupDeleteAlert = false; @State private var accountToDeleteIndex: IndexSet?; @State private var groupToDeleteIndex: IndexSet?
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: themeBG).ignoresSafeArea()
                List {
                    Section(header: Text("お財布の管理").foregroundColor(Color(hex: themeSubText))) { ForEach(Array(accounts.enumerated()), id: \.element.id) { i, acc in NavigationLink(destination: AccountEditView(account: $accounts[i], transactions: $transactions, allAccounts: accounts)) { HStack { Image(systemName: acc.type.icon).foregroundColor(Color(hex: themeBodyText).opacity(0.6)); Text(acc.name).foregroundColor(Color(hex: themeBodyText)); Spacer(); Text("¥\(acc.balance)").foregroundColor(Color(hex: themeBodyText).opacity(0.6)) } } }.onMove { src, dst in accounts.move(fromOffsets: src, toOffset: dst) }.onDelete { accountToDeleteIndex = $0; isShowingAccountDeleteAlert = true }; Button(action: { isShowingAccountCreator = true }) { Label("新しいお財布を追加", systemImage: "plus.circle") }.foregroundColor(Color(hex: themeMain)) }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    Section(header: Text("グループ設定").foregroundColor(Color(hex: themeSubText))) { NavigationLink(destination: TotalAssetEditView(isVisible: $showTotalAssets)) { HStack { Image(systemName: "sum").foregroundColor(Color(hex: themeBodyText).opacity(0.6)); Text("総資産").foregroundColor(Color(hex: themeBodyText)); Spacer(); let b = accounts.reduce(0) { $0 + $1.balance }; Text("¥\(b)").foregroundColor(Color(hex: themeBodyText).opacity(0.6)) } }; ForEach(Array(groups.enumerated()), id: \.element.id) { i, g in NavigationLink(destination: AccountGroupEditView(group: $groups[i], accounts: $accounts)) { HStack { Image(systemName: "folder").foregroundColor(Color(hex: themeBodyText).opacity(0.6)); Text(g.name).foregroundColor(Color(hex: themeBodyText)); Spacer(); let b = accounts.filter { g.accountIds.contains($0.id) }.reduce(0) { $0 + $1.balance }; Text("¥\(b)").foregroundColor(Color(hex: themeBodyText).opacity(0.6)) } } }.onMove { src, dst in groups.move(fromOffsets: src, toOffset: dst) }.onDelete { groupToDeleteIndex = $0; isShowingGroupDeleteAlert = true }; Button(action: { isShowingGroupCreator = true }) { Label("新しいグループを追加", systemImage: "plus.circle") }.foregroundColor(Color(hex: themeMain)) }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    Section(header: Text("分析").foregroundColor(Color(hex: themeSubText))) { NavigationLink(destination: WalletAnalysisView(transactions: transactions)) { Label("今月の収支分析", systemImage: "chart.bar.xaxis").foregroundColor(Color(hex: themeBodyText)) } }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                }.scrollContentBackground(.hidden).listStyle(.insetGrouped)
            }.navigationTitle("お財布").navigationBarTitleDisplayMode(.inline).toolbar { EditButton().foregroundColor(Color(hex: themeMain)) }.toolbarBackground(Color(hex: themeBarBG), for: .navigationBar, .tabBar).toolbarBackground(.visible, for: .navigationBar, .tabBar).sheet(isPresented: $isShowingAccountCreator) { AccountCreateView(accounts: $accounts, transactions: $transactions) }.sheet(isPresented: $isShowingGroupCreator) { AccountGroupCreateView(groups: $groups, accounts: $accounts) }.alert("お財布の削除", isPresented: $isShowingAccountDeleteAlert) { Button("キャンセル", role: .cancel){ accountToDeleteIndex = nil }; Button("削除", role: .destructive){ if let o = accountToDeleteIndex { let acc = accounts[o.first!]; for i in 0..<groups.count { groups[i].accountIds.removeAll(where: { $0 == acc.id }) }; withAnimation { accounts.remove(atOffsets: o) } }; accountToDeleteIndex = nil } }.alert("グループの削除", isPresented: $isShowingGroupDeleteAlert) { Button("キャンセル", role: .cancel){}; Button("削除", role: .destructive){ if let o = groupToDeleteIndex { withAnimation { groups.remove(atOffsets: o) } } } }
        }
    }
}

struct SettingTabView: View {
    @Binding var transactions: [Transaction]; @Binding var accounts: [Account]; @Binding var groups: [AccountGroup]; @Binding var activeAlert: ActiveAlert?; @Binding var isRestoringManual: Bool; @Binding var backupDateString: String; @Binding var pendingImportDataV2: FullBackupData?
    var createFullBackup: () -> FullBackupData
    var applyFullBackup: (FullBackupData) -> Void
    
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"; @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"; @AppStorage("theme_barBG") var themeBarBG: String = "#F8F8F8FF"; @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"; @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"; @AppStorage("monthlyBudget") var monthlyBudget: Int = 50000
    @State private var isShowingImporter = false
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: themeBG).ignoresSafeArea()
                List {
                    Section(header: Text("カスタマイズ").foregroundColor(Color(hex: themeSubText))) { NavigationLink(destination: UserProfileSettingView()) { Label("表示ユーザー設定", systemImage: "person.crop.circle").foregroundColor(Color(hex: themeBodyText)) }; NavigationLink(destination: ThemeSettingView()) { Label("テーマ設定", systemImage: "paintpalette").foregroundColor(Color(hex: themeBodyText)) } }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    Section(header: Text("予算設定").foregroundColor(Color(hex: themeSubText))) { Stepper("今月の予算: ¥\(monthlyBudget)", value: $monthlyBudget, in: 1000...500000, step: 1000).foregroundColor(Color(hex: themeBodyText)) }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    Section(header: Text("バックアップ管理").foregroundColor(Color(hex: themeSubText))) { Button("手動保存") { backupDateString = BackupManager.getBackupDate(isManual: true); activeAlert = .save }.foregroundColor(Color(hex: themeBodyText)); Button("手動保存から復元") { isRestoringManual = true; backupDateString = BackupManager.getBackupDate(isManual: true); activeAlert = .restore }.foregroundColor(Color(hex: themeBodyText)); Button("自動保存から復元") { isRestoringManual = false; backupDateString = BackupManager.getBackupDate(isManual: false); activeAlert = .restore }.foregroundColor(Color(hex: themeBodyText)); Button("バックアップを共有 (全データ)") { exportBackup() }.foregroundColor(Color(hex: themeMain)); Button("外部から読み込む") { isShowingImporter = true }.foregroundColor(Color(hex: themeMain)) }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    Section(header: Text("データ管理").foregroundColor(Color(hex: themeSubText))) { Button("全データをリセット", role: .destructive) { activeAlert = .reset } }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                }.scrollContentBackground(.hidden).listStyle(.insetGrouped)
            }.navigationTitle("設定").navigationBarTitleDisplayMode(.inline).toolbarBackground(Color(hex: themeBarBG), for: .navigationBar, .tabBar).toolbarBackground(.visible, for: .navigationBar, .tabBar).fileImporter(isPresented: $isShowingImporter, allowedContentTypes: [.json]) { r in if case .success(let u) = r { if u.startAccessingSecurityScopedResource() { handleImport(from: u); u.stopAccessingSecurityScopedResource() } } }
        }
    }
    func handleImport(from url: URL) { guard let data = try? Data(contentsOf: url) else { return }; if let v2 = try? JSONDecoder().decode(FullBackupData.self, from: data) { pendingImportDataV2 = v2; activeAlert = .importConfirm; return }; guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let txStr = json["transactions"] as? String, let accStr = json["accounts"] as? String, let dec = try? JSONDecoder().decode([Transaction].self, from: txStr.data(using: .utf8)!), let aDec = try? JSONDecoder().decode([Account].self, from: accStr.data(using: .utf8)!) else { return }; let fd = createFullBackup(); pendingImportDataV2 = FullBackupData(transactions: dec, accounts: aDec, groups: fd.groups, monthlyBudget: fd.monthlyBudget, isDarkMode: fd.isDarkMode, themeMain: fd.themeMain, themeIncome: fd.themeIncome, themeExpense: fd.themeExpense, themeHoliday: fd.themeHoliday, themeSaturday: fd.themeSaturday, themeBG: fd.themeBG, themeBarBG: fd.themeBarBG, themeBarText: fd.themeBarText, themeTabAccent: fd.themeTabAccent, themeBodyText: fd.themeBodyText, themeSubText: fd.themeSubText, userName: fd.userName, userId: fd.userId, userIconData: fd.userIconData, showTotalAssets: fd.showTotalAssets, homeDisplayOrder: fd.homeDisplayOrder, backupDate: "以前の形式"); activeAlert = .importConfirm }
    func exportBackup() { let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted; let dict = createFullBackup(); guard let finalData = try? encoder.encode(dict) else { return }; let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Paytter_FullBackup.json"); try? finalData.write(to: tempURL); let av = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil); if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene, let rootVC = scene.windows.first?.rootViewController { av.popoverPresentationController?.sourceView = rootVC.view; rootVC.present(av, animated: true) } }
}
