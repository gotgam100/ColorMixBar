# ColorMix Bar

메뉴바에 상주하는 단순한 색상 팔레트 앱입니다. 스포이드나 원형 색상표로 색을 모아 두고, 클릭해서 복사하고, 물감처럼 섞을 수 있습니다. App Store 샌드박스 안에서 동작합니다.

- 앱 ID: `com.baekmac.ColorMixBar`
- 대상: macOS 14 이상
- 앱 아이콘: `Sources/Assets.xcassets/AppIcon.appiconset` (물감 방울 세 개를 곱하기로 겹친 그림)

## 쓰는 법
- **색 모으기**: 파란 스포이드로 화면의 색을 찍거나, `+`를 눌러 원형 색상표에서 고릅니다. 스포이드로 찍으면 메뉴바 아이콘이 1.5초 동안 그 색으로 바뀝니다.
  - 색을 고른 뒤 팝업을 자동으로 다시 열지 않는 것은 일부러 그런 것입니다. 스포이드가 정리되는 중에 팝업을 열면 보이지 않는 스포이드 창이 남아 맥 전체의 클릭을 막는 문제가 있었습니다(`App.swift`의 `pickColor` 주석 참고).
- **복사**: 색 칩을 클릭하면 복사됩니다(형식은 설정에서 HEX / RGB / HSL).
- **다른 팔레트로 옮기기**: 색 칩을 위쪽 팔레트 탭에 끌어다 놓거나, 칩 오른쪽 클릭 → ‘색상 복사’ 후 탭이나 빈 곳을 오른쪽 클릭 → ‘색상 붙여넣기’.
- **섞기**: 색 칩을 섞기 접시로 끌어다 놓습니다. 같은 색을 여러 번 놓으면 그만큼 많이 섞입니다.
- **팔레트**: 탭을 누르면 불러오고, `+`로 ‘새 팔레트1’, ‘새 팔레트2’… 를 만듭니다. 이름이나 탭을 오른쪽 클릭하면 이름 변경·복제·삭제.
- **고정**: 제목 오른쪽 📌를 누르거나 제목 줄을 끌어 떼어내면, 다른 앱 위에 계속 떠 있는 창이 됩니다.
- **설정**: 화면 모드, 언어(한국어/English/日本語), 로그인 시 실행, iCloud 동기화, 복사 형식, 초기화(완전 / 팔레트만).

## 섞는 방식
화면의 빛처럼 평균을 내면 파랑과 노랑이 회색이 되지만, 이 앱은 물감처럼 초록이 되게 섞습니다. [spectral.js](https://github.com/rvanwijnen/spectral.js) 3.0.0(MIT 라이선스)의 Kubelka-Munk 혼합 계산을 Swift로 옮겼고, 원본과 결과가 같은지 확인했습니다. 라이선스 전문은 앱의 설정 → 정보 → 오픈소스 라이선스에서 볼 수 있습니다.

## 빌드
팀 `SB2Z6HL579`로 자동 서명합니다. 처음이거나 기능이 바뀌면 `-allowProvisioningUpdates`가 개발자 계정의 앱 ID·프로필을 맞춰 줍니다.
```bash
xcodegen generate
xcodebuild -project ColorMixBar.xcodeproj -scheme ColorMixBar -configuration Release -derivedDataPath build -allowProvisioningUpdates build
```

## App Store용 아카이브·내보내기
Xcode에서 Product → Archive로 해도 되고, 터미널에서는 아래처럼 합니다. `BUILD`는 `project.yml`의 `CURRENT_PROJECT_VERSION`과 같게 맞춥니다.
```bash
BUILD=4
AR="$HOME/Library/Developer/Xcode/Archives/$(date +%Y-%m-%d)/ColorMixBar 1.0 ($BUILD).xcarchive"
xcodebuild -project ColorMixBar.xcodeproj -scheme ColorMixBar -configuration Release -derivedDataPath build -allowProvisioningUpdates -archivePath "$AR" archive
xcodebuild -exportArchive -archivePath "$AR" -exportOptionsPlist dist/ExportOptions.plist -exportPath dist/AppStore -allowProvisioningUpdates
```
- 아카이브는 Xcode → Window → Organizer에 보입니다. 거기서 **Distribute App**으로 바로 올려도 됩니다.
- `dist/AppStore/ColorMix Bar.pkg`는 **Transporter** 앱으로 올릴 수 있습니다.
- 다시 올릴 때는 `project.yml`의 `CURRENT_PROJECT_VERSION`(빌드 번호)을 하나 올려야 합니다. 같은 번호는 다시 올릴 수 없습니다.

| 파일 | 역할 |
|---|---|
| `project.yml` | 프로젝트 설정, 앱 이름·ID, 메뉴바 전용(`LSUIElement`), 샌드박스 권한 |
| `Sources/App.swift` | 메뉴바 아이콘, 팝업, 떠 있는 창(고정), 스포이드, 설정 창 |
| `Sources/PaletteStore.swift` | 팔레트 저장, 섞기 접시, 복사·붙여넣기, 내보내기·가져오기, iCloud, 초기화 |
| `Sources/PaletteView.swift` | 팝업 화면 |
| `Sources/ColorWheelPicker.swift` | 원형 색상표 |
| `Sources/SettingsView.swift` | 설정 창, `AppLinks`(이용약관 링크) |
| `Sources/Localization.swift` | 앱 이름, 언어 전환(`L`), 화면 모드 |
| `Sources/SpectralMixer.swift`, `SpectralData.swift` | 물감처럼 섞는 계산 |
| `Sources/PrivacyInfo.xcprivacy` | App Store 개인정보 신고(추적·수집 없음, UserDefaults 사용 이유) |
| `docs/` | 고객지원·개인정보 처리방침·이용약관·오픈소스 라이선스 웹페이지(한국어·영어·일본어, 일본어는 `docs/ja/`). 커밋·푸시하면 GitHub Pages에 반영됩니다 |
| `tools/docs/` | 웹페이지 생성기. `python3 tools/docs/gen_docs.py docs Sources/Resources/spectral-js-LICENSE.txt` (일본어 내용은 `gen_docs_ja.py`, `docs/styles.css`는 직접 관리) |
| `tools/screenshots/` | App Store 스크린샷 생성기. `tools/screenshots/make.sh` → `AppStoreScreenshots/`(한·영·일 각 5장, 2880×1800) |
| `CLAUDE.md` | Claude Code 작업 안내(규칙, 주의할 점, 진행 상황) |

저장 위치: `~/Library/Containers/com.baekmac.ColorMixBar/Data/Library/Application Support/ColorMixBar/palettes.json`

## App Store 제출 진행 상황
- [x] 개발자 계정에 앱 ID `com.baekmac.ColorMixBar` 등록 (iCloud 키-값 저장소 포함), 팀 `SB2Z6HL579` 자동 서명
- [x] 이용약관·개인정보 처리방침 페이지(`docs/`)를 GitHub Pages로 공개: https://gotgam100.github.io/ColorMixBar/ — 앱의 이용약관 및 정책 버튼에 연결
- [x] App Store용 아카이브(1.0, 빌드 4: 일본어 앱·일본어 웹페이지 연결 포함)와 `dist/AppStore/ColorMix Bar.pkg` 내보내기
- [x] App Store Connect 등록 정보 입력 (`APP_STORE.md`), 앱 개인정보·심사 연락처·개인정보 처리방침 URL
- [ ] 업로드 (Organizer의 Distribute App 또는 Transporter)
