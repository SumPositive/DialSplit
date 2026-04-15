//
//  AppSettings.swift
//  DialSplit
//

import SwiftUI
import AZDial

// MARK: - 名称プリセット

struct NamePreset: Identifiable {
    let names: [String]   // 必ず4要素
    var id: String { names.joined(separator: "/") }

    static var all: [NamePreset] {
        [
        NamePreset(names: ["A",    "B",    "C",    "D"   ]),  // デフォルト
        NamePreset(names: ["1",    "2",    "3",    "4"   ]),
        NamePreset(names: [String(localized: "大富豪"), String(localized: "富豪"), String(localized: "平民"), String(localized: "貧民")]),
        NamePreset(names: [String(localized: "社長"), String(localized: "部長"), String(localized: "課長"), String(localized: "係長")]),
        NamePreset(names: [String(localized: "金"), String(localized: "銀"), String(localized: "銅"), String(localized: "鉄")]),
        NamePreset(names: [String(localized: "特上"), String(localized: "上"), String(localized: "並"), String(localized: "下")]),
        NamePreset(names: [String(localized: "先輩"), String(localized: "同僚"), String(localized: "後輩"), String(localized: "新人")]),
        NamePreset(names: ["",     "",     "",     ""    ]),  // ブランク
    ]
    }
}

// MARK: - AppSettings

@Observable
final class AppSettings {
    /// 区別ごとの名称
    var panelNames: [String] {
        didSet { UserDefaults.standard.set(panelNames, forKey: "panelNames") }
    }

    /// レザーデザイン
    var leatherStyle: LeatherStyle {
        didSet { UserDefaults.standard.set(leatherStyle.rawValue, forKey: "leatherStyle") }
    }

    /// ダイアルスタイル
    var dialStyle: DialStyle {
        didSet { UserDefaults.standard.set(dialStyle.id, forKey: "dialStyle") }
    }

    /// パネル明るさ（-40 ... 40）
    var panelBrightness: Int {
        didSet { UserDefaults.standard.set(panelBrightness, forKey: "panelBrightness") }
    }

    /// 文字色（黒=-20 / 白=-10 / 色相=0...360, 10刻み）
    var textHue: Int {
        didSet { UserDefaults.standard.set(textHue, forKey: "textHue") }
    }

    /// 文字の濃淡（0...100）
    var textTone: Int {
        didSet { UserDefaults.standard.set(textTone, forKey: "textTone") }
    }

    init() {
        let defaults = NamePreset.all[2].names   // ["大富豪","富豪","平民","貧民"]
        var names = UserDefaults.standard.stringArray(forKey: "panelNames") ?? defaults
        // 旧バージョンからの移行: 足りない分を補完
        while names.count < 4 { names.append(defaults[names.count]) }
        panelNames = names

        let styleRaw = UserDefaults.standard.string(forKey: "leatherStyle") ?? ""
        leatherStyle = LeatherStyle(rawValue: styleRaw) ?? .brown

        let dialId = UserDefaults.standard.string(forKey: "dialStyle") ?? "brass"
        dialStyle = DialStyle.builtin(id: dialId) ?? .brass

        let storedBrightness = UserDefaults.standard.integer(forKey: "panelBrightness")
        panelBrightness = min(40, max(-40, storedBrightness))

        // 旧キー amountHue から移行しつつ、新キー textHue を優先
        let hueObj = UserDefaults.standard.object(forKey: "textHue")
        let migratedHueObj = UserDefaults.standard.object(forKey: "amountHue")
        let storedHue = hueObj != nil
            ? UserDefaults.standard.integer(forKey: "textHue")
            : (migratedHueObj != nil ? UserDefaults.standard.integer(forKey: "amountHue") : 40)
        textHue = normalizedTextHueValue(storedHue)

        let toneObj = UserDefaults.standard.object(forKey: "textTone")
        let storedTone = toneObj != nil ? UserDefaults.standard.integer(forKey: "textTone") : 80
        textTone = min(100, max(0, storedTone))
    }

    func name(for index: Int) -> String {
        guard index < panelNames.count else { return "\(index + 1)" }
        return panelNames[index]
    }

    func setName(_ name: String, for index: Int) {
        while panelNames.count <= index { panelNames.append("\(panelNames.count + 1)") }
        panelNames[index] = name
    }
}

func normalizedTextHueValue(_ raw: Int) -> Int {
    if raw <= -15 { return -20 }   // black
    if raw < 0 { return -10 }      // white
    let clamped = min(360, max(0, raw))
    let snapped = Int((Double(clamped) / 10.0).rounded()) * 10
    return min(360, max(0, snapped))
}

func linkedTextColor(hue: Int, tone: Int, for cs: ColorScheme) -> Color {
    let normalized = normalizedTextHueValue(hue)
    let t = Double(min(100, max(0, tone))) / 100.0
    if normalized == -20 {
        let v = cs == .dark ? (0.10 + t * 0.55) : (0.00 + t * 0.35)
        return Color(white: v)
    }
    if normalized == -10 {
        let v = cs == .dark ? (0.75 + t * 0.25) : (0.82 + t * 0.18)
        return Color(white: min(1.0, v))
    }
    let normalizedHue = Double(normalized % 360) / 360.0
    let saturation = 0.10 + (cs == .dark ? 0.82 : 0.90) * t
    let brightness = cs == .dark ? (0.65 + 0.30 * t) : (0.38 + 0.34 * t)
    return Color(hue: normalizedHue, saturation: saturation, brightness: brightness)
}

// MARK: - LeatherStyle

enum LeatherStyle: String, CaseIterable {
    case monotone
    case brown
    case black

    var backgroundImage: String {
        switch self {
        case .monotone: return ""               // テクスチャなし → フォールバックグラデーション
        case .brown:    return "leather_brown"
        case .black:    return "leather_black"
        }
    }

    /// フォールバック用グラデーションカラー（モノトーンはカラースキーム対応）
    func fallbackColors(for cs: ColorScheme) -> [Color] {
        switch self {
        case .monotone:
            return cs == .dark
                ? [Color(red: 0.13, green: 0.13, blue: 0.15),
                   Color(red: 0.06, green: 0.06, blue: 0.08)]
                : [Color(white: 0.68), Color(white: 0.54)]
        case .brown:    return [Color(red: 0.35, green: 0.22, blue: 0.12),
                                Color(red: 0.22, green: 0.13, blue: 0.07)]
        case .black:    return [Color(red: 0.18, green: 0.18, blue: 0.18),
                                Color(red: 0.08, green: 0.08, blue: 0.08)]
        }
    }

    /// ステッチ装飾を表示するか
    var showsStitch: Bool { self != .monotone }

    var localizedName: String {
        switch self {
        case .monotone: return String(localized: "モノトーン")
        case .brown:    return String(localized: "ブラウンレザー")
        case .black:    return String(localized: "ブラックレザー")
        }
    }
}
