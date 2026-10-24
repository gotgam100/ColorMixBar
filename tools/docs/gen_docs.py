#!/usr/bin/env python3
"""ColorMix Bar 이용약관 및 정책 페이지(한국어·영어·일본어)를 만듭니다. 사용: gen_docs.py <docs 폴더> <spectral LICENSE 파일>"""
import html, os, sys

OUT, LICENSE_FILE = sys.argv[1], sys.argv[2]
MAIL = "yogotgam@gmail.com"
LICENSE_TEXT = html.escape(open(LICENSE_FILE, encoding="utf-8").read().strip())

T = {
    "ko": dict(sub="색을 모으고, 물감처럼 섞고", other="English", date="2026년 10월 23일",
               copy=f"© 2026 ColorMix Bar. All rights reserved."),
    "en": dict(sub="Collect colors. Mix like paint.", other="한국어", date="October 23, 2026",
               copy=f"© 2026 ColorMix Bar. All rights reserved."),
    "ja": dict(sub="色を集めて、絵の具のように混ぜる", other="", date="2026年10月23日",
               copy=f"© 2026 ColorMix Bar. All rights reserved."),
}

LANG_NAMES = {"ko": "한국어", "en": "English", "ja": "日本語"}


def lang_href(cur, target, name):
    """지금 언어 페이지에서 다른 언어의 같은 페이지로 가는 상대 경로. 한국어는 맨 위 폴더, 영어·일본어는 하위 폴더."""
    if cur == "ko":
        return f"./{target}/{name}"
    return f"../{name}" if target == "ko" else f"../{target}/{name}"


def page(lang, name, title, body, small=True):
    root = "./" if lang == "ko" else "../"
    switch = "".join(f'<a class="lang" href="{lang_href(lang, o, name)}">{LANG_NAMES[o]}</a>'
                     for o in ("ko", "en", "ja") if o != lang)
    t = T[lang]
    hero = "hero small" if small else "hero"
    return f"""<!doctype html>
<html lang="{lang}">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{title} - ColorMix Bar</title>
  <link rel="icon" href="{root}icon.png">
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/dist/web/static/pretendard.min.css">
  <link rel="stylesheet" href="{root}styles.css">
</head>
<body>
  <header class="{hero}">
    <div class="inner">
      <span class="langs">{switch}</span>
      <a class="brand" href="./index.html"><img class="logo" src="{root}icon.png" alt=""><span><span class="brand-name">ColorMix Bar</span><br><span class="brand-sub">{t['sub']}</span></span></a>
    </div>
  </header>
  <main class="wrap">
{body}
  </main>
</body>
</html>
"""


def foot(lang, effective=True):
    t = T[lang]
    first = ({"ko": f"본 문서는 {t['date']}부터 적용됩니다.<br>", "en": f"Effective as of {t['date']}.<br>",
              "ja": f"本書は{t['date']}から適用されます。<br>"}[lang]) if effective else ""
    return f'<p class="foot">{first}{t["copy"]} · <a href="mailto:{MAIL}">{MAIL}</a></p>'


def article(inner):
    return f'    <article class="panel">\n{inner}\n    </article>'


def faq(items):
    return "\n".join(f"<details><summary>{q}</summary><p>{a}</p></details>" for q, a in items)


# ---------------- 첫 화면 ----------------
def index(lang):
    cards = [("support.html", "#F2C230", "고객지원", "Support", "サポート"),
             ("privacy.html", "#3E8EDE", "개인정보 처리방침", "Privacy Policy", "プライバシーポリシー"),
             ("terms.html", "#EF5B8A", "이용약관", "Terms of Service", "利用規約"),
             ("licenses.html", "#4E9A4A", "오픈소스 라이선스", "Open Source Licenses", "オープンソースライセンス")]
    rows = []
    for href, color, ko, en, ja in cards:
        main, sub = {"ko": (ko, en), "en": (en, ko), "ja": (ja, en)}[lang]
        rows.append(f'      <a class="card" href="./{href}"><span class="bar" style="background:{color}"></span>'
                    f'<span class="body"><div class="title">{main}</div><div class="en">{sub}</div></span><span class="arrow">→</span></a>')
    heading, lead = {"ko": ("이용정책 및 약관", "ColorMix Bar 이용에 필요한 안내와 문서를 모았어요."),
                     "en": ("Policies & Terms", "Support and legal documents for ColorMix Bar."),
                     "ja": ("利用規約とポリシー", "ColorMix Bar をご利用いただくための案内と文書をまとめました。")}[lang]
    body = f"""    <section>
      <h2 class="group">{heading}</h2>
      <p class="lead">{lead}</p>
{chr(10).join(rows)}
    </section>
    <footer>{T[lang]['copy']}<br><a href="mailto:{MAIL}">{MAIL}</a></footer>"""
    return page(lang, "index.html", heading, body, small=False)


# ---------------- 고객지원 ----------------
def support(lang):
    if lang == "ja":
        return support_ja()
    if lang == "ko":
        items = [
            ("앱을 열었는데 창이 보이지 않아요.", "ColorMix Bar는 메뉴바 앱이라 Dock 아이콘과 창이 없어요. 화면 오른쪽 위 메뉴바의 팔레트 아이콘을 누르면 열립니다. 메뉴바 아이콘이 많아 가려졌다면 다른 아이콘을 줄여 보세요."),
            ("화면의 색을 가져오려면요?", "파란 스포이드 버튼을 누르고 화면에서 원하는 곳을 클릭하세요(취소는 Esc). 찍은 색은 지금 팔레트에 바로 저장되고, 메뉴바 아이콘이 잠깐 그 색으로 바뀝니다. 화면 녹화 권한은 필요 없어요."),
            ("원하는 색을 직접 만들 수 있나요?", "스포이드 왼쪽의 + 버튼을 누르면 원형 색상표가 나와요. 원 위에서 색을 고르고 밝기 막대로 조절한 뒤 ‘팔레트에 추가’를 누르세요."),
            ("색을 복사하려면요?", "색 칩을 클릭하면 복사됩니다. 복사 형식(HEX, RGB, HSL)은 설정 › 일반 › 복사 형식에서 고를 수 있어요. 칩을 오른쪽 클릭 › 다른 형식으로 복사를 써도 되고, 칩을 다른 앱의 입력칸으로 끌어다 놓아도 돼요."),
            ("색은 어떻게 섞나요?", "색 칩을 아래 섞기 접시로 끌어다 놓으세요. 같은 색을 여러 번 놓으면 그 색이 더 많이 섞이고, 접시의 작은 동그라미를 누르면 하나씩 빠집니다. 결과 색을 클릭하면 복사되고 ‘팔레트에 추가’로 저장할 수 있어요. 파랑과 노랑을 섞으면 회색이 아니라 초록이 되는 물감 혼합 방식이에요."),
            ("팔레트를 여러 개 쓰고 싶어요.", "위쪽 탭 줄의 +로 새 팔레트를 만들고, 탭을 눌러 바꿉니다. 탭을 오른쪽 클릭하면 이름 변경·복제·삭제, 탭을 끌어 다른 탭 위에 놓으면 순서가 바뀝니다."),
            ("색을 다른 팔레트로 옮기려면요?", "색 칩을 다른 팔레트 탭 위로 끌어다 놓으세요. 또는 칩을 오른쪽 클릭 › 색상 복사 후, 탭이나 칩 판의 빈 곳을 오른쪽 클릭 › 색상 붙여넣기를 누르면 됩니다."),
            ("다른 앱을 쓰는 동안 계속 띄워 두고 싶어요.", "팝업 제목 오른쪽의 📌을 누르거나, 제목 줄을 잡고 메뉴바에서 멀리 끌면 다른 앱 위에 떠 있는 작은 창이 됩니다. 📌을 다시 누르거나 창을 닫으면 원래대로 돌아가요."),
            ("팔레트를 백업하거나 다른 맥으로 옮기려면요?", "설정 › 팔레트에서 팔레트를 .json 파일로 내보내고, 다른 맥에서 가져오면 됩니다. 같은 Apple 계정이라면 iCloud 동기화를 켜도 돼요."),
            ("iCloud 동기화가 안 돼요.", "두 맥 모두 같은 Apple 계정으로 iCloud에 로그인되어 있는지, 앱의 설정 › 일반 › iCloud 동기화가 켜져 있는지 확인해 주세요. 다른 맥에 나타나기까지 몇 분 걸릴 수 있어요. 처음 켜면 iCloud의 팔레트와 이 맥의 팔레트를 합칩니다."),
            ("언어나 화면 모드를 바꾸고 싶어요.", "설정 › 일반에서 화면 모드(시스템 설정 따름/라이트/다크)와 언어(시스템 설정 따름/한국어/English/日本語)를 고르면 바로 바뀝니다."),
            ("맥을 켤 때 자동으로 실행되게 하려면요?", "설정 › 일반 › 로그인 시 실행을 켜 주세요."),
            ("처음 상태로 되돌리고 싶어요.", "설정 › 일반 › 초기화에서 ‘완전 초기화’(설정과 팔레트 모두) 또는 ‘팔레트 초기화’(설정은 유지)를 고를 수 있어요. 지운 팔레트는 되돌릴 수 없습니다."),
            ("앱을 삭제하려면요?", "로그인 시 실행을 켜 두었다면 먼저 끄고, 팝업 아래 ‘종료’를 누른 뒤 응용 프로그램 폴더에서 ColorMix Bar를 휴지통으로 옮기세요."),
            ("환불받고 싶어요.", 'App Store 결제는 Apple이 처리하므로 <a href="https://reportaproblem.apple.com">reportaproblem.apple.com</a>에서 Apple에 환불을 요청해 주세요. 개발자는 직접 환불할 수 없어요.'),
            ("내 정보는 어디에 저장되나요?", '내 맥과, iCloud 동기화를 켠 경우 내 iCloud에만 저장되고 개발자는 볼 수 없어요. 자세한 내용은 <a href="./privacy.html">개인정보 처리방침</a>을 확인해 주세요.'),
        ]
        inner = f"""<h1>고객지원</h1>
<p>문의, 오류 제보, 개선 의견은 아래 이메일로 보내주세요. 보통 영업일 기준 3일 안에 답장드립니다.</p>
<a class="mail" href="mailto:{MAIL}?subject=%5BColorMix%20Bar%5D%20%EB%AC%B8%EC%9D%98">{MAIL}</a>
<p class="note">오류를 제보할 때 <strong>맥 모델, macOS 버전, 앱 버전</strong>(설정 › 정보)과 어떤 순서로 하다가 문제가 생겼는지, 가능하면 화면 캡처를 함께 보내주시면 빨리 해결할 수 있어요.</p>
<h2>자주 묻는 질문</h2>
{faq(items)}
{foot(lang, effective=False)}"""
        return page(lang, "support.html", "고객지원", article(inner))
    items = [
        ("I opened the app but no window appears.", "ColorMix Bar is a menu bar app, so it has no Dock icon or main window. Click the palette icon in the menu bar at the top right of your screen. If your menu bar is crowded, the icon may be hidden behind other icons."),
        ("How do I pick a color from the screen?", "Click the blue eyedropper button, then click anywhere on screen (press Esc to cancel). The color is saved to the current palette and the menu bar icon briefly shows it. No Screen Recording permission is needed."),
        ("Can I make my own color?", "Click + next to the eyedropper to open the color wheel. Choose a color, adjust brightness, and click “Add to Palette”."),
        ("How do I copy a color?", "Click a color chip. Choose the format (HEX, RGB, HSL) in Settings › General › Copy Format. You can also right-click › Copy As, or drag a chip into a text field in another app."),
        ("How do I mix colors?", "Drag color chips into the Mixing Dish. Drop the same color again to add more of it, and click a small dot in the dish to remove one. Click the result to copy it, or “Add to Palette” to keep it. Mixing works like paint: blue and yellow make green, not gray."),
        ("Can I have more than one palette?", "Use + in the tab row to create a palette and click a tab to switch. Right-click a tab to rename, duplicate, or delete it, and drag a tab onto another to reorder."),
        ("How do I move a color to another palette?", "Drag the chip onto another palette’s tab. Or right-click the chip › Copy Color, then right-click a tab or an empty area › Paste Color."),
        ("Can it stay open while I use other apps?", "Click 📌 next to the title, or drag the title bar away from the menu bar, to turn it into a small floating window. Click 📌 again or close the window to go back."),
        ("How do I back up palettes or move them to another Mac?", "Export palettes as .json files in Settings › Palettes and import them on the other Mac. With the same Apple Account, you can also turn on iCloud Sync."),
        ("iCloud Sync isn’t working.", "Make sure both Macs are signed in to iCloud with the same Apple Account and that Settings › General › iCloud Sync is on. Changes can take a few minutes to appear. Turning sync on merges iCloud and local palettes."),
        ("How do I change the language or appearance?", "Choose Appearance (Follow System/Light/Dark) and Language (Follow System/한국어/English/日本語) in Settings › General."),
        ("Can it start when I log in?", "Turn on Settings › General › Launch at Login."),
        ("How do I reset the app?", "In Settings › General › Reset, choose “Reset Everything” (settings and palettes) or “Reset Palettes” (keep settings). Deleted palettes can’t be restored."),
        ("How do I uninstall it?", "If Launch at Login is on, turn it off first. Click “Quit” at the bottom of the popover, then move ColorMix Bar from Applications to the Trash."),
        ("I’d like a refund.", 'Purchases are handled by Apple. Please request a refund at <a href="https://reportaproblem.apple.com">reportaproblem.apple.com</a>. The developer can’t issue refunds directly.'),
        ("Where is my data stored?", 'Only on your Mac and, if you turn on sync, in your own iCloud. The developer can’t see it. See the <a href="./privacy.html">Privacy Policy</a> for details.'),
    ]
    inner = f"""<h1>Support</h1>
<p>For questions, bug reports, or suggestions, please email us. We usually reply within three business days.</p>
<a class="mail" href="mailto:{MAIL}?subject=%5BColorMix%20Bar%5D%20Support">{MAIL}</a>
<p class="note">When reporting a problem, please include your <strong>Mac model, macOS version, and app version</strong> (Settings › About), the steps that led to the problem, and a screenshot if possible.</p>
<h2>FAQ</h2>
{faq(items)}
{foot(lang, effective=False)}"""
    return page(lang, "support.html", "Support", article(inner))


# ---------------- 개인정보 처리방침 ----------------
def privacy(lang):
    if lang == "ja":
        return privacy_ja()
    if lang == "ko":
        inner = f"""<h1>개인정보 처리방침</h1>
<p class="date">시행일: {T['ko']['date']}</p>
<p>ColorMix Bar 개발자(이하 "개발자")는 이용자의 개인정보를 소중히 여기며 「개인정보 보호법」 등 관련 법령을 지킵니다. 이 방침은 ColorMix Bar macOS 앱(이하 "앱")이 어떤 정보를 어디에 저장하고 어떻게 쓰는지 설명합니다.</p>
<p class="note"><strong>요약</strong> — ColorMix Bar는 회원가입이 없고, 개발자가 운영하는 서버가 없습니다. 팔레트와 설정은 이용자의 맥과(iCloud 동기화를 켠 경우) 이용자 본인의 iCloud에만 저장되며, 개발자는 그 내용을 볼 수 없습니다. 결제는 Apple이 처리하며 개발자는 결제 정보를 받지 않습니다. 광고, 분석 도구, 추적 기능을 쓰지 않습니다.</p>
<h2>1. 수집·저장하는 정보</h2>
<p>앱은 이름, 이메일, 전화번호, 위치 등 이용자를 식별하는 정보를 수집하지 않습니다. 앱 기능을 위해 다음 정보가 <strong>이용자의 맥 안에</strong> 저장됩니다.</p>
<table>
<tr><th>팔레트</th><td>팔레트 이름과 순서, 팔레트에 담은 색(sRGB 값)</td></tr>
<tr><th>앱 설정</th><td>화면 모드, 언어, 복사 형식, 고정 여부, iCloud 동기화 사용 여부, 창 위치</td></tr>
<tr><th>섞기 접시</th><td>섞는 중인 색은 앱이 켜져 있는 동안만 메모리에 있고 저장되지 않습니다</td></tr>
</table>
<h2>2. 이용 목적</h2>
<ul>
<li>팔레트 저장·불러오기, 색 복사, 색 섞기 기능 제공</li>
<li>앱을 다시 열었을 때 팔레트와 설정 복원</li>
<li>iCloud 동기화를 켠 경우 같은 Apple 계정의 맥끼리 팔레트 동기화</li>
</ul>
<h2>3. 저장 위치와 보관 기간</h2>
<ul>
<li><strong>맥:</strong> 팔레트와 설정은 macOS가 이 앱에만 허락한 저장 공간(앱 샌드박스) 안에 저장되며, 다른 앱은 접근할 수 없습니다.</li>
<li><strong>iCloud:</strong> 설정 › 일반 › iCloud 동기화를 켜면 팔레트(이름·순서·색)가 Apple의 iCloud 키-값 저장소, 즉 <strong>이용자 본인의 iCloud 계정</strong>에 저장되어 동기화됩니다. 앱 설정은 동기화되지 않습니다. 개발자는 이 데이터에 접근할 수 없습니다.</li>
<li>정보는 이용자가 지우거나 앱을 삭제할 때까지 보관됩니다.</li>
</ul>
<h2>4. 정보의 삭제와 이용자의 권리</h2>
<p>모든 정보는 이용자가 직접 확인하고, 고치고, 지울 수 있습니다.</p>
<ul>
<li>색 하나 지우기: 색 칩 오른쪽 클릭 › <strong>삭제</strong></li>
<li>팔레트의 색 모두 지우기: 색 칩 판의 빈 곳 오른쪽 클릭 › <strong>색 모두 지우기</strong></li>
<li>팔레트 지우기: 팔레트 탭 오른쪽 클릭 › <strong>삭제</strong></li>
<li>한꺼번에 지우기: 설정 › 일반 › <strong>초기화</strong> (완전 초기화 / 팔레트 초기화)</li>
<li>맥의 모든 정보 지우기: 앱 삭제</li>
</ul>
<p>iCloud 동기화를 켠 상태에서 지운 팔레트는 iCloud와 다른 맥에서도 지워집니다. ‘완전 초기화’는 동기화를 먼저 끄므로 iCloud의 팔레트는 남습니다. iCloud의 팔레트까지 지우려면 동기화를 켠 상태에서 ‘팔레트 초기화’를 하세요. 삭제한 정보는 되돌릴 수 없습니다.</p>
<h2>5. 제3자 제공 및 처리 위탁</h2>
<p>개발자는 이용자의 정보를 판매하거나 제3자에게 제공하지 않으며, 개발자 서버로 전송하지 않습니다. iCloud 동기화는 Apple의 iCloud 서비스로 이뤄지며 <a href="https://www.apple.com/kr/legal/privacy/">Apple 개인정보 처리방침</a>을 따릅니다.</p>
<p>앱 구매 결제는 Apple App Store가 처리합니다. 개발자는 이용자의 이름, Apple 계정, 카드·계좌 정보를 받지 않으며, App Store Connect에서 국가별 판매 건수 같은 익명 집계만 볼 수 있습니다.</p>
<h2>6. 기기 기능과 권한</h2>
<ul>
<li><strong>스포이드:</strong> macOS의 기본 색 추출 기능을 씁니다. 이용자가 클릭한 한 점의 색 값만 받으며, 화면 녹화 권한을 요청하지 않고 화면 이미지를 저장하거나 전송하지 않습니다.</li>
<li><strong>클립보드:</strong> 색을 복사할 때 색 코드를 클립보드에 넣기만 하며, 앱이 클립보드의 내용을 읽지 않습니다.</li>
<li><strong>파일:</strong> 팔레트 내보내기·가져오기 때 이용자가 직접 고른 파일만 읽고 씁니다.</li>
<li><strong>로그인 시 실행:</strong> 이용자가 켠 경우에만 macOS 로그인 항목에 등록됩니다.</li>
<li>앱은 위치, 사진, 연락처, 카메라, 마이크, 알림 권한을 요청하지 않으며, 개발자 서버와 통신하지 않습니다.</li>
</ul>
<h2>7. 광고·분석·추적</h2>
<p>앱에는 광고, 분석(애널리틱스), 오류 수집 SDK가 없으며, 다른 회사의 앱이나 웹사이트에 걸쳐 이용자를 추적하지 않습니다. 앱 오류 정보는 이용자가 Apple과 공유하도록 설정한 경우 Apple이 개발자에게 익명 통계로 제공할 수 있습니다.</p>
<h2>8. 아동의 개인정보</h2>
<p>개발자는 만 14세 미만 아동의 개인정보를 의도적으로 수집하지 않습니다.</p>
<h2>9. 개인정보 보호책임자 및 문의</h2>
<p>개인정보 보호책임자: ColorMix Bar 개발자<br>이메일: <a href="mailto:{MAIL}">{MAIL}</a></p>
<h2>10. 방침의 변경</h2>
<p>이 방침이 바뀌면 시행 7일 전부터 이 페이지에 알립니다. 이용자의 권리에 중요한 변경은 30일 전부터 알립니다.</p>
{foot(lang)}"""
        return page(lang, "privacy.html", "개인정보 처리방침", article(inner))
    inner = f"""<h1>Privacy Policy</h1>
<p class="date">Effective: {T['en']['date']}</p>
<p>The developer of ColorMix Bar (“we”) respects your privacy. This policy explains what the ColorMix Bar macOS app (the “App”) stores, where, and how it is used.</p>
<p class="note"><strong>Summary</strong> — ColorMix Bar has no accounts and no developer-operated servers. Your palettes and settings are stored only on your Mac and, if you turn on iCloud Sync, in your own iCloud. We can’t see them. Payments are handled by Apple and we don’t receive payment information. The App has no ads, analytics, or tracking.</p>
<h2>1. Information Stored</h2>
<p>The App doesn’t collect information that identifies you, such as your name, email, phone number, or location. The following is stored <strong>on your Mac</strong> so the App can work.</p>
<table>
<tr><th>Palettes</th><td>Palette names and order, and the colors in them (sRGB values)</td></tr>
<tr><th>Settings</th><td>Appearance, language, copy format, pinned state, whether iCloud Sync is on, window position</td></tr>
<tr><th>Mixing Dish</th><td>Colors being mixed are kept in memory only while the App is running and are not saved</td></tr>
</table>
<h2>2. How It’s Used</h2>
<ul>
<li>To save and load palettes, copy colors, and mix colors</li>
<li>To restore your palettes and settings when you reopen the App</li>
<li>To sync palettes between your Macs with the same Apple Account, if you turn on iCloud Sync</li>
</ul>
<h2>3. Where It’s Stored and for How Long</h2>
<ul>
<li><strong>Your Mac:</strong> Palettes and settings are stored in the App’s sandboxed container, which other apps can’t access.</li>
<li><strong>iCloud:</strong> If you turn on Settings › General › iCloud Sync, palettes (names, order, colors) are stored in Apple’s iCloud key-value storage in <strong>your own iCloud account</strong>. Settings are not synced. We can’t access this data.</li>
<li>Data is kept until you delete it or delete the App.</li>
</ul>
<h2>4. Deleting Your Data</h2>
<p>You can view, edit, and delete everything yourself.</p>
<ul>
<li>One color: right-click a chip › <strong>Delete</strong></li>
<li>All colors in a palette: right-click an empty area of the chip area › <strong>Remove All Colors</strong></li>
<li>A palette: right-click its tab › <strong>Delete</strong></li>
<li>Everything at once: Settings › General › <strong>Reset</strong> (Reset Everything / Reset Palettes)</li>
<li>All data on your Mac: delete the App</li>
</ul>
<p>Palettes deleted while iCloud Sync is on are also removed from iCloud and your other Macs. “Reset Everything” turns sync off first, so palettes in iCloud are kept. To remove them from iCloud too, use “Reset Palettes” while sync is on. Deleted data can’t be restored.</p>
<h2>5. Sharing with Third Parties</h2>
<p>We don’t sell or share your information and don’t send it to our servers. iCloud Sync is provided by Apple under the <a href="https://www.apple.com/legal/privacy/">Apple Privacy Policy</a>.</p>
<p>Purchases are processed by the Apple App Store. We don’t receive your name, Apple Account, or card details; App Store Connect only shows us anonymous totals such as sales by country.</p>
<h2>6. Device Features and Permissions</h2>
<ul>
<li><strong>Eyedropper:</strong> Uses the built-in macOS color sampler. The App receives only the color of the single point you click. It doesn’t request Screen Recording permission and doesn’t save or send screen images.</li>
<li><strong>Clipboard:</strong> The App only writes color codes to the clipboard when you copy. It doesn’t read clipboard contents.</li>
<li><strong>Files:</strong> When you export or import palettes, the App reads and writes only the files you choose.</li>
<li><strong>Launch at Login:</strong> The App is added to macOS login items only if you turn this on.</li>
<li>The App doesn’t request location, photos, contacts, camera, microphone, or notification permissions, and doesn’t communicate with developer servers.</li>
</ul>
<h2>7. Ads, Analytics, and Tracking</h2>
<p>The App contains no advertising, analytics, or crash-reporting SDKs and doesn’t track you across other companies’ apps or websites. If you choose to share diagnostics with Apple, Apple may provide us with anonymous statistics.</p>
<h2>8. Children</h2>
<p>We don’t knowingly collect personal information from children under 14.</p>
<h2>9. Contact</h2>
<p>Privacy contact: ColorMix Bar developer<br>Email: <a href="mailto:{MAIL}">{MAIL}</a></p>
<h2>10. Changes</h2>
<p>We’ll post changes on this page at least 7 days before they take effect, or 30 days before for significant changes to your rights.</p>
{foot(lang)}"""
    return page(lang, "privacy.html", "Privacy Policy", article(inner))


# ---------------- 이용약관 ----------------
def terms(lang):
    if lang == "ja":
        return terms_ja()
    if lang == "ko":
        inner = f"""<h1>이용약관</h1>
<p class="date">시행일: {T['ko']['date']}</p>
<h2>제1조 (목적)</h2>
<p>이 약관은 ColorMix Bar 개발자(이하 "개발자")가 제공하는 ColorMix Bar macOS 앱(이하 "앱")의 이용 조건과 절차, 이용자와 개발자의 권리·의무를 정합니다.</p>
<h2>제2조 (서비스 내용)</h2>
<p>앱은 메뉴바에서 쓰는 컬러 팔레트 앱으로, 다음 기능을 제공합니다.</p>
<ul>
<li>스포이드로 화면의 색 찍기, 원형 색상표로 색 만들기</li>
<li>여러 팔레트에 색 저장, 팔레트 이름·순서 변경, 팔레트 사이에서 색 옮기기</li>
<li>색 코드(HEX, RGB, HSL) 복사, 다른 앱으로 색 코드 끌어다 놓기</li>
<li>물감처럼 색 섞기(섞기 접시)</li>
<li>떠 있는 창으로 고정, 팔레트 파일 내보내기·가져오기, iCloud 동기화, 화면 모드·언어(한국어/English/日本語) 전환</li>
</ul>
<h2>제3조 (약관의 효력과 변경)</h2>
<p>이 약관은 앱을 설치하거나 이용하는 때부터 효력이 생깁니다. 개발자는 관련 법령을 어기지 않는 범위에서 약관을 바꿀 수 있으며, 바뀐 약관은 시행 7일 전(이용자에게 불리한 변경은 30일 전)부터 이 페이지에 알립니다. 바뀐 약관에 동의하지 않으면 앱 이용을 그만두고 앱을 삭제할 수 있습니다.</p>
<h2>제4조 (이용 요금)</h2>
<ul>
<li><strong>가격:</strong> 앱은 유료 앱으로, 가격은 대한민국 기준 <strong>1,100원</strong>(부가가치세 포함)이며 다른 나라에서는 App Store에 표시된 가격을 따릅니다.</li>
<li><strong>일회성 구매:</strong> 한 번 구매하면 모든 기능을 쓸 수 있습니다. 구독, 앱 내 구입, 추가 요금이 없습니다.</li>
<li><strong>결제와 다시 받기:</strong> 결제는 Apple App Store가 처리합니다. 같은 Apple 계정으로 로그인한 맥에서는 App Store 규정에 따라 다시 내려받을 수 있습니다.</li>
<li><strong>청약철회와 환불:</strong> 앱은 구매 즉시 제공되는 디지털 콘텐츠이므로 「전자상거래 등에서의 소비자보호에 관한 법률」 제17조 제2항에 따라 청약철회가 제한될 수 있습니다. 환불은 Apple의 환불 정책에 따라 <a href="https://reportaproblem.apple.com">reportaproblem.apple.com</a>에서 요청할 수 있고, 개발자는 직접 환불할 수 없습니다.</li>
<li><strong>가격 변경:</strong> 가격이 바뀌어도 이미 구매한 이용자에게는 추가 요금이 없습니다.</li>
</ul>
<h2>제5조 (이용자의 의무)</h2>
<ul>
<li>이용자는 관련 법령과 이 약관을 지켜야 하며, 앱을 역설계하거나 정상적인 운영을 방해해서는 안 됩니다.</li>
<li>인쇄, 제작, 브랜드 작업처럼 색이 중요한 용도에는 앱에서 얻은 색 값을 이용자가 직접 확인해 주세요.</li>
</ul>
<h2>제6조 (데이터 관리)</h2>
<ul>
<li>팔레트는 이용자의 맥과(iCloud 동기화를 켠 경우) 이용자 본인의 iCloud에 저장되며, 개발자는 데이터를 보관하거나 백업하지 않습니다. 필요하면 설정 › 팔레트의 내보내기로 백업해 주세요.</li>
<li>삭제나 초기화로 지운 팔레트는 되돌릴 수 없습니다.</li>
<li>iCloud 동기화는 Apple 계정 상태, iCloud, 네트워크, macOS 정책에 따라 늦어지거나 되지 않을 수 있습니다. 같은 팔레트를 여러 맥에서 거의 동시에 고치면 나중에 저장된 내용이 남을 수 있습니다.</li>
</ul>
<h2>제7조 (색 표현과 섞기 결과)</h2>
<p>같은 색 값이라도 디스플레이와 색 공간 설정에 따라 다르게 보일 수 있습니다. 섞기 접시는 물감이 섞이는 원리를 흉내 낸 계산이며, 실제 물감·잉크·인쇄 결과와 다를 수 있습니다.</p>
<h2>제8조 (지식재산권)</h2>
<p>앱의 디자인, 이름, 로고와 소프트웨어에 대한 권리는 개발자에게 있습니다. 앱에 포함된 오픈소스 구성 요소는 각 라이선스를 따릅니다(<a href="./licenses.html">오픈소스 라이선스</a>). 이용자가 만든 팔레트의 권리는 이용자에게 있습니다.</p>
<h2>제9조 (서비스 변경과 중단)</h2>
<p>개발자는 기능 개선이나 운영상 필요에 따라 앱의 일부 또는 전부를 바꾸거나 업데이트를 멈출 수 있습니다. 앱 제공을 끝내는 경우 가능한 한 미리 알립니다. 이미 설치한 앱은 계속 쓸 수 있습니다.</p>
<h2>제10조 (면책)</h2>
<p>개발자는 천재지변, 기기 고장, macOS 업데이트·정책 변경, iCloud 장애, 이용자의 실수나 삭제로 생긴 팔레트 손실, 색 값의 차이로 생긴 손해에 대해 관련 법령이 허용하는 범위에서 책임을 지지 않습니다. 다만 개발자의 고의 또는 중대한 과실로 생긴 손해는 예외로 합니다.</p>
<h2>제11조 (App Store 이용 조건)</h2>
<p>앱은 Apple App Store를 통해 배포되며, 이 약관에 정하지 않은 사항은 Apple의 <a href="https://www.apple.com/legal/internet-services/itunes/dev/stdeula/">표준 사용권 계약(EULA)</a>을 따릅니다. 앱에 대한 책임과 지원은 Apple이 아닌 개발자에게 있습니다.</p>
<h2>제12조 (개인정보 보호)</h2>
<p>개인정보 처리는 <a href="./privacy.html">개인정보 처리방침</a>을 따릅니다.</p>
<h2>제13조 (준거법과 분쟁 해결)</h2>
<p>이 약관은 대한민국 법을 따르며, 분쟁이 생기면 개발자와 이용자가 성실히 협의해 해결합니다. 협의로 해결되지 않으면 민사소송법에 따른 관할 법원에서 해결합니다.</p>
<h2>제14조 (문의)</h2>
<p>서비스 문의: <a href="mailto:{MAIL}">{MAIL}</a></p>
{foot(lang)}"""
        return page(lang, "terms.html", "이용약관", article(inner))
    inner = f"""<h1>Terms of Service</h1>
<p class="date">Effective: {T['en']['date']}</p>
<h2>1. Purpose</h2>
<p>These Terms set out the conditions for using the ColorMix Bar macOS app (the “App”) provided by the developer of ColorMix Bar (“we”), and the rights and obligations of users and the developer.</p>
<h2>2. The Service</h2>
<p>The App is a color palette for the menu bar and provides:</p>
<ul>
<li>Picking colors from the screen with an eyedropper and making colors with a color wheel</li>
<li>Saving colors in multiple palettes, renaming and reordering palettes, and moving colors between them</li>
<li>Copying color codes (HEX, RGB, HSL) and dragging color codes into other apps</li>
<li>Mixing colors like paint (Mixing Dish)</li>
<li>A pinned floating window, palette export and import, iCloud Sync, and appearance and language (English/Korean/Japanese) options</li>
</ul>
<h2>3. Effect and Changes</h2>
<p>These Terms apply from when you install or use the App. We may change them within the limits of applicable law and will post changes on this page at least 7 days before they take effect (30 days for changes unfavorable to you). If you don’t agree, you may stop using and delete the App.</p>
<h2>4. Price</h2>
<ul>
<li><strong>Price:</strong> The App is a paid app. In Korea it costs <strong>₩1,100</strong> (VAT included); elsewhere, the price shown on the App Store applies.</li>
<li><strong>One-time purchase:</strong> A single purchase unlocks every feature. There are no subscriptions, in-app purchases, or additional charges.</li>
<li><strong>Payment and re-downloads:</strong> Payment is processed by the Apple App Store. You can re-download the App on Macs signed in with the same Apple Account, subject to App Store rules.</li>
<li><strong>Refunds:</strong> Refunds are handled by Apple under its refund policy at <a href="https://reportaproblem.apple.com">reportaproblem.apple.com</a>. We can’t issue refunds directly.</li>
<li><strong>Price changes:</strong> Price changes never result in additional charges for existing customers.</li>
</ul>
<h2>5. Your Obligations</h2>
<ul>
<li>You must follow applicable laws and these Terms, and must not reverse engineer the App or interfere with its operation.</li>
<li>For color-critical work such as printing, manufacturing, or branding, please verify color values yourself.</li>
</ul>
<h2>6. Your Data</h2>
<ul>
<li>Palettes are stored on your Mac and, if you turn on iCloud Sync, in your own iCloud. We don’t store or back up your data. Use Settings › Palettes › Export to make backups.</li>
<li>Palettes removed by deleting or resetting can’t be restored.</li>
<li>iCloud Sync may be delayed or unavailable depending on your Apple Account, iCloud, network, and macOS. If the same palette is edited on several Macs at nearly the same time, the most recently saved version may be kept.</li>
</ul>
<h2>7. Color Display and Mixing</h2>
<p>The same color value may look different depending on your display and color settings. The Mixing Dish simulates how paint mixes and may differ from real paint, ink, or printed results.</p>
<h2>8. Intellectual Property</h2>
<p>We own the rights to the App’s design, name, logo, and software. Open source components follow their own licenses (<a href="./licenses.html">Open Source Licenses</a>). Palettes you create belong to you.</p>
<h2>9. Changes to the Service</h2>
<p>We may change all or part of the App or stop updates for improvement or operational reasons, and will give notice in advance where possible. Installed copies of the App will keep working.</p>
<h2>10. Disclaimer</h2>
<p>To the extent permitted by law, we are not liable for damages caused by natural disasters, device failure, macOS updates or policy changes, iCloud outages, palette loss due to user error or deletion, or differences in color values, except for damages caused by our intentional misconduct or gross negligence.</p>
<h2>11. App Store Terms</h2>
<p>The App is distributed through the Apple App Store. Matters not covered here are governed by Apple’s <a href="https://www.apple.com/legal/internet-services/itunes/dev/stdeula/">Standard End User License Agreement (EULA)</a>. We, not Apple, are responsible for the App and its support.</p>
<h2>12. Privacy</h2>
<p>Personal information is handled according to our <a href="./privacy.html">Privacy Policy</a>.</p>
<h2>13. Governing Law</h2>
<p>These Terms are governed by the laws of the Republic of Korea. Disputes will first be resolved in good faith between the parties and, failing that, by the competent court under the Korean Civil Procedure Act.</p>
<h2>14. Contact</h2>
<p>Email: <a href="mailto:{MAIL}">{MAIL}</a></p>
{foot(lang)}"""
    return page(lang, "terms.html", "Terms of Service", article(inner))


# ---------------- 오픈소스 라이선스 ----------------
def licenses(lang):
    if lang == "ja":
        return licenses_ja()
    if lang == "ko":
        inner = f"""<h1>오픈소스 라이선스</h1>
<p class="date">최종 수정일: {T['ko']['date']}</p>
<p>ColorMix Bar는 Apple 기본 프레임워크(SwiftUI, AppKit, ServiceManagement)로 만들었습니다. 물감처럼 섞는 계산에는 아래 오픈소스를 Swift로 옮겨 사용했습니다.</p>
<h2>포함 항목</h2>
<table>
<tr><th>이름</th><td>spectral.js 3.0.0</td></tr>
<tr><th>쓰는 곳</th><td>섞기 접시의 색 혼합 계산(Kubelka-Munk 이론). 계산 방식과 반사율 데이터 표를 Swift로 옮겼습니다.</td></tr>
<tr><th>저작권</th><td>Copyright (c) 2025 Ronald van Wijnen</td></tr>
<tr><th>라이선스</th><td>MIT License</td></tr>
<tr><th>출처</th><td><a href="https://github.com/rvanwijnen/spectral.js">github.com/rvanwijnen/spectral.js</a></td></tr>
</table>
<p>라이선스 원문은 앱의 설정 › 정보 › 오픈소스 라이선스에서도 볼 수 있습니다.</p>
<h2>라이선스 원문</h2>
<h3>spectral.js — MIT License</h3>
<pre>{LICENSE_TEXT}</pre>
<p class="note">이 웹페이지의 글꼴 Pretendard(SIL Open Font License 1.1)는 웹페이지에만 쓰이며 앱에는 들어 있지 않습니다.</p>
{foot(lang, effective=False)}"""
        return page(lang, "licenses.html", "오픈소스 라이선스", article(inner))
    inner = f"""<h1>Open Source Licenses</h1>
<p class="date">Last updated: {T['en']['date']}</p>
<p>ColorMix Bar is built with Apple frameworks (SwiftUI, AppKit, ServiceManagement). Its paint-like color mixing is ported to Swift from the open source project below.</p>
<h2>Included</h2>
<table>
<tr><th>Name</th><td>spectral.js 3.0.0</td></tr>
<tr><th>Used for</th><td>Color mixing in the Mixing Dish (Kubelka-Munk theory). The algorithm and reflectance data tables were ported to Swift.</td></tr>
<tr><th>Copyright</th><td>Copyright (c) 2025 Ronald van Wijnen</td></tr>
<tr><th>License</th><td>MIT License</td></tr>
<tr><th>Source</th><td><a href="https://github.com/rvanwijnen/spectral.js">github.com/rvanwijnen/spectral.js</a></td></tr>
</table>
<p>The license text is also available in the App under Settings › About › Open Source Licenses.</p>
<h2>License Text</h2>
<h3>spectral.js — MIT License</h3>
<pre>{LICENSE_TEXT}</pre>
<p class="note">The Pretendard font (SIL Open Font License 1.1) is used only on this website and is not included in the App.</p>
{foot(lang, effective=False)}"""
    return page(lang, "licenses.html", "Open Source Licenses", article(inner))


from gen_docs_ja import support_ja, privacy_ja, terms_ja, licenses_ja  # noqa: E402

for lang in ("ko", "en", "ja"):
    d = OUT if lang == "ko" else os.path.join(OUT, lang)
    os.makedirs(d, exist_ok=True)
    for name, fn in [("index.html", index), ("support.html", support), ("privacy.html", privacy),
                     ("terms.html", terms), ("licenses.html", licenses)]:
        with open(os.path.join(d, name), "w", encoding="utf-8") as f:
            f.write(fn(lang))
print("ok")
