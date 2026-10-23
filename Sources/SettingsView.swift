import SwiftUI
import AppKit

private enum SettingsPage: String, CaseIterable, Identifiable {
    case general, palettes, about
    var id: Self { self }

    var title: String {
        switch self {
        case .general: L("일반", "General", ja: "一般")
        case .palettes: L("팔레트", "Palettes", ja: "パレット")
        case .about: L("정보", "About", ja: "情報")
        }
    }

    var icon: String {
        switch self {
        case .general: "gearshape"
        case .palettes: "paintpalette"
        case .about: "info.circle"
        }
    }
}

/// 설정 창: 왼쪽 사이드바 + 오른쪽 묶음형 항목 (참고 이미지 2번 구조)
struct SettingsView: View {
    @EnvironmentObject private var store: PaletteStore
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.system.rawValue
    @State private var page: SettingsPage? = .general

    // NavigationSplitView는 쓰지 않습니다. 창 위에 도구 막대(사이드바 가리기 버튼)를 붙이고
    // 첫 번째 항목을 그 아래로 가리기 때문에, 사이드바와 본문을 직접 나란히 놓습니다.
    var body: some View {
        HStack(spacing: 0) {
            List(SettingsPage.allCases, selection: $page) { p in
                Label(p.title, systemImage: p.icon).tag(p)
            }
            .listStyle(.sidebar)
            .frame(width: 190)

            Divider()

            Group {
                switch page ?? .general {
                case .general: GeneralPage()
                case .palettes: PalettesPage()
                case .about: AboutPage()
                }
            }
            .formStyle(.grouped)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 640, minHeight: 440)
        .onChange(of: page) { old, new in
            // 사이드바 빈 곳을 눌러 선택이 풀리면 이전 페이지를 유지합니다.
            if new == nil { page = old }
        }
        // 언어를 바꾸면 창 전체를 새로 그립니다.
        .id(language)
    }
}

/// 한 줄짜리 설정 항목: 이름 + ⓘ 설명 + 오른쪽 조절 장치
private struct SettingRow<Control: View>: View {
    let title: String
    let info: String
    @ViewBuilder let control: Control

    var body: some View {
        HStack {
            Text(title)
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
                .help(info)
            Spacer()
            control
        }
    }
}

private struct GeneralPage: View {
    @EnvironmentObject private var store: PaletteStore
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.system.rawValue
    @AppStorage("copyFormat") private var copyFormat: CopyFormat = .hex
    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.system.rawValue
    @State private var confirmReset = false

    /// 미리보기에 쓸 색: 지금 팔레트의 첫 색, 없으면 예시 색
    private var sampleColor: RGB8 {
        store.current?.swatches.first?.color ?? RGB8(r: 58, g: 123, b: 213)
    }

    var body: some View {
        Form {
            Section {
                SettingRow(title: L("화면 모드", "Appearance", ja: "外観モード"),
                           info: L("라이트 또는 다크 모드를 고릅니다. ‘시스템 설정 따름’은 맥의 화면 모드를 따릅니다.",
                                   "Choose Light or Dark. “Follow System” matches your Mac’s appearance.", ja: "ライトまたはダークを選びます。「システム設定に従う」は Mac の外観モードに合わせます。")) {
                    Picker("", selection: $appearance) {
                        ForEach(AppAppearance.allCases) { Text($0.label).tag($0.rawValue) }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .onChange(of: appearance) { _, _ in AppAppearance.apply() }
                }
                SettingRow(title: L("언어", "Language", ja: "言語"),
                           info: L("앱에 표시되는 언어입니다. ‘시스템 설정 따름’은 맥의 언어 설정을 따릅니다.",
                                   "The language used in the app. “Follow System” uses your Mac’s language.", ja: "アプリに表示する言語です。「システム設定に従う」は Mac の言語設定に合わせます。")) {
                    Picker("", selection: $language) {
                        ForEach(AppLanguage.allCases) { Text($0.label).tag($0.rawValue) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                SettingRow(title: L("로그인 시 실행", "Launch at Login", ja: "ログイン時に起動"),
                           info: L("맥을 켜고 로그인하면 \(appName)가 메뉴바에 자동으로 나타납니다.",
                                   "Show \(appName) in the menu bar automatically when you log in.", ja: "ログインすると \(appName) がメニューバーに自動で表示されます。")) {
                    Toggle("", isOn: Binding(get: { store.launchAtLogin },
                                             set: { store.launchAtLogin = $0 }))
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                SettingRow(title: L("iCloud 동기화", "iCloud Sync", ja: "iCloud 同期"),
                           info: L("팔레트를 iCloud에 저장해 같은 Apple 계정을 쓰는 다른 맥과 맞춥니다. 처음 켜면 iCloud의 팔레트와 이 맥의 팔레트를 합칩니다.",
                                   "Store palettes in iCloud and keep them in sync across Macs using the same Apple Account. Turning it on merges iCloud and local palettes.", ja: "パレットを iCloud に保存し、同じ Apple アカウントを使う他の Mac と同期します。初めてオンにすると、iCloud とこの Mac のパレットを統合します。")) {
                    Toggle("", isOn: $store.iCloudSyncEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .disabled(!PaletteStore.iCloudAvailable)
                }
                if !PaletteStore.iCloudAvailable {
                    Text(L("이 빌드는 iCloud 권한 없이 서명되어 있어 동기화를 켤 수 없습니다. Apple 개발자 계정으로 서명한 정식 빌드에서 사용할 수 있습니다.",
                           "This build isn’t signed with iCloud access, so sync is unavailable. It works in builds signed with an Apple Developer account.", ja: "このビルドは iCloud の権限なしで署名されているため、同期を利用できません。Apple Developer アカウントで署名した正式ビルドで利用できます。"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section(L("복사", "Copy", ja: "コピー")) {
                SettingRow(title: L("복사 형식", "Copy Format", ja: "コピー形式"),
                           info: L("색 칩을 클릭했을 때 클립보드에 복사되는 글자의 형식입니다.",
                                   "The text format copied to the clipboard when you click a color chip.", ja: "カラーチップをクリックしたときにクリップボードへコピーされる文字の形式です。")) {
                    Picker("", selection: $copyFormat) {
                        ForEach(CopyFormat.allCases) { Text($0.name).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
                SettingRow(title: L("미리보기", "Preview", ja: "プレビュー"),
                           info: L("지금 팔레트의 첫 번째 색을 이 형식으로 복사하면 이렇게 됩니다.",
                                   "How the first color in the current palette is copied in this format.", ja: "現在のパレットの最初の色をこの形式でコピーした例です。")) {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(sampleColor.swiftUIColor)
                            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.primary.opacity(0.15)))
                            .frame(width: 18, height: 18)
                        Text(copyFormat.string(for: sampleColor))
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                    }
                }
            }

            Section {
                SettingRow(title: L("초기화", "Reset", ja: "リセット"),
                           info: L("설정과 팔레트를 모두 처음 상태로 되돌리거나, 설정은 두고 팔레트만 지울 수 있습니다.",
                                   "Reset both settings and palettes, or erase palettes only and keep your settings.", ja: "設定とパレットをすべて初期状態に戻すか、設定はそのままでパレットだけを削除できます。")) {
                    Button(L("초기화…", "Reset…", ja: "リセット…")) { confirmReset = true }
                }
            }
        }
        .confirmationDialog(L("무엇을 초기화할까요?", "What do you want to reset?", ja: "何をリセットしますか？"),
                            isPresented: $confirmReset) {
            Button(L("완전 초기화 (설정값, 팔레트 모두)", "Reset Everything (Settings & Palettes)", ja: "すべてリセット（設定とパレット）")) {
                store.resetAll()
            }
            Button(L("팔레트 초기화 (설정값은 유지)", "Reset Palettes (Keep Settings)", ja: "パレットをリセット（設定は保持）")) {
                store.resetPalettes()
            }
            Button(L("취소", "Cancel", ja: "キャンセル"), role: .cancel) {}
        } message: {
            Text(L("두 가지 모두 저장한 팔레트와 색을 지우며 되돌릴 수 없습니다.\n\n‘완전 초기화’는 화면 모드·언어·복사 형식·로그인 시 실행·iCloud 동기화·고정도 처음 상태로 되돌립니다. 동기화를 먼저 끄기 때문에 iCloud와 다른 맥의 팔레트는 지우지 않습니다.\n\n‘팔레트 초기화’는 설정값을 그대로 둡니다. iCloud 동기화를 켜 두었다면 같은 계정의 다른 맥에서도 팔레트가 지워집니다.",
                   "Both options delete your saved palettes and colors and can’t be undone.\n\n“Reset Everything” also restores appearance, language, copy format, Launch at Login, iCloud Sync, and pinning. Sync is turned off first, so palettes in iCloud and on other Macs are kept.\n\n“Reset Palettes” keeps your settings. If iCloud Sync is on, palettes are also removed on your other Macs.", ja: "どちらも保存したパレットと色を削除し、元に戻すことはできません。\n\n「すべてリセット」は外観モード・言語・コピー形式・ログイン時に起動・iCloud 同期・固定も初期状態に戻します。先に同期をオフにするため、iCloud と他の Mac のパレットは削除されません。\n\n「パレットをリセット」は設定をそのまま保持します。iCloud 同期がオンの場合、同じアカウントの他の Mac でもパレットが削除されます。"))
        }
    }
}

private struct PalettesPage: View {
    @EnvironmentObject private var store: PaletteStore

    var body: some View {
        Form {
            Section(L("저장된 팔레트", "Saved Palettes", ja: "保存したパレット")) {
                ForEach(store.palettes) { p in
                    HStack {
                        HStack(spacing: 3) {
                            ForEach(Array(p.swatches.prefix(8))) { s in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(s.color.swiftUIColor)
                                    .frame(width: 12, height: 12)
                            }
                        }
                        Text(p.name)
                        Spacer()
                        Text(L("\(p.swatches.count)색", "\(p.swatches.count) colors", ja: "\(p.swatches.count) 色"))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section(L("파일", "Files", ja: "ファイル")) {
                SettingRow(title: L("현재 팔레트 내보내기", "Export Current Palette", ja: "現在のパレットを書き出す"),
                           info: L("지금 고른 팔레트를 .json 파일로 저장합니다. 다른 맥에서 가져올 수 있습니다.",
                                   "Save the current palette as a .json file you can import on another Mac.", ja: "現在のパレットを .json ファイルとして保存します。他の Mac で読み込めます。")) {
                    Button(L("내보내기…", "Export…", ja: "書き出す…")) { store.exportCurrent() }
                }
                SettingRow(title: L("팔레트 가져오기", "Import Palettes", ja: "パレットを読み込む"),
                           info: L("내보낸 .json 파일을 새 팔레트로 불러옵니다. 여러 파일을 한 번에 고를 수 있습니다.",
                                   "Load exported .json files as new palettes. You can choose several files.", ja: "書き出した .json ファイルを新しいパレットとして読み込みます。複数のファイルを一度に選べます。")) {
                    Button(L("가져오기…", "Import…", ja: "読み込む…")) { store.importFromFile() }
                }
            }
        }
    }
}

/// 외부 웹페이지 링크 (GitHub Pages: gotgam100/ColorMixBar 저장소의 docs 폴더)
enum AppLinks {
    /// 이용약관 및 정책 페이지. 앱 언어에 맞는 페이지를 엽니다.
    static var termsAndPolicy: URL? {
        let base = "https://gotgam100.github.io/ColorMixBar/"
        switch AppLanguage.resolved {
        case .ko: return URL(string: base)
        case .ja: return URL(string: base + "ja/")
        case .en, .system: return URL(string: base + "en/")
        }
    }
}

private struct AboutPage: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    @State private var showLicense = false

    private var licenseText: String {
        guard let url = Bundle.main.url(forResource: "spectral-js-LICENSE", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return text
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(appName).font(.title3.weight(.semibold))
                        Text(L("버전 \(version)", "Version \(version)", ja: "バージョン \(version)")).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                SettingRow(title: L("이용약관 및 정책", "Terms & Policies", ja: "利用規約とポリシー"),
                           info: L("이용약관과 개인정보 처리방침을 웹페이지에서 엽니다.",
                                   "Opens the terms of use and privacy policy in your browser.", ja: "利用規約とプライバシーポリシーをブラウザで開きます。")) {
                    Button {
                        if let url = AppLinks.termsAndPolicy { NSWorkspace.shared.open(url) }
                    } label: {
                        Label(L("열기", "Open", ja: "開く"), systemImage: "arrow.up.right.square")
                    }
                    .disabled(AppLinks.termsAndPolicy == nil)
                    .help(AppLinks.termsAndPolicy == nil
                          ? L("링크 준비 중입니다", "Link coming soon", ja: "リンクは準備中です")
                          : (AppLinks.termsAndPolicy?.absoluteString ?? ""))
                }
            }

            Section {
                // MIT 라이선스는 앱과 함께 저작권 표시를 남기라고 요구하므로, 짧은 한 줄로 두고 누르면 전문을 보여 줍니다.
                SettingRow(title: L("오픈소스 라이선스", "Open Source Licenses", ja: "オープンソースライセンス"),
                           info: L("물감처럼 섞는 계산은 spectral.js(MIT 라이선스)를 Swift로 옮겨 사용했습니다.",
                                   "Paint-like color mixing is ported from spectral.js (MIT License).", ja: "絵の具のような混色の計算は、spectral.js（MIT ライセンス）を Swift に移植して使用しています。")) {
                    Button(L("보기", "View", ja: "表示")) { showLicense = true }
                }
            }
        }
        .sheet(isPresented: $showLicense) {
            VStack(alignment: .leading, spacing: 12) {
                Text("spectral.js").font(.headline)
                ScrollView {
                    Text(licenseText)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack {
                    Spacer()
                    Button(L("닫기", "Close", ja: "閉じる")) { showLicense = false }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
            .frame(width: 520, height: 380)
        }
    }
}
