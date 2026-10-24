# ColorMix Bar — Claude 작업 안내

macOS 메뉴바 컬러 팔레트 앱. 스포이드·원형 색상표로 색을 모으고, 클릭해 복사하고, 물감처럼 섞는다.
App Store 유료 앱(₩1,100, 일회성 구매, 앱 내 구입 없음)으로 제출 준비가 끝난 상태.

## 사용자와 일하는 방식
- 사용자는 한국어로 소통하고, 쉬운 말로 짧게 설명하는 것을 선호한다. 기술 용어는 풀어서 설명한다.
- 이 맥에서 Claude는 **화면 캡처·마우스 조작 권한이 없다.** 클릭·드래그가 필요한 동작은 사용자에게 시험을 부탁하고, 화면 확인은 `NSHostingView` 렌더링 이미지로 대신한다.
- GitHub 푸시, 개발자 계정 변경(앱 ID 등록 등)처럼 밖에 남는 일은 사용자가 요청했을 때만 한다.

## 기본 정보
| 항목 | 값 |
|---|---|
| 폴더 | `05_CODE/ColorMix Bar` (예전 `etc/palette-bar` → `etc/ColorMix Bar` → 지금 위치로 옮김) |
| 번들 ID | `com.baekmac.ColorMixBar` (개발자 계정에 iCloud 키-값 저장소 기능과 함께 등록됨) |
| 팀 | `SB2Z6HL579` (Xcode 자동 서명) |
| 버전 | 1.0, 빌드 4 (`project.yml`의 `CURRENT_PROJECT_VERSION`. 이미 올린 번호는 다시 못 올림) |
| 최소 macOS | 14.0 |
| GitHub | https://github.com/gotgam100/ColorMixBar (**공개 저장소** — 소스 전체가 공개됨. 사용자가 선택함) |
| 웹페이지 | https://gotgam100.github.io/ColorMixBar/ (`/en/`, `/ja/`) — GitHub Pages, main 브랜치 `/docs` |
| 연락처 | yogotgam@gmail.com (웹페이지·지원 페이지에 공개된 개발자 이메일) |

## 빌드
`project.yml`이 원본이고 `ColorMixBar.xcodeproj`는 XcodeGen이 만든다. 소스 파일을 추가·삭제하면 `xcodegen generate`를 다시 돌려야 한다.
```bash
xcodegen generate
xcodebuild -project ColorMixBar.xcodeproj -scheme ColorMixBar -configuration Release -derivedDataPath build -allowProvisioningUpdates build
```
- 경고 0개로 빌드되는 상태를 유지한다.
- 프로젝트 안 `build/`에 새 derivedData 폴더를 만들면 "disk I/O error"가 난 적이 있다. 깨끗한 빌드 확인은 스크래치 폴더에 `-derivedDataPath`를 주고 한다.
- App Store 아카이브·내보내기 명령은 `README.md`에 있다. 내보내기 설정은 `dist/ExportOptions.plist`(app-store-connect, export만 함).

## 코드 구조
| 파일 | 역할 |
|---|---|
| `Sources/App.swift` | 메뉴바 아이콘, 팝오버, 고정 패널(NSPanel), 끌어서 떼어내기, 스포이드, 설정 창 |
| `Sources/PaletteStore.swift` | 데이터·상태 전부: 팔레트 저장(JSON), 섞기 접시, 복사·붙여넣기, 내보내기·가져오기, iCloud, 초기화, 로그인 시 실행 |
| `Sources/PaletteView.swift` | 팝오버 화면 (탭 줄, 색 칩 판, 섞기 접시, [설정][종료]) |
| `Sources/ColorWheelPicker.swift` | '+'로 여는 원형 색상표 |
| `Sources/SettingsView.swift` | 설정 창(일반/팔레트/정보), `AppLinks`(이용약관 링크) |
| `Sources/Localization.swift` | `appName`, 언어(`AppLanguage`, `L`), 화면 모드(`AppAppearance`) |
| `Sources/SpectralMixer.swift`, `SpectralData.swift` | 물감처럼 섞는 계산 (spectral.js 3.0.0 MIT를 Swift로 옮김) |
| `Sources/PrivacyInfo.xcprivacy` | 개인정보 신고: 수집·추적 없음, UserDefaults 사용 이유 CA92.1 |

## 꼭 지킬 규칙 (지키지 않으면 실제로 문제가 났던 것들)
- **스포이드(NSColorSampler)**: 색을 고른 직후 팝오버를 다시 열거나 `NSApp.activate()`를 부르지 않는다. 그렇게 했다가 보이지 않는 ColorSampler 창이 남아 **맥 전체의 클릭이 막혔다.** 지금은 샘플러 객체를 붙잡아 두고, 0.2초 뒤에 띄우고, 고른 뒤 0.3초 뒤에 저장하며, 메뉴바 아이콘만 잠깐 그 색으로 바꾼다. 막히면 `ColorSampler.xpc` 프로세스를 강제 종료하면 풀린다.
- **문구는 모두 `L("한국어", "English", ja: "日本語")`**로 쓴다. `ja:`는 필수 인자라 빠뜨리면 빌드가 실패한다(번역 누락 방지). 메뉴 이름을 바꾸면 웹페이지 지원 안내(`tools/docs`)도 같이 맞춘다.
- **팝오버 크기는 고정**: 탭 줄 40pt, 색 칩 판 3줄 높이, 섞기 접시 74pt, 아래 줄 20pt. 내용에 따라 높이가 바뀌면 안 된다.
- **색 칩 30pt, 간격 6pt**: 한 줄 7개가 카드 안쪽(268pt)에 스크롤바까지 들어가야 한다. 넘치면 위쪽 이름·버튼 줄이 옆으로 밀린다.
- **확인 창 버튼에 `role: .destructive`를 쓰지 않는다**(다크 모드에서 붉은 배경에 붉은 글씨라 안 보임). 취소 버튼은 직접 넣는다(자동 취소 버튼은 시스템 언어로 나옴). 오른쪽 클릭 메뉴의 '삭제'만 destructive를 쓴다.
- **설정 창에 NavigationSplitView를 쓰지 않는다**(도구 막대가 생겨 사이드바 가리기 버튼이 나오고 첫 줄을 가림). 사이드바는 HStack으로 직접 배치한다.
- **붙여넣기는 시스템 클립보드를 읽지 않는다**(최신 macOS의 허용 창 때문). 앱 안에 기억한 `copiedColor`만 쓴다. 클립보드에는 쓰기만 한다.
- **탭 끌기 데이터**는 `"colormixbar-palette:" + UUID` 글자다. 색 코드로 읽히지 않으므로 탭 위에 놓이면 순서 바꾸기, 색이면 그 팔레트에 추가로 구분한다.
- **iCloud**: 키-값 저장소, 값 1MB 제한(넘으면 올리지 않음). 팀 서명 빌드에서만 동작한다(`PaletteStore.iCloudAvailable`). '완전 초기화'는 동기화를 먼저 꺼서 iCloud의 팔레트를 지우지 않고, '팔레트 초기화'는 켜져 있으면 다른 맥에서도 지운다.
- 팀 서명된 앱의 저장 폴더(`~/Library/Containers/com.baekmac.ColorMixBar`)는 macOS가 보호해서 셸에서 읽을 수 없다.

## 자주 하는 작업
- **스크린샷 다시 만들기** (2880×1800, 한·영·일 각 5장 → `AppStoreScreenshots/`):
  `tools/screenshots/make.sh`. 문구·예시 팔레트는 `tools/screenshots/main.swift`의 `T`, `makeStore`. 캡처 권한이 없어 사이드바 선택·스위치·주요 버튼은 스크린샷 전용 스타일로 대체해 그린다(`Styles.swift`).
- **웹페이지 고치기** (`docs/`, 한·영·일 각 5쪽):
  `python3 tools/docs/gen_docs.py docs Sources/Resources/spectral-js-LICENSE.txt` 로 다시 만든다(한·영은 `gen_docs.py`, 일본어는 `gen_docs_ja.py`). `docs/styles.css`는 손으로 관리하며 생성기가 덮어쓰지 않는다. 커밋·푸시하면 GitHub Pages에 반영된다.
- **기존 테스트**: 섞기 결과는 원본 spectral.js와 정해 둔 9개 + 무작위 300개 조합이 모두 일치했다. 색 코드 읽기, 팝업 높이 고정, 초기화, 탭 순서, 복사·붙여넣기도 검사했다. 테스트는 스크래치 폴더에서 소스를 함께 컴파일하는 방식으로 돌렸다.

## 로그인 시 실행 (폴더를 옮길 때)
지금은 `build/Build/Products/Release/ColorMixBar.app`이 메뉴바에서 돌고, 로그인 항목도 이 경로로 등록되어 있다. 폴더를 옮기면:
1. 앱을 끄고 옮긴 뒤 새 위치의 앱을 실행, `lsregister -u`로 옛 경로 등록을 정리한다.
2. 사용자에게 **설정 → 일반 화면을 열기만** 해 달라고 한다. 앱이 상태를 조회할 때 macOS가 경로를 새 위치로 고친다. 스위치를 껐다 켜면 꺼진 채로 끝난 적이 있다.
3. `sfltool dumpbtm`으로 `com.baekmac.ColorMixBar`의 Disposition·URL을 확인한다.

## App Store 등록 상태
- 등록 문구(한·영·중 간체·일, 글자 수 검증 완료), 가격, URL, 개인정보, 심사 메모, 체크리스트는 `APP_STORE.md`에 있다.
- App Store Connect에서 완료: 앱 개인정보 '데이터를 수집하지 않음', 개인정보 처리방침 URL, 심사 연락처, DSA 거래자 신고 진행(사업자등록증 제출).
- 남은 일: Xcode에서 이 폴더의 프로젝트로 아카이브 → 업로드 → 심사 제출. 중국 본토는 ICP 번호가 없으면 판매 국가에서 뺀다.
- 앱 내 구입은 만들지 않는다(유료 앱). 설명·약관에도 '앱 내 구입 없음'으로 적혀 있다.
