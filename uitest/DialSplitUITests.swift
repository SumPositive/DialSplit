//
//  DialSplitUITests.swift
//  DialSplitUITests
//
//  fastlane snapshot 用の UI テスト。
//  まずはメイン画面 1 カットだけを撮影して仕組みを検証する。
//  カットを増やすときは test メソッド内に snapshot("02Settings") のように追記していく。
//

import XCTest

final class DialSplitUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTakeScreenshots() throws {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launch()

        // メイン画面が描画されるまで少し待つ（アニメーション/初期化対策）
        // 必要なら特定要素の待機に置き換える:
        //   XCTAssertTrue(app.otherElements["mainScreen"].waitForExistence(timeout: 10))
        sleep(2)

        // 1 カット目: メイン画面
        snapshot("01MainScreen")
    }
}
