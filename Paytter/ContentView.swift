import SwiftUI
import Foundation
import UniformTypeIdentifiers

// アラートの種類を定義
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

// ホーム画面の並び順を統合して管理するためのモデル
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
    @AppStorage("transactions_v4") var transactions: [Transaction] = []
    @AppStorage("accounts_v2") var accounts: [Account] = [
        Account(name: "お財布", balance: 0, type: .wallet),
        Account(name: "口座", balance: 0, type: .bank),
        Account(name: "ポイント", balance: 0, type: .point)
    ]
    @AppStorage("account_groups") var groups: [AccountGroup] = []
    
    @AppStorage("monthlyBudget") var monthlyBudget: Int = 50000
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    
    // --- テーマ設定データ ---
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_income") var themeIncome: String = "#FF19B219"
    @AppStorage("theme_expense") var themeExpense: String = "#FFFF3B30"
    @AppStorage("theme_holiday") var themeHoliday: String = "#FFFF3B30"
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_barBG") var themeBarBG: String = "#F8F8F8FF"
    @AppStorage("theme_barText") var themeBarText: String = "#FF000000"
    @AppStorage("theme_tabAccent") var themeTabAccent: String = "#FF007AFF"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"

    @State private var selection = 0
    @State private var isShowingInputSheet = false
    @State private var inputText: String = ""
    @State private var isShowingSwipeDeleteAlert = false
    @State private var transactionToDelete: Transaction?
    @State private var isShowingAccountCreator = false
    @State private var isShowingGroupCreator = false
    @State private var isShowingAccountDeleteAlert = false
    @State private var isShowingGroupDeleteAlert = false
    @State private var accountToDeleteIndex: IndexSet?
    @State private var groupToDeleteIndex: IndexSet?
    
    // ホーム並べ替えモードとドラッグ状態
    @State private var isHomeEditMode = false
    @State private var draggedItemId: String?
    @State private var dragOffset: CGFloat = 0 
    @State private var dragLastX: CGFloat?
    
    @AppStorage("show_total_assets") var showTotalAssets: Bool = true
    @AppStorage("home_display_order") var homeDisplayOrder: [String] = []
    @State private var homeItems: [HomeItem] = []
    
    @State private var activeAlert: ActiveAlert?
    @State private var isRestoringManual = false
    @State private var backupDateString = ""
    @State private var isShowingImporter = false
    @State private var pendingImportData: ([Transaction], [Account], String)?

    let appearancePublisher = NotificationCenter.default.publisher(for: NSNotification.Name("UpdateAppearance"))

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
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToHomeTab"))) { _ in
                self.selection = 0
            }
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
            case .reset:
                return Alert(title: Text("全リセット"), message: Text("全ての投稿とお財布設定を初期化します。"), primaryButton: .destructive(Text("リセット")) { resetAll() }, secondaryButton: .cancel(Text("キャンセル")))
            case .restore:
                return Alert(title: Text("バックアップの復元"), message: Text("\(isRestoringManual ? "手動":"自動")保存日時: \(backupDateString)\nデータを復元しますか？"), primaryButton: .destructive(Text("復元")) {
                    if let t = BackupManager.loadTransactions(isManual: isRestoringManual), let a = BackupManager.loadAccounts(isManual: isRestoringManual) {
                        transactions = t; accounts = a; recalculateBalances(); activeAlert = .completion("復元完了")
                    }
                }, secondaryButton: .cancel(Text("キャンセル")))
            case .save:
                return Alert(title: Text("バックアップの保存"), message: Text("現在の手動保存日時: \(backupDateString)\n現在のデータで上書きしますか？"), primaryButton: .default(Text("保存")) {
                    BackupManager.saveAll(transactions: transactions, accounts: accounts, isManual: true); activeAlert = .completion("保存完了")
                }, secondaryButton: .cancel(Text("キャンセル")))
            case .importConfirm:
                return Alert(title: Text("外部データの読込"), message: Text("保存日時: \(pendingImportData?.2 ?? "")\nデータを上書きしますか？"), primaryButton: .destructive(Text("読み込む")) {
                    if let d = pendingImportData { transactions = d.0; accounts = d.1; recalculateBalances(); activeAlert = .completion("読込完了") }; pendingImportData = nil
                }, secondaryButton: .cancel(Text("キャンセル")) { pendingImportData = nil })
            case .completion(let msg):
                return Alert(title: Text("完了"), message: Text(msg), dismissButton: .default(Text("OK")))
            }
        }
        .sheet(isPresented: $isShowingInputSheet) { 
            // 【変更】onPost に isExcluded を追加
            PostView(inputText: $inputText, isPresented: $isShowingInputSheet, initialDate: Date(), onPost: { isInc, nDate, isExc in addTransaction(isInc: isInc, date: nDate, isExcluded: isExc) }, transactions: transactions, accounts: accounts) 
        }
    }

    private var homeTab: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                Color(hex: themeBG).ignoresSafeArea()
                VStack(spacing: 0) {
                    VStack(spacing: 8) {
                        HStack(spacing: 10) {
                            ForEach(homeItems) { item in
                                Group {
                                    switch item {
                                    case .totalAssets:
                                        let totalB = accounts.reduce(0) { $0 + $1.balance }
                                        let totalD = accounts.reduce(0) { $0 + $1.diffAmount }
                                        BalanceView(title: "総資産", amount: totalB, color: Color(hex: themeBodyText), diff: totalD)
                                        
                                    case .account(let acc):
                                        if let currentAcc = accounts.first(where: { $0.id == acc.id }) {
                                            BalanceView(title: currentAcc.name, amount: currentAcc.balance, color: Color(hex: themeBodyText), diff: currentAcc.diffAmount)
                                        }
                                        
                                    case .group(let group):
                                        if let currentGroup = groups.first(where: { $0.id == group.id }) {
                                            let groupAccounts = accounts.filter { currentGroup.accountIds.contains($0.id) }
                                            let totalBalance = groupAccounts.reduce(0) { $0 + $1.balance }
                                            let totalDiff = groupAccounts.reduce(0) { $0 + $1.diffAmount }
                                            BalanceView(title: currentGroup.name, amount: totalBalance, color: Color(hex: themeBodyText), diff: totalDiff)
                                        }
                                    }
                                }
                                .background(draggedItemId == item.id ? Color(hex: themeMain).opacity(0.1) : Color.clear)
                                .cornerRadius(8)
                                .overlay(isHomeEditMode ? RoundedRectangle(cornerRadius: 8).stroke(Color(hex: themeMain).opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4])) : nil)
                                .offset(x: draggedItemId == item.id ? dragOffset : 0, y: 0)
                                .zIndex(draggedItemId == item.id ? 100 : 0)
                                .gesture(
                                    isHomeEditMode ? DragGesture(minimumDistance: 0, coordinateSpace: .global)
                                        .onChanged { value in
                                            if draggedItemId != item.id {
                                                draggedItemId = item.id
                                                dragLastX = value.location.x
                                                dragOffset = 0
                                            }
                                            guard let lastX = dragLastX else { return }
                                            let dx = value.location.x - lastX
                                            dragOffset += dx
                                            dragLastX = value.location.x
                                            
                                            if let idx = homeItems.firstIndex(where: { $0.id == item.id }) {
                                                let spacing: CGFloat = 10
                                                let padding: CGFloat = 32
                                                let spacingTotal = CGFloat(max(homeItems.count - 1, 0)) * spacing
                                                let availableWidth = UIScreen.main.bounds.width - padding - spacingTotal
                                                let itemWidth = availableWidth / CGFloat(max(homeItems.count, 1))
                                                let jumpDistance = itemWidth + spacing
                                                let threshold = jumpDistance * 0.5
                                                
                                                if dragOffset > threshold && idx < homeItems.count - 1 {
                                                    withAnimation(.easeInOut(duration: 0.2)) { 
                                                        homeItems.swapAt(idx, idx + 1)
                                                        dragOffset -= jumpDistance
                                                    }
                                                } else if dragOffset < -threshold && idx > 0 {
                                                    withAnimation(.easeInOut(duration: 0.2)) { 
                                                        homeItems.swapAt(idx, idx - 1)
                                                        dragOffset += jumpDistance
                                                    }
                                                }
                                            }
                                        }
                                        .onEnded { _ in
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                draggedItemId = nil
                                                dragOffset = 0
                                                dragLastX = nil
                                            }
                                            homeDisplayOrder = homeItems.map { $0.id }
                                        }
                                    : nil
                                )
                            }
                        }
                        .padding()
                    }
                    .background(Color(hex: themeBarBG).opacity(0.8))
                    
                    Divider()
                    List {
                        ForEach(transactions.sorted(by: { $0.date > $1.date })) { item in
                            ZStack {
                                NavigationLink(destination: TransactionDetailView(item: item, transactions: $transactions, accounts: $accounts)) { EmptyView() }.opacity(0)
                                TwitterRow(item: item)
                                    .opacity(item.date > Date() ? 0.6 : 1.0)
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(item.date > Date() ? Color.black.opacity(0.06) : Color(hex: themeBG))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button { transactionToDelete = item; isShowingSwipeDeleteAlert = true } label: { Text("削除") }.tint(.red)
                            }
                        }
                    }
                    .listStyle(.plain).scrollContentBackground(.hidden)
                    .refreshable { recalculateBalances() }
                }
                
                if !isHomeEditMode {
                    Button(action: { inputText = ""; isShowingInputSheet = true }) {
                        Image(systemName: "plus").font(.system(size: 22, weight: .bold)).foregroundColor(.white).frame(width: 56, height: 56).background(Color(hex: themeMain)).clipShape(Circle())
                    }.padding(20).padding(.bottom, 10)
                }
            }
            .navigationTitle("ホーム").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { withAnimation(.spring()) { isHomeEditMode.toggle() } }) {
                        Image(systemName: isHomeEditMode ? "checkmark.circle.fill" : "arrow.left.and.right.circle")
                            .foregroundColor(isHomeEditMode ? .green : Color(hex: themeMain))
                    }
                }
            }
            .toolbarBackground(Color(hex: themeBarBG), for: .navigationBar, .tabBar).toolbarBackground(.visible, for: .navigationBar, .tabBar)
            .alert("投稿を削除しますか？", isPresented: $isShowingSwipeDeleteAlert) {
                Button("キャンセル", role: .cancel) {}; Button("削除", role: .destructive) { if let t = transactionToDelete { transactions.removeAll(where: { $0.id == t.id }); recalculateBalances() } }
            }
        }
    }
    
    private var calendarTab: some View { NavigationView { CalendarView(transactions: $transactions, accounts: $accounts).navigationTitle("カレンダー").navigationBarTitleDisplayMode(.inline).toolbarBackground(Color(hex: themeBarBG), for: .navigationBar, .tabBar).toolbarBackground(.visible, for: .navigationBar, .tabBar) } }

    private var walletTab: some View { 
        NavigationView { 
            ZStack {
                Color(hex: themeBG).ignoresSafeArea()
                List { 
                    Section(header: Text("お財布の管理").foregroundColor(Color(hex: themeSubText))) { 
                        ForEach(Array(accounts.enumerated()), id: \.element.id) { index, acc in 
                            NavigationLink(destination: AccountEditView(account: $accounts[index], transactions: $transactions, allAccounts: accounts)) { 
                                HStack { Image(systemName: acc.type.icon).foregroundColor(Color(hex: themeBodyText).opacity(0.6)); Text(acc.name).foregroundColor(Color(hex: themeBodyText)); Spacer(); Text("¥\(acc.balance)").foregroundColor(Color(hex: themeBodyText).opacity(0.6)) } 
                            }
                        }
                        .onMove(perform: moveAccount)
                        .onDelete { accountToDeleteIndex = $0; isShowingAccountDeleteAlert = true }
                        
                        Button(action: { isShowingAccountCreator = true }) { Label("新しいお財布を追加", systemImage: "plus.circle") }.foregroundColor(Color(hex: themeMain))
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))

                    Section(header: Text("グループ設定").foregroundColor(Color(hex: themeSubText))) {
                        NavigationLink(destination: TotalAssetEditView(isVisible: $showTotalAssets)) {
                            HStack {
                                Image(systemName: "sum").foregroundColor(Color(hex: themeBodyText).opacity(0.6))
                                Text("総資産").foregroundColor(Color(hex: themeBodyText))
                                Spacer()
                                let totalB = accounts.reduce(0) { $0 + $1.balance }
                                Text("¥\(totalB)").foregroundColor(Color(hex: themeBodyText).opacity(0.6))
                            }
                        }
                        
                        ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                            NavigationLink(destination: AccountGroupEditView(group: $groups[index], accounts: $accounts)) {
                                HStack { 
                                    Image(systemName: "folder").foregroundColor(Color(hex: themeBodyText).opacity(0.6))
                                    Text(group.name).foregroundColor(Color(hex: themeBodyText))
                                    Spacer()
                                    let groupTotal = accounts.filter { group.accountIds.contains($0.id) }.reduce(0) { $0 + $1.balance }
                                    Text("¥\(groupTotal)").foregroundColor(Color(hex: themeBodyText).opacity(0.6))
                                }
                            }
                        }
                        .onMove(perform: moveGroup)
                        .onDelete { groupToDeleteIndex = $0; isShowingGroupDeleteAlert = true }
                        
                        Button(action: { isShowingGroupCreator = true }) { Label("新しいグループを追加", systemImage: "plus.circle") }.foregroundColor(Color(hex: themeMain))
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))

                    Section(header: Text("分析").foregroundColor(Color(hex: themeSubText))) { NavigationLink(destination: WalletAnalysisView(transactions: transactions)) { Label("今月の収支分析", systemImage: "chart.bar.xaxis").foregroundColor(Color(hex: themeBodyText)) } }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                }.scrollContentBackground(.hidden).listStyle(.insetGrouped) 
            }
            .navigationTitle("お財布").navigationBarTitleDisplayMode(.inline)
            .toolbar { EditButton().foregroundColor(Color(hex: themeMain)) }
            .toolbarBackground(Color(hex: themeBarBG), for: .navigationBar, .tabBar).toolbarBackground(.visible, for: .navigationBar, .tabBar)
            .sheet(isPresented: $isShowingAccountCreator) { AccountCreateView(accounts: $accounts, transactions: $transactions) }
            .sheet(isPresented: $isShowingGroupCreator) { AccountGroupCreateView(groups: $groups, accounts: $accounts) }
            .alert("お財布の削除", isPresented: $isShowingAccountDeleteAlert) {
                Button("キャンセル", role: .cancel){ accountToDeleteIndex = nil }
                Button("削除", role: .destructive){ 
                    if let o = accountToDeleteIndex { 
                        let accToDelete = accounts[o.first!]
                        for i in 0..<groups.count { groups[i].accountIds.removeAll(where: { $0 == accToDelete.id }) }
                        withAnimation { accounts.remove(atOffsets: o); recalculateBalances() } 
                    }; accountToDeleteIndex = nil 
                }
            }
            .alert("グループの削除", isPresented: $isShowingGroupDeleteAlert) {
                Button("キャンセル", role: .cancel){}; Button("削除", role: .destructive){ if let o = groupToDeleteIndex { withAnimation { groups.remove(atOffsets: o) } } }
            }
        } 
    }

    private var settingTab: some View { 
        NavigationView { 
            ZStack { 
                Color(hex: themeBG).ignoresSafeArea()
                List { 
                    Section(header: Text("カスタマイズ").foregroundColor(Color(hex: themeSubText))) { 
                        NavigationLink(destination: UserProfileSettingView()) { Label("表示ユーザー設定", systemImage: "person.crop.circle").foregroundColor(Color(hex: themeBodyText)) }
                        NavigationLink(destination: ThemeSettingView()) { Label("テーマ設定", systemImage: "paintpalette").foregroundColor(Color(hex: themeBodyText)) } 
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    Section(header: Text("予算設定").foregroundColor(Color(hex: themeSubText))) { Stepper("今月の予算: ¥\(monthlyBudget)", value: $monthlyBudget, in: 1000...500000, step: 1000).foregroundColor(Color(hex: themeBodyText)) }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    Section(header: Text("バックアップ管理").foregroundColor(Color(hex: themeSubText))) { 
                        Button("手動保存") { backupDateString = BackupManager.getBackupDate(isManual: true); activeAlert = .save }.foregroundColor(Color(hex: themeBodyText))
                        Button("手動保存から復元") { isRestoringManual = true; backupDateString = BackupManager.getBackupDate(isManual: true); activeAlert = .restore }.foregroundColor(Color(hex: themeBodyText))
                        Button("自動保存から復元") { isRestoringManual = false; backupDateString = BackupManager.getBackupDate(isManual: false); activeAlert = .restore }.foregroundColor(Color(hex: themeBodyText))
                        Button("バックアップを共有 (外部に書き出す)") { exportBackup() }.foregroundColor(Color(hex: themeMain))
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

    func moveAccount(from source: IndexSet, to destination: Int) { accounts.move(fromOffsets: source, toOffset: destination) }
    func moveGroup(from source: IndexSet, to destination: Int) { groups.move(fromOffsets: source, toOffset: destination) }

    func syncHomeItems() {
        if draggedItemId != nil { return } 
        var items: [HomeItem] = []
        if showTotalAssets { items.append(.totalAssets) }
        items.append(contentsOf: accounts.filter({ $0.isVisible }).map { .account($0) })
        items.append(contentsOf: groups.filter({ $0.isVisible }).map { .group($0) })
        
        items.sort { item1, item2 in
            let idx1 = homeDisplayOrder.firstIndex(of: item1.id) ?? Int.max
            let idx2 = homeDisplayOrder.firstIndex(of: item2.id) ?? Int.max
            return idx1 < idx2
        }
        homeItems = items
    }

    func handleImport(from url: URL) {
        guard let data = try? Data(contentsOf: url), let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let txStr = json["transactions"] as? String, let accStr = json["accounts"] as? String, let dateStr = json["date"] as? String else { return }
        let dec = JSONDecoder(); if let t = try? dec.decode([Transaction].self, from: txStr.data(using: .utf8)!), let a = try? dec.decode([Account].self, from: accStr.data(using: .utf8)!) { self.pendingImportData = (t, a, dateStr); self.activeAlert = .importConfirm }
    }
    
    func resetAll() { transactions = []; accounts = [Account(name: "お財布", balance: 0, type: .wallet), Account(name: "口座", balance: 0, type: .bank), Account(name: "ポイント", balance: 0, type: .point)]; groups = []; monthlyBudget = 50000; recalculateBalances(); activeAlert = .completion("リセット完了") }
    
    // 【変更】isExcluded を追加
    func addTransaction(isInc: Bool, date: Date, isExcluded: Bool) { transactions.append(Transaction(amount: parseAmount(from: inputText), date: date, note: inputText, source: parseSourceName(from: inputText), isIncome: isInc, isExcludedFromBalance: isExcluded)); recalculateBalances() }

    // 【変更】isExcludedFromBalance が true のものは加算しないように修正
    func recalculateBalances() { 
        for i in 0..<accounts.count { 
            var cur = 0; 
            for tx in transactions where tx.source == accounts[i].name && !tx.isExcludedFromBalance { 
                cur += (tx.isIncome ? tx.amount : -tx.amount) 
            }; 
            accounts[i].diffAmount = cur - accounts[i].balance; 
            accounts[i].balance = cur 
        }; 
        BackupManager.saveAll(transactions: transactions, accounts: accounts, isManual: false) 
    }

    func parseAmount(from text: String) -> Int { text.components(separatedBy: .whitespacesAndNewlines).filter { $0.contains("¥") }.reduce(0) { $0 + (Int($1.replacingOccurrences(of: "¥", with: "")) ?? 0) } }
    func parseSourceName(from t: String) -> String { for acc in accounts { if t.contains("@\(acc.name)") { return acc.name } }; return accounts.first?.name ?? "お財布" }
    
    func exportBackup() {
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        let dict: [String: Any] = ["transactions": String(data: (try? encoder.encode(transactions)) ?? Data(), encoding: .utf8) ?? "", "accounts": String(data: (try? encoder.encode(accounts)) ?? Data(), encoding: .utf8) ?? "", "date": BackupManager.getBackupDate(isManual: true)]
        guard let finalData = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted) else { return }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Paytter_Backup.json")
        try? finalData.write(to: tempURL)
        let av = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene, let rootVC = scene.windows.first?.rootViewController {
            av.popoverPresentationController?.sourceView = rootVC.view
            rootVC.present(av, animated: true)
        }
    }

    func updateAppearance() {
        let bgColor = UIColor(Color(hex: themeBarBG)); let textColor = UIColor(Color(hex: themeBarText))
        let appearance = UINavigationBarAppearance(); appearance.configureWithOpaqueBackground(); appearance.backgroundColor = bgColor; appearance.titleTextAttributes = [.foregroundColor: textColor]; appearance.largeTitleTextAttributes = [.foregroundColor: textColor]
        UINavigationBar.appearance().standardAppearance = appearance; UINavigationBar.appearance().scrollEdgeAppearance = appearance; UINavigationBar.appearance().compactAppearance = appearance
        let tabAppearance = UITabBarAppearance(); tabAppearance.configureWithOpaqueBackground(); tabAppearance.backgroundColor = bgColor
        UITabBar.appearance().standardAppearance = tabAppearance; UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.windows.forEach { window in updateViewHierarchy(window.rootViewController); window.setNeedsLayout(); window.layoutIfNeeded() }
        }
    }

    private func updateViewHierarchy(_ vc: UIViewController?) {
        guard let vc = vc else { return }
        if let nav = vc as? UINavigationController { nav.navigationBar.standardAppearance = UINavigationBar.appearance().standardAppearance; nav.navigationBar.scrollEdgeAppearance = UINavigationBar.appearance().standardAppearance; nav.navigationBar.setNeedsLayout(); nav.navigationBar.layoutIfNeeded() }
        if let tab = vc as? UITabBarController { tab.tabBar.standardAppearance = UITabBar.appearance().standardAppearance; if #available(iOS 15.0, *) { tab.tabBar.scrollEdgeAppearance = UITabBar.appearance().scrollEdgeAppearance } }
        vc.children.forEach { updateViewHierarchy($0) }
    }
}
