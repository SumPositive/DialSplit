//
//  AppSettings.swift
//  DialSplit
//

import SwiftUI
import AZDial

enum MoneyFormat {
    static var currencyCode: String {
        Locale.current.currency?.identifier ?? "JPY"
    }

    static var fractionDigits: Int {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .current
        formatter.currencyCode = currencyCode
        return max(0, formatter.maximumFractionDigits)
    }

    static var minorUnitScale: Int {
        var scale = 1
        for _ in 0..<fractionDigits {
            scale *= 10
        }
        return scale
    }

    static var maxMajorValue: Int { 999_900 }
    static var maxMinorValue: Int { maxMajorValue * minorUnitScale }

    static var dialStepCandidates: [Int] {
        [1, 10, 100, 500, 1_000]
    }

    static var dialStepDefinitionOptions: [Int] {
        [1, 2, 5, 10, 20, 50, 100, 200, 500, 1_000, 2_000, 5_000, 10_000, 20_000, 50_000, 100_000]
            .filter { $0 <= maxMinorValue }
    }

    static var defaultDialStep: Int {
        500
    }

    static func localizedAmount(_ minorValue: Int, placeholder: String? = nil) -> String {
        if minorValue == 0, let placeholder {
            return localizedPlaceholder(placeholder)
        }

        let amount = NSDecimalNumber(value: minorValue)
            .dividing(by: NSDecimalNumber(value: minorUnitScale))

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .current
        formatter.currencyCode = currencyCode
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: amount) ?? amount.stringValue
    }

    static func localizedAmountValue(_ minorValue: Int) -> String {
        let amount = NSDecimalNumber(value: minorValue)
            .dividing(by: NSDecimalNumber(value: minorUnitScale))

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: amount) ?? amount.stringValue
    }

    private static func localizedPlaceholder(_ placeholder: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .current
        formatter.currencyCode = currencyCode
        return "\(formatter.positivePrefix ?? "")\(placeholder)\(formatter.positiveSuffix ?? "")"
    }
}

// MARK: - 名称プリセット

struct NamePreset: Identifiable {
    let names: [String]   // 必ず4要素
    var id: String { names.joined(separator: "/") }

    static var all: [NamePreset] {
        [
        NamePreset(names: ["A",    "B",    "C",    "D"   ]),  // デフォルト
        NamePreset(names: ["1",    "2",    "3",    "4"   ]),
        NamePreset(names: [String(localized: "preset.name.vip"), String(localized: "preset.name.high"), String(localized: "preset.name.mid"), String(localized: "preset.name.low")]),
        NamePreset(names: [String(localized: "preset.name.exec"), String(localized: "preset.name.lead"), String(localized: "preset.name.manager"), String(localized: "preset.name.staff")]),
        NamePreset(names: [String(localized: "preset.name.gold"), String(localized: "preset.name.silver"), String(localized: "preset.name.bronze"), String(localized: "preset.name.iron")]),
        NamePreset(names: [String(localized: "preset.name.premium"), String(localized: "preset.name.upper"), String(localized: "preset.name.standard"), String(localized: "preset.name.basic")]),
        NamePreset(names: [String(localized: "preset.name.senior"), String(localized: "preset.name.peer"), String(localized: "preset.name.junior"), String(localized: "preset.name.newcomer")]),
        NamePreset(names: ["",     "",     "",     ""    ]),  // ブランク
    ]
    }
}

// MARK: - 文字サイズ倍率

enum AppFontScale: Int, CaseIterable, Identifiable {
    case system   = 0   // 自動（システム設定に従う）
    case standard = 1   // 標準（Large 固定）
    case large    = 2   // 大（xxxLarge 相当）
    case xLarge   = 3   // 特大（accessibility2 相当）

    var id: Int { rawValue }

    var titleKey: String {
        switch self {
        case .system:   return "settings.fontScale.system"
        case .standard: return "settings.fontScale.standard"
        case .large:    return "settings.fontScale.large"
        case .xLarge:   return "settings.fontScale.xLarge"
        }
    }

    /// true のときはシステム設定に委ねる
    var followsSystem: Bool { self == .system }

    var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .system:   return .large
        case .standard: return .large
        case .large:    return .xxxLarge
        case .xLarge:   return .accessibility2
        }
    }
}

// MARK: - AppSettings

@Observable
@MainActor
final class AppSettings {
    static let shared = AppSettings()

    /// 区別ごとの名称
    var panelNames: [String] {
        didSet { UserDefaults.standard.set(panelNames, forKey: "panelNames") }
    }

    /// レザーデザイン
    var leatherStyle: LeatherStyle {
        didSet {
            UserDefaults.standard.set(leatherStyle.rawValue, forKey: "leatherStyle")
            guard leatherStyle != oldValue else { return }
            Telemetry.event(.backgroundChanged(style: leatherStyle.rawValue))
            Telemetry.setUserProperty(leatherStyle.rawValue, forName: "p_leather")
        }
    }

    /// ダイアルスタイル
    var dialStyle: DialStyle {
        didSet { UserDefaults.standard.set(dialStyle.id, forKey: "dialStyle") }
    }

    /// ダイアル操作設定
    var dialTuning: AZDialInteractionTuning {
        didSet { Self.saveDialTuning(dialTuning) }
    }

    /// 外観モード
    var appearanceMode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appearanceMode")
            guard appearanceMode != oldValue else { return }
            Telemetry.event(.appearanceChanged(mode: appearanceMode.rawValue))
            Telemetry.setUserProperty(appearanceMode.rawValue, forName: "p_appearance")
        }
    }

    /// 金額ダイアルステップ候補（最小通貨単位）
    var amountDialSteps: [Int] {
        didSet { UserDefaults.standard.set(Self.normalizedAmountDialSteps(amountDialSteps), forKey: "amountDialSteps") }
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

    /// 文字サイズ倍率
    var fontScale: AppFontScale {
        didSet {
            UserDefaults.standard.set(fontScale.rawValue, forKey: "fontScale")
            guard fontScale != oldValue else { return }
            Telemetry.event(.fontScaleChanged(scale: fontScale.rawValue))
            Telemetry.setUserProperty(String(fontScale.rawValue), forName: "p_font_scale")
        }
    }

    /// AZDialView のステッパーボタンを表示するか
    var showDialStepper: Bool {
        didSet {
            UserDefaults.standard.set(showDialStepper, forKey: "showDialStepper")
            guard showDialStepper != oldValue else { return }
            Telemetry.event(.showDialStepperToggled(enabled: showDialStepper))
            Telemetry.setUserProperty(showDialStepper ? "1" : "0", forName: "p_stepper")
        }
    }

    init() {
        let defaults = NamePreset.all[2].names   // 初期値は大富豪・富豪・平民・貧民
        var names = UserDefaults.standard.stringArray(forKey: "panelNames") ?? defaults
        // 旧バージョンからの移行: 足りない分を補完
        while names.count < 4 { names.append(defaults[names.count]) }
        panelNames = names

        let styleRaw = UserDefaults.standard.string(forKey: "leatherStyle") ?? ""
        leatherStyle = LeatherStyle(rawValue: styleRaw) ?? .brown

        let dialId = UserDefaults.standard.string(forKey: "dialStyle") ?? "brass"
        dialStyle = DialStyle.builtin(id: dialId) ?? .brass
        dialTuning = Self.loadDialTuning()

        let appearanceRaw = UserDefaults.standard.string(forKey: "appearanceMode") ?? ""
        appearanceMode = AppearanceMode(rawValue: appearanceRaw) ?? .automatic

        let storedSteps = UserDefaults.standard.array(forKey: "amountDialSteps") as? [Int]
        amountDialSteps = Self.normalizedAmountDialSteps(storedSteps ?? MoneyFormat.dialStepCandidates)

        let storedBrightness = UserDefaults.standard.integer(forKey: "panelBrightness")
        panelBrightness = min(40, max(-40, storedBrightness))

        // 旧キー amountHue から移行しつつ、新キー textHue を優先
        let hueObj = UserDefaults.standard.object(forKey: "textHue")
        let migratedHueObj = UserDefaults.standard.object(forKey: "amountHue")
        let storedHue = hueObj != nil
            ? UserDefaults.standard.integer(forKey: "textHue")
            : (migratedHueObj != nil ? UserDefaults.standard.integer(forKey: "amountHue") : -20)
        textHue = normalizedTextHueValue(storedHue)

        let toneObj = UserDefaults.standard.object(forKey: "textTone")
        let storedTone = toneObj != nil ? UserDefaults.standard.integer(forKey: "textTone") : 0
        textTone = min(100, max(0, storedTone))

        let storedFontScale = UserDefaults.standard.integer(forKey: "fontScale")
        fontScale = AppFontScale(rawValue: storedFontScale) ?? .system

        let stepperObj = UserDefaults.standard.object(forKey: "showDialStepper")
        showDialStepper = stepperObj != nil ? UserDefaults.standard.bool(forKey: "showDialStepper") : false
    }

    func name(for index: Int) -> String {
        guard index < panelNames.count else { return "\(index + 1)" }
        return panelNames[index]
    }

    func setName(_ name: String, for index: Int) {
        while panelNames.count <= index { panelNames.append("\(panelNames.count + 1)") }
        panelNames[index] = name
    }

    func setAmountDialStep(_ step: Int, at index: Int) {
        guard amountDialSteps.indices.contains(index) else { return }
        var next = amountDialSteps
        next[index] = max(1, min(MoneyFormat.maxMinorValue, step))
        amountDialSteps = Self.normalizedAmountDialSteps(next)
    }

    private static func normalizedAmountDialSteps(_ raw: [Int]) -> [Int] {
        var steps = raw.map { max(1, min(MoneyFormat.maxMinorValue, $0)) }
        if steps.isEmpty { steps = MoneyFormat.dialStepCandidates }
        while steps.count < 5 {
            steps.append(MoneyFormat.dialStepCandidates[min(steps.count, MoneyFormat.dialStepCandidates.count - 1)])
        }
        if steps.count > 5 {
            steps = Array(steps.prefix(5))
        }
        return steps
    }

    private static func loadDialTuning() -> AZDialInteractionTuning {
        let defaults = UserDefaults.standard
        let migrationKey = "dialTuningDefaultsToMildMigrated"

        if let data = defaults.data(forKey: "dialTuning"),
           let stored = try? JSONDecoder().decode(AZDialInteractionTuning.self, from: data) {
            // 既存ユーザー：以前「標準」(.default) のままなら一度だけ「控えめ」(.mild) に移行
            if !defaults.bool(forKey: migrationKey) {
                defaults.set(true, forKey: migrationKey)
                if stored == .default {
                    let mild = AZDialInteractionTuningPreset.mild.tuning
                    saveDialTuning(mild)
                    return mild
                }
            }
            return stored
        }
        // 新規インストール：デフォルトを「控えめ」に
        defaults.set(true, forKey: migrationKey)
        return AZDialInteractionTuningPreset.mild.tuning
    }

    private static func saveDialTuning(_ tuning: AZDialInteractionTuning) {
        guard let data = try? JSONEncoder().encode(tuning) else { return }
        UserDefaults.standard.set(data, forKey: "dialTuning")
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case automatic
    case light
    case dark

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .automatic: return "appearance.automatic"
        case .light:     return "appearance.light"
        case .dark:      return "appearance.dark"
        }
    }

    var localizedName: String {
        switch self {
        case .automatic: return String(localized: "appearance.automatic")
        case .light: return String(localized: "appearance.light")
        case .dark: return String(localized: "appearance.dark")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .automatic: return nil
        case .light: return .light
        case .dark: return .dark
        }
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

enum LeatherStyle: String, CaseIterable, Identifiable {
    case monotone
    case brown
    case black

    var id: String { rawValue }

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
        case .monotone: return String(localized: "leather.monotone")
        case .brown:    return String(localized: "leather.brown")
        case .black:    return String(localized: "leather.black")
        }
    }
}
