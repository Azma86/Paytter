import SwiftUI
import PhotosUI

struct UserProfileEditSection: View {
    @Binding var profile: UserProfile
    let themeMain: String
    let themeBodyText: String
    let themeSubText: String
    let themeBG: String
    
    let onDeleteRequest: () -> Void
    @State private var selectedItem: PhotosPickerItem? = nil

    var body: some View {
        if profile.isDeleted == true {
            Section(header: Text("削除されたユーザー").foregroundColor(Color(hex: themeSubText))) {
                Text("このユーザーは削除されていますが、過去の投稿は残っています。")
                    .font(.caption)
                    .foregroundColor(Color(hex: themeSubText))
                Button(action: onDeleteRequest) {
                    HStack {
                        Spacer()
                        Text("投稿ごと完全に削除する").foregroundColor(.red)
                        Spacer()
                    }
                }
            }
            .listRowBackground(Color(hex: themeBG).opacity(0.5))
        } else {
            Section(header: Text("ユーザー情報").foregroundColor(Color(hex: themeSubText))) {
                HStack {
                    Spacer()
                    PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                        if let iconData = profile.iconData, let uiImage = UIImage(data: iconData) {
                            Image(uiImage: uiImage).resizable().scaledToFill().frame(width: 80, height: 80).clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill").resizable().frame(width: 80, height: 80).foregroundColor(Color(hex: themeSubText))
                        }
                    }
                    .onChange(of: selectedItem) { newItem in
                        guard let item = newItem else { return }
                        Task {
                            if let data = try? await item.loadTransferable(type: Data.self),
                               let uiImage = UIImage(data: data),
                               let compressedData = uiImage.jpegData(compressionQuality: 0.5) {
                                DispatchQueue.main.async {
                                    profile.iconData = compressedData
                                    selectedItem = nil
                                }
                            } else {
                                DispatchQueue.main.async { selectedItem = nil }
                            }
                        }
                    }
                    Spacer()
                }.padding(.vertical, 8)
                
                HStack {
                    Text("名前").foregroundColor(Color(hex: themeBodyText)).frame(width: 80, alignment: .leading)
                    TextField("ユーザー名", text: $profile.name).foregroundColor(Color(hex: themeBodyText))
                }
                HStack {
                    Text("ID").foregroundColor(Color(hex: themeBodyText)).frame(width: 80, alignment: .leading)
                    Text("@").foregroundColor(Color(hex: themeSubText))
                    TextField("ユーザーID", text: $profile.userId).foregroundColor(Color(hex: themeBodyText)).autocapitalization(.none)
                }
                
                Toggle("タイムラインに表示", isOn: $profile.isVisible).foregroundColor(Color(hex: themeBodyText))
                Toggle("鍵アカウントにする（ロック時非表示）", isOn: Binding(get: { profile.isPrivate ?? false }, set: { profile.isPrivate = $0 })).foregroundColor(Color(hex: themeBodyText))
                
                Button(action: onDeleteRequest) {
                    HStack {
                        Spacer()
                        Text("このユーザーを削除").foregroundColor(.red)
                        Spacer()
                    }
                }
            }
            .listRowBackground(Color(hex: themeBG).opacity(0.5))
        }
    }
}

struct UserProfileSettingView: View {
    @Binding var transactions: [Transaction]
    @AppStorage("user_profiles_v1") var profiles: [UserProfile] = []
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    
    @State private var profileToDelete: UserProfile?
    @State private var isShowingDeleteActionSheet = false
    
    var body: some View {
        ZStack {
            Color(hex: themeBG).ignoresSafeArea()
            List {
                ForEach($profiles) { $profile in
                    UserProfileEditSection(
                        profile: $profile,
                        themeMain: themeMain,
                        themeBodyText: themeBodyText,
                        themeSubText: themeSubText,
                        themeBG: themeBG,
                        onDeleteRequest: {
                            profileToDelete = profile
                            isShowingDeleteActionSheet = true
                        }
                    )
                }
                
                Button(action: {
                    profiles.append(UserProfile(name: "新規ユーザー", userId: "new_user"))
                }) {
                    Label("ユーザーを追加", systemImage: "person.badge.plus").foregroundColor(Color(hex: themeMain))
                }
                .listRowBackground(Color(hex: themeBG).opacity(0.5))
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
        }
        .navigationTitle("表示ユーザー設定")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .onAppear {
            if profiles.isEmpty { profiles.append(UserProfile(name: "むつき", userId: "Mutsuki_dev")) }
        }
        .actionSheet(isPresented: $isShowingDeleteActionSheet) {
            ActionSheet(
                title: Text("ユーザーの削除"),
                message: Text("ユーザーを削除します。過去の投稿はどうしますか？"),
                buttons: [
                    .destructive(Text("投稿もすべて削除する")) {
                        if let p = profileToDelete {
                            transactions.removeAll(where: { $0.profileId == p.id })
                            profiles.removeAll(where: { $0.id == p.id })
                            ensureAtLeastOneProfile()
                        }
                    },
                    .default(Text("投稿は残してユーザーのみ削除")) {
                        if let p = profileToDelete {
                            if let idx = profiles.firstIndex(where: { $0.id == p.id }) {
                                profiles[idx].isDeleted = true
                            }
                            ensureAtLeastOneProfile()
                        }
                    },
                    .cancel(Text("キャンセル")) {
                        profileToDelete = nil
                    }
                ]
            )
        }
    }
    
    func ensureAtLeastOneProfile() {
        if profiles.filter({ !($0.isDeleted ?? false) }).isEmpty {
            profiles.append(UserProfile(name: "新規ユーザー", userId: "new_user"))
        }
        profileToDelete = nil
    }
}
