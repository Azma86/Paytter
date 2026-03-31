private var homeTab: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    HStack(spacing: 15) {
                        ForEach(accounts.filter { $0.isVisible }) { acc in
                            BalanceView(title: acc.name, amount: acc.balance, color: .primary, diff: acc.diffAmount)
                        }
                    }.padding().background(Color(.systemGray6))
                    Divider()
                    List {
                        ForEach(displayedTransactions, id: \.id) { item in
                            ZStack {
                                NavigationLink(destination: TransactionDetailView(item: item, transactions: $transactions, accounts: $accounts)) {
                                    EmptyView()
                                }.opacity(0)
                                
                                TwitterRow(item: item)
                            }
                            .listRowInsets(EdgeInsets())
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                // アニメーションなしでダイアログを呼ぶ
                                Button(role: .destructive) {
                                    var transaction = item
                                    transactionToDelete = transaction
                                    isShowingSwipeDeleteAlert = true
                                } label: {
                                    Text("削除")
                                }
                            }
                        }
                    }.listStyle(.plain)
                }
                Button(action: { inputText = ""; isShowingInputSheet = true }) {
                    Image(systemName: "plus").font(.system(size: 22, weight: .bold)).foregroundColor(.white).frame(width: 56, height: 56).background(Color.blue).clipShape(Circle())
                }.padding(20).padding(.bottom, 10)
            }
            .navigationTitle("ホーム").navigationBarTitleDisplayMode(.inline)
            // アニメーションを無効化した状態でダイアログを表示
            .alert("投稿を削除しますか？", isPresented: $isShowingSwipeDeleteAlert) {
                Button("キャンセル", role: .cancel) { transactionToDelete = nil }
                Button("削除", role: .destructive) { 
                    if let t = transactionToDelete { 
                        // 削除するときだけアニメーションさせる
                        withAnimation(.easeOut) { deleteSpecificTransaction(t) } 
                    }
                    transactionToDelete = nil 
                }
            } message: { if let t = transactionToDelete { Text(t.cleanNote) } }
        }
    }
