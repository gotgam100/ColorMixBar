import Foundation

/// 0~255 sRGB 색
struct RGB8: Hashable, Codable {
    var r: Int
    var g: Int
    var b: Int

    var hex: String { String(format: "#%02X%02X%02X", r, g, b) }

    init(r: Int, g: Int, b: Int) {
        self.r = min(max(r, 0), 255)
        self.g = min(max(g, 0), 255)
        self.b = min(max(b, 0), 255)
    }

    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        guard s.count == 6, let v = Int(s, radix: 16) else { return nil }
        self.init(r: (v >> 16) & 0xFF, g: (v >> 8) & 0xFF, b: v & 0xFF)
    }
}

extension RGB8 {
    /// 사용자가 직접 입력한 색 코드를 읽습니다.
    /// HEX: "#3A7BD5", "3A7BD5", "#3AD" / RGB: "rgb(58, 123, 213)", "58, 123, 213", "58 123 213"
    init?(text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        if let hex = RGB8(hex: t) {
            self = hex
            return
        }
        var body = t.lowercased()
        if body.hasPrefix("rgb") {
            guard let open = body.firstIndex(of: "("), let close = body.lastIndex(of: ")"), open < close else { return nil }
            body = String(body[body.index(after: open)..<close])
        }
        let parts = body.split(whereSeparator: { $0 == "," || $0 == " " }).map(String.init)
        guard parts.count == 3 else { return nil }
        let values = parts.compactMap(Int.init)
        guard values.count == 3, values.allSatisfy({ (0...255).contains($0) }) else { return nil }
        self.init(r: values[0], g: values[1], b: values[2])
    }
}

/// 물감처럼 섞기 (Kubelka-Munk 이론 기반).
/// spectral.js 3.0.0 (MIT, Copyright (c) 2025 Ronald van Wijnen)의 mix 알고리즘을 Swift로 옮긴 것입니다.
/// 파랑과 노랑을 섞으면 회색이 아니라 초록이 나옵니다.
enum SpectralMixer {
    private static let size = 38
    private static let gamma = 2.4

    /// 색과 비율(부분 수)을 받아 섞은 색을 돌려줍니다.
    static func mix(_ items: [(color: RGB8, parts: Double)]) -> RGB8? {
        let items = items.filter { $0.parts > 0 }
        guard !items.isEmpty else { return nil }
        // 한 가지 색만 있으면 계산 오차 없이 그대로 돌려줍니다.
        if Set(items.map(\.color)).count == 1 { return items[0].color }

        let pigments = items.map { item -> (ks: [Double], concentration: Double) in
            let lrgb = linearRGB(item.color)
            let reflectance = spectralReflectance(lrgb)
            let luminance = max(Double.ulpOfOne, mulMatVec(SpectralData.cmf, reflectance)[1])
            return (reflectance.map(ks), item.parts * item.parts * luminance)
        }
        let total = pigments.reduce(0) { $0 + $1.concentration }

        var mixed = [Double](repeating: 0, count: size)
        for i in 0..<size {
            let ksMix = pigments.reduce(0) { $0 + $1.ks[i] * $1.concentration }
            mixed[i] = km(ksMix / total)
        }

        let xyz = mulMatVec(SpectralData.cmf, mixed)
        let lrgb = mulMatVec(SpectralData.xyzToRGB, xyz)
        return toSRGB8(lrgb: lrgb, xyz: xyz)
    }

    // MARK: - Kubelka-Munk

    private static func ks(_ r: Double) -> Double { (1 - r) * (1 - r) / (2 * r) }
    private static func km(_ ks: Double) -> Double { 1 + ks - (ks * ks + 2 * ks).squareRoot() }

    private static func spectralReflectance(_ lrgb: [Double]) -> [Double] {
        let w = lrgb.min()!
        let v = [lrgb[0] - w, lrgb[1] - w, lrgb[2] - w]
        let c = min(v[1], v[2])
        let m = min(v[0], v[2])
        let y = min(v[0], v[1])
        let r = max(0, min(v[0] - v[2], v[0] - v[1]))
        let g = max(0, min(v[1] - v[2], v[1] - v[0]))
        let b = max(0, min(v[2] - v[1], v[2] - v[0]))

        return (0..<size).map { i in
            max(Double.ulpOfOne,
                w * SpectralData.baseW[i] + c * SpectralData.baseC[i] + m * SpectralData.baseM[i]
                + y * SpectralData.baseY[i] + r * SpectralData.baseR[i] + g * SpectralData.baseG[i]
                + b * SpectralData.baseB[i])
        }
    }

    // MARK: - 색 공간 변환

    private static func uncompand(_ x: Double) -> Double {
        x > 0.04045 ? pow((x + 0.055) / 1.055, gamma) : x / 12.92
    }

    private static func compand(_ x: Double) -> Double {
        x > 0.0031308 ? 1.055 * pow(x, 1.0 / gamma) - 0.055 : x * 12.92
    }

    private static func linearRGB(_ c: RGB8) -> [Double] {
        [c.r, c.g, c.b].map { uncompand(Double($0) / 255) }
    }

    private static func mulMatVec(_ m: [[Double]], _ v: [Double]) -> [Double] {
        m.map { row in zip(row, v).reduce(0) { $0 + $1.0 * $1.1 } }
    }

    private static func xyzToOKLab(_ xyz: [Double]) -> [Double] {
        let lms = mulMatVec(SpectralData.xyzToLMS, xyz).map { cbrt($0) }
        return mulMatVec(SpectralData.lmsToLab, lms)
    }

    private static func okLabToXYZ(_ lab: [Double]) -> [Double] {
        let lms = mulMatVec(SpectralData.labToLMS, lab).map { $0 * $0 * $0 }
        return mulMatVec(SpectralData.lmsToXYZ, lms)
    }

    private static func lrgbToOKLab(_ lrgb: [Double]) -> [Double] {
        xyzToOKLab(mulMatVec(SpectralData.rgbToXYZ, lrgb))
    }

    private static func inGamut(_ lrgb: [Double]) -> Bool {
        lrgb.allSatisfy { $0 >= 0 && $0 <= 1 }
    }

    private static func deltaEOK(_ a: [Double], _ b: [Double]) -> Double {
        ((a[0] - b[0]) * (a[0] - b[0]) + (a[1] - b[1]) * (a[1] - b[1]) + (a[2] - b[2]) * (a[2] - b[2])).squareRoot()
    }

    private static func clamp01(_ x: Double) -> Double { min(max(x, 0), 1) }

    private static func rgb8(fromLinear lrgb: [Double]) -> RGB8 {
        let v = lrgb.map { Int((compand($0) * 255).rounded()) }
        return RGB8(r: v[0], g: v[1], b: v[2])
    }

    /// 화면에 표시할 수 없는 색이면 채도를 줄여 가장 가까운 색으로 옮깁니다 (spectral.js gamutMap과 같은 방식).
    private static func toSRGB8(lrgb: [Double], xyz: [Double]) -> RGB8 {
        if inGamut(lrgb) { return rgb8(fromLinear: lrgb) }

        let lab = xyzToOKLab(xyz)
        let lightness = lab[0]
        if lightness >= 1 { return RGB8(r: 255, g: 255, b: 255) }
        if lightness <= 0 { return RGB8(r: 0, g: 0, b: 0) }

        var hue = atan2(lab[2], lab[1]) * 180 / .pi
        if hue < 0 { hue += 360 }
        let jnd = 0.03, epsilon = 0.0001
        var low = 0.0
        var high = (lab[1] * lab[1] + lab[2] * lab[2]).squareRoot()
        var lowInGamut = true

        var current = lrgb
        var clipped = lrgbToOKLab(current.map(clamp01))
        var deltaE = deltaEOK(clipped, lrgbToOKLab(current))
        if deltaE < jnd {
            return rgb8(fromLinear: mulMatVec(SpectralData.xyzToRGB, okLabToXYZ(clipped)))
        }

        while high - low > epsilon {
            let chroma = (low + high) / 2
            let candidate = [lightness, chroma * cos(hue * .pi / 180), chroma * sin(hue * .pi / 180)]
            current = mulMatVec(SpectralData.xyzToRGB, okLabToXYZ(candidate))

            if lowInGamut && inGamut(current) {
                low = chroma
            } else {
                clipped = lrgbToOKLab(current.map(clamp01))
                deltaE = deltaEOK(clipped, candidate)
                if deltaE < jnd {
                    if jnd - deltaE < epsilon { break }
                    lowInGamut = false
                    low = chroma
                } else {
                    high = chroma
                }
            }
        }
        return rgb8(fromLinear: mulMatVec(SpectralData.xyzToRGB, okLabToXYZ(clipped)))
    }
}
