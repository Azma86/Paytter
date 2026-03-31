import SwiftUI
import Foundation

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

    var body: some View {
        TabView {
            homeTab.tabItem { Label("ホーム", systemImage: "house") }
            calendarTab.tabItem { Label("カレンダー", systemImage: "calendar") }
            walletTab.tabItem { Label("お財布", systemImage: "wallet.pass") }
            settingTab.tabItem { Label("設定", systemImage: "gearshape") }
        }
        .accentColor(Color(hex: themeTabAccent))
        .onAppear { recalculateBalances(); updateAppearance() }
        .onChange(of: transactions) { _ in recalculateBalances() }
        // テーマ変更を検知して即座にシステムバーを更新
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
                            BalanceView(title: acc.name, amount: acc.balance, color: Color(hex: themeBarText), diff: acc.diffAmount)
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
            .alert("投稿を削除しますか？", isPresented: $isShowingSwipeDeleteAlert) {
                Button("キャンセル", role: .cancel) { }; Button("削除", role: .destructive) { if let t = transactionToDelete { withAnimation(.easeOut(duration: 0.2)) { deleteSpecificTransaction(t) } } }
            } message: { if let t = transactionToDelete { Text(t.cleanNote) } }
        }
    }
    
    private var calendarTab: some View { NavigationView { CalendarView(transactions: $transactions, accounts: $accounts) } }
    private var walletTab: some View { NavigationView { ZStack { Color(hex: themeBG).ignoresSafeArea(); List { Section(header: Text("お財布の管理")) { ForEach(Array(accounts.enumerated()), id: \.element.id) { index, acc in NavigationLink(destination: AccountEditView(account: $accounts[index], transactions: $transactions, allAccounts: accounts)) { HStack { Image(systemName: acc.type.icon).foregroundColor(.secondary); Text(acc.name); Spacer(); Text("¥\(acc.balance)").foregroundColor(.secondary) } }.swipeActions(edge: .trailing, allowsFullSwipe: false) { Button { accountToDeleteIndex = IndexSet(integer: index); isShowingAccountDeleteAlert = true } label: { Text("削除") }.tint(.red) } }; Button(action: { isShowingAccountCreator = true }) { Label("新しいお財布を追加", systemImage: "plus.circle") } }.listRowBackground(Color(hex: themeBG).opacity(0.5)); Section(header: Text("分析")) { NavigationLink(destination: WalletAnalysisView(transactions: transactions)) { Label("今月の収支分析", systemImage: "chart.bar.xaxis") } }.listRowBackground(Color(hex: themeBG).opacity(0.5)) }.scrollContentBackground(.hidden).listStyle(.insetGrouped) }.navigationTitle("お財布").sheet(isPresented: $isShowingAccountCreator) { AccountCreateView(accounts: $accounts, transactions: $transactions) }.alert("削除", isPresented: $isShowingAccountDeleteAlert) { Button("キャンセル", role: .cancel){}; Button("削除", role: .destructive){ if let o = accountToDeleteIndex { withAnimation { accounts.remove(atOffsets: o); recalculateBalances() } } } } } }
    private var settingTab: some View { NavigationView { ZStack { Color(hex: themeBG).ignoresSafeArea(); List { Section(header: Text("カスタマイズ")) { NavigationLink(destination: ThemeSettingView()) { Label("テーマ設定", systemImage: "paintpalette") } }.listRowBackground(Color(hex: themeBG).opacity(0.5)); Section(header: Text("予算設定")) { Stepper("今月の予算: ¥\(monthlyBudget)", value: $monthlyBudget, in: 1000...500000, step: 1000) }.listRowBackground(Color(hex: themeBG).opacity(0.5)); Section(header: Text("バックアップ")) { Button("手動保存") { backupDateString = BackupManager.getBackupDate(isManual: true); isShowingSaveConfirm = true }; Button("復元") { isRestoringManual = true; backupDateString = BackupManager.getBackupDate(isManual: true); isShowingRestoreConfirm = true } }.listRowBackground(Color(hex: themeBG).opacity(0.5)); Section(header: Text("データ")) { Button("全データをリセット", role: .destructive) { isShowingResetAlert = true } }.listRowBackground(Color(hex: themeBG).opacity(0.5)) }.scrollContentBackground(.hidden).listStyle(.insetGrouped) }.navigationTitle("設定").alert("リセット", isPresented: $isShowingResetAlert) { Button("キャンセル", role: .cancel){}; Button("リセット", role: .destructive){ resetAll() } } } }

    func addTransaction(isInc: Bool, date: Date) { transactions.append(Transaction(amount: parseAmount(from: inputText), date: date, note: inputText, source: parseSourceName(from: inputText), isIncome: isInc)) }
    func deleteSpecificTransaction(_ target: Transaction) { if let index = transactions.firstIndex(where: { $0.id == target.id }) { transactions.remove(at: index) } }
    func recalculateBalances() { for i in 0..<accounts.count { var cur = 0; for tx in transactions where tx.source == accounts[i].name { cur += (tx.isIncome ? tx.amount : -tx.amount) }; accounts[i].diffAmount = cur - accounts[i].balance; accounts[i].balance = cur }; BackupManager.saveAll(transactions: transactions, accounts: accounts, isManual: false) }
    func resetAll() { transactions = []; accounts = [Account(name: "お財布", balance: 0, type: .wallet), Account(name: "口座", balance: 0, type: .bank), Account(name: "ポイント", balance: 0, type: .point)]; monthlyBudget = 50000 }
    func parseAmount(from text: String) -> Int { text.components(separatedBy: .whitespacesAndNewlines).filter { $0.contains("¥") }.reduce(0) { $0 + (Int($1.replacingOccurrences(of: "¥", with: "")) ?? 0) } }
    func parseSourceName(from t: String) -> String { for acc in accounts { if t.contains("@\(acc.name)") { return acc.name } }; return accounts.first?.name ?? "お財布" }

    func updateAppearance() {
        let bgColor = UIColor(Color(hex: themeBarBG))
        let textColor = UIColor(Color(hex: themeBarText))
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = bgColor
        navBarAppearance.titleTextAttributes = [.foregroundColor: textColor]
        navBarAppearance.largeTitleTextAttributes = [.foregroundColor: textColor]
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = bgColor
        UITabBar.appearance().standardAppearance = tabBarAppearance
        if #available(iOS 15.0, *) { UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance }
        // 変更を即座に適用させるためのハック
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.windows.forEach { $0.setNeedsLayout(); $0.layoutIfNeeded() }
        }
    }
}

// --- デザインを統一したテーマ設定画面 ---
struct ThemeSettingView: View {
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_income") var themeIncome: String = "#FF19B219"
    @AppStorage("theme_expense") var themeExpense: String = "#FFFF3B30"
    @AppStorage("theme_holiday") var themeHoliday: String = "#FFFF3B30"
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_barBG") var themeBarBG: String = "#F8F8F8FF"
    @AppStorage("theme_barText") var themeBarText: String = "#FF000000"
    @AppStorage("theme_tabAccent") var themeTabAccent: String = "#FF007AFF"

    struct Preset {
        let name: String; let main: String; let inc: String; let exp: String; let hol: String; let bg: String; let barBG: String; let barTxt: String; let tab: String
    }

    let presets: [Preset] = [
        Preset(name: "デフォルト", main: "#FF007AFF", inc: "#FF19B219", exp: "#FFFF3B30", hol: "#FFFF3B30", bg: "#FFFFFFFF", barBG: "#F8F8F8FF", barTxt: "#FF000000", tab: "#FF007AFF"),
        Preset(name: "ダーク", main: "#FF0A84FF", inc: "#FF30D158", exp: "#FFFF453A", hol: "#FFFF453A", bg: "#FF000000", barBG: "#FF1C1C1E", barTxt: "#FFFFFFFF", tab: "#FF0A84FF"),
        Preset(name: "ナチュラル", main: "#FF6B8E23", inc: "#FF19B219", exp: "#FFFF3B30", hol: "#FFCD5C5C", bg: "#FFF5F5DC", barBG: "#FFE4E4D0", barTxt: "#FF4B3621", tab: "#FF6B8E23"),
        Preset(name: "モノクロ", main: "#FF333333", inc: "#FF19B219", exp: "#FFFF3B30", hol: "#FF999999", bg: "#FFFFFFFF", barBG: "#FFF2F2F2", barTxt: "#FF000000", tab: "#FF000000"),
        Preset(name: "カフェ", main: "#FF8B4513", inc: "#FF19B219", exp: "#FFFF3B30", hol: "#FFA52A2A", bg: "#FFFFF8DC", barBG: "#FFDEB887", barTxt: "#FF3E2723", tab: "#FF8B4513")
    ]

    var body: some View {
        ZStack {
            Color(hex: themeBG).ignoresSafeArea()
            VStack(spacing: 0) {
                // プリセットセレクターを上部に配置 (TwitterRowスタイルに合わせる)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(presets, id: \.name) { p in
                            Button(action: { apply(p) }) {
                                VStack {
                                    Circle().fill(Color(hex: p.main)).frame(width: 44, height: 44)
                                        .overlay(Circle().stroke(Color(hex: themeBarText).opacity(0.2), lineWidth: 1))
                                    Text(p.name).font(.caption2).foregroundColor(Color(hex: themeBarText))
                                }
                            }.buttonStyle(.plain)
                        }
                    }.padding()
                }.background(Color(hex: themeBarBG).opacity(0.5))
                
                Divider()

                List {
                    Section(header: Text("全体設定").foregroundColor(Color(hex: themeBarText).opacity(0.7))) {
                        colorRow(title: "背景色", hex: $themeBG, defaultHex: "#FFFFFFFF")
                        colorRow(title: "バー背景色", hex: $themeBarBG, defaultHex: "#F8F8F8FF")
                        colorRow(title: "メニュー文字色", hex: $themeBarText, defaultHex: "#FF000000")
                        colorRow(title: "フッター選択色", hex: $themeTabAccent, defaultHex: "#FF007AFF")
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    
                    Section(header: Text("個別パーツ").foregroundColor(Color(hex: themeBarText).opacity(0.7))) {
                        colorRow(title: "メインカラー", hex: $themeMain, defaultHex: "#FF007AFF")
                        colorRow(title: "祝日の色", hex: $themeHoliday, defaultHex: "#FFFF3B30")
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("テーマ設定")
    }
    
    func apply(_ p: Preset) {
        withAnimation {
            themeMain = p.main; themeIncome = p.inc; themeExpense = p.exp; themeHoliday = p.hol
            themeBG = p.bg; themeBarBG = p.barBG; themeBarText = p.barTxt; themeTabAccent = p.tab
        }
    }

    func colorRow(title: String, hex: Binding<String>, defaultHex: String) -> some View {
        HStack {
            ColorPicker(title, selection: Binding(get: { Color(hex: hex.wrappedValue) }, set: { hex.wrappedValue = $0.toHex() }))
                .foregroundColor(Color(hex: themeBarText))
            Spacer()
            if hex.wrappedValue != defaultHex {
                Button(action: { hex.wrappedValue = defaultHex }) { 
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .foregroundColor(Color(hex: themeBarText).opacity(0.5))
                        .font(.title3) 
                }.buttonStyle(.plain)
            }
        }
    }
}
