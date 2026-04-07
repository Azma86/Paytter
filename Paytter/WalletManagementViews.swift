import SwiftUI

struct AccountCreateView: View {
    @Binding var accounts: [Account]
    @Binding var transactions: [Transaction]
    @Environment(\.dismiss) var dismiss
    
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    
    @State private var name = ""
    @State private var initial = ""
    @State private var selectedType: AccountType = .wallet
    @State private var isVisible = true
    
    @State private var creditLimitStr = ""
    @State private var closingDay = 0
    @State private var isWithdrawalNextMonth = true 
    @State private var withdrawalDay = 0
    @State private var withdrawalAccountId: UUID? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: themeBG).ignoresSafeArea()
                Form {
                    Section(header: Text("基本情報").foregroundColor(Color(hex: themeSubText))) {
                        TextField("お財布の名前", text: $name).foregroundColor(Color(hex: themeBodyText))
                        Picker(selection: $selectedType) {
                            ForEach(AccountType.allCases, id: \.self) { type in
                                Label(type.rawValue, systemImage: type.icon).tag(type)
                            }
                        } label: { Text("種類").foregroundColor(Color(hex: themeBodyText)) }
                        
                        HStack {
                            Text("現在の金額").foregroundColor(Color(hex: themeBodyText))
                            Spacer()
                            HStack(spacing: 2) {
                                Text("¥").foregroundColor(Color(hex: themeSubText))
                                TextField("0", text: $initial)
                                    .keyboardType(.numberPad)
                                    .foregroundColor(Color(hex: themeBodyText))
                                    .multilineTextAlignment(.trailing)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .onChange(of: initial) { val in
                                        let clean = val.replacingOccurrences(of: "[^0-9-]", with: "", options: .regularExpression)
                                        if let intVal = Int(clean) { initial = intVal.formattedWithComma } else { initial = "" }
                                    }
                            }
                        }
                        
                        Toggle("ホーム上部に表示", isOn: $isVisible).foregroundColor(Color(hex: themeBodyText))
                    }
                    .listRowBackground(Color(hex: themeBG).opacity(0.5))
                    
                    if selectedType == .credit {
                        Section(header: Text("クレジットカード設定").foregroundColor(Color(hex: themeSubText))) {
                            HStack {
                                Text("限度額").foregroundColor(Color(hex: themeBodyText))
                                Spacer()
                                HStack(spacing: 2) {
                                    Text("¥").foregroundColor(Color(hex: themeSubText))
                                    TextField("0", text: $creditLimitStr)
                                        .keyboardType(.numberPad)
                                        .foregroundColor(Color(hex: themeBodyText))
                                        .multilineTextAlignment(.trailing)
                                        .fixedSize(horizontal: true, vertical: false)
                                        .onChange(of: creditLimitStr) { val in
                                            let clean = val.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
                                            if let intVal = Int(clean) { creditLimitStr = intVal.formattedWithComma } else { creditLimitStr = "" }
                                        }
                                }
                            }
                            
                            Picker("締め日", selection: $closingDay) {
                                ForEach(1...28, id: \.self) { day in Text("\(day)日").tag(day) }
                                Text("月末").tag(0)
                            }.foregroundColor(Color(hex: themeBodyText))
                            
                            Picker("引き落とし月", selection: $isWithdrawalNextMonth) {
                                Text("当月").tag(false)
                                Text("翌月").tag(true)
                            }.foregroundColor(Color(hex: themeBodyText))
                            
                            Picker("引き落とし日", selection: $withdrawalDay) {
                                ForEach(1...28, id: \.self) { day in Text("\(day)日").tag(day) }
                                Text("月末").tag(0)
                            }.foregroundColor(Color(hex: themeBodyText))
                            
                            Picker("引き落とし口座", selection: $withdrawalAccountId) {
                                Text("未設定").tag(UUID?(nil))
                                ForEach(accounts) { acc in
                                    Text(acc.name).tag(UUID?(acc.id))
                                }
                            }.foregroundColor(Color(hex: themeBodyText))
                        }
                        .listRowBackground(Color(hex: themeBG).opacity(0.5))
                    }
                }.scrollContentBackground(.hidden)
            }
            .navigationTitle("新しいお財布")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("キャンセル") { dismiss() }.foregroundColor(Color(hex: themeMain)),
                trailing: Button("追加") {
                    let val = Int(initial.replacingOccurrences(of: ",", with: "")) ?? 0
                    var newAcc = Account(name: name, balance: val, type: selectedType, isVisible: isVisible, createdAt: Date())
                    
                    if selectedType == .credit {
                        newAcc.closingDay = closingDay
                        newAcc.isWithdrawalNextMonth = isWithdrawalNextMonth
                        newAcc.withdrawalDay = withdrawalDay
                        newAcc.withdrawalAccountId = withdrawalAccountId
                        newAcc.creditLimit = Int(creditLimitStr.replacingOccurrences(of: ",", with: ""))
                    }
                    
                    accounts.append(newAcc)
                    if val != 0 {
                        transactions.append(Transaction(amount: val, date: Date(), note: "お財布登録 @\(name) ¥\(val.formattedWithComma)", source: name, isIncome: true))
                    }
                    dismiss()
                }.disabled(name.isEmpty).foregroundColor(Color(hex: themeMain)).fontWeight(.bold)
            )
            .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }
}

struct AccountEditView: View {
    @Binding var account: Account
    @Binding var transactions: [Transaction]
    var allAccounts: [Account]
    
    @AppStorage("account_groups") var groups: [AccountGroup] = []
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    
    @State private var editBalance: String = ""
    @State private var creditLimitStr = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color(hex: themeBG).ignoresSafeArea()
            Form {
                Section(header: Text("基本設定").foregroundColor(Color(hex: themeSubText))) {
                    TextField("名前", text: $account.name).foregroundColor(Color(hex: themeBodyText))
                    Picker(selection: $account.type) {
                        ForEach(AccountType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon).tag(type)
                        }
                    } label: { Text("種類") }
                    Toggle("ホーム上部に表示", isOn: $account.isVisible).foregroundColor(Color(hex: themeBodyText))
                }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                
                if account.type == .credit {
                    Section(header: Text("クレジットカード設定").foregroundColor(Color(hex: themeSubText))) {
                        HStack {
                            Text("限度額").foregroundColor(Color(hex: themeBodyText))
                            Spacer()
                            HStack(spacing: 2) {
                                Text("¥").foregroundColor(Color(hex: themeSubText))
                                TextField("0", text: $creditLimitStr)
                                    .keyboardType(.numberPad)
                                    .foregroundColor(Color(hex: themeBodyText))
                                    .multilineTextAlignment(.trailing)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .onChange(of: creditLimitStr) { val in
                                        let clean = val.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
                                        if let intVal = Int(clean) { 
                                            creditLimitStr = intVal.formattedWithComma
                                            account.creditLimit = intVal
                                        } else { 
                                            creditLimitStr = "" 
                                            account.creditLimit = 0
                                        }
                                    }
                            }
                        }
                        
                        Picker("締め日", selection: Binding(get: { account.closingDay ?? 0 }, set: { account.closingDay = $0 })) {
                            ForEach(1...28, id: \.self) { day in Text("\(day)日").tag(day) }
                            Text("月末").tag(0)
                        }.foregroundColor(Color(hex: themeBodyText))
                        
                        Picker("引き落とし月", selection: Binding(get: { account.isWithdrawalNextMonth ?? true }, set: { account.isWithdrawalNextMonth = $0 })) {
                            Text("当月").tag(false)
                            Text("翌月").tag(true)
                        }.foregroundColor(Color(hex: themeBodyText))
                        
                        Picker("引き落とし日", selection: Binding(get: { account.withdrawalDay ?? 0 }, set: { account.withdrawalDay = $0 })) {
                            ForEach(1...28, id: \.self) { day in Text("\(day)日").tag(day) }
                            Text("月末").tag(0)
                        }.foregroundColor(Color(hex: themeBodyText))
                        
                        Picker("引き落とし口座", selection: $account.withdrawalAccountId) {
                            Text("未設定").tag(UUID?(nil))
                            ForEach(allAccounts.filter { $0.id != account.id }) { acc in
                                Text(acc.name).tag(UUID?(acc.id))
                            }
                        }.foregroundColor(Color(hex: themeBodyText))
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                }
                
                Section(header: Text("残高の調整").foregroundColor(Color(hex: themeSubText))) {
                    HStack {
                        HStack(spacing: 2) {
                            Text("¥").foregroundColor(Color(hex: themeSubText))
                            TextField("新しい残高", text: $editBalance)
                                .keyboardType(.numberPad)
                                .foregroundColor(Color(hex: themeBodyText))
                                .fixedSize(horizontal: true, vertical: false)
                                .onChange(of: editBalance) { val in
                                    let clean = val.replacingOccurrences(of: "[^0-9-]", with: "", options: .regularExpression)
                                    if let intVal = Int(clean) { editBalance = intVal.formattedWithComma } else { editBalance = "" }
                                }
                        }
                        Spacer()
                        Button("調整投稿") {
                            if let newVal = Int(editBalance.replacingOccurrences(of: ",", with: "")) {
                                let diff = newVal - account.balance
                                if diff != 0 {
                                    transactions.append(Transaction(amount: abs(diff), date: Date(), note: "残額調整 @\(account.name) ¥\(abs(diff).formattedWithComma)", source: account.name, isIncome: diff > 0))
                                }
                                editBalance = ""
                                NotificationCenter.default.post(name: NSNotification.Name("SwitchToHomeTab"), object: nil)
                                dismiss()
                            }
                        }.buttonStyle(.borderedProminent).tint(Color(hex: themeMain))
                    }
                }.listRowBackground(Color(hex: themeBG).opacity(0.5))

                Section(header: Text("所属グループ").foregroundColor(Color(hex: themeSubText))) {
                    let belongedGroups = groups.filter { $0.accountIds.contains(account.id) }
                    if belongedGroups.isEmpty {
                        Text("未設定").foregroundColor(Color(hex: themeSubText)).font(.subheadline)
                    } else {
                        ForEach(belongedGroups) { group in
                            HStack {
                                Image(systemName: "folder").foregroundColor(Color(hex: themeMain))
                                Text(group.name).foregroundColor(Color(hex: themeBodyText))
                            }
                        }
                    }
                }.listRowBackground(Color(hex: themeBG).opacity(0.5))
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(account.name)
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .onAppear {
            if let limit = account.creditLimit {
                creditLimitStr = limit.formattedWithComma
            }
        }
    }
}

struct TotalAssetEditView: View {
    @Binding var isVisible: Bool
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    
    var body: some View {
        ZStack {
            Color(hex: themeBG).ignoresSafeArea()
            Form {
                Section(header: Text("グループ設定").foregroundColor(Color(hex: themeSubText))) {
                    Toggle("ホーム上部に表示", isOn: $isVisible)
                }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                Section(footer: Text("「総資産」グループは自動的にすべてのお財布を合算します。").foregroundColor(Color(hex: themeSubText))) {
                    EmptyView()
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("総資産")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}

struct AccountGroupEditView: View {
    @Binding var group: AccountGroup
    @Binding var accounts: [Account]
    
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color(hex: themeBG).ignoresSafeArea()
            Form {
                Section(header: Text("グループ設定").foregroundColor(Color(hex: themeSubText))) {
                    TextField("グループ名", text: $group.name).foregroundColor(Color(hex: themeBodyText))
                    Toggle("ホーム上部に表示", isOn: $group.isVisible).foregroundColor(Color(hex: themeBodyText))
                }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                
                Section(header: Text("対象のお財布を選択").foregroundColor(Color(hex: themeSubText))) {
                    ForEach(accounts) { acc in
                        Button(action: {
                            if group.accountIds.contains(acc.id) {
                                group.accountIds.removeAll(where: { $0 == acc.id })
                            } else {
                                group.accountIds.append(acc.id)
                            }
                        }) {
                            HStack {
                                Image(systemName: acc.type.icon).foregroundColor(Color(hex: themeBodyText).opacity(0.6))
                                Text(acc.name).foregroundColor(Color(hex: themeBodyText))
                                Spacer()
                                if group.accountIds.contains(acc.id) {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(Color(hex: themeMain))
                                } else {
                                    Image(systemName: "circle").foregroundColor(Color(hex: themeSubText))
                                }
                            }
                        }
                    }
                }.listRowBackground(Color(hex: themeBG).opacity(0.5))
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}

struct AccountGroupCreateView: View {
    @Binding var groups: [AccountGroup]
    @Binding var accounts: [Account]
    @Environment(\.dismiss) var dismiss
    
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    
    @State private var name = ""
    @State private var isVisible = true
    @State private var selectedAccountIds: [UUID] = []
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: themeBG).ignoresSafeArea()
                Form {
                    Section(header: Text("基本情報").foregroundColor(Color(hex: themeSubText))) {
                        TextField("グループ名（例：銀行まとめなど）", text: $name).foregroundColor(Color(hex: themeBodyText))
                        Toggle("ホーム上部に表示", isOn: $isVisible)
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    
                    Section(header: Text("お財布を紐付ける").foregroundColor(Color(hex: themeSubText))) {
                        ForEach(accounts) { acc in
                            Button(action: {
                                if selectedAccountIds.contains(acc.id) {
                                    selectedAccountIds.removeAll(where: { $0 == acc.id })
                                } else {
                                    selectedAccountIds.append(acc.id)
                                }
                            }) {
                                 HStack {
                                    Image(systemName: acc.type.icon).foregroundColor(Color(hex: themeBodyText).opacity(0.6))
                                    Text(acc.name).foregroundColor(Color(hex: themeBodyText))
                                    Spacer()
                                    if selectedAccountIds.contains(acc.id) {
                                        Image(systemName: "checkmark.circle.fill").foregroundColor(Color(hex: themeMain))
                                    } else {
                                        Image(systemName: "circle").foregroundColor(Color(hex: themeSubText))
                                    }
                                }
                            }
                        }
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("新しいグループ")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("キャンセル") { dismiss() }.foregroundColor(Color(hex: themeMain)),
                trailing: Button("追加") {
                    let newGroup = AccountGroup(name: name, isVisible: isVisible, accountIds: selectedAccountIds)
                    groups.append(newGroup)
                    dismiss()
                }.disabled(name.isEmpty).foregroundColor(Color(hex: themeMain)).fontWeight(.bold)
            )
            .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }
}

struct WalletAnalysisView: View {
    let transactions: [Transaction]
    @AppStorage("monthlyBudget") var monthlyBudget: Int = 50000
    @AppStorage("closingDay") var closingDay: Int = 0
    
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_expense") var themeExpense: String = "#FFFF3B30"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("user_profiles_v1") var profiles: [UserProfile] = []
    @ObservedObject var lockManager = LockManager.shared
    
    var validTransactions: [Transaction] {
        if lockManager.isUnlocked || lockManager.reflectPrivateBalanceWhenLocked {
            return transactions
        } else {
            return transactions.filter { tx in
                let profile = profiles.first(where: { $0.id == tx.profileId }) ?? profiles.first
                return !(profile?.isPrivate ?? false)
            }
        }
    }
    
    var currentPeriodRange: (start: Date, end: Date) {
        let cal = Calendar.current
        let now = Date()
        let currentDay = cal.component(.day, from: now)
        
        if closingDay == 0 { 
            let comps = cal.dateComponents([.year, .month], from: now)
            let start = cal.date(from: comps)!
            let end = cal.date(byAdding: DateComponents(month: 1, day: -1), to: start)!
            return (start, cal.date(bySettingHour: 23, minute: 59, second: 59, of: end)!)
        } else { 
            var startComps = cal.dateComponents([.year, .month], from: now)
            if currentDay <= closingDay { startComps.month! -= 1 }
            startComps.day = closingDay + 1
            let start = cal.date(from: startComps)!
            
            let endMonth = cal.date(byAdding: .month, value: 1, to: start)!
            let end = cal.date(byAdding: .day, value: -1, to: endMonth)!
            return (start, cal.date(bySettingHour: 23, minute: 59, second: 59, of: end)!)
        }
    }
    
    var monthlyTotal: Int {
        let range = currentPeriodRange
        return validTransactions.filter { !$0.isIncome && $0.date >= range.start && $0.date <= range.end }.reduce(0) { $0 + $1.amount }
    }
    
    var rangeText: String {
        let df = DateFormatter()
        df.dateFormat = "M/d"
        return "\(df.string(from: currentPeriodRange.start)) 〜 \(df.string(from: currentPeriodRange.end))"
    }
    
    var body: some View {
        ZStack {
            Color(hex: themeBG).ignoresSafeArea()
            List {
                Section(header: Text("今期のサマリー (\(rangeText))").foregroundColor(Color(hex: themeSubText))) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("合計支出").font(.caption).foregroundColor(Color(hex: themeSubText))
                        Text("¥\(monthlyTotal.formattedWithComma)").font(.system(.title, design: .rounded).bold()).foregroundColor(Color(hex: themeBodyText))
                        
                        ProgressView(value: min(Double(monthlyTotal), Double(monthlyBudget)), total: Double(monthlyBudget))
                            .accentColor(monthlyTotal > Int(Double(monthlyBudget) * 0.9) ? Color(hex: themeExpense) : Color(hex: themeMain))
                        
                        Text("予算 ¥\(monthlyBudget.formattedWithComma) まであと ¥\(max(0, monthlyBudget - monthlyTotal).formattedWithComma)")
                            .font(.caption2).foregroundColor(Color(hex: themeSubText))
                    }.padding(.vertical, 10)
                }
                .listRowBackground(Color(hex: themeBG).opacity(0.5))
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("分析")
    }
}

struct RecurringPaymentCreateView: View {
    @Binding var recurringPayments: [RecurringPayment]
    let accounts: [Account]
    let profiles: [UserProfile]
    @Environment(\.dismiss) var dismiss
    
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    
    @State private var name = ""
    @State private var amountStr = ""
    @State private var startDate = Date()
    @State private var hasEndDate = false
    @State private var endDate = Date()
    @State private var paymentDay = 1
    @State private var selectedProfileId: UUID?
    @State private var selectedSourceName = ""
    @State private var fractionType = 0
    @State private var fractionAmountStr = ""
    
    @State private var isNextMonth = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: themeBG).ignoresSafeArea()
                Form {
                    Section(header: Text("基本情報").foregroundColor(Color(hex: themeSubText))) {
                        TextField("名前（例：Apple Music）", text: $name).foregroundColor(Color(hex: themeBodyText))
                        
                        HStack {
                            Text("毎月の金額").foregroundColor(Color(hex: themeBodyText))
                            Spacer()
                            HStack(spacing: 2) {
                                Text("¥").foregroundColor(Color(hex: themeSubText))
                                TextField("0", text: $amountStr)
                                    .keyboardType(.numberPad)
                                    .foregroundColor(Color(hex: themeBodyText))
                                    .multilineTextAlignment(.trailing)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .onChange(of: amountStr) { val in
                                        let clean = val.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
                                        if let intVal = Int(clean) { amountStr = intVal.formattedWithComma } else { amountStr = "" }
                                    }
                            }
                        }
                        
                        Picker(selection: $selectedSourceName) {
                            ForEach(accounts, id: \.name) { acc in Text(acc.name).tag(acc.name) }
                        } label: { Text("お財布").foregroundColor(Color(hex: themeBodyText)) }
                        
                        Picker(selection: $selectedProfileId) {
                            Text("未選択").tag(UUID?(nil))
                            ForEach(profiles) { prof in Text(prof.name).tag(UUID?(prof.id)) }
                        } label: { Text("ユーザー").foregroundColor(Color(hex: themeBodyText)) }
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    
                    Section(header: Text("スケジュール").foregroundColor(Color(hex: themeSubText))) {
                        DatePicker("開始月", selection: $startDate, displayedComponents: .date).environment(\.locale, Locale(identifier: "ja_JP"))
                        
                        Picker("引き落とし", selection: $isNextMonth) {
                            Text("当月").tag(false)
                            Text("翌月").tag(true)
                        }.foregroundColor(Color(hex: themeBodyText))
                        
                        Picker("支払日", selection: $paymentDay) {
                            ForEach(1...31, id: \.self) { day in Text("\(day)日").tag(day) }
                        }
                        Toggle("終了月を設定する", isOn: $hasEndDate).foregroundColor(Color(hex: themeBodyText))
                        if hasEndDate {
                            DatePicker("終了月", selection: $endDate, displayedComponents: .date).environment(\.locale, Locale(identifier: "ja_JP"))
                        }
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                    
                    Section(header: Text("端数調整").foregroundColor(Color(hex: themeSubText))) {
                        Picker("調整のタイミング", selection: $fractionType) {
                            Text("なし").tag(0)
                            Text("初回").tag(1)
                            Text("最終回").tag(2)
                        }.pickerStyle(.segmented)
                        if fractionType != 0 {
                            HStack {
                                Text("調整金額").foregroundColor(Color(hex: themeBodyText))
                                Spacer()
                                HStack(spacing: 2) {
                                    Text("¥").foregroundColor(Color(hex: themeSubText))
                                    TextField("0", text: $fractionAmountStr)
                                        .keyboardType(.numberPad)
                                        .foregroundColor(Color(hex: themeBodyText))
                                        .multilineTextAlignment(.trailing)
                                        .fixedSize(horizontal: true, vertical: false)
                                        .onChange(of: fractionAmountStr) { val in
                                            let clean = val.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
                                            if let intVal = Int(clean) { fractionAmountStr = intVal.formattedWithComma } else { fractionAmountStr = "" }
                                        }
                                }
                            }
                        }
                    }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                }.scrollContentBackground(.hidden)
            }
            .navigationTitle("新規登録")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button("キャンセル") { dismiss() }.foregroundColor(Color(hex: themeMain)), trailing: Button("追加") {
                let rp = RecurringPayment(name: name, amount: Int(amountStr.replacingOccurrences(of: ",", with: "")) ?? 0, startDate: startDate, hasEndDate: hasEndDate, endDate: endDate, paymentDay: paymentDay, profileId: selectedProfileId, source: selectedSourceName.isEmpty ? (accounts.first?.name ?? "お財布") : selectedSourceName, isIncome: false, fractionType: fractionType, fractionAmount: Int(fractionAmountStr.replacingOccurrences(of: ",", with: "")) ?? 0, createdAt: Date(), isNextMonth: isNextMonth)
                recurringPayments.append(rp)
                NotificationCenter.default.post(name: NSNotification.Name("CheckRecurringPayments"), object: nil)
                dismiss()
            }.disabled(name.isEmpty || amountStr.isEmpty).foregroundColor(Color(hex: themeMain)).fontWeight(.bold))
            .preferredColorScheme(isDarkMode ? .dark : .light)
            .onAppear {
                if selectedSourceName.isEmpty { selectedSourceName = accounts.first?.name ?? "お財布" }
            }
        }
    }
}

struct RecurringPaymentEditView: View {
    @Binding var payment: RecurringPayment
    @Binding var recurringPayments: [RecurringPayment]
    @Binding var transactions: [Transaction] 
    let accounts: [Account]
    let profiles: [UserProfile]
    
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    
    @Environment(\.dismiss) var dismiss
    @State private var amountStr = ""
    @State private var fractionAmountStr = ""
    
    var body: some View {
        ZStack {
            Color(hex: themeBG).ignoresSafeArea()
            Form {
                let info = payment.paymentInfo()
                Section(header: Text("状況").foregroundColor(Color(hex: themeSubText))) {
                    HStack { Text("支払った金額").foregroundColor(Color(hex: themeBodyText)); Spacer(); Text("¥\(info.paid.formattedWithComma)").foregroundColor(Color(hex: themeBodyText)).bold() }
                    if payment.hasEndDate {
                        HStack { Text("残りの金額").foregroundColor(Color(hex: themeBodyText)); Spacer(); Text("¥\(info.remaining.formattedWithComma)").foregroundColor(Color(hex: themeBodyText)).bold() }
                        HStack { Text("合計金額").foregroundColor(Color(hex: themeBodyText)); Spacer(); Text("¥\(info.total.formattedWithComma)").foregroundColor(Color(hex: themeBodyText)).bold() }
                        if info.total > 0 {
                            ProgressView(value: min(Double(info.paid), Double(info.total)), total: Double(info.total)).accentColor(Color(hex: themeMain))
                        }
                    } else {
                        HStack { Text("合計金額").foregroundColor(Color(hex: themeBodyText)); Spacer(); Text("無限").foregroundColor(Color(hex: themeSubText)) }
                    }
                }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                
                Section(header: Text("基本情報").foregroundColor(Color(hex: themeSubText))) {
                    TextField("名前", text: $payment.name).foregroundColor(Color(hex: themeBodyText))
                    
                    HStack {
                        Text("毎月の金額").foregroundColor(Color(hex: themeBodyText))
                        Spacer()
                        HStack(spacing: 2) {
                            Text("¥").foregroundColor(Color(hex: themeSubText))
                            TextField("0", text: $amountStr)
                                .keyboardType(.numberPad)
                                .foregroundColor(Color(hex: themeBodyText))
                                .multilineTextAlignment(.trailing)
                                .fixedSize(horizontal: true, vertical: false)
                                .onChange(of: amountStr) { val in
                                    let clean = val.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
                                    if let intVal = Int(clean) {
                                        amountStr = intVal.formattedWithComma
                                        payment.amount = intVal
                                    } else {
                                        amountStr = ""
                                        payment.amount = 0
                                    }
                                }
                        }
                    }
                    
                    Picker(selection: $payment.source) { ForEach(accounts, id: \.name) { acc in Text(acc.name).tag(acc.name) } } label: { Text("お財布").foregroundColor(Color(hex: themeBodyText)) }
                    Picker(selection: $payment.profileId) { Text("未選択").tag(UUID?(nil)); ForEach(profiles) { prof in Text(prof.name).tag(UUID?(prof.id)) } } label: { Text("ユーザー").foregroundColor(Color(hex: themeBodyText)) }
                }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                
                Section(header: Text("スケジュール").foregroundColor(Color(hex: themeSubText))) {
                    DatePicker("開始月", selection: $payment.startDate, displayedComponents: .date).environment(\.locale, Locale(identifier: "ja_JP"))
                    
                    Picker("引き落とし", selection: Binding(get: { payment.isNextMonth ?? false }, set: { payment.isNextMonth = $0 })) {
                        Text("当月").tag(false)
                        Text("翌月").tag(true)
                    }.foregroundColor(Color(hex: themeBodyText))
                    
                    Picker("支払日", selection: $payment.paymentDay) { ForEach(1...31, id: \.self) { day in Text("\(day)日").tag(day) } }
                    Toggle("終了月を設定する", isOn: $payment.hasEndDate).foregroundColor(Color(hex: themeBodyText))
                    if payment.hasEndDate {
                        DatePicker("終了月", selection: $payment.endDate, displayedComponents: .date).environment(\.locale, Locale(identifier: "ja_JP"))
                    }
                }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                
                Section(header: Text("端数調整").foregroundColor(Color(hex: themeSubText))) {
                    Picker("調整のタイミング", selection: $payment.fractionType) { Text("なし").tag(0); Text("初回").tag(1); Text("最終回").tag(2) }.pickerStyle(.segmented)
                    if payment.fractionType != 0 {
                        HStack {
                            Text("調整金額").foregroundColor(Color(hex: themeBodyText))
                            Spacer()
                            HStack(spacing: 2) {
                                Text("¥").foregroundColor(Color(hex: themeSubText))
                                TextField("0", text: $fractionAmountStr)
                                    .keyboardType(.numberPad)
                                    .foregroundColor(Color(hex: themeBodyText))
                                    .multilineTextAlignment(.trailing)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .onChange(of: fractionAmountStr) { val in
                                        let clean = val.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
                                        if let intVal = Int(clean) {
                                            fractionAmountStr = intVal.formattedWithComma
                                            payment.fractionAmount = intVal
                                        } else {
                                            fractionAmountStr = ""
                                            payment.fractionAmount = 0
                                        }
                                    }
                            }
                        }
                    }
                }.listRowBackground(Color(hex: themeBG).opacity(0.5))
                
                Section(header: Text("過去の履歴").foregroundColor(Color(hex: themeSubText)), footer: Text("間違って消してしまった時や、アプリ導入前の履歴を一気に作成します。何度でも作成可能で、残高には影響しません。").foregroundColor(Color(hex: themeSubText))) {
                    Button(action: postPastTransactions) {
                        Text("過去の分を履歴に追加（残高除外・何度でも可）")
                            .foregroundColor(Color(hex: themeMain))
                            .bold()
                    }
                }.listRowBackground(Color(hex: themeBG).opacity(0.5))
            }.scrollContentBackground(.hidden)
        }
        .navigationTitle(payment.name)
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .onAppear { amountStr = payment.amount.formattedWithComma; fractionAmountStr = payment.fractionAmount.formattedWithComma }
        .onDisappear {
            NotificationCenter.default.post(name: NSNotification.Name("CheckRecurringPayments"), object: nil)
        }
    }
    
    func postPastTransactions() {
        let cal = Calendar.current
        let now = Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM"
        
        var newTransactions: [Transaction] = []
        
        guard let startNorm = cal.date(from: cal.dateComponents([.year, .month], from: payment.startDate)) else { return }
        let nowMonthDate = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        
        var currentMonthDate = startNorm
        
        while true {
            var targetComps = cal.dateComponents([.year, .month], from: currentMonthDate)
            if payment.isNextMonth == true { targetComps.month! += 1 }
            let targetMonthDate = cal.date(from: targetComps)!
            
            if targetMonthDate > nowMonthDate { break }
            
            let monthStr = fmt.string(from: currentMonthDate)
            
            if payment.hasEndDate {
                let endMonthStr = fmt.string(from: payment.endDate)
                if monthStr > endMonthStr { break }
            }
            
            let range = cal.range(of: .day, in: .month, for: targetMonthDate)!
            targetComps.day = min(payment.paymentDay, range.count)
            targetComps.hour = 0
            targetComps.minute = 0
            targetComps.second = 0
            
            if let targetDate = cal.date(from: targetComps), now >= targetDate {
                var postAmount = payment.amount
                if currentMonthDate == startNorm && payment.fractionType == 1 {
                    postAmount = payment.fractionAmount
                } else if payment.hasEndDate && monthStr == fmt.string(from: payment.endDate) && payment.fractionType == 2 {
                    postAmount = payment.fractionAmount
                }
                
                let monthNum = cal.component(.month, from: currentMonthDate)
                let noteText = "\(payment.name) \(monthNum)月分 ¥\(postAmount.formattedWithComma) (過去分)"
                
                let tx = Transaction(amount: postAmount, date: targetDate, note: noteText, source: payment.source, isIncome: payment.isIncome, isExcludedFromBalance: true, profileId: payment.profileId)
                newTransactions.append(tx)
            }
            currentMonthDate = cal.date(byAdding: .month, value: 1, to: currentMonthDate)!
        }
        
        if !newTransactions.isEmpty {
            transactions.append(contentsOf: newTransactions)
            dismiss()
        }
    }
}
