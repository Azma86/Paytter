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
    @AppStorage("monthlyBudget") var monthlyBudget: Int = 50000
    
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
    @State private var isShowingAccountDeleteAlert = false
    @State private var accountToDeleteIndex: IndexSet?
    
    @State private var isShowingResetAlert = false
    @State private var isShowingRestoreConfirm = false
    @State private var isShowingSaveConfirm = false
    @State private var isRestoringManual = false
    @State private var backupDateString = ""
    @State private var isShowingCompletionAlert = false
    @State private var completionMessage = ""
    
    @State private var isShowingImporter = false
    @State private var pendingImportData: ([Transaction], [Account], String)?
    @State private var isShowingImportConfirm = false

    var body: some View {
        TabView(selection: $selection) {
            homeTab.tag(0).tabItem { Label("ホーム", systemImage: "house") }
            calendarTab.tag(1).tabItem { Label("カレンダー", systemImage: "calendar") }
            walletTab.tag(2).tabItem { Label("お財布", systemImage: "wallet.pass") }
            settingTab.tag(3).tabItem { Label("設定", systemImage: "gearshape") }
        }
        .accentColor(Color(hex: themeTabAccent))
        .onAppear { recalculateBalances(); updateAppearance() }
        .onChange(of: transactions) { _ in recalculateBalances() }
        .onChange(of: themeBarBG) { _ in updateAppearance() }
        .onChange(of: themeBarText) { _ in updateAppearance() }
        .sheet(isPresented: $isShowingInputSheet) { 
            PostView(inputText: $inputText, isPresented: $isShowingInputSheet, initialDate: Date(), onPost: { isInc, nDate in addTransaction(isInc: isInc, date: nDate) }, transactions: transactions, accounts: accounts) 
        }
    }

    private var homeTab: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                Color(hex: themeBG).ignoresSafeArea()
                VStack(spacing: 0) {
                    HStack(spacing: 15) {
                        ForEach(accounts.filter { $0.isVisible }) { acc in
                            BalanceView(title: acc.name, amount: acc.balance, color: Color(hex: themeBodyText), diff: acc.diffAmount)
                        }
                    }.padding().background(Color(hex: themeBarBG).opacity(0.8))
                    Divider()
                    List {
                        ForEach(transactions.sorted(by: { $0.date > $1.date })) { item in
                            ZStack {
                                NavigationLink(destination: TransactionDetailView(item: item, transactions: $transactions, accounts: $accounts)) { EmptyView() }.opacity(0)
                                TwitterRow(item: item)
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color(hex: themeBG))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button { transactionToDelete = item; isShowingSwipeDeleteAlert = true } label: { Text("削除") }.tint(.red)
                            }
                        }
                    }.listStyle(.plain).scrollContentBackground(.hidden)
                }
                Button(action: { inputText = ""; isShowingInputSheet = true }) {
                    Image(systemName: "plus").font(.system(size: 22, weight: .bold)).foregroundColor(.white).frame(width: 56, height: 56).background(Color(hex: themeMain)).clipShape(Circle())
                }.padding(20).padding(.bottom, 10)
            }
            .navigationTitle("ホーム").navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: themeBarBG), for: .navigationBar, .tabBar)
            .toolbarBackground(.visible, for: .navigationBar, .tabBar)
            .alert("投稿を削除しますか？", isPresented: $isShowingSwipeDeleteAlert) {
                Button("キャンセル", role: .cancel) { }; Button("削除", role: .destructive) { if let t = transactionToDelete { withAnimation(.easeOut(duration: 0.2)) { deleteSpecificTransaction(t) } } }
            } message: { if let t = transactionToDelete { Text(t.cleanNote).foregroundColor(Color(hex: themeBodyText)) } }
        }
    }
    
    private var calendarTab: some View { 
        NavigationView { 
            CalendarView(transactions: $transactions, accounts: $accounts)
                .toolbarBackground(Color(hex: themeBarBG), for: .navigationBar, .tabBar)
                .toolbarBackground(.visible, for: .navigationBar, .tabBar)
        } 
    }

    private var walletTab: some View { 
        NavigationView { 
            ZStack {
                Color(hex: themeBG).ignoresSafeArea()
                List { 
                    Section(header: Text("お財布の管理").foregroundColor(Color(hex: themeSubText))) { 
                        ForEach(Array(accounts.enumerated()), id: \.element.id) { index, acc in 
                            NavigationLink(destination: AccountEditView(account: $accounts[index], transactions: $transactions, allAccounts: accounts)) { 
                                HStack { 
                                    Image(systemName: acc.type.icon).foregroundColor(Color(hex: themeBodyText).opacity(0.6))
                                    Text(acc.name).foregroundColor(Color(hex: themeBodyText))
                                    Spacer()
                                    Text("¥\(acc.balance)").foregroundColor(Color(hex: themeBodyText).opacity(0.6))
                                } 
                            }.swipeActions(edge: .trailing, allowsFullSwipe: false) { 
                                Button { accountToDeleteIndex = IndexSet(integer: index); isShowingAccountDeleteAlert = true } label: { Text("削除") }.tint(.red) 
                            } 
                        }
                        Button(action: { isShowingAccountCreator = true }) { Label("新しいお財布を追加", systemImage: "plus.circle") }.foregroundColor(Color(hex: themeMain))
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    Section(header: Text("分析").foregroundColor(Color(hex: themeSubText))) { 
                        NavigationLink(destination: WalletAnalysisView(transactions: transactions)) { 
                            Label("今月の収支分析", systemImage: "chart.bar.xaxis").foregroundColor(Color(hex: themeBodyText))
                        } 
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5)) 
                }.scrollContentBackground(.hidden).listStyle(.insetGrouped) 
            }
            .navigationTitle("お財布")
            .toolbarBackground(Color(hex: themeBarBG), for: .navigationBar, .tabBar)
            .toolbarBackground(.visible, for: .navigationBar, .tabBar)
            .sheet(isPresented: $isShowingAccountCreator) { AccountCreateView(accounts: $accounts, transactions: $transactions) }
            .alert("削除", isPresented: $isShowingAccountDeleteAlert) {
                Button("キャンセル", role: .cancel){}; Button("削除", role: .destructive){ if let o = accountToDeleteIndex { withAnimation { accounts.remove(atOffsets: o); recalculateBalances() } } }
            } message: { Text("このお財布に関連付けられた投稿の金額計算ができなくなる可能性があります。") }
        } 
    }

    private var settingTab: some View { 
        NavigationView { 
            ZStack { 
                Color(hex: themeBG).ignoresSafeArea()
                List { 
                    Section(header: Text("カスタマイズ").foregroundColor(Color(hex: themeSubText))) { 
                        NavigationLink(destination: ThemeSettingView()) { Label("テーマ設定", systemImage: "paintpalette").foregroundColor(Color(hex: themeBodyText)) } 
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    Section(header: Text("予算設定").foregroundColor(Color(hex: themeSubText))) { 
                        Stepper(value: $monthlyBudget, in: 1000...500000, step: 1000) {
                            Text("今月の予算: ¥\(monthlyBudget)").foregroundColor(Color(hex: themeBodyText))
                        }
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    Section(header: Text("バックアップ管理").foregroundColor(Color(hex: themeSubText))) { 
                        Button("手動バックアップを作成") { backupDateString = BackupManager.getBackupDate(isManual: true); isShowingSaveConfirm = true }.foregroundColor(Color(hex: themeBodyText))
                        Button("手動バックアップから復元") { isRestoringManual = true; backupDateString = BackupManager.getBackupDate(isManual: true); isShowingRestoreConfirm = true }.foregroundColor(Color(hex: themeBodyText))
                        Button("自動保存から復元") { isRestoringManual = false; backupDateString = BackupManager.getBackupDate(isManual: false); isShowingRestoreConfirm = true }.foregroundColor(Color(hex: themeBodyText))
                        Button("バックアップを共有") { exportBackup() }.foregroundColor(Color(hex: themeMain))
                        Button("外部から読み込み") { isShowingImporter = true }.foregroundColor(Color(hex: themeMain))
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    Section(header: Text("データ管理").foregroundColor(Color(hex: themeSubText))) { 
                        Button("全データをリセット", role: .destructive) { isShowingResetAlert = true } 
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5)) 
                }.scrollContentBackground(.hidden).listStyle(.insetGrouped) 
            }
            .navigationTitle("設定")
            .toolbarBackground(Color(hex: themeBarBG), for: .navigationBar, .tabBar)
            .toolbarBackground(.visible, for: .navigationBar, .tabBar)
            .alert("バックアップの上書き", isPresented: $isShowingSaveConfirm) {
                Button("キャンセル", role: .cancel) { }; Button("上書き保存") { BackupManager.saveAll(transactions: transactions, accounts: accounts, isManual: true); completionMessage = "手動バックアップの保存が完了しました。"; isShowingCompletionAlert = true }
            } message: { Text("前回の手動保存日時: \(backupDateString)\n現在のデータでお財布設定と投稿を上書きしますか？") }
            .alert("バックアップの復元", isPresented: $isShowingRestoreConfirm) {
                Button("キャンセル", role: .cancel) { }
                Button("復元する", role: .destructive) { if let t = BackupManager.loadTransactions(isManual: isRestoringManual), let a = BackupManager.loadAccounts(isManual: isRestoringManual) { transactions = t; accounts = a; recalculateBalances(); completionMessage = "\(isRestoringManual ? "手動バックアップ" : "自動保存ファイル")からの復元が完了しました。"; isShowingCompletionAlert = true } }
            } message: { Text("\(isRestoringManual ? "手動" : "自動")保存日時: \(backupDateString)\n現在のデータを上書きしますか？") }
            .alert("リセット", isPresented: $isShowingResetAlert) {
                Button("キャンセル", role: .cancel) { }; Button("初期化する", role: .destructive) { resetAll(); completionMessage = "全てのデータを初期状態にリセットしました。"; isShowingCompletionAlert = true }
            } message: { Text("全ての投稿、お財布設定、予算を初期状態に戻します。バックアップファイルは保護されます。") }
            .alert("外部バックアップの読み込み", isPresented: $isShowingImportConfirm) {
                Button("キャンセル", role: .cancel) { pendingImportData = nil }
                Button("復元する", role: .destructive) {
                    if let data = pendingImportData {
                        transactions = data.0; accounts = data.1; recalculateBalances()
                        completionMessage = "外部バックアップからの復元が完了しました。"; isShowingCompletionAlert = true
                    }
                    pendingImportData = nil
                }
            } message: { if let data = pendingImportData { Text("選択されたファイルの保存日時: \(data.2)\n現在のデータを上書きしてもよろしいですか？") } }
            .alert("完了", isPresented: $isShowingCompletionAlert) { Button("OK") { } } message: { Text(completionMessage) }
            .fileImporter(isPresented: $isShowingImporter, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url): if url.startAccessingSecurityScopedResource() { handleImport(from: url); url.stopAccessingSecurityScopedResource() }
                case .failure(let error): print(error.localizedDescription)
                }
            }
        } 
    }

    func handleImport(from url: URL) {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let txStr = json["transactions"] as? String,
              let accStr = json["accounts"] as? String,
              let dateStr = json["date"] as? String else { return }
        let dec = JSONDecoder()
        if let t = try? dec.decode([Transaction].self, from: txStr.data(using: .utf8)!),
           let a = try? dec.decode([Account].self, from: accStr.data(using: .utf8)!) {
            self.pendingImportData = (t, a, dateStr); self.isShowingImportConfirm = true
        }
    }
    func addTransaction(isInc: Bool, date: Date) { transactions.append(Transaction(amount: parseAmount(from: inputText), date: date, note: inputText, source: parseSourceName(from: inputText), isIncome: isInc)) }
    func deleteSpecificTransaction(_ target: Transaction) { if let index = transactions.firstIndex(where: { $0.id == target.id }) { transactions.remove(at: index) } }
    func recalculateBalances() { for i in 0..<accounts.count { var cur = 0; for tx in transactions where tx.source == accounts[i].name { cur += (tx.isIncome ? tx.amount : -tx.amount) }; accounts[i].diffAmount = cur - accounts[i].balance; accounts[i].balance = cur }; BackupManager.saveAll(transactions: transactions, accounts: accounts, isManual: false) }
    func resetAll() { transactions = []; accounts = [Account(name: "お財布", balance: 0, type: .wallet), Account(name: "口座", balance: 0, type: .bank), Account(name: "ポイント", balance: 0, type: .point)]; monthlyBudget = 50000 }
    func parseAmount(from text: String) -> Int { text.components(separatedBy: .whitespacesAndNewlines).filter { $0.contains("¥") }.reduce(0) { $0 + (Int($1.replacingOccurrences(of: "¥", with: "")) ?? 0) } }
    func parseSourceName(from t: String) -> String { for acc in accounts { if t.contains("@\(acc.name)") { return acc.name } }; return accounts.first?.name ?? "お財布" }

    func exportBackup() {
        let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("manual_transactions.json")
        if !FileManager.default.fileExists(atPath: path.path) { BackupManager.saveAll(transactions: transactions, accounts: accounts, isManual: true) }
        let av = UIActivityViewController(activityItems: [path], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene, let rootVC = windowScene.windows.first?.rootViewController { rootVC.present(av, animated: true) }
    }

    func updateAppearance() {
        let bgColor = UIColor(Color(hex: themeBarBG)); let textColor = UIColor(Color(hex: themeBarText))
        let accentColor = UIColor(Color(hex: themeTabAccent))
        
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = bgColor
        // ここでタイトルの色を「メニュー文字色」に強制指定
        navBarAppearance.titleTextAttributes = [.foregroundColor: textColor]
        navBarAppearance.largeTitleTextAttributes = [.foregroundColor: textColor]
        
        // 戻るボタンなどのパーツ色（themeMainと連動させると自然です）
        let backButtonAppearance = UIBarButtonItemAppearance()
        backButtonAppearance.normal.titleTextAttributes = [.foregroundColor: textColor]
        navBarAppearance.backButtonAppearance = backButtonAppearance
        
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().tintColor = textColor // 戻るアイコンの色
        
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = bgColor
        UITabBar.appearance().standardAppearance = tabBarAppearance
    }
}

// --- テーマ設定画面 ---
struct ThemeSettingView: View {
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
    
    @AppStorage("theme_base_main") var baseMain: String = "#FF007AFF"
    @AppStorage("theme_base_inc") var baseInc: String = "#FF19B219"
    @AppStorage("theme_base_exp") var baseExp: String = "#FFFF3B30"
    @AppStorage("theme_base_hol") var baseHol: String = "#FFFF3B30"
    @AppStorage("theme_base_bg") var baseBG: String = "#FFFFFFFF"
    @AppStorage("theme_base_barBG") var baseBarBG: String = "#F8F8F8FF"
    @AppStorage("theme_base_barText") var baseBarText: String = "#FF000000"
    @AppStorage("theme_base_tab") var baseTab: String = "#FF007AFF"
    @AppStorage("theme_base_body") var baseBody: String = "#FF000000"
    @AppStorage("theme_base_sub") var baseSub: String = "#FF8E8E93"

    var body: some View {
        ZStack {
            Color(hex: themeBG).ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        presetBtn("デフォルト", "#FF007AFF", "#FF19B219", "#FFFF3B30", "#FFFF3B30", "#FFFFFFFF", "#F8F8F8FF", "#FF000000", "#FF007AFF", "#FF000000", "#FF8E8E93")
                        presetBtn("ダーク", "#FF0A84FF", "#FF19B219", "#FFFF3B30", "#FFFF453A", "#FF000000", "#FF1C1C1E", "#FFFFFFFF", "#FF0A84FF", "#FFFFFFFF", "#FF8E8E93")
                        presetBtn("ナチュラル", "#FF6B8E23", "#FF19B219", "#FFFF3B30", "#EB4E3D", "#FFF5F5DC", "#FFE4E4D0", "#FF4B3621", "#FF6B8E23", "#FF4B3621", "#FF999988")
                        presetBtn("モノクロ", "#FF333333", "#FF19B219", "#FFFF3B30", "#FF999999", "#FFFFFFFF", "#FFF2F2F2", "#FF000000", "#FF000000", "#FF000000", "#FF999999")
                        presetBtn("カフェ", "#FF8B4513", "#FF19B219", "#FFFF3B30", "#EB4E3D", "#FFFFF8DC", "#FFDEB887", "#FF3E2723", "#FF8B4513", "#FF3E2723", "#FFA08878")
                    }.padding(.horizontal, 20).padding(.vertical, 16)
                }.background(Color(hex: themeBarBG).opacity(0.5))
                Divider()
                List {
                    Section(header: Text("全体設定").foregroundColor(Color(hex: themeSubText))) {
                        colorRow(title: "背景色", hex: $themeBG, base: baseBG)
                        colorRow(title: "メニュー背景色", hex: $themeBarBG, base: baseBarBG)
                        colorRow(title: "メニュー文字色", hex: $themeBarText, base: baseBarText)
                        colorRow(title: "本文文字色", hex: $themeBodyText, base: baseBody)
                        colorRow(title: "サブ文字色", hex: $themeSubText, base: baseSub)
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    Section(header: Text("フッターメニュー").foregroundColor(Color(hex: themeSubText))) {
                        colorRow(title: "メニュー選択色", hex: $themeTabAccent, base: baseTab)
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    Section(header: Text("個別パーツ").foregroundColor(Color(hex: themeSubText))) {
                        colorRow(title: "メインカラー", hex: $themeMain, base: baseMain)
                        colorRow(title: "収入の色", hex: $themeIncome, base: baseInc)
                        colorRow(title: "支出の色", hex: $themeExpense, base: baseExp)
                        colorRow(title: "祝日の色", hex: $themeHoliday, base: baseHol)
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                }.scrollContentBackground(.hidden).listStyle(.insetGrouped)
            }
        }
        .navigationTitle("テーマ設定").navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(hex: themeBarBG), for: .navigationBar, .tabBar).toolbarBackground(.visible, for: .navigationBar, .tabBar)
    }
    func presetBtn(_ name: String, _ main: String, _ inc: String, _ exp: String, _ hol: String, _ bg: String, _ barBG: String, _ barTxt: String, _ tab: String, _ body: String, _ sub: String) -> some View {
        Button(action: { apply(main, inc, exp, hol, bg, barBG, barTxt, tab, body, sub) }) {
            VStack(spacing: 8) {
                Circle().fill(Color(hex: main)).frame(width: 46, height: 46).overlay(Circle().stroke(Color(hex: themeBarText).opacity(0.2), lineWidth: 1))
                Text(name).font(.system(size: 10, weight: .medium)).foregroundColor(Color(hex: themeSubText))
            }
        }.buttonStyle(.plain)
    }
    func apply(_ main: String, _ inc: String, _ exp: String, _ hol: String, _ bg: String, _ barBG: String, _ barTxt: String, _ tab: String, _ body: String, _ sub: String) {
        withAnimation {
            themeMain = main; themeIncome = inc; themeExpense = exp; themeHoliday = hol; themeBG = bg; themeBarBG = barBG; themeBarText = barTxt; themeTabAccent = tab; themeBodyText = body; themeSubText = sub
            baseMain = main; baseInc = inc; baseExp = exp; baseHol = hol; baseBG = bg; baseBarBG = barBG; baseBarText = barTxt; baseTab = tab; baseBody = body; baseSub = sub
        }
    }
    func colorRow(title: String, hex: Binding<String>, base: String) -> some View {
        HStack { ColorPicker(title, selection: Binding(get: { Color(hex: hex.wrappedValue) }, set: { hex.wrappedValue = $0.toHex() })).foregroundColor(Color(hex: themeBodyText)); Spacer(); if hex.wrappedValue != base { Button(action: { hex.wrappedValue = base }) { Image(systemName: "arrow.counterclockwise.circle.fill").foregroundColor(Color(hex: themeSubText).opacity(0.8)).font(.title3) }.buttonStyle(.plain) } }
    }
}
