import Foundation
import AppKit

/// 앱 안에서 바로 바꿀 수 있는 표시 언어.
/// 시스템 언어와 별개로 고를 수 있게 .lproj 대신 간단한 함수(L)로 처리합니다.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, ko, en, ja
    var id: Self { self }

    static let storageKey = "appLanguage"

    static var selected: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .system
    }

    /// '시스템 설정 따름'이면 맥의 첫 번째 선호 언어로 정합니다 (한국어·일본어가 아니면 영어).
    static var resolved: AppLanguage {
        switch selected {
        case .system:
            let first = Locale.preferredLanguages.first ?? "en"
            if first.hasPrefix("ko") { return .ko }
            if first.hasPrefix("ja") { return .ja }
            return .en
        case .ko, .en, .ja:
            return selected
        }
    }

    var label: String {
        switch self {
        case .system: L("시스템 설정 따름", "Follow System", ja: "システム設定に従う")
        case .ko: "한국어"
        case .en: "English"
        case .ja: "日本語"
        }
    }
}

/// 앱 이름. 모든 언어에서 같은 이름을 씁니다.
let appName = "ColorMix Bar"

/// 현재 언어에 맞는 문구를 고릅니다. 일본어도 반드시 넣어야 빌드됩니다(번역 누락 방지).
func L(_ ko: String, _ en: String, ja: String) -> String {
    switch AppLanguage.resolved {
    case .ko: ko
    case .ja: ja
    case .en, .system: en
    }
}

/// 화면 모드: 시스템 설정 따름 / 라이트 / 다크. 팝업, 떠 있는 창, 설정 창에 모두 적용됩니다.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: Self { self }

    static let storageKey = "appAppearance"

    static var selected: AppAppearance {
        AppAppearance(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .system
    }

    var label: String {
        switch self {
        case .system: L("시스템 설정 따름", "Follow System", ja: "システム設定に従う")
        case .light: L("라이트", "Light", ja: "ライト")
        case .dark: L("다크", "Dark", ja: "ダーク")
        }
    }

    /// 앱 전체에 지금 고른 모드를 적용합니다.
    @MainActor
    static func apply() {
        switch selected {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
