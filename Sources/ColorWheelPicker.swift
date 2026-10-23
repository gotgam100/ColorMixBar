import SwiftUI
import AppKit

/// HSB(색상·선명도·밝기) 값을 0~255 sRGB로 바꿉니다.
func rgb8(hue: Double, saturation: Double, brightness: Double) -> RGB8 {
    let c = NSColor(colorSpace: .sRGB, hue: hue, saturation: saturation, brightness: brightness, alpha: 1)
    return RGB8(r: Int((c.redComponent * 255).rounded()),
                g: Int((c.greenComponent * 255).rounded()),
                b: Int((c.blueComponent * 255).rounded()))
}

/// 원형 색상표. 각도 = 색상, 중심에서의 거리 = 선명도. 밝기는 바깥에서 받습니다.
struct ColorWheel: View {
    @Binding var hue: Double
    @Binding var saturation: Double
    let brightness: Double

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let radius = size / 2
            let angle = hue * 2 * .pi
            let distance = saturation * radius

            ZStack {
                // 색상: 오른쪽(빨강)에서 시계 방향으로 한 바퀴
                Circle().fill(AngularGradient(
                    colors: stride(from: 0.0, through: 1.0, by: 1.0 / 12).map {
                        Color(hue: $0, saturation: 1, brightness: 1)
                    },
                    center: .center))
                // 선명도: 가운데로 갈수록 흰색
                Circle().fill(RadialGradient(colors: [.white, .white.opacity(0)],
                                             center: .center, startRadius: 0, endRadius: radius))
                // 밝기: 낮출수록 어둡게
                Circle().fill(Color.black.opacity(1 - brightness))
                Circle().strokeBorder(Color.primary.opacity(0.15))

                // 지금 고른 위치 표시
                Circle()
                    .fill(rgb8(hue: hue, saturation: saturation, brightness: brightness).swiftUIColor)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                    .shadow(color: .black.opacity(0.35), radius: 1.5)
                    .frame(width: 14, height: 14)
                    .position(x: radius + cos(angle) * distance, y: radius + sin(angle) * distance)
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                let dx = value.location.x - radius
                let dy = value.location.y - radius
                var a = atan2(dy, dx)
                if a < 0 { a += 2 * .pi }
                hue = a / (2 * .pi)
                saturation = min((dx * dx + dy * dy).squareRoot() / radius, 1)
            })
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// '+'를 누르면 색 칩 판 자리에 나오는 색 고르기 화면.
/// 팝업 크기가 바뀌지 않도록 색 칩 판과 같은 높이(위: contentHeight, 아래: 버튼 줄 rowHeight)를 씁니다.
struct ColorWheelPicker: View {
    let contentHeight: CGFloat
    let rowHeight: CGFloat
    let onAdd: (RGB8) -> Void
    let onCancel: () -> Void

    @State private var hue = 0.58
    @State private var saturation = 0.6
    @State private var brightness = 0.9

    private var color: RGB8 { rgb8(hue: hue, saturation: saturation, brightness: brightness) }

    var body: some View {
        VStack(spacing: 8) {
            picker.frame(height: contentHeight)
            buttons.frame(height: rowHeight)
        }
    }

    private var picker: some View {
        HStack(alignment: .center, spacing: 14) {
            ColorWheel(hue: $hue, saturation: $saturation, brightness: brightness)
                .frame(width: 104, height: 104)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(color.swiftUIColor)
                        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.primary.opacity(0.15)))
                        .frame(width: 32, height: 32)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(color.hex)
                            .font(.callout.monospaced())
                            .textSelection(.enabled)
                        Text("\(color.r), \(color.g), \(color.b)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("밝기", "Brightness", ja: "明るさ"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $brightness, in: 0...1)
                        .controlSize(.small)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 아래 버튼 줄 (색 칩 판의 안내 문구 자리)
    private var buttons: some View {
        HStack(spacing: 8) {
            Spacer()
            Button(L("취소", "Cancel", ja: "キャンセル"), action: onCancel)
                .keyboardShortcut(.cancelAction)
            Button(L("팔레트에 추가", "Add to Palette", ja: "パレットに追加")) { onAdd(color) }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .controlSize(.small)
    }
}
