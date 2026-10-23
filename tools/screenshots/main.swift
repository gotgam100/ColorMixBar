import SwiftUI
import AppKit
import ImageIO
import UniformTypeIdentifiers

// 사용: shots <출력 폴더> <ko|en>
let outDir = CommandLine.arguments[1]
let lang = CommandLine.arguments[2]
UserDefaults.standard.setVolatileDomain([
    AppLanguage.storageKey: lang, "iCloudSync": true, "pinned": false, "copyFormat": "hex", "appAppearance": "system",
], forName: UserDefaults.argumentDomain)

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let W: CGFloat = 2880, H: CGFloat = 1800

/// 화면 밖에 두고 키 창이 될 수 있는 창 (목록 선택 강조색이 제대로 그려지도록)
final class OffscreenWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

func hex(_ s: String, _ a: CGFloat = 1) -> NSColor {
    let c = RGB8(hex: s)!
    return NSColor(srgbRed: CGFloat(c.r) / 255, green: CGFloat(c.g) / 255, blue: CGFloat(c.b) / 255, alpha: a)
}

// MARK: - 앱 화면을 이미지로

@MainActor
func render<V: View>(_ view: V, width: CGFloat, height: CGFloat? = nil, dark: Bool) -> NSImage {
    let host = NSHostingController(rootView: view.environment(\.colorScheme, dark ? .dark : .light))
    host.sizingOptions = [.preferredContentSize]
    let win = OffscreenWindow(contentRect: NSRect(x: -6000, y: -6000, width: width, height: height ?? 600),
                              styleMask: [.borderless], backing: .buffered, defer: false)
    win.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
    win.contentViewController = host
    if let height { win.setContentSize(NSSize(width: width, height: height)) }
    win.setFrameOrigin(NSPoint(x: -6000, y: -6000))
    NSApp.activate()
    win.makeKeyAndOrderFront(nil)
    for _ in 0..<6 { RunLoop.current.run(until: Date().addingTimeInterval(0.15)) }
    if height == nil { win.setContentSize(host.preferredContentSize) }
    RunLoop.current.run(until: Date().addingTimeInterval(0.4))
    let v = win.contentView!
    let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds)!
    v.cacheDisplay(in: v.bounds, to: rep)
    win.orderOut(nil)
    let img = NSImage(size: v.bounds.size)
    img.addRepresentation(rep)
    return img
}

// MARK: - 합성 도우미 (좌표: 왼쪽 위가 0,0)

final class Canvas {
    let rep: NSBitmapImageRep
    let ctx: NSGraphicsContext
    init() {
        rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H), bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
        let base = NSGraphicsContext(bitmapImageRep: rep)!
        let cg = base.cgContext
        cg.translateBy(x: 0, y: H)
        cg.scaleBy(x: 1, y: -1)
        ctx = NSGraphicsContext(cgContext: cg, flipped: true)
        NSGraphicsContext.current = ctx
    }

    func fill(_ rect: NSRect, _ color: NSColor, radius: CGFloat = 0, shadow: Bool = false) {
        NSGraphicsContext.saveGraphicsState()
        if shadow {
            let s = NSShadow()
            s.shadowColor = NSColor.black.withAlphaComponent(0.28)
            s.shadowBlurRadius = 60
            s.shadowOffset = NSSize(width: 0, height: -24)   // 뒤집힌 좌표라 아래로
            s.set()
        }
        color.setFill()
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    func gradient(_ rect: NSRect, _ top: NSColor, _ bottom: NSColor) {
        NSGradient(starting: top, ending: bottom)!.draw(in: rect, angle: -90)
    }

    func blob(_ center: NSPoint, _ r: CGFloat, _ color: NSColor) {
        let g = NSGradient(colors: [color, color.withAlphaComponent(0)])!
        g.draw(in: NSBezierPath(ovalIn: NSRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
               relativeCenterPosition: .zero)
    }

    func image(_ img: NSImage, _ rect: NSRect, radius: CGFloat = 0, shadow: Bool = false, border: NSColor? = nil) {
        if shadow { fill(rect, .black, radius: radius, shadow: true) }
        NSGraphicsContext.saveGraphicsState()
        if radius > 0 { NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip() }
        img.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
        NSGraphicsContext.restoreGraphicsState()
        if let border {
            border.setStroke()
            let p = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: radius, yRadius: radius)
            p.lineWidth = 2
            p.stroke()
        }
    }

    func text(_ s: String, _ rect: NSRect, size: CGFloat, weight: NSFont.Weight, color: NSColor,
              align: NSTextAlignment = .left, lineSpacing: CGFloat = 0) {
        let para = NSMutableParagraphStyle()
        para.alignment = align
        para.lineSpacing = lineSpacing
        para.lineBreakStrategy = .hangulWordPriority
        NSAttributedString(string: s, attributes: [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color, .paragraphStyle: para, .kern: -size * 0.01,
        ]).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading])
    }

    func symbol(_ name: String, _ rect: NSRect, color: NSColor, pointSize: CGFloat) {
        let cfg = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
            .applying(.init(paletteColors: [color]))
        guard let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(cfg) else { return }
        let s = img.size
        img.draw(in: NSRect(x: rect.midX - s.width / 2, y: rect.midY - s.height / 2, width: s.width, height: s.height),
                 from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }

    /// 투명도 없는 RGB PNG로 저장 (App Store 스크린샷은 투명 영역이 없어야 함)
    func save(_ path: String) {
        let cg = rep.cgImage!
        let ctx = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: W, height: H))
        let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
        CGImageDestinationFinalize(dest)
    }
}

// MARK: - 공통 배경: 바탕, 메뉴바, 헤드라인

let appIcon = NSImage(contentsOfFile: CommandLine.arguments[3])!

func background(_ c: Canvas, dark: Bool) {
    let full = NSRect(x: 0, y: 0, width: W, height: H)
    if dark {
        c.gradient(full, hex("#25252C"), hex("#16161B"))
        c.blob(NSPoint(x: 2300, y: 1450), 900, hex("#3E8EDE", 0.22))
        c.blob(NSPoint(x: 600, y: 1600), 800, hex("#EF5B8A", 0.16))
        c.blob(NSPoint(x: 1500, y: 300), 700, hex("#F2C230", 0.12))
    } else {
        c.gradient(full, hex("#FBF9F5"), hex("#EDE7DC"))
        c.blob(NSPoint(x: 2350, y: 1500), 950, hex("#3E8EDE", 0.20))
        c.blob(NSPoint(x: 450, y: 1650), 850, hex("#EF5B8A", 0.16))
        c.blob(NSPoint(x: 1450, y: 250), 750, hex("#F2C230", 0.22))
    }
    // 메뉴바
    let bar = NSRect(x: 0, y: 0, width: W, height: 66)
    c.fill(bar, dark ? NSColor.black.withAlphaComponent(0.35) : NSColor.white.withAlphaComponent(0.55))
    let fg = dark ? NSColor.white : hex("#23232A")
    c.text(lang == "ko" ? "10월 23일 (목) 오후 2:30" : lang == "ja" ? "10月23日(木) 14:30" : "Thu Oct 23  2:30 PM",
           NSRect(x: 2200, y: 14, width: 640, height: 50), size: 28, weight: .medium, color: fg, align: .right)
    c.symbol("wifi", NSRect(x: 2280, y: 8, width: 50, height: 50), color: fg, pointSize: 26)
    c.symbol("battery.75percent", NSRect(x: 2340, y: 8, width: 70, height: 50), color: fg, pointSize: 26)
}

/// 메뉴바의 ColorMix Bar 아이콘 (눌린 상태) — 가운데 x 좌표를 돌려줌
@discardableResult
func statusIcon(_ c: Canvas, dark: Bool, x: CGFloat = 2220) -> CGFloat {
    c.fill(NSRect(x: x - 34, y: 8, width: 68, height: 50), (dark ? NSColor.white : NSColor.black).withAlphaComponent(0.14), radius: 12)
    c.symbol("paintpalette", NSRect(x: x - 34, y: 8, width: 68, height: 50), color: dark ? .white : hex("#23232A"), pointSize: 27)
    return x
}

func headline(_ c: Canvas, title: String, sub: String, dark: Bool, rect: NSRect, align: NSTextAlignment = .left) {
    let main = dark ? NSColor.white : hex("#1E1E24")
    let muted = dark ? NSColor.white.withAlphaComponent(0.7) : hex("#5E5D66")
    // 앱 이름 배지
    let badgeY = rect.minY
    let iconX = align == .center ? rect.midX - 150 : rect.minX
    c.image(appIcon, NSRect(x: iconX, y: badgeY, width: 72, height: 72))
    c.text("ColorMix Bar", NSRect(x: iconX + 86, y: badgeY + 12, width: 600, height: 60), size: 40, weight: .bold, color: main)
    c.text(title, NSRect(x: rect.minX, y: badgeY + 120, width: rect.width, height: 380), size: 104, weight: .heavy, color: main,
           align: align, lineSpacing: 6)
    let lines = CGFloat(title.components(separatedBy: "\n").count)
    c.text(sub, NSRect(x: rect.minX, y: badgeY + 150 + lines * 132, width: rect.width, height: 200), size: 46, weight: .medium,
           color: muted, align: align, lineSpacing: 10)
}

/// 메뉴바 아이콘 아래 매달린 팝업 (화살표 포함)
func popover(_ c: Canvas, _ img: NSImage, iconX: CGFloat, scale: CGFloat, dark: Bool) -> NSRect {
    let size = NSSize(width: img.size.width * 2 * scale, height: img.size.height * 2 * scale)
    let rect = NSRect(x: iconX - size.width + 230, y: 96, width: size.width, height: size.height)
    let bg = dark ? hex("#2C2C31") : hex("#F4F3F1")
    let line = (dark ? NSColor.white : NSColor.black).withAlphaComponent(0.10)
    let half: CGFloat = 26, tip: CGFloat = 24

    // 1) 그림자 + 본체 + 테두리
    c.fill(rect, .black, radius: 34, shadow: true)
    c.image(img, rect, radius: 34, border: line)

    // 2) 화살표: 본체 안쪽까지 살짝 겹쳐 덮어서 테두리 선이 화살표 밑을 지나지 않게 함
    let overlap: CGFloat = 6
    let tri = NSBezierPath()
    tri.move(to: NSPoint(x: iconX - half - overlap, y: rect.minY + overlap))
    tri.line(to: NSPoint(x: iconX, y: rect.minY - tip))
    tri.line(to: NSPoint(x: iconX + half + overlap, y: rect.minY + overlap))
    tri.close()
    bg.setFill()
    tri.fill()

    // 3) 화살표 두 빗변에 본체와 같은 테두리 선을 이어 그림
    let edge = NSBezierPath()
    edge.move(to: NSPoint(x: iconX - half, y: rect.minY + 1))
    edge.line(to: NSPoint(x: iconX, y: rect.minY - tip))
    edge.line(to: NSPoint(x: iconX + half, y: rect.minY + 1))
    edge.lineWidth = 2
    edge.lineJoinStyle = .round
    line.setStroke()
    edge.stroke()
    return rect
}

/// 일반 창 모양(제목 막대 + 신호등 버튼)을 그리고 안쪽 내용 영역을 돌려줌
func windowFrame(_ c: Canvas, _ rect: NSRect, title: String, dark: Bool, titleBar: CGFloat = 76) -> NSRect {
    let body = dark ? hex("#232328") : hex("#FFFFFF")
    c.fill(rect, .black, radius: 26, shadow: true)
    c.fill(rect, body, radius: 26)
    let bar = NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: titleBar)
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: rect, xRadius: 26, yRadius: 26).addClip()
    c.fill(bar, dark ? hex("#2E2E34") : hex("#F2F1EF"))
    NSGraphicsContext.restoreGraphicsState()
    for (i, col) in ["#FF5F57", "#FEBC2E", "#28C840"].enumerated() {
        c.fill(NSRect(x: rect.minX + 30 + CGFloat(i) * 40, y: rect.minY + titleBar / 2 - 13, width: 26, height: 26), hex(col), radius: 13)
    }
    c.text(title, NSRect(x: rect.minX, y: rect.minY + titleBar / 2 - 22, width: rect.width, height: 44), size: 28, weight: .semibold,
           color: dark ? NSColor.white.withAlphaComponent(0.85) : hex("#3A3A40"), align: .center)
    return NSRect(x: rect.minX, y: rect.minY + titleBar, width: rect.width, height: rect.height - titleBar)
}

// MARK: - 예시 데이터

@MainActor
func makeStore() -> PaletteStore {
    let s = PaletteStore()
    let names = lang == "ko" ? ["브랜드", "봄 정원", "웹 UI"] : lang == "ja" ? ["ブランド", "春の庭", "Web UI"] : ["Brand", "Spring", "Web UI"]
    let sets = [
        ["#1F3A5F", "#3E8EDE", "#F2C230", "#EF5B8A", "#4E9A4A", "#F5F2EC", "#23232A",
         "#9B5DE5", "#00BBF9", "#F15BB5", "#FEE440", "#00C49A", "#FF8C42", "#6C757D"],
        ["#F7D6E0", "#F2B5D4", "#B8E0D2", "#95D5B2", "#EAC4D5", "#FFE5A5", "#D6EADF"],
        ["#0A84FF", "#30D158", "#FF9F0A", "#FF453A", "#BF5AF2", "#64D2FF", "#1C1C1E", "#F2F2F7"],
    ]
    s.palettes = zip(names, sets).map { name, colors in
        Palette(name: name, swatches: colors.map { Swatch(color: RGB8(hex: $0)!) })
    }
    s.currentID = s.palettes[0].id
    return s
}

// MARK: - 스크린샷 5장

let T: [String: [(String, String)]] = [
    "ko": [("메뉴바에서 바로 쓰는\n컬러 팔레트", "색을 모으고, 클릭해서 복사하고,\n물감처럼 섞으세요."),
           ("파랑 + 노랑 = 초록", "섞기 접시에 끌어다 놓으면\n실제 물감처럼 섞입니다."),
           ("원하는 색을\n바로 담기", "스포이드로 화면에서 찍거나,\n원형 색상표에서 고르세요."),
           ("작업하는 동안\n계속 띄워 두기", "📌 고정하면 다른 앱 위에\n작은 창으로 떠 있습니다."),
           ("단순하게, 내 방식대로", "다크 모드 · 한국어/English/日本語 · iCloud 동기화")],
    "en": [("Your color palette,\nright in the menu bar", "Collect colors, copy with a click,\nand mix them like paint."),
           ("Blue + Yellow = Green", "Drop colors into the dish and\nthey mix like real paint."),
           ("Grab any color\nin a click", "Pick from the screen with the eyedropper,\nor choose on the color wheel."),
           ("Keep it floating\nwhile you work", "Pin it and it stays\nabove your other apps."),
           ("Simple, your way", "Dark mode · English/日本語/한국어 · iCloud Sync")],
    "ja": [("メニューバーで使える\nカラーパレット", "色を集めて、クリックでコピー、\n絵の具のように混ぜられます。"),
           ("青 + 黄 = 緑", "混色皿にドラッグすると、\n本物の絵の具のように混ざります。"),
           ("欲しい色を\nすぐに保存", "スポイトで画面から取得、\nまたはカラーホイールで選べます。"),
           ("作業中も\nずっと表示", "📌 固定すると、他のアプリの上に\n小さなウインドウで表示されます。"),
           ("シンプルに、自分らしく", "ダークモード · 日本語/한국어/English · iCloud 同期")],
]

@MainActor
func run() {
    let t = T[lang]!
    let blue = RGB8(hex: "#3E8EDE")!, yellow = RGB8(hex: "#F2C230")!

    func paletteImage(_ store: PaletteStore, dark: Bool) -> NSImage {
        AppAppearance.apply()
        NSApp.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        return render(PaletteView(pickColor: {}, openSettings: {}, togglePin: {}).environmentObject(store)
                        .background(dark ? Color(nsColor: hex("#2C2C31")) : Color(nsColor: hex("#F4F3F1"))),
                      width: 320, dark: dark)
    }

    // 1) 메뉴바 팔레트
    do {
        let store = makeStore()
        store.addToMix(blue); store.addToMix(yellow)
        let img = paletteImage(store, dark: false)
        let c = Canvas()
        background(c, dark: false)
        let ix = statusIcon(c, dark: false)
        _ = popover(c, img, iconX: ix, scale: 1.32, dark: false)
        headline(c, title: t[0].0, sub: t[0].1, dark: false, rect: NSRect(x: 190, y: 470, width: 1250, height: 900))
        c.save("\(outDir)/01.png")
    }
    // 2) 섞기
    do {
        let store = makeStore()
        store.addToMix(blue); store.addToMix(yellow)
        let mixed = store.mixedColor!
        let img = paletteImage(store, dark: false)
        let c = Canvas()
        background(c, dark: false)
        let ix = statusIcon(c, dark: false)
        _ = popover(c, img, iconX: ix, scale: 1.32, dark: false)
        headline(c, title: t[1].0, sub: t[1].1, dark: false, rect: NSRect(x: 190, y: 300, width: 1300, height: 700))
        // 큰 물감 방울 그림: 파랑 + 노랑 = 결과
        let y: CGFloat = 1040, r: CGFloat = 150
        let items: [(RGB8?, String?)] = [(blue, nil), (nil, "+"), (yellow, nil), (nil, "="), (mixed, nil)]
        var x: CGFloat = 190
        for (color, sym) in items {
            if let color {
                c.fill(NSRect(x: x, y: y, width: r * 2, height: r * 2), NSColor(srgbRed: CGFloat(color.r) / 255, green: CGFloat(color.g) / 255, blue: CGFloat(color.b) / 255, alpha: 1), radius: r, shadow: true)
                c.text(color.hex, NSRect(x: x, y: y + r * 2 + 24, width: r * 2, height: 50), size: 34, weight: .semibold, color: hex("#5E5D66"), align: .center)
                x += r * 2 + 30
            } else if let sym {
                c.text(sym, NSRect(x: x, y: y + r - 70, width: 90, height: 140), size: 110, weight: .bold, color: hex("#1E1E24"), align: .center)
                x += 120
            }
        }
        c.save("\(outDir)/02.png")
    }
    // 3) 원형 색상표
    do {
        let store = makeStore()
        store.select(store.palettes[1].id)
        store.isAddingColor = true
        let img = paletteImage(store, dark: false)
        let c = Canvas()
        background(c, dark: false)
        let ix = statusIcon(c, dark: false)
        _ = popover(c, img, iconX: ix, scale: 1.32, dark: false)
        headline(c, title: t[2].0, sub: t[2].1, dark: false, rect: NSRect(x: 190, y: 470, width: 1300, height: 900))
        c.save("\(outDir)/03.png")
    }
    // 4) 고정해서 띄우기 (다크)
    do {
        let store = makeStore()
        store.select(store.palettes[2].id)
        store.isPinned = true
        let img = paletteImage(store, dark: true)
        let c = Canvas()
        background(c, dark: true)
        // 뒤쪽 작업 창: 이름 없는 디자인 문서
        let docRect = NSRect(x: 150, y: 760, width: 1750, height: 960)
        let inner = windowFrame(c, docRect, title: lang == "ko" ? "포스터 시안" : lang == "ja" ? "ポスター案" : "Poster Draft", dark: true)
        c.fill(inner.insetBy(dx: 60, dy: 50), hex("#F5F2EC"), radius: 14)
        let canvas = inner.insetBy(dx: 60, dy: 50)
        c.fill(NSRect(x: canvas.minX + 80, y: canvas.minY + 80, width: 560, height: 560), hex("#0A84FF"), radius: 280)
        c.fill(NSRect(x: canvas.minX + 470, y: canvas.minY + 260, width: 480, height: 480), hex("#FF9F0A", 0.92), radius: 240)
        c.fill(NSRect(x: canvas.minX + 900, y: canvas.minY + 120, width: 620, height: 140), hex("#1C1C1E"), radius: 20)
        c.fill(NSRect(x: canvas.minX + 900, y: canvas.minY + 300, width: 460, height: 60), hex("#BF5AF2"), radius: 14)
        c.fill(NSRect(x: canvas.minX + 900, y: canvas.minY + 390, width: 380, height: 60), hex("#30D158"), radius: 14)
        c.fill(NSRect(x: canvas.minX + 900, y: canvas.minY + 480, width: 300, height: 60), hex("#FF453A"), radius: 14)
        // 떠 있는 팔레트 창
        let size = NSSize(width: img.size.width * 2 * 1.3, height: img.size.height * 2 * 1.3)
        let panel = NSRect(x: 1960, y: 230, width: size.width, height: size.height)
        c.image(img, panel, radius: 30, shadow: true, border: NSColor.white.withAlphaComponent(0.12))
        statusIcon(c, dark: true)
        headline(c, title: t[3].0, sub: t[3].1, dark: true, rect: NSRect(x: 190, y: 130, width: 1700, height: 480))
        c.save("\(outDir)/04.png")
    }
    // 5) 설정 (다크)
    do {
        let store = makeStore()
        NSApp.appearance = NSAppearance(named: .darkAqua)
        UserDefaults.standard.setVolatileDomain([
            AppLanguage.storageKey: lang, "iCloudSync": true, "pinned": false, "copyFormat": "hex", "appAppearance": "dark",
        ], forName: UserDefaults.argumentDomain)
        let img = render(SettingsView(initialPage: "general").environmentObject(store)
                            .background(Color(nsColor: hex("#1E1E22"))),
                         width: 700, height: 470, dark: true)
        let c = Canvas()
        background(c, dark: true)
        statusIcon(c, dark: true)
        let s: CGFloat = 1.2
        let size = NSSize(width: img.size.width * 2 * s, height: img.size.height * 2 * s)
        let rect = NSRect(x: (W - size.width) / 2, y: 520, width: size.width, height: size.height + 76)
        let inner = windowFrame(c, rect, title: L("\(appName) 설정", "\(appName) Settings", ja: "\(appName) 設定"), dark: true)
        c.image(img, inner)
        headline(c, title: t[4].0, sub: t[4].1, dark: true, rect: NSRect(x: 190, y: 130, width: W - 380, height: 380), align: .center)
        c.save("\(outDir)/05.png")
    }
}

MainActor.assumeIsolated { run() }
print("ok")
