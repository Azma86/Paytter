import SwiftUI

struct PasscodeSettingView: View {
    @ObservedObject var lockManager = LockManager.shared
    @State private var newPasscode = ""
    @State private var selectedType = 0
    @State private var useBiometrics = false
    
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    @AppStorage("theme_subText") var themeSubText: String = "#FF8E8E93"
    
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color(hex: themeBG).ignoresSafeArea()
            Form {
                if lockManager.passcode.isEmpty {
                    Section(header: Text("新しいパスコード").foregroundColor(Color(hex: themeSubText))) {
                        Picker("形式", selection: $selectedType) {
                            Text("4桁の数字").tag(0)
                            Text("6桁の数字").tag(1)
                            Text("自由入力").tag(2)
                        }.pickerStyle(.segmented)
                        
                        SecureField("パスコードを入力", text: $newPasscode)
                            .keyboardType(selectedType == 2 ? .default : .numberPad)
                            .foregroundColor(Color(hex: themeBodyText))
                        
                        Toggle("生体認証(TouchID/FaceID)を使用", isOn: $useBiometrics)
                            .foregroundColor(Color(hex: themeBodyText))
                        
                        Button("設定する") {
                            if validate() {
                                lockManager.passcodeType = selectedType
                                lockManager.useBiometrics = useBiometrics
                                lockManager.passcode = newPasscode
                                lockManager.isUnlocked = true
                                dismiss()
                            }
                        }
                        .foregroundColor(Color(hex: themeMain))
                        .disabled(!validate())
                    }
                    .listRowBackground(Color(hex: themeBG).opacity(0.5))
                } else {
                    Section(header: Text("パスコード設定").foregroundColor(Color(hex: themeSubText))) {
                        Text("パスコードは設定済みです").foregroundColor(Color(hex: themeBodyText))
                        Button("パスコードをオフにする", role: .destructive) {
                            lockManager.passcode = ""
                            lockManager.isUnlocked = true
                        }
                    }
                    .listRowBackground(Color(hex: themeBG).opacity(0.5))
                    
                    Section(header: Text("ロックの動作").foregroundColor(Color(hex: themeSubText))) {
                        Picker("ロック時の制限", selection: $lockManager.lockBehavior) {
                            Text("全画面をロック").tag(0)
                            Text("鍵アカウントのみ非表示").tag(1)
                        }.pickerStyle(.menu)
                        
                        Picker("鍵投稿の非表示方法", selection: $lockManager.privatePostDisplayMode) {
                            Text("完全に非表示").tag(0)
                            Text("内容のみ隠す").tag(1)
                        }.pickerStyle(.menu)
                        
                        Toggle("ロック時も鍵投稿を残額に反映", isOn: $lockManager.reflectPrivateBalanceWhenLocked)
                            .foregroundColor(Color(hex: themeBodyText))
                    }
                    .listRowBackground(Color(hex: themeBG).opacity(0.5))
                }
            }.scrollContentBackground(.hidden)
        }
        .navigationTitle("パスコードロック")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    func validate() -> Bool {
        if selectedType == 0 && newPasscode.count != 4 { return false }
        if selectedType == 1 && newPasscode.count != 6 { return false }
        if newPasscode.isEmpty { return false }
        return true
    }
}

struct PasscodeLockOverlay: View {
    @ObservedObject var lockManager = LockManager.shared
    @State private var inputCode = ""
    @State private var isError = false
    
    @AppStorage("theme_bg") var themeBG: String = "#FFFFFFFF"
    @AppStorage("theme_main") var themeMain: String = "#FF007AFF"
    @AppStorage("theme_bodyText") var themeBodyText: String = "#FF000000"
    
    var body: some View {
        ZStack {
            Color(hex: themeBG).ignoresSafeArea()
            VStack(spacing: 30) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Color(hex: themeMain))
                
                Text("パスコードを入力")
                    .font(.title2).bold()
                    .foregroundColor(Color(hex: themeBodyText))
                
                SecureField("パスコード", text: $inputCode)
                    .keyboardType(lockManager.passcodeType == 2 ? .default : .numberPad)
                    .multilineTextAlignment(.center)
                    .font(.title)
                    .foregroundColor(Color(hex: themeBodyText))
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal, 40)
                    .onChange(of: inputCode) { newValue in
                        isError = false
                        if lockManager.passcodeType == 0 && newValue.count == 4 { submit() }
                        else if lockManager.passcodeType == 1 && newValue.count == 6 { submit() }
                    }
                
                if isError {
                    Text("パスコードが違います").foregroundColor(.red).font(.footnote)
                }
                
                if lockManager.passcodeType == 2 {
                    Button("解除") { submit() }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(hex: themeMain))
                }
                
                if lockManager.useBiometrics {
                    Button(action: { lockManager.authenticateWithBiometrics() }) {
                        Image(systemName: "faceid")
                            .font(.largeTitle)
                            .foregroundColor(Color(hex: themeMain))
                    }
                    .padding(.top, 20)
                }
                
                Spacer()
                
                if lockManager.lockBehavior == 1 {
                    Button("キャンセルして鍵アカウントを非表示") {
                        lockManager.cancelUnlock()
                    }
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .padding(.bottom, 30)
                }
            }.padding(.top, 80)
        }
        .onAppear {
            if lockManager.useBiometrics {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    lockManager.authenticateWithBiometrics()
                }
            }
        }
    }
    
    func submit() {
        if !lockManager.unlock(with: inputCode) {
            isError = true
            inputCode = ""
        }
    }
}
