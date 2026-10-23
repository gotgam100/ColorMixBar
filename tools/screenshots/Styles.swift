import SwiftUI

/// 스크린샷 전용: 캡처 권한 없이 그릴 때 빠지는 macOS 재질 대신, 활성 창의 모양을 그대로 흉내 냄
struct MacSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Capsule()
            .fill(configuration.isOn ? Color.accentColor : Color.primary.opacity(0.18))
            .frame(width: 40, height: 23)
            .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                Circle().fill(.white).shadow(color: .black.opacity(0.25), radius: 1, y: 0.5).padding(2)
            }
    }
}

struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .frame(height: 20)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color.accentColor))
    }
}

struct ShotSidebar<Page: Hashable & Identifiable>: View {
    let pages: [Page]
    let selected: Page?
    let title: (Page) -> String
    let icon: (Page) -> String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(pages) { p in
                HStack(spacing: 8) {
                    Image(systemName: icon(p)).foregroundStyle(Color.accentColor).frame(width: 22)
                    Text(title(p))
                }
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 7).fill(p == selected ? Color.primary.opacity(0.14) : .clear))
            }
            Spacer()
        }
        .padding(10)
        .frame(maxHeight: .infinity)
        .background(Color.primary.opacity(0.05))
    }
}
