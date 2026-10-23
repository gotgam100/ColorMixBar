import Foundation
import AppKit
import UniformTypeIdentifiers
import ServiceManagement
import Security

struct Swatch: Identifiable, Codable, Hashable {
    var id = UUID()
    var color: RGB8
}

struct Palette: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var swatches: [Swatch] = []
}

/// 섞기 접시에 올린 색 한 가지와 그 양(부분 수)
struct MixPart: Identifiable, Hashable {
    var color: RGB8
    var parts: Int
    var id: RGB8 { color }
}

enum CopyFormat: String, CaseIterable, Identifiable {
    case hex, rgb, hsl
    var id: Self { self }

    var name: String { rawValue.uppercased() }

    func string(for c: RGB8) -> String {
        switch self {
        case .hex:
            return c.hex
        case .rgb:
            return "rgb(\(c.r), \(c.g), \(c.b))"
        case .hsl:
            let r = Double(c.r) / 255, g = Double(c.g) / 255, b = Double(c.b) / 255
            let maxV = max(r, g, b), minV = min(r, g, b)
            let l = (maxV + minV) / 2
            var h = 0.0, s = 0.0
            let d = maxV - minV
            if d > 0 {
                s = d / (1 - abs(2 * l - 1))
                switch maxV {
                case r: h = 60 * ((g - b) / d).truncatingRemainder(dividingBy: 6)
                case g: h = 60 * ((b - r) / d + 2)
                default: h = 60 * ((r - g) / d + 4)
                }
                if h < 0 { h += 360 }
            }
            return "hsl(\(Int(h.rounded()) % 360), \(Int((s * 100).rounded()))%, \(Int((l * 100).rounded()))%)"
        }
    }
}

private struct SavedData: Codable {
    var palettes: [Palette]
    var currentID: UUID?
}

/// 내보내기/가져오기 파일 형식: {"name": "...", "colors": ["#RRGGBB", ...]}
private struct PaletteFile: Codable {
    var name: String
    var colors: [String]
}

@MainActor
final class PaletteStore: ObservableObject {
    @Published var palettes: [Palette] = [] { didSet { save() } }
    @Published var currentID: UUID? { didSet { save() } }
    @Published var mixParts: [MixPart] = []
    @Published var toast: String?
    /// 팔레트 이름을 바꾸는 중인지 (팝오버의 이름 칸이 입력칸으로 바뀜)
    @Published var isRenaming = false {
        didSet { if isRenaming { isAddingColor = false } }
    }
    /// '+'로 원형 색상표를 연 상태인지. 이름 바꾸기와 동시에 열리지 않게 합니다.
    @Published var isAddingColor = false {
        didSet { if isAddingColor { isRenaming = false } }
    }
    /// 떠 있는 창으로 고정했는지. 다음 실행 때도 기억합니다.
    @Published var isPinned = UserDefaults.standard.bool(forKey: "pinned") {
        didSet { UserDefaults.standard.set(isPinned, forKey: "pinned") }
    }

    private let fileURL: URL
    private var toastTask: Task<Void, Never>?

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ColorMixBar", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("palettes.json")

        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode(SavedData.self, from: data),
           !saved.palettes.isEmpty {
            palettes = saved.palettes
            currentID = saved.currentID ?? saved.palettes.first?.id
        } else {
            let first = Palette(name: L("내 팔레트", "My Palette", ja: "マイパレット"))
            palettes = [first]
            currentID = first.id
        }
        if iCloudSyncEnabled { startICloudSync() }
    }

    // MARK: - 현재 팔레트

    var currentIndex: Int? {
        palettes.firstIndex { $0.id == currentID } ?? (palettes.isEmpty ? nil : 0)
    }

    var current: Palette? { currentIndex.map { palettes[$0] } }

    func add(_ color: RGB8) {
        guard let i = currentIndex else { return }
        palettes[i].swatches.append(Swatch(color: color))
    }

    // MARK: - 팔레트 순서

    /// 탭을 끌어서 다른 탭 위에 놓으면 그 자리로 옮깁니다.
    /// 오른쪽으로 옮기면 놓은 탭의 뒤로, 왼쪽으로 옮기면 놓은 탭의 앞으로 들어갑니다.
    func movePalette(_ id: UUID, to targetID: UUID) {
        guard id != targetID,
              let from = palettes.firstIndex(where: { $0.id == id }),
              let to = palettes.firstIndex(where: { $0.id == targetID }) else { return }
        let palette = palettes.remove(at: from)
        palettes.insert(palette, at: to)
    }

    /// 탭을 끌 때 싣는 글자. 색 코드와 구분되도록 앞에 표시를 붙입니다.
    static let paletteDragPrefix = "colormixbar-palette:"

    /// 지정한 팔레트에 색을 넣습니다 (탭에 끌어다 놓기, 탭에서 붙여넣기).
    func add(_ colors: [RGB8], to paletteID: UUID) {
        guard let i = palettes.firstIndex(where: { $0.id == paletteID }), !colors.isEmpty else { return }
        palettes[i].swatches.append(contentsOf: colors.map { Swatch(color: $0) })
        let name = palettes[i].name
        showToast(colors.count == 1
                  ? L("\(colors[0].hex)를 ‘\(name)’에 추가했습니다", "Added \(colors[0].hex) to “\(name)”", ja: "\(colors[0].hex) を「\(name)」に追加しました")
                  : L("색 \(colors.count)개를 ‘\(name)’에 추가했습니다", "Added \(colors.count) colors to “\(name)”", ja: "\(colors.count) 色を「\(name)」に追加しました"))
    }

    // MARK: - 색상 복사·붙여넣기

    /// '색상 복사'로 기억해 둔 색. 붙여넣기는 시스템 클립보드를 읽지 않고 이 값을 씁니다
    /// (최신 macOS는 앱이 클립보드를 읽을 때 허용 창을 띄울 수 있어서).
    @Published var copiedColor: RGB8?

    /// 색을 기억하고, 지금 복사 형식의 색 코드도 클립보드에 넣습니다(다른 앱에 붙여넣기용).
    func copyColor(_ color: RGB8, format: CopyFormat) {
        copiedColor = color
        let text = format.string(for: color)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        showToast(L("\(text) 복사됨 · 다른 팔레트에 붙여넣을 수 있습니다", "Copied \(text) · Paste it into any palette", ja: "\(text) をコピーしました · 他のパレットに貼り付けられます"))
    }

    func pasteColor(to paletteID: UUID) {
        guard let copiedColor else { return }
        add([copiedColor], to: paletteID)
    }

    func remove(_ swatch: Swatch) {
        guard let i = currentIndex else { return }
        palettes[i].swatches.removeAll { $0.id == swatch.id }
    }

    func clearCurrent() {
        guard let i = currentIndex else { return }
        palettes[i].swatches.removeAll()
    }

    // MARK: - 팔레트 저장/불러오기

    /// 새 팔레트는 '새 팔레트1', '새 팔레트2' … 순서로, 비어 있는 가장 작은 번호를 씁니다.
    func newPalette() {
        let names = Set(palettes.map(\.name))
        var n = 1
        while names.contains(Self.newPaletteName(n)) { n += 1 }
        let p = Palette(name: Self.newPaletteName(n))
        palettes.append(p)
        currentID = p.id
    }

    static func newPaletteName(_ n: Int) -> String {
        L("새 팔레트\(n)", "New Palette \(n)", ja: "新規パレット\(n)")
    }

    func select(_ id: UUID) {
        if currentID != id {
            isRenaming = false
            isAddingColor = false
        }
        currentID = id
    }

    func renameCurrent(to name: String) {
        guard let i = currentIndex else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { palettes[i].name = trimmed }
    }

    func duplicateCurrent() {
        guard let p = current else { return }
        let copy = Palette(name: uniqueName(p.name + L(" 사본", " Copy", ja: " のコピー")),
                           swatches: p.swatches.map { Swatch(color: $0.color) })
        palettes.append(copy)
        currentID = copy.id
    }

    func deleteCurrent() {
        guard let i = currentIndex else { return }
        isRenaming = false
        isAddingColor = false
        palettes.remove(at: i)
        if palettes.isEmpty { palettes = [Palette(name: L("내 팔레트", "My Palette", ja: "マイパレット"))] }
        currentID = palettes[min(i, palettes.count - 1)].id
    }

    private func uniqueName(_ base: String) -> String {
        let names = Set(palettes.map(\.name))
        if !names.contains(base) { return base }
        var n = 2
        while names.contains("\(base) \(n)") { n += 1 }
        return "\(base) \(n)"
    }

    // MARK: - 섞기 접시

    func addToMix(_ color: RGB8) {
        if let i = mixParts.firstIndex(where: { $0.color == color }) {
            mixParts[i].parts += 1
        } else {
            mixParts.append(MixPart(color: color, parts: 1))
        }
    }

    func removeOnePart(_ color: RGB8) {
        guard let i = mixParts.firstIndex(where: { $0.color == color }) else { return }
        if mixParts[i].parts > 1 { mixParts[i].parts -= 1 } else { mixParts.remove(at: i) }
    }

    var mixedColor: RGB8? {
        SpectralMixer.mix(mixParts.map { ($0.color, Double($0.parts)) })
    }

    // MARK: - 복사

    func copy(_ color: RGB8, format: CopyFormat) {
        let text = format.string(for: color)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        showToast(L("\(text) 복사됨", "Copied \(text)", ja: "\(text) をコピーしました"))
    }

    func showToast(_ message: String) {
        toast = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    // MARK: - 파일로 내보내기/가져오기

    func exportCurrent() {
        guard let p = current else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = p.name + ".json"
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let file = PaletteFile(name: p.name, colors: p.swatches.map(\.color.hex))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        do {
            try encoder.encode(file).write(to: url, options: .atomic)
            showToast(L("‘\(p.name)’을 파일로 저장했습니다", "Saved “\(p.name)” to a file", ja: "「\(p.name)」をファイルに保存しました"))
        } catch {
            showToast(L("파일을 저장하지 못했습니다", "Couldn’t save the file", ja: "ファイルを保存できませんでした"))
        }
    }

    func importFromFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = true
        NSApp.activate()
        guard panel.runModal() == .OK else { return }

        var imported = 0
        for url in panel.urls {
            guard let data = try? Data(contentsOf: url) else { continue }
            let decoded: PaletteFile?
            if let file = try? JSONDecoder().decode(PaletteFile.self, from: data) {
                decoded = file
            } else if let colors = try? JSONDecoder().decode([String].self, from: data) {
                decoded = PaletteFile(name: url.deletingPathExtension().lastPathComponent, colors: colors)
            } else {
                decoded = nil
            }
            guard let file = decoded else { continue }
            let swatches = file.colors.compactMap(RGB8.init(hex:)).map { Swatch(color: $0) }
            let p = Palette(name: uniqueName(file.name), swatches: swatches)
            palettes.append(p)
            currentID = p.id
            imported += 1
        }
        showToast(imported > 0
                  ? L("팔레트 \(imported)개를 가져왔습니다", "Imported \(imported) palette(s)", ja: "パレットを \(imported) 個読み込みました")
                  : L("가져올 수 있는 팔레트 파일이 없습니다", "No palette files to import", ja: "読み込めるパレットファイルがありません"))
    }

    // MARK: - iCloud 동기화

    /// iCloud 키-값 저장소에 팔레트를 올려 같은 Apple 계정의 다른 맥과 맞춥니다.
    /// 앱이 iCloud 권한(entitlement)을 가지고 서명되어 있어야 동작합니다.
    @Published var iCloudSyncEnabled = UserDefaults.standard.bool(forKey: "iCloudSync") {
        didSet {
            UserDefaults.standard.set(iCloudSyncEnabled, forKey: "iCloudSync")
            if iCloudSyncEnabled { startICloudSync() } else { stopICloudSync() }
        }
    }

    /// 이 빌드가 iCloud 권한을 가지고 서명됐는지. 임시 서명 빌드에서는 false.
    static let iCloudAvailable: Bool = {
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        let value = SecTaskCopyValueForEntitlement(
            task, "com.apple.developer.ubiquity-kvstore-identifier" as CFString, nil)
        return value != nil
    }()

    private static let iCloudKey = "palettes"
    /// iCloud 키-값 저장소의 한 값 크기 제한(1MB). 넘으면 Apple이 저장을 거부하므로 올리지 않습니다.
    private static let iCloudValueLimit = 1_000_000
    private var iCloudObserver: NSObjectProtocol?
    private var applyingRemote = false

    private func startICloudSync() {
        guard Self.iCloudAvailable, iCloudObserver == nil else { return }
        let kvs = NSUbiquitousKeyValueStore.default
        iCloudObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvs, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyRemotePalettes(merge: false) }
        }
        kvs.synchronize()
        // 처음 켤 때는 iCloud 쪽과 이 맥의 팔레트를 합칩니다.
        applyRemotePalettes(merge: true)
        pushToICloud()
    }

    private func stopICloudSync() {
        if let iCloudObserver { NotificationCenter.default.removeObserver(iCloudObserver) }
        iCloudObserver = nil
    }

    private func applyRemotePalettes(merge: Bool) {
        guard let data = NSUbiquitousKeyValueStore.default.data(forKey: Self.iCloudKey),
              let remote = try? JSONDecoder().decode([Palette].self, from: data),
              !remote.isEmpty else { return }
        applyingRemote = true
        defer { applyingRemote = false }
        if merge {
            let remoteIDs = Set(remote.map(\.id))
            palettes = remote + palettes.filter { !remoteIDs.contains($0.id) }
        } else {
            palettes = remote
        }
        if !palettes.contains(where: { $0.id == currentID }) { currentID = palettes.first?.id }
    }

    private func pushToICloud() {
        guard iCloudSyncEnabled, Self.iCloudAvailable, !applyingRemote,
              let data = try? JSONEncoder().encode(palettes),
              data.count < Self.iCloudValueLimit else { return }
        NSUbiquitousKeyValueStore.default.set(data, forKey: Self.iCloudKey)
    }

    // MARK: - 초기화

    /// 설정만 처음 상태로: 언어(시스템 설정 따름), 복사 형식(HEX), 로그인 시 실행(끔), iCloud 동기화(끔), 고정(해제)
    func resetSettings() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: AppLanguage.storageKey)
        defaults.removeObject(forKey: AppAppearance.storageKey)
        AppAppearance.apply()
        defaults.removeObject(forKey: "copyFormat")
        // 동기화를 먼저 꺼서, '완전 초기화'가 iCloud와 다른 맥의 팔레트를 지우지 않게 합니다.
        iCloudSyncEnabled = false
        isPinned = false
        if SMAppService.mainApp.status == .enabled {
            try? SMAppService.mainApp.unregister()
        }
        objectWillChange.send()
    }

    /// 설정과 모든 팔레트를 지우고 처음 설치한 상태로 되돌립니다.
    func resetAll() {
        resetSettings()
        resetPalettes()
    }

    /// 팔레트만 처음 상태로('내 팔레트' 하나만 남김). 설정값은 그대로 둡니다.
    /// iCloud 동기화를 켜 둔 상태라면 이 변경이 같은 계정의 다른 맥에도 반영됩니다.
    func resetPalettes() {
        isRenaming = false
        isAddingColor = false
        mixParts.removeAll()
        let first = Palette(name: L("내 팔레트", "My Palette", ja: "マイパレット"))
        palettes = [first]
        currentID = first.id
    }

    // MARK: - 로그인 시 실행

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                showToast(L("로그인 시 실행을 바꾸지 못했습니다", "Couldn’t change Launch at Login", ja: "ログイン時に起動の設定を変更できませんでした"))
            }
            objectWillChange.send()
        }
    }

    // MARK: - 저장

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(SavedData(palettes: palettes, currentID: currentID)) else { return }
        try? data.write(to: fileURL, options: .atomic)
        pushToICloud()
    }
}
