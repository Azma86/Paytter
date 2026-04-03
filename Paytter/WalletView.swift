import SwiftUI

struct WalletView: View {
    @Binding var transactions: [Transaction]
    @Binding var accounts: [Account]
    @Binding var groups: [AccountGroup]
    
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_barBG") var themeBarBG: String = "#F8F8F8FF"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    @AppStorage("show_total_assets") var showTotalAssets: Bool = true
    
    @State private var isShowingAccountCreator = false
    @State private var isShowingGroupCreator = false
    @State private var isShowingAccountDeleteAlert = false
    @State private var isShowingGroupDeleteAlert = false
    @State private var accountToDeleteIndex: IndexSet?
    @State private var groupToDeleteIndex: IndexSet?
    
    var body: some View {
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
                        withAnimation { accounts.remove(atOffsets: o) } 
                    }; accountToDeleteIndex = nil 
                }
            }
            .alert("グループの削除", isPresented: $isShowingGroupDeleteAlert) {
                Button("キャンセル", role: .cancel){}; Button("削除", role: .destructive){ if let o = groupToDeleteIndex { withAnimation { groups.remove(atOffsets: o) } } }
            }
        }
    }
    
    func moveAccount(from source: IndexSet, to destination: Int) { accounts.move(fromOffsets: source, toOffset: destination) }
    func moveGroup(from source: IndexSet, to destination: Int) { groups.move(fromOffsets: source, toOffset: destination) }
}
