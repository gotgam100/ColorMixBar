import SwiftUI
import AppKit
import Combine

@main
struct ColorMixBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // 메뉴바 앱이라 창은 없습니다. 화면은 AppDelegate의 팝오버에서 그립니다.
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, NSWindowDelegate {
    let store = PaletteStore()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()

    /// 고정했거나 떼어낸 팔레트를 담는 떠 있는 창.
    /// 다른 앱 위에 계속 떠 있고, 눌러도 앱이 앞으로 튀어나오지 않습니다(nonactivatingPanel).
    private var panel: NSPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppAppearance.apply()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "paintpalette", accessibilityDescription: appName)
            button.action = #selector(statusItemClicked)
            button.target = self
        }

        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self
        popover.contentViewController = makeHost()

        // 지난번에 고정해 둔 채로 끝냈으면 다시 띄웁니다.
        if store.isPinned { showPanel(near: nil) }

        // 언어를 바꾸면 창 제목처럼 SwiftUI 밖에서 정한 글자도 바로 바꿉니다.
        languageObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshLocalizedTitles() }
        }

        // 설정 초기화 등으로 고정이 풀리면 떠 있는 창도 닫습니다.
        pinObserver = store.$isPinned
            .removeDuplicates()
            .sink { [weak self] pinned in
                if !pinned { self?.panel?.orderOut(nil) }
            }
    }

    private var pinObserver: AnyCancellable?
    private var languageObserver: NSObjectProtocol?
    private var lastLanguage = AppLanguage.resolved

    /// 설정 창·떠 있는 창 제목과 메뉴바 아이콘 설명을 지금 언어로 맞춥니다.
    private func refreshLocalizedTitles() {
        guard AppLanguage.resolved != lastLanguage else { return }
        lastLanguage = AppLanguage.resolved
        settingsWindow?.title = L("\(appName) 설정", "\(appName) Settings", ja: "\(appName) 設定")
        panel?.title = appName
        statusItem.button?.image?.accessibilityDescription = appName
    }

    private func makeHost() -> NSHostingController<some View> {
        let host = NSHostingController(
            rootView: PaletteView(pickColor: { [weak self] in self?.pickColor() },
                                  openSettings: { [weak self] in self?.openSettings() },
                                  togglePin: { [weak self] in self?.togglePin() })
                .environmentObject(store)
        )
        host.sizingOptions = [.preferredContentSize]
        return host
    }

    @objc private func statusItemClicked() {
        if store.isPinned {
            // 고정 중에는 아이콘으로 떠 있는 창을 숨기거나 다시 보이게 합니다.
            if let panel, panel.isVisible { panel.orderOut(nil) } else { showPanel(near: nil) }
        } else if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    // MARK: - 고정 (떠 있는 창)

    func togglePin() {
        if store.isPinned {
            store.isPinned = false
            panel?.orderOut(nil)
        } else {
            store.isPinned = true
            // 팝오버가 있던 자리에 그대로 띄웁니다.
            let popoverFrame = popover.contentViewController?.view.window?.frame
            popover.performClose(nil)
            showPanel(near: popoverFrame)
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 480),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = makeHost()
        panel.title = appName
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.setFrameAutosaveName("PinnedPanel")
        return panel
    }

    private func showPanel(near popoverFrame: NSRect?) {
        let isNew = panel == nil
        let panel = self.panel ?? makePanel()
        self.panel = panel
        if let frame = popoverFrame {
            panel.setFrameTopLeftPoint(NSPoint(x: frame.minX, y: frame.maxY))
        } else if isNew, UserDefaults.standard.string(forKey: "NSWindow Frame PinnedPanel") == nil,
                  let buttonFrame = statusItem.button?.window?.frame {
            // 처음 띄울 때는 메뉴바 아이콘 바로 아래에 둡니다.
            panel.setFrameTopLeftPoint(NSPoint(x: buttonFrame.midX - 160, y: buttonFrame.minY - 6))
        }
        panel.orderFrontRegardless()
    }

    /// 떠 있는 창의 닫기(✕) 버튼 = 고정 해제
    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSPanel) === panel {
            store.isPinned = false
        }
    }

    // MARK: - 팝오버를 끌어서 떼어내기

    func popoverShouldDetach(_ popover: NSPopover) -> Bool { true }

    /// 끌어서 떼어낼 때 macOS가 이 창을 대신 띄웁니다.
    func detachableWindow(for popover: NSPopover) -> NSWindow? {
        store.isPinned = true
        let panel = self.panel ?? makePanel()
        self.panel = panel
        return panel
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        NSApp.activate()
    }

    /// macOS 내장 스포이드. 샌드박스에서도 동작하고 화면 기록 권한이 필요 없습니다.
    ///
    /// 주의: 색을 고른 직후 팝오버를 다시 띄우거나 앱을 앞으로 가져오면,
    /// 스포이드가 정리되는 도중에 끼어들어 보이지 않는 스포이드 창이 화면에 남고
    /// 맥 전체의 클릭을 가로챌 수 있습니다. 그래서 고른 뒤에는 팝오버를 열지 않고
    /// 메뉴바 아이콘만 잠깐 그 색으로 바꿔 알려 줍니다.
    ///
    /// 떠 있는 창(고정)은 스포이드 동안 그대로 두고 아무것도 하지 않습니다(띄우기·앞으로 가져오기 없음).
    /// 고른 색은 저장소에 들어가면서 떠 있는 창에 바로 나타납니다.
    func pickColor() {
        guard sampler == nil else { return }  // 스포이드가 겹쳐 뜨지 않게
        let sampler = NSColorSampler()
        self.sampler = sampler
        if popover.isShown { popover.performClose(nil) }

        // 팝오버가 완전히 닫힌 뒤에 스포이드를 띄웁니다.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.showSampler(sampler)
        }
    }

    private func showSampler(_ sampler: NSColorSampler) {
        sampler.show { [weak self] color in
            // 스포이드가 스스로 정리를 마치도록, 처리는 다음 차례로 미룹니다.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                guard let self else { return }
                self.sampler = nil
                guard let color, let srgb = color.usingColorSpace(.sRGB) else { return }
                let picked = RGB8(
                    r: Int((srgb.redComponent * 255).rounded()),
                    g: Int((srgb.greenComponent * 255).rounded()),
                    b: Int((srgb.blueComponent * 255).rounded())
                )
                self.store.add(picked)
                self.flashStatusIcon(with: picked)
            }
        }
    }

    private var sampler: NSColorSampler?
    private var settingsWindow: NSWindow?

    /// 설정 창 (사이드바형). 메뉴바 앱이라 직접 창을 만들어 띄웁니다.
    func openSettings() {
        if popover.isShown { popover.performClose(nil) }
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 700, height: 480),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView().environmentObject(store))
            window.center()
            window.setFrameAutosaveName("SettingsWindow")
            settingsWindow = window
        }
        settingsWindow?.title = L("\(appName) 설정", "\(appName) Settings", ja: "\(appName) 設定")
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
    private var flashWorkItem: DispatchWorkItem?

    /// 메뉴바 아이콘을 1.5초 동안 고른 색 동그라미로 바꿔 저장됐음을 알립니다.
    private func flashStatusIcon(with color: RGB8) {
        guard let button = statusItem.button else { return }
        let size = NSSize(width: 16, height: 16)
        let dot = NSImage(size: size, flipped: false) { rect in
            let path = NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1))
            NSColor(srgbRed: CGFloat(color.r) / 255, green: CGFloat(color.g) / 255,
                    blue: CGFloat(color.b) / 255, alpha: 1).setFill()
            path.fill()
            NSColor.labelColor.withAlphaComponent(0.35).setStroke()
            path.lineWidth = 1
            path.stroke()
            return true
        }
        dot.isTemplate = false
        button.image = dot

        flashWorkItem?.cancel()
        let restore = DispatchWorkItem { [weak self] in
            self?.statusItem.button?.image = NSImage(systemSymbolName: "paintpalette",
                                                     accessibilityDescription: appName)
        }
        flashWorkItem = restore
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: restore)
    }
}
