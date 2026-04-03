import SwiftUI

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
                HomeView(transactions: $transactions, accounts: $accounts, groups: $groups)
                    .tag(0).tabItem { Label("ホーム", systemImage: "house") }
                
                NavigationView { CalendarView(transactions: $transactions, accounts: $accounts) }
                    .tag(1).tabItem { Label("カレンダー", systemImage: "calendar") }
                
                WalletView(transactions: $transactions, accounts: $accounts, groups: $groups)
                    .tag(2).tabItem { Label("お財布", systemImage: "wallet.pass") }
                
                SettingView(transactions: $transactions, accounts: $accounts, groups: $groups)
                    .tag(3).tabItem { Label("設定", systemImage: "gearshape") }
            }
            .accentColor(Color(hex: themeTabAccent))
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToHomeTab"))) { _ in
                self.selection = 0
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .onAppear { recalculateBalances(); updateAppearance() }
        .onReceive(appearancePublisher) { _ in updateAppearance() }
        .onChange(of: transactions) { _ in recalculateBalances() }
        .onChange(of: themeBarBG) { _ in updateAppearance() }
        .onChange(of: isDarkMode) { _ in updateAppearance() }
    }
    
    // 【重要】ここで「計算除外フラグ」をチェックして残高を計算します
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
