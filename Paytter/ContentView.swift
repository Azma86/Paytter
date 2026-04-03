import SwiftUI
import Foundation
import UniformTypeIdentifiers

struct ContentView: View {
    @AppStorage("transactions_v4") var transactions: [Transaction] = []
    @AppStorage("accounts_v2") var accounts: [Account] = [
        Account(name: "お財布", balance: 0, type: .wallet),
        Account(name: "口座", balance: 0, type: .bank),
        Account(name: "ポイント", balance: 0, type: .point)
    ]
    @AppStorage("account_groups") var groups: [AccountGroup] = []
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_barBG") var themeBarBG: String = "#F8F8F8FF"
    @AppStorage("theme_barText") var themeBarText: String = "#FF000000"
    @AppStorage("theme_tabAccent") var themeTabAccent: String = "#FF007AFF"

    @State private var selection = 0
    let appearancePublisher = NotificationCenter.default.publisher(for: NSNotification.Name("UpdateAppearance"))

    var body: some View {
        ZStack {
            Color(hex: themeBG).ignoresSafeArea()
            TabView(selection: $selection) {
                // コンパイラエラー回避のため、各タブの内容を別パーツとして定義
                HomeTabView(transactions: $transactions, accounts: $accounts, groups: $groups)
                    .tag(0).tabItem { Label("ホーム", systemImage: "house") }
                
                NavigationView { CalendarView(transactions: $transactions, accounts: $accounts) }
                    .tag(1).tabItem { Label("カレンダー", systemImage: "calendar") }
                
                WalletTabView(transactions: $transactions, accounts: $accounts, groups: $groups)
                    .tag(2).tabItem { Label("お財布", systemImage: "wallet.pass") }
                
                SettingTabView(transactions: $transactions, accounts: $accounts, groups: $groups)
                    .tag(3).tabItem { Label("設定", systemImage: "gearshape") }
            }
            .accentColor(Color(hex: themeTabAccent))
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToHomeTab"))) { _ in self.selection = 0 }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .onAppear { recalculateBalances(); updateAppearance() }
        .onReceive(appearancePublisher) { _ in updateAppearance() }
        .onChange(of: transactions) { _ in recalculateBalances() }
        .onChange(of: themeBarBG) { _ in updateAppearance() }
        .onChange(of: isDarkMode) { _ in updateAppearance() }
    }
    
    // 【重要】残高計算ロジック：除外フラグが立っている投稿をスキップします
    func recalculateBalances() { 
        for i in 0..<accounts.count { 
            var cur = 0
            for tx in transactions where tx.source == accounts[i].name && !tx.isExcludedFromBalance { 
                cur += (tx.isIncome ? tx.amount : -tx.amount) 
            }
            accounts[i].diffAmount = cur - accounts[i].balance
            accounts[i].balance = cur 
        }
        BackupManager.saveAll(transactions: transactions, accounts: accounts, isManual: false) 
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

// --- 以下、コンパイラ負荷を分散するためのサブビュー定義 ---

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
                        HStack(spacing: 10) { ForEach(homeItems) { item in homeHeaderItem(for: item).background(draggedItemId == item.id ? Color(hex: themeMain).opacity(0.1) : Color.clear).cornerRadius(8).overlay(isHomeEditMode ? RoundedRectangle(cornerRadius: 8).stroke(Color(hex: themeMain).opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4])) : nil).offset(x: draggedItemId == item.id ? dragOffset : 0).zIndex(draggedItemId == item.id ? 100 : 0).gesture(isHomeEditMode ? DragGesture(minimumDistance: 0, coordinateSpace: .global).onChanged { v in if draggedItemId != item.id { draggedItemId = item.id; dragLastX = v.location.x; dragOffset = 0 }; guard let lx = dragLastX else { return }; let dx = v.location.x - lx; dragOffset += dx; dragLastX = v.location.x; if let idx = homeItems.firstIndex(where: { $0.id == item.id }) { let jD = (UIScreen.main.bounds.width - 32 - CGFloat(max(homeItems.count - 1, 0)) * 10) / CGFloat(max(homeItems.count, 1)) + 10; let th = jD * 0.5; if dragOffset > th && idx < homeItems.count - 1 { withAnimation(.easeInOut(duration: 0.2)) { homeItems.swapAt(idx, idx + 1); dragOffset -= jD } } else if dragOffset < -th && idx > 0 { withAnimation(.easeInOut(duration: 0.2)) { homeItems.swapAt(idx, idx - 1); dragOffset += jD } } } }.onEnded { _ in withAnimation(.easeInOut(duration: 0.2)) { draggedItemId = nil; dragOffset = 0; dragLastX = nil }; homeDisplayOrder = homeItems.map { $0.id } } : nil) } }
                        .padding()
                    }.background(Color(hex: themeBarBG).opacity(0.8))
                    Divider()
                    List { ForEach(transactions.sorted(by: { $0.date > $1.date })) { item in let isFuture = item.date > Date(); ZStack { NavigationLink(destination: TransactionDetailView(item: item, transactions: $transactions, accounts: $accounts)) { EmptyView() }.opacity(0); TwitterRow(item: item).opacity(isFuture ? 0.6 : 1.0) }.listRowInsets(EdgeInsets()).listRowBackground(isFuture ? Color.black.opacity(0.06) : Color(hex: themeBG)).swipeActions(edge: .trailing, allowsFullSwipe: false) { Button { transactionToDelete = item; isShowingSwipeDeleteAlert = true } label: { Text("削除") }.tint(.red) } } }.listStyle(.plain).scrollContentBackground(.hidden).refreshable { NotificationCenter.default.post(name: NSNotification.Name("UpdateAppearance"), object: nil) }
                }
                if !isHomeEditMode { Button(action: { inputText = ""; isShowingInputSheet = true }) { Image(systemName: "plus").font(.system(size: 22, weight: .bold)).foregroundColor(.white).frame(width: 56, height: 56).background(Color(hex: themeMain)).clipShape(Circle()) }.padding(20).padding(.bottom, 10) }
            }.navigationTitle("ホーム").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button(action: { withAnimation(.spring()) { isHomeEditMode.toggle() } }) { Image(systemName: isHomeEditMode ? "checkmark.circle.fill" : "arrow.left.and.right.circle").foregroundColor(isHomeEditMode ? .green : Color(hex: themeMain)) } } }.toolbarBackground(Color(hex: themeBarBG), for: .navigationBar, .tabBar).toolbarBackground(.visible, for: .navigationBar, .tabBar).alert("削除しますか？", isPresented: $isShowingSwipeDeleteAlert) { Button("キャンセル", role: .cancel) {}; Button("削除", role: .destructive) { if let t = transactionToDelete { transactions.removeAll(where: { $0.id == t.id }) } } }
        }.onAppear { syncHomeItems() }.onChange(of: accounts) { _ in syncHomeItems() }.onChange(of: groups) { _ in syncHomeItems() }.onChange(of: showTotalAssets) { _ in syncHomeItems() }.sheet(isPresented: $isShowingInputSheet) { PostView(inputText: $inputText, isPresented: $isShowingInputSheet, initialDate: Date(), onPost: { isInc, nDate, isExc in transactions.append(Transaction(amount: parseAmount(from: inputText), date: nDate, note: inputText, source: parseSourceName(from: inputText), isIncome: isInc, isExcludedFromBalance: isExc)) }, transactions: transactions, accounts: accounts) }
    }
    @ViewBuilder private func homeHeaderItem(for item: HomeItem) -> some View {
        switch item {
        case .totalAssets: let b = accounts.reduce(0) { $0 + $1.balance }; let d = accounts.reduce(0) { $0 + $1.diffAmount }; BalanceView(title: "総資産", amount: b, color: Color(hex: themeBodyText), diff: d)
        case .account(let a): if let c = accounts.first(where: { $0.id == a.id }) { BalanceView(title: c.name, amount: c.balance, color: Color(hex: themeBodyText), diff: c.diffAmount) } else { EmptyView() }
        case .group(let g): if let c = groups.first(where: { $0.id == g.id }) { let accs = accounts.filter { c.accountIds.contains($0.id) }; let b = accs.reduce(0) { $0 + $1.balance }; let d = accs.reduce(0) { $0 + $1.diffAmount }; BalanceView(title: c.name, amount: b, color: Color(hex: themeBodyText), diff: d) } else { EmptyView() }
        }
    }
    func syncHomeItems() { if draggedItemId != nil { return }; var items: [HomeItem] = []; if showTotalAssets { items.append(.totalAssets) }; items.append(contentsOf: accounts.filter({ $0.isVisible }).map { .account($0) }); items.append(contentsOf: groups.filter({ $0.isVisible }).map { .group($0) }); items.sort { i1, i2 in let idx1 = homeDisplayOrder.firstIndex(of: i1.id) ?? Int.max; let idx2 = homeDisplayOrder.firstIndex(of: i2.id) ?? Int.max; return idx1 < idx2 }; homeItems = items }
    func parseAmount(from t: String) -> Int { t.components(separatedBy: .whitespacesAndNewlines).filter { $0.contains("¥") }.reduce(0) { $0 + (Int($1.replacingOccurrences(of: "¥", with: "")) ?? 0) } }
    func parseSourceName(from t: String) -> String { for acc in accounts { if t.contains("@\(acc.name)") { return acc.name } }; return accounts.first?.name ?? "お財布" }
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
    @Binding var transactions: [Transaction]; @Binding var accounts: [Account]; @Binding var groups: [AccountGroup]
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"; @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"; @AppStorage("theme_barBG") var themeBarBG: String = "#F8F8F8FF"; @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"; @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"; @AppStorage("monthlyBudget") var monthlyBudget: Int = 50000
    @State private var activeAlert: ActiveAlert?; @State private var isRestoringManual = false; @State private var backupDateString = ""; @State private var isShowingImporter = false; @State private var pendingImportData: ([Transaction], [Account], String)?
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: themeBG).ignoresSafeArea()
                List {
                    Section(header: Text("カスタマイズ").foregroundColor(Color(hex: themeSubText))) { NavigationLink(destination: UserProfileSettingView()) { Label("表示ユーザー設定", systemImage: "person.crop.circle").foregroundColor(Color(hex: themeBodyText)) }; NavigationLink(destination: ThemeSettingView()) { Label("テーマ設定", systemImage: "paintpalette").foregroundColor(Color(hex: themeBodyText)) } }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    Section(header: Text("予算設定").foregroundColor(Color(hex: themeSubText))) { Stepper("今月の予算: ¥\(monthlyBudget)", value: $monthlyBudget, in: 1000...500000, step: 1000).foregroundColor(Color(hex: themeBodyText)) }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    Section(header: Text("バックアップ管理").foregroundColor(Color(hex: themeSubText))) { Button("手動保存") { backupDateString = BackupManager.getBackupDate(isManual: true); activeAlert = .save }.foregroundColor(Color(hex: themeBodyText)); Button("手動保存から復元") { isRestoringManual = true; backupDateString = BackupManager.getBackupDate(isManual: true); activeAlert = .restore }.foregroundColor(Color(hex: themeBodyText)); Button("自動保存から復元") { isRestoringManual = false; backupDateString = BackupManager.getBackupDate(isManual: false); activeAlert = .restore }.foregroundColor(Color(hex: themeBodyText)); Button("バックアップを共有") { exportBackup() }.foregroundColor(Color(hex: themeMain)); Button("外部から読み込む") { isShowingImporter = true }.foregroundColor(Color(hex: themeMain)) }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    Section(header: Text("データ管理").foregroundColor(Color(hex: themeSubText))) { Button("全データをリセット", role: .destructive) { activeAlert = .reset } }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                }.scrollContentBackground(.hidden).listStyle(.insetGrouped)
            }.navigationTitle("設定").navigationBarTitleDisplayMode(.inline).toolbarBackground(Color(hex: themeBarBG), for: .navigationBar, .tabBar).toolbarBackground(.visible, for: .navigationBar, .tabBar).fileImporter(isPresented: $isShowingImporter, allowedContentTypes: [.json]) { r in if case .success(let u) = r { if u.startAccessingSecurityScopedResource() { handleImport(from: u); u.stopAccessingSecurityScopedResource() } } }
        }.alert(item: $activeAlert) { type in switch type { case .reset: return Alert(title: Text("リセット"), message: Text("初期化します"), primaryButton: .destructive(Text("リセット")) { transactions = []; accounts = [Account(name: "お財布", balance: 0, type: .wallet), Account(name: "口座", balance: 0, type: .bank), Account(name: "ポイント", balance: 0, type: .point)]; groups = []; monthlyBudget = 50000 }, secondaryButton: .cancel()) case .restore: return Alert(title: Text("復元"), message: Text("復元しますか？"), primaryButton: .destructive(Text("復元")) { if let t = BackupManager.loadTransactions(isManual: isRestoringManual), let a = BackupManager.loadAccounts(isManual: isRestoringManual) { transactions = t; accounts = a } }, secondaryButton: .cancel()) case .save: return Alert(title: Text("保存"), message: Text("現在のデータで上書きしますか？"), primaryButton: .default(Text("保存")) { BackupManager.saveAll(transactions: transactions, accounts: accounts, isManual: true) }, secondaryButton: .cancel()) case .importConfirm: return Alert(title: Text("読込"), message: Text("上書きしますか？"), primaryButton: .destructive(Text("読込")) { if let d = pendingImportData { transactions = d.0; accounts = d.1 }; pendingImportData = nil }, secondaryButton: .cancel()) case .completion(let msg): return Alert(title: Text("完了"), message: Text(msg)) } }
    }
    func handleImport(from url: URL) { guard let data = try? Data(contentsOf: url), let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let txStr = json["transactions"] as? String, let accStr = json["accounts"] as? String, let dateStr = json["date"] as? String else { return }; let dec = JSONDecoder(); if let t = try? dec.decode([Transaction].self, from: txStr.data(using: .utf8)!), let a = try? dec.decode([Account].self, from: accStr.data(using: .utf8)!) { self.pendingImportData = (t, a, dateStr); self.activeAlert = .importConfirm } }
    func exportBackup() { let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted; let dict: [String: Any] = ["transactions": String(data: (try? encoder.encode(transactions)) ?? Data(), encoding: .utf8) ?? "", "accounts": String(data: (try? encoder.encode(accounts)) ?? Data(), encoding: .utf8) ?? "", "date": BackupManager.getBackupDate(isManual: true)]; guard let finalData = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted) else { return }; let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Paytter_Backup.json"); try? finalData.write(to: tempURL); let av = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil); if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene, let rootVC = scene.windows.first?.rootViewController { av.popoverPresentationController?.sourceView = rootVC.view; rootVC.present(av, animated: true) } }
}
