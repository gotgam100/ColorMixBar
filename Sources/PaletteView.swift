import SwiftUI
import AppKit

extension RGB8 {
    var swiftUIColor: Color {
        Color(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}

/// 아래쪽 [설정] [종료] 버튼 모양
private struct FooterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(configuration.isPressed ? 0.12 : 0.05)))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.08)))
            .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct PaletteView: View {
    @EnvironmentObject private var store: PaletteStore
    @AppStorage("copyFormat") private var copyFormat: CopyFormat = .hex
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.system.rawValue
    let pickColor: () -> Void
    let openSettings: () -> Void
    let togglePin: () -> Void

    @State private var confirmDelete = false
    @State private var confirmClear = false

    var body: some View {
        VStack(spacing: 12) {
            appHeader
            PaletteTabs(confirmDelete: $confirmDelete)
            PaletteSection(copyFormat: copyFormat, pickColor: pickColor,
                           confirmDelete: $confirmDelete, confirmClear: $confirmClear)
            MixDish(copyFormat: copyFormat)
            footer
        }
        .padding(14)
        .frame(width: 320)
        .overlay(alignment: .bottom) {
            if let toast = store.toast {
                Text(toast)
                    .font(.callout)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, 60)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: store.toast)
        .confirmationDialog(L("‘\(store.current?.name ?? "")’ 팔레트를 삭제할까요?",
                              "Delete “\(store.current?.name ?? "")”?", ja: "「\(store.current?.name ?? "")」を削除しますか？"),
                            isPresented: $confirmDelete) {
            Button(L("삭제", "Delete", ja: "削除")) { store.deleteCurrent() }
            Button(L("취소", "Cancel", ja: "キャンセル"), role: .cancel) {}
        }
        .confirmationDialog(L("이 팔레트의 색을 모두 지울까요?", "Remove all colors from this palette?", ja: "このパレットの色をすべて削除しますか？"),
                            isPresented: $confirmClear) {
            Button(L("모두 지우기", "Remove All", ja: "すべて削除")) { store.clearCurrent() }
            Button(L("취소", "Cancel", ja: "キャンセル"), role: .cancel) {}
        }
        // 언어를 바꾸면 화면 전체를 새로 그립니다.
        .id(language)
    }

    private var appHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "paintpalette.fill")
                .foregroundStyle(.tint)
            Text(appName)
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 24)
        // 제목 줄 빈 곳을 끌면 팝오버가 떨어져 나와 떠 있는 창이 됩니다(macOS 기본 동작).
        .overlay(alignment: .trailing) {
            Button(action: togglePin) {
                Image(systemName: store.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(store.isPinned ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .rotationEffect(.degrees(45))
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(store.isPinned
                  ? L("고정 해제 (다시 팝업으로)", "Unpin (back to popover)", ja: "固定を解除（ポップアップに戻す）")
                  : L("고정: 다른 곳을 눌러도 닫히지 않고 계속 떠 있게", "Pin: keep the palette floating", ja: "固定：ほかをクリックしても閉じずに表示し続ける"))
        }
        .padding(.top, 2)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button(action: openSettings) {
                Label(L("설정", "Settings", ja: "設定"), systemImage: "gearshape")
            }
            .buttonStyle(FooterButtonStyle())
            Button {
                NSApp.terminate(nil)
            } label: {
                Label(L("종료", "Quit", ja: "終了"), systemImage: "power")
            }
            .buttonStyle(FooterButtonStyle())
        }
    }
}

// MARK: - 팔레트 탭 줄

/// 저장해 둔 팔레트를 가로 탭으로 보여 줍니다. 누르면 불러오고, 오른쪽 클릭하면 이름 변경·복제·삭제.
private struct PaletteTabs: View {
    @EnvironmentObject private var store: PaletteStore
    @Binding var confirmDelete: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(store.palettes) { p in
                        tab(p).id(p.id)
                    }
                    Button {
                        store.newPalette()
                    } label: {
                        Image(systemName: "plus")
                            .font(.callout.weight(.semibold))
                            .frame(width: 30, height: 30)
                            .background(RoundedRectangle(cornerRadius: 9).fill(Color.primary.opacity(0.06)))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(L("새 팔레트", "New Palette", ja: "新規パレット"))
                    .id("add")
                }
                .padding(5)
            }
            .frame(height: 40)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.primary.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.08)))
            .onChange(of: store.currentID) { _, id in
                withAnimation { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }

    private func tab(_ p: Palette) -> some View {
        PaletteTab(palette: p, confirmDelete: $confirmDelete)
    }
}

/// 팔레트 탭 하나. 색 칩을 이 위로 끌어다 놓으면 이 팔레트에 추가됩니다.
private struct PaletteTab: View {
    @EnvironmentObject private var store: PaletteStore
    let palette: Palette
    @Binding var confirmDelete: Bool
    @State private var isDropTarget = false

    var body: some View {
        let p = palette
        let selected = p.id == store.current?.id
        return HStack(spacing: 5) {
            // 팔레트 앞쪽 색 3개를 작은 점으로 미리 보여 줍니다.
            HStack(spacing: -4) {
                ForEach(Array(p.swatches.prefix(3))) { s in
                    Circle()
                        .fill(s.color.swiftUIColor)
                        .overlay(Circle().strokeBorder(Color.primary.opacity(0.2)))
                        .frame(width: 11, height: 11)
                }
                if p.swatches.isEmpty {
                    Circle()
                        .strokeBorder(Color.secondary, style: StrokeStyle(lineWidth: 1, dash: [2]))
                        .frame(width: 11, height: 11)
                }
            }
            Text(p.name)
                .font(.callout.weight(selected ? .semibold : .regular))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(RoundedRectangle(cornerRadius: 9)
            .fill(isDropTarget ? Color.accentColor.opacity(0.35)
                  : selected ? Color.accentColor.opacity(0.22) : Color.clear))
        .overlay(RoundedRectangle(cornerRadius: 9)
            .strokeBorder(isDropTarget ? Color.accentColor
                          : selected ? Color.accentColor.opacity(0.6) : Color.clear,
                          lineWidth: isDropTarget ? 2 : 1))
        .contentShape(RoundedRectangle(cornerRadius: 9))
        .onTapGesture { store.select(p.id) }
        // 탭을 끌어서 다른 탭 위에 놓으면 순서가 바뀝니다.
        .draggable(PaletteStore.paletteDragPrefix + p.id.uuidString) {
            Text(p.name)
                .font(.callout.weight(.semibold))
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(RoundedRectangle(cornerRadius: 9).fill(Color.accentColor.opacity(0.3)))
        }
        // 놓인 것이 팔레트 탭이면 순서 바꾸기, 색(칩·섞기 결과)이면 이 팔레트에 추가
        .dropDestination(for: String.self) { items, _ in
            let prefix = PaletteStore.paletteDragPrefix
            if let moved = items.first(where: { $0.hasPrefix(prefix) }),
               let id = UUID(uuidString: String(moved.dropFirst(prefix.count))) {
                withAnimation(.easeOut(duration: 0.2)) { store.movePalette(id, to: p.id) }
                return true
            }
            let colors = items.compactMap(RGB8.init(text:))
            store.add(colors, to: p.id)
            return !colors.isEmpty
        } isTargeted: {
            isDropTarget = $0
        }
        .help(L("탭을 끌어 순서를 바꾸거나, 색 칩을 놓아 이 팔레트에 추가합니다",
                "Drag tabs to reorder, or drop a color chip to add it to this palette", ja: "タブをドラッグして並べ替え、カラーチップをドロップするとこのパレットに追加します"))
        .contextMenu {
            Button(store.copiedColor.map { L("색상 붙여넣기 (\($0.hex))", "Paste Color (\($0.hex))", ja: "カラーを貼り付け (\($0.hex))") }
                   ?? L("색상 붙여넣기", "Paste Color", ja: "カラーを貼り付け")) {
                store.pasteColor(to: p.id)
            }
            .disabled(store.copiedColor == nil)
            Divider()
            Button(L("이름 변경", "Rename", ja: "名前を変更")) {
                store.select(p.id)
                store.isRenaming = true
            }
            Button(L("복제", "Duplicate", ja: "複製")) {
                store.select(p.id)
                store.duplicateCurrent()
            }
            Divider()
            Button(L("삭제…", "Delete…", ja: "削除…"), role: .destructive) {
                store.select(p.id)
                confirmDelete = true
            }
        }
    }
}

// MARK: - 현재 팔레트 (이름 + 색 칩 판)

private struct PaletteSection: View {
    @EnvironmentObject private var store: PaletteStore
    let copyFormat: CopyFormat
    let pickColor: () -> Void
    @Binding var confirmDelete: Bool
    @Binding var confirmClear: Bool

    @State private var draftName = ""
    @FocusState private var nameFocused: Bool

    /// 칩 크기와 간격. 한 줄(7개) 너비 = 7×30 + 6×6 = 246pt.
    /// 카드 안쪽 너비(268pt)에서 스크롤바(최대 약 16pt)가 생겨도 넘치지 않게 맞춘 값입니다.
    /// 넘치면 카드가 넓어지면서 위쪽 이름·버튼 줄까지 옆으로 밀립니다.
    static let chipSize: CGFloat = 30
    private static let chipSpacing: CGFloat = 6
    private let columns = Array(repeating: GridItem(.fixed(chipSize), spacing: chipSpacing), count: 7)
    /// 칩 3줄 높이. 팔레트 내용과 상관없이 팝업 크기가 바뀌지 않도록 고정합니다.
    private let gridHeight: CGFloat = chipSize * 3 + chipSpacing * 2 + 2

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            grid
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                // 카드 배경(칩이 없는 곳)을 오른쪽 클릭하면 '색상 붙여넣기', '색 모두 지우기'
                .background {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.primary.opacity(0.05))
                        .contextMenu { emptySpaceMenu }
                }
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.08)))
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            if store.isRenaming {
                // Enter 또는 ✓로 저장, Esc 또는 ✕로 취소.
                // (포커스가 빠질 때 저장하게 하면 오른쪽 클릭 메뉴가 닫히는 순간 입력칸이 바로 닫힐 수 있어서 쓰지 않습니다.)
                TextField(L("팔레트 이름", "Palette name", ja: "パレット名"), text: $draftName)
                    .textFieldStyle(.roundedBorder)
                    .focused($nameFocused)
                    .onSubmit(commitRename)
                    .onExitCommand { store.isRenaming = false }
                    .onAppear {
                        draftName = store.current?.name ?? ""
                        DispatchQueue.main.async { nameFocused = true }
                    }
                Button(action: commitRename) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
                .help(L("저장 (Enter)", "Save (Return)", ja: "保存 (Return)"))
                Button {
                    store.isRenaming = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(L("취소 (Esc)", "Cancel (Esc)", ja: "キャンセル (Esc)"))
            } else {
                // 이름을 오른쪽 클릭하면 '이름 변경', 두 번 클릭해도 바로 바꿀 수 있습니다.
                Text(store.current?.name ?? "")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { store.isRenaming = true }
                    .contextMenu {
                        Button(L("이름 변경", "Rename", ja: "名前を変更")) { store.isRenaming = true }
                    }
                    .help(L("오른쪽 클릭하면 이름을 바꿀 수 있습니다", "Right-click to rename", ja: "右クリックで名前を変更できます"))
            }

            Spacer(minLength: 4)

            if !store.isRenaming {
                Button {
                    store.isAddingColor.toggle()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(store.isAddingColor ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                        .rotationEffect(.degrees(store.isAddingColor ? 45 : 0))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(store.isAddingColor
                                                  ? AnyShapeStyle(Color.secondary)
                                                  : AnyShapeStyle(Color.primary.opacity(0.08))))
                        .contentShape(Circle())
                        .animation(.easeOut(duration: 0.15), value: store.isAddingColor)
                }
                .buttonStyle(.plain)
                .help(store.isAddingColor
                      ? L("색상표 닫기", "Close color wheel", ja: "カラーホイールを閉じる")
                      : L("색상표에서 색 골라 추가", "Pick a color from the color wheel", ja: "カラーホイールから色を選んで追加"))
            }

            Button(action: pickColor) {
                Image(systemName: "eyedropper")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.accentColor))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help(L("스포이드로 화면의 색 찍기", "Pick a color from the screen", ja: "スポイトで画面の色を取得"))
        }
        .frame(height: 28)
        .padding(.horizontal, 2)
    }

    @ViewBuilder
    private var emptySpaceMenu: some View {
        Button(store.copiedColor.map { L("색상 붙여넣기 (\($0.hex))", "Paste Color (\($0.hex))", ja: "カラーを貼り付け (\($0.hex))") }
               ?? L("색상 붙여넣기", "Paste Color", ja: "カラーを貼り付け")) {
            if let id = store.current?.id { store.pasteColor(to: id) }
        }
        .disabled(store.copiedColor == nil)
        Divider()
        Button(L("색 모두 지우기…", "Remove All Colors…", ja: "すべての色を削除…")) { confirmClear = true }
            .disabled(store.current?.swatches.isEmpty ?? true)
    }

    private func commitRename() {
        guard store.isRenaming else { return }
        store.renameCurrent(to: draftName)
        store.isRenaming = false
    }

    /// 안내 문구·버튼 줄 높이 (색상표가 열려도 팝업 크기가 같도록 고정)
    private let bottomRowHeight: CGFloat = 20

    @ViewBuilder
    private var grid: some View {
        if store.isAddingColor {
            ColorWheelPicker(contentHeight: gridHeight, rowHeight: bottomRowHeight) { color in
                store.add(color)
                store.showToast(L("\(color.hex)를 추가했습니다", "Added \(color.hex)", ja: "\(color.hex) を追加しました"))
                store.isAddingColor = false
            } onCancel: {
                store.isAddingColor = false
            }
        } else {
            swatchGrid
        }
    }

    private var swatchGrid: some View {
        let swatches = store.current?.swatches ?? []
        return VStack(alignment: .leading, spacing: 8) {
            Group {
                if swatches.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "eyedropper.halffull")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text(L("스포이드 버튼을 눌러 화면의 색을 찍으세요", "Click the eyedropper to pick a color", ja: "スポイトボタンで画面の色を取得しましょう"))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, alignment: .leading, spacing: Self.chipSpacing) {
                            ForEach(swatches) { swatch in
                                SwatchChip(color: swatch.color, copyFormat: copyFormat) {
                                    store.remove(swatch)
                                }
                            }
                        }
                        .padding(1)
                        .frame(minHeight: gridHeight, alignment: .topLeading)
                        .background {
                            Color.primary.opacity(0.001)
                                .contextMenu { emptySpaceMenu }
                        }
                    }
                }
            }
            .frame(height: gridHeight)

            Text(swatches.isEmpty
                 ? L("찍은 색은 이 팔레트에 자동으로 저장됩니다", "Picked colors are saved to this palette", ja: "取得した色はこのパレットに保存されます")
                 : L("클릭하면 복사 · 아래 접시로 끌어 놓으면 섞기", "Click to copy · Drag to the dish to mix", ja: "クリックでコピー · 混色皿へドラッグで混ぜる"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(height: bottomRowHeight)
        }
    }
}

/// 팔레트의 색 칩 하나
private struct SwatchChip: View {
    @EnvironmentObject private var store: PaletteStore
    let color: RGB8
    let copyFormat: CopyFormat
    let onDelete: () -> Void

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(color.swiftUIColor)
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.primary.opacity(0.15)))
            .frame(width: PaletteSection.chipSize, height: PaletteSection.chipSize)
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .onTapGesture { store.copy(color, format: copyFormat) }
            .help(color.hex)
            // 끌 때 HEX 글자를 실어 보내서, 접시뿐 아니라 다른 앱의 글 입력칸에도 놓을 수 있습니다.
            .draggable(color.hex) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.swiftUIColor)
                    .frame(width: PaletteSection.chipSize, height: PaletteSection.chipSize)
            }
            .contextMenu {
                Button(L("색상 복사", "Copy Color", ja: "カラーをコピー")) { store.copyColor(color, format: copyFormat) }
                Menu(L("다른 형식으로 복사", "Copy As", ja: "別の形式でコピー")) {
                    ForEach(CopyFormat.allCases) { format in
                        Button(format.string(for: color)) { store.copy(color, format: format) }
                    }
                }
                Divider()
                Button(L("섞기 접시에 넣기", "Add to Mixing Dish", ja: "混色皿に入れる")) { store.addToMix(color) }
                Divider()
                Button(L("삭제", "Delete", ja: "削除"), role: .destructive, action: onDelete)
            }
    }
}

// MARK: - 섞기 접시

/// 색을 끌어다 놓으면 물감처럼 섞어 주는 접시
private struct MixDish: View {
    @EnvironmentObject private var store: PaletteStore
    let copyFormat: CopyFormat
    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L("섞기 접시", "Mixing Dish", ja: "混色皿"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !store.mixParts.isEmpty {
                    Button(L("비우기", "Clear", ja: "クリア")) { store.mixParts.removeAll() }
                        .buttonStyle(.borderless)
                        .font(.callout)
                }
            }
            .frame(height: 24)
            .padding(.horizontal, 2)

            dish
                .frame(height: 74)
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isTargeted ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(isTargeted ? Color.accentColor : Color.primary.opacity(0.1),
                                      style: StrokeStyle(lineWidth: 1, dash: store.mixParts.isEmpty ? [4] : []))
                )
                .dropDestination(for: String.self) { items, _ in
                    let colors = items.compactMap(RGB8.init(hex:))
                    colors.forEach(store.addToMix)
                    return !colors.isEmpty
                } isTargeted: {
                    isTargeted = $0
                }
        }
    }

    @ViewBuilder
    private var dish: some View {
        if let mixed = store.mixedColor {
            HStack(spacing: 12) {
                Circle()
                    .fill(mixed.swiftUIColor)
                    .overlay(Circle().strokeBorder(.primary.opacity(0.15)))
                    .frame(width: 54, height: 54)
                    .contentShape(Circle())
                    .onTapGesture { store.copy(mixed, format: copyFormat) }
                    .draggable(mixed.hex)
                    .help(L("클릭하면 \(copyFormat.string(for: mixed)) 복사",
                            "Click to copy \(copyFormat.string(for: mixed))", ja: "クリックで \(copyFormat.string(for: mixed)) をコピー"))

                VStack(alignment: .leading, spacing: 6) {
                    Text(mixed.hex)
                        .font(.callout.monospaced())
                        .textSelection(.enabled)
                    // 섞은 색이 많아지면 이 줄만 가로로 넘겨 볼 수 있게 합니다(접시 높이는 그대로).
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(store.mixParts) { part in
                                    Button {
                                        store.removeOnePart(part.color)
                                    } label: {
                                        HStack(spacing: 2) {
                                            Circle()
                                                .fill(part.color.swiftUIColor)
                                                .overlay(Circle().strokeBorder(.primary.opacity(0.15)))
                                                .frame(width: 14, height: 14)
                                            if part.parts > 1 {
                                                Text("×\(part.parts)")
                                                    .font(.caption2.monospacedDigit())
                                                    .fixedSize()
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .help(L("\(part.color.hex) \(part.parts)만큼 · 클릭하면 하나 빼기",
                                            "\(part.color.hex) × \(part.parts) · Click to remove one", ja: "\(part.color.hex) × \(part.parts) · クリックで1つ減らす"))
                                    .id(part.id)
                                }
                            }
                            .padding(.trailing, 2)
                        }
                        .frame(height: 16)
                        // 새로 넣은 색이 보이도록 끝으로 넘깁니다.
                        .onChange(of: store.mixParts.count) { _, _ in
                            if let last = store.mixParts.last {
                                withAnimation { proxy.scrollTo(last.id, anchor: .trailing) }
                            }
                        }
                    }
                    Button(L("팔레트에 추가", "Add to Palette", ja: "パレットに追加")) {
                        store.add(mixed)
                        store.showToast(L("\(mixed.hex)를 팔레트에 추가했습니다", "Added \(mixed.hex) to the palette", ja: "\(mixed.hex) をパレットに追加しました"))
                    }
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            Text(L("색 칩을 여기로 끌어다 놓으세요.\n같은 색을 여러 번 놓으면 그만큼 많이 섞입니다.",
                   "Drag color chips here.\nDrop the same color again to add more of it.", ja: "カラーチップをここにドラッグしてください。\n同じ色を何度も入れると、その色が多く混ざります。"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .multilineTextAlignment(.center)
        }
    }
}
