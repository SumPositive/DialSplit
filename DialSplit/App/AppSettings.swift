import SwiftUI
import AZDecimal

@Observable
final class AppSettings {
    var panelCount: Int {
        didSet { UserDefaults.standard.set(panelCount, forKey: "panelCount") }
    }
    var panelNames: [String] {
        didSet { UserDefaults.standard.set(panelNames, forKey: "panelNames") }
    }
    var roundType: AZDecimalConfig.RoundType {
        didSet { UserDefaults.standard.set(roundType.rawValue, forKey: "roundType") }
    }
    var leatherStyle: LeatherStyle {
        didSet { UserDefaults.standard.set(leatherStyle.rawValue, forKey: "leatherStyle") }
    }

    init() {
        let count = UserDefaults.standard.integer(forKey: "panelCount")
        panelCount = count > 0 ? count : 3

        let names = UserDefaults.standard.stringArray(forKey: "panelNames")
        panelNames = names ?? ["Aさん", "Bさん", "Cさん"]

        let modeRaw = UserDefaults.standard.integer(forKey: "roundType")
        roundType = AZDecimalConfig.RoundType(rawValue: modeRaw) ?? .r54

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

    var roundConfig: AZDecimalConfig {
        AZDecimalConfig.default.rounding(roundType).digits(0)
    }
}

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
