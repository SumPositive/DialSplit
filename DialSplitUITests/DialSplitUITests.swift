//
//  DialSplitUITests.swift
//  DialSplitUITests
//
//  fastlane snapshot 用の UI テスト。
//  メイン画面 / 設定画面 / パネルスタイルの 3 カットを撮影する。
//
//  言語と通貨の確定方針:
//   - 言語は snapshot が渡す FASTLANE_LANGUAGE を UITest 側で読み、
//     -AppleLanguages に「(言語)」形式で明示的に渡す（zh-Hant のように
//     snapshot 既定の渡し方では切り替わらない言語を確実に切り替えるため）。
//   - 通貨は言語 → 代表地域ロケールへマップし、-SNAPSHOT_CURRENCY_LOCALE で
//     アプリへ明示渡し（MoneyFormat.effectiveLocale が最優先で読む）。
//     -AppleLocale は Locale.current に確実に効かないため使わない。
//
//  タップ対象は言語非依存の accessibilityIdentifier で特定:
//    - openSettingsButton   … ヘッダー右端の歯車（設定）
//    - openPanelStyleButton … ヘッダー左端のパレット（パネルスタイル）
//

import XCTest

final class DialSplitUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// 表示言語 → 通貨を出したい代表地域ロケール
    private func currencyLocale(for language: String) -> String {
        // language は "ja", "en-US", "zh-Hant" のような snapshot のフォルダ名
        let lang = language.lowercased()
        if lang.hasPrefix("ja")       { return "ja_JP" }   // ¥
        if lang.hasPrefix("en")       { return "en_US" }   // $
        if lang.hasPrefix("de")       { return "de_DE" }   // €
        if lang.hasPrefix("es")       { return "es_ES" }   // €
        if lang.hasPrefix("fr")       { return "fr_FR" }   // €
        if lang.hasPrefix("it")       { return "it_IT" }   // €
        if lang.hasPrefix("ko")       { return "ko_KR" }   // ₩
        if lang.hasPrefix("zh-hant")  { return "zh_TW"  }   // NT$
        if lang.hasPrefix("zh")       { return "zh_CN"  }
        return ""
    }

    @MainActor
    func testTakeScreenshots() throws {
        let app = XCUIApplication()
        setupSnapshot(app)

        // snapshot が撮影中の言語。SnapshotHelper が cache(language.txt) から読んで
        // グローバル変数 deviceLanguage に入れている（setupSnapshot 実行後に有効）。
        // ProcessInfo.environment["FASTLANE_LANGUAGE"] は UITest ランナープロセスには
        // 継承されず空になるため使わない。
        //
        // 言語(-AppleLanguages)は SnapshotHelper が既に language.txt の値
        // （例 "zh-Hant"。アプリの .lproj 名と一致する正しい値）で設定済みなので、
        // ここでは触らない（"zh-Hant-TW" 等に上書きすると .lproj にマッチせず失敗する）。
        // ここでは通貨ロケールだけをアプリへ明示渡しする。
        let language = deviceLanguage
        if !language.isEmpty {
            let currency = currencyLocale(for: language)
            if !currency.isEmpty {
                app.launchArguments += ["-SNAPSHOT_CURRENCY_LOCALE", currency]
            }
        }

        app.launch()

        // メイン画面が描画されるまで待つ
        sleep(2)

        // 1 カット目: メイン画面
        snapshot("01MainScreen")

        // 2 カット目: 設定画面（歯車ボタン → シート）
        let settingsButton = app.buttons["openSettingsButton"]
        if settingsButton.waitForExistence(timeout: 10) {
            settingsButton.tap()
            sleep(2)
            snapshot("02Settings")
            app.swipeDown(velocity: .fast)
            sleep(1)
        }

        // 3 カット目: パネルスタイル（パレットボタン → シート）
        // パレットボタンはヘッダー左端にあり、スクロールせずに常に見えている
        let styleButton = app.buttons["openPanelStyleButton"]
        if styleButton.waitForExistence(timeout: 10) {
            styleButton.tap()
            sleep(2)
            snapshot("03PanelStyle")
            app.swipeDown(velocity: .fast)
            sleep(1)
        }
    }
}
