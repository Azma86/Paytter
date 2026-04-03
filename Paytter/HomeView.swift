import SwiftUI

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

struct HomeView: View {
    @Binding var transactions: [Transaction]
    @Binding var accounts: [Account]
    @Binding var groups: [AccountGroup]
    
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_barBG") var themeBarBG: String = "#F8F8F8FF"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    
    @State private var isShowingInputSheet = false
    @State private var inputText: String = ""
    @State private var isShowingSwipeDeleteAlert = false
    @State private var transactionToDelete: Transaction?
    
    @State private var isHomeEditMode = false
    @State private var draggedItemId: String?
    @State private var dragOffset: CGFloat = 0 
    @State private var dragLastX: CGFloat?
    
    @AppStorage("show_total_assets") var showTotalAssets: Bool = true
    @AppStorage("home_display_order") var homeDisplayOrder: [String] = []
    @State private var homeItems: [HomeItem] = []
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                Color(hex: themeBG).ignoresSafeArea()
                VStack(spacing: 0) {
                    VStack(spacing: 8) {
                        HStack(spacing: 10) {
                            ForEach(homeItems) { item in
                                homeHeaderItem(for: item)
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
                                                    let jumpDistance = (UIScreen.main.bounds.width - 32 - CGFloat(max(homeItems.count - 1, 0)) * 10) / CGFloat(max(homeItems.count, 1)) + 10
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
                        
                        if isHomeEditMode {
                            Text("横にスライドして淡々と並べ替えられます")
                                .font(.caption2)
                                .foregroundColor(Color(hex: themeMain))
                                .padding(.bottom, 4)
                        }
                    }
                    .background(Color(hex: themeBarBG).opacity(0.8))
                    
                    Divider()
                    List {
                        ForEach(transactions.sorted(by: { $0.date > $1.date })) { item in
                            transactionRow(for: item)
                        }
                    }
                    .listStyle(.plain).scrollContentBackground(.hidden)
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
                Button("キャンセル", role: .cancel) {}; Button("削除", role: .destructive) { if let t = transactionToDelete { transactions.removeAll(where: { $0.id == t.id }) } }
            }
        }
        .onAppear { syncHomeItems() }
        .onChange(of: accounts) { _ in syncHomeItems() }
        .onChange(of: groups) { _ in syncHomeItems() }
        .onChange(of: showTotalAssets) { _ in syncHomeItems() }
        .sheet(isPresented: $isShowingInputSheet) { 
            PostView(inputText: $inputText, isPresented: $isShowingInputSheet, initialDate: Date(), onPost: { isInc, nDate, isExc in addTransaction(isInc: isInc, date: nDate, isExcluded: isExc) }, transactions: transactions, accounts: accounts) 
        }
    }
    
    @ViewBuilder
    private func homeHeaderItem(for item: HomeItem) -> some View {
        switch item {
        case .totalAssets:
            let totalB = accounts.reduce(0) { $0 + $1.balance }
            let totalD = accounts.reduce(0) { $0 + $1.diffAmount }
            BalanceView(title: "総資産", amount: totalB, color: Color(hex: themeBodyText), diff: totalD)
            
        case .account(let acc):
            if let currentAcc = accounts.first(where: { $0.id == acc.id }) {
                BalanceView(title: currentAcc.name, amount: currentAcc.balance, color: Color(hex: themeBodyText), diff: currentAcc.diffAmount)
            } else { EmptyView() }
            
        case .group(let group):
            if let currentGroup = groups.first(where: { $0.id == group.id }) {
                let groupAccounts = accounts.filter { currentGroup.accountIds.contains($0.id) }
                let totalBalance = groupAccounts.reduce(0) { $0 + $1.balance }
                let totalDiff = groupAccounts.reduce(0) { $0 + $1.diffAmount }
                BalanceView(title: currentGroup.name, amount: totalBalance, color: Color(hex: themeBodyText), diff: totalDiff)
            } else { EmptyView() }
        }
    }
    
    @ViewBuilder
    private func transactionRow(for item: Transaction) -> some View {
        let isFuture = item.date > Date()
        ZStack {
            NavigationLink(destination: TransactionDetailView(item: item, transactions: $transactions, accounts: $accounts)) { EmptyView() }.opacity(0)
            TwitterRow(item: item)
                .opacity(isFuture ? 0.6 : 1.0)
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(isFuture ? Color.black.opacity(0.06) : Color(hex: themeBG))
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button { transactionToDelete = item; isShowingSwipeDeleteAlert = true } label: { Text("削除") }.tint(.red)
        }
    }

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

    func addTransaction(isInc: Bool, date: Date, isExcluded: Bool) { 
        transactions.append(Transaction(amount: parseAmount(from: inputText), date: date, note: inputText, source: parseSourceName(from: inputText), isIncome: isInc, isExcludedFromBalance: isExcluded))
    }
    func parseAmount(from text: String) -> Int { text.components(separatedBy: .whitespacesAndNewlines).filter { $0.contains("¥") }.reduce(0) { $0 + (Int($1.replacingOccurrences(of: "¥", with: "")) ?? 0) } }
    func parseSourceName(from t: String) -> String { for acc in accounts { if t.contains("@\(acc.name)") { return acc.name } }; return accounts.first?.name ?? "お財布" }
}
