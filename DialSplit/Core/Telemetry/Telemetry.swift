//
//  Telemetry.swift
//  DialSplit
//
//  Firebase Analytics / Crashlytics ラッパー
//  - 匿名利用統計の収集
//  - try エラーなど非致命的エラーの記録
//

import Foundation

#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif
#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

enum Telemetry {

    // MARK: - 初期化

    /// FirebaseApp.configure() の直後に呼ぶ
    static func setup() {
        #if canImport(FirebaseAnalytics)
        Analytics.setAnalyticsCollectionEnabled(true)
        #endif
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        #endif
    }

    // MARK: - イベント送信

    /// 構造化イベントを送信
    static func event(_ event: TelemetryEvent) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(event.name, parameters: event.parameters)
        #endif
    }

    /// シンプルなイベント（パラメータなし）
    static func event(_ name: String, _ parameters: [String: Any]? = nil) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(name, parameters: parameters)
        #endif
    }

    // MARK: - 非致命的エラー記録

    /// try エラーなどを Crashlytics に記録
    static func record(_ error: Error,
                       context: String? = nil,
                       file: String = #fileID,
                       line: Int = #line) {
        #if canImport(FirebaseCrashlytics)
        let ns = error as NSError
        var info = ns.userInfo
        info["sourceFile"] = file
        info["sourceLine"] = line
        if let context { info["context"] = context }
        let enriched = NSError(domain: ns.domain, code: ns.code, userInfo: info)
        Crashlytics.crashlytics().record(error: enriched)
        #endif
    }

    /// 任意のメッセージを Crashlytics の log に追加（直近のクラッシュにアタッチされる）
    static func log(_ message: String) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().log(message)
        #endif
    }

    // MARK: - ユーザープロパティ（低カーディナリティ）

    /// 設定状態などをユーザープロパティとして送信
    /// Firebase の上限：最大25個、各値36文字以内
    static func setUserProperty(_ value: String?, forName name: String) {
        #if canImport(FirebaseAnalytics)
        Analytics.setUserProperty(value, forName: name)
        #endif
    }

    /// AppSettings の現状をまとめてユーザープロパティに反映
    /// 起動時 + 設定変更時に呼ぶ
    @MainActor
    static func snapshotSettings(_ s: AppSettings) {
        setUserProperty(s.appearanceMode.rawValue, forName: "p_appearance")
        setUserProperty(String(s.fontScale.rawValue), forName: "p_font_scale")
        setUserProperty(s.dialStyle.id, forName: "p_dial_style")
        setUserProperty(s.leatherStyle.rawValue, forName: "p_leather")
        setUserProperty(s.showDialStepper ? "1" : "0", forName: "p_stepper")

        // パネル名プリセット（既存プリセットと一致するか）
        let presetIndex = NamePreset.all.firstIndex(where: { $0.names == s.panelNames }) ?? -1
        setUserProperty(String(presetIndex), forName: "p_name_preset")

        // 文字色（黒/白/有彩）
        let hue = normalizedTextHueValue(s.textHue)
        let colorBucket: String
        if hue == -20 { colorBucket = "black" }
        else if hue == -10 { colorBucket = "white" }
        else { colorBucket = "hue_\(hue)" }
        setUserProperty(colorBucket, forName: "p_text_color")
        setUserProperty(String(s.textTone), forName: "p_text_tone")
        setUserProperty(String(s.panelBrightness), forName: "p_brightness")

        // ロケール由来の通貨
        setUserProperty(MoneyFormat.currencyCode, forName: "p_currency")
    }
}
