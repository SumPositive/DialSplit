//
//  AppSettings.swift
//  DialSplit
//

import SwiftUI

@Observable
final class AppSettings {
    /// 各クラスの名前（大富豪/富豪/平民）
    var panelNames: [String] {
        didSet { UserDefaults.standard.set(panelNames, forKey: "panelNames") }
    }

    /// レザーデザイン
    var leatherStyle: LeatherStyle {
        didSet { UserDefaults.standard.set(leatherStyle.rawValue, forKey: "leatherStyle") }
    }

    init() {
        let names = UserDefaults.standard.stringArray(forKey: "panelNames")
        panelNames = names ?? ["大富豪", "富豪", "平民"]

        let styleRaw = UserDefaults.standard.string(forKey: "leatherStyle") ?? ""
        leatherStyle = LeatherStyle(rawValue: styleRaw) ?? .brown
    }

    func name(for index: Int) -> String {
        guard index < panelNames.count else { return "\(index + 1)" }
        return panelNames[index]
    }

    func setName(_ name: String, for index: Int) {
        while panelNames.count <= index {
            panelNames.append("\(panelNames.count + 1)")
        }
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
