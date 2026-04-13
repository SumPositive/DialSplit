//
//  AppSettings.swift
//  DialSplit
//

import SwiftUI
import AZDial

@Observable
final class AppSettings {
    /// 区別ごとの名称（A=大富豪 / B=富豪 / C=平民 / D=貧民）
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

    init() {
        let defaults = ["大富豪", "富豪", "平民", "貧民"]
        var names = UserDefaults.standard.stringArray(forKey: "panelNames") ?? defaults
        // 旧3段階からの移行: 足りない分を補完
        while names.count < 4 { names.append(defaults[names.count]) }
        panelNames = names

        let styleRaw = UserDefaults.standard.string(forKey: "leatherStyle") ?? ""
        leatherStyle = LeatherStyle(rawValue: styleRaw) ?? .brown

        let dialId = UserDefaults.standard.string(forKey: "dialStyle") ?? "brass"
        dialStyle = DialStyle.builtin(id: dialId) ?? .brass
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

// MARK: - LeatherStyle

enum LeatherStyle: String, CaseIterable {
    case brown
    case black

    var backgroundImage: String {
        switch self {
        case .brown: return "leather_brown"
        case .black: return "leather_black"
        }
    }

    var localizedName: String {
        switch self {
        case .brown: return "ブラウン"
        case .black: return "ブラック"
        }
    }
}
