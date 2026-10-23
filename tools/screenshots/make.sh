#!/bin/zsh
# App Store 스크린샷(2880×1800, 한국어·영어 각 5장)을 다시 만듭니다.
# 사용: tools/screenshots/make.sh   (프로젝트 폴더 어디서든)
set -e
T=${0:A:h}; P=${T:h:h}; B=$(mktemp -d)
# 스크린샷용 사본: iCloud를 '사용 가능'으로 표시, 설정 창 시작 페이지 지정,
# 캡처 권한 없이 그릴 때 빠지는 macOS 재질(사이드바 선택·스위치·주요 버튼)을 활성 창 모양으로 대체
sed 's/    static let iCloudAvailable: Bool = {/    static let iCloudAvailable: Bool = true\n    static let iCloudAvailableReal: Bool = {/' "$P/Sources/PaletteStore.swift" > $B/PaletteStore.swift
python3 - "$P" "$B" <<'PY'
import sys
P, B = sys.argv[1], sys.argv[2]
s = open(P + "/Sources/SettingsView.swift").read()
s = s.replace('@State private var page: SettingsPage? = .general',
              '@State private var page: SettingsPage?\n    init(initialPage: String = "general") { _page = State(initialValue: SettingsPage(rawValue: initialPage)) }')
s = s.replace('''            List(SettingsPage.allCases, selection: $page) { p in
                Label(p.title, systemImage: p.icon).tag(p)
            }
            .listStyle(.sidebar)''', '''            ShotSidebar(pages: SettingsPage.allCases, selected: page, title: { $0.title }, icon: { $0.icon })''')
s = s.replace(".toggleStyle(.switch)", ".toggleStyle(MacSwitchStyle())")
open(B + "/SettingsView.swift", "w").write(s)
w = open(P + "/Sources/ColorWheelPicker.swift").read()
open(B + "/ColorWheelPicker.swift", "w").write(w.replace(".buttonStyle(.borderedProminent)", ".buttonStyle(AccentButtonStyle())"))
PY
swiftc -O -o $B/shots "$T/main.swift" "$T/Styles.swift" $B/PaletteStore.swift $B/SettingsView.swift $B/ColorWheelPicker.swift \
  "$P/Sources/PaletteView.swift" "$P/Sources/SpectralMixer.swift" "$P/Sources/SpectralData.swift" "$P/Sources/Localization.swift"
for L in ko en ja; do
  mkdir -p "$P/AppStoreScreenshots/$L"
  defaults delete shots 2>/dev/null || true
  $B/shots "$P/AppStoreScreenshots/$L" $L "$P/Sources/Assets.xcassets/AppIcon.appiconset/icon_256.png"
done
defaults delete shots 2>/dev/null || true
rm -rf "$HOME/Library/Application Support/ColorMixBar" $B   # 생성 중 만든 예시 데이터 정리
echo "완료: $P/AppStoreScreenshots"
