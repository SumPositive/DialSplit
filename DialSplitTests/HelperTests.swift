//
//  HelperTests.swift
//  DialSplitTests
//
//  Layer 3: 純粋ヘルパー（MoneyFormat / 文字色 / SFSymbol / プリセット）
//

import Testing
import SwiftUI
import Foundation
@testable import DialSplit

struct HelperTests {

    // MARK: - normalizedTextHueValue

    @Test("-15 以下は黒(-20)")
    func hueBlack() {
        #expect(normalizedTextHueValue(-15) == -20)
        #expect(normalizedTextHueValue(-100) == -20)
    }

    @Test("-15 より大きく 0 未満は白(-10)")
    func hueWhite() {
        #expect(normalizedTextHueValue(-10) == -10)
        #expect(normalizedTextHueValue(-1) == -10)
    }

    @Test("色相は 10 刻みにスナップ", arguments: [
        (0, 0), (4, 0), (5, 10), (14, 10), (15, 20), (355, 360), (360, 360), (400, 360),
    ])
    func hueSnap(raw: Int, expected: Int) {
        #expect(normalizedTextHueValue(raw) == expected)
    }

    // MARK: - linkedTextColor（クラッシュ・範囲の健全性）

    @Test("文字色は全色相・両カラースキームで生成できる")
    func textColorGenerates() {
        for hue in stride(from: -20, through: 360, by: 10) {
            for tone in [0, 50, 100] {
                _ = linkedTextColor(hue: hue, tone: tone, for: .light)
                _ = linkedTextColor(hue: hue, tone: tone, for: .dark)
            }
        }
    }

    // MARK: - SFSymbol フォールバック

    @Test("存在するシンボルはそのまま返す")
    func symbolAvailable() {
        #expect(SFSymbol.resolve("lock.fill", fallback: "questionmark") == "lock.fill")
    }

    @Test("存在しないシンボルは fallback に置き換わる")
    func symbolFallback() {
        let resolved = SFSymbol.resolve("definitely.not.a.real.symbol.xyz", fallback: "lock.fill")
        #expect(resolved == "lock.fill")
    }

    // MARK: - NamePreset

    @Test("全プリセットは区分 4 つを持つ")
    func presetsHaveFourTiers() {
        for preset in NamePreset.all {
            #expect(preset.names.count == 4)
        }
    }

    @Test("プリセットは複数登録されている")
    func presetsNotEmpty() {
        #expect(NamePreset.all.count >= 2)
    }

    // MARK: - AppFontScale

    @Test("自動以外はシステム追従しない")
    func fontScaleFollowsSystem() {
        #expect(AppFontScale.system.followsSystem == true)
        #expect(AppFontScale.standard.followsSystem == false)
        #expect(AppFontScale.large.followsSystem == false)
        #expect(AppFontScale.xLarge.followsSystem == false)
    }
}

// MARK: - 通貨依存ヘルパー（JPY 環境でのみ実行）

/// テスト実行環境のロケールが日本円かどうか
private var isJPY: Bool { MoneyFormat.currencyCode == "JPY" }

struct MoneyFormatTests {

    @Test("JPY は小数なし（fractionDigits=0 / scale=1）", .enabled(if: isJPY))
    func jpyScale() {
        #expect(MoneyFormat.fractionDigits == 0)
        #expect(MoneyFormat.minorUnitScale == 1)
    }

    @Test("JPY の端数拡張表示は小数1位を追加する", .enabled(if: isJPY))
    func extendedTruncatedJPY() {
        // 28,833.6 → main は 28,833 を含み、extra は ".6"
        let r = MoneyFormat.extendedTruncated(realMinor: 28_833.6)
        #expect(r.main.contains("28,833"))
        #expect(r.extra == ".6")
    }

    @Test("ダイアルステップ候補は最大値以下に絞られる")
    func dialStepOptionsBounded() {
        for step in MoneyFormat.dialStepDefinitionOptions {
            #expect(step <= MoneyFormat.maxMinorValue)
            #expect(step >= 1)
        }
    }

    @Test("通貨の小数桁と scale が整合する（ロケール非依存）")
    func scaleConsistency() {
        let digits = MoneyFormat.fractionDigits
        let expectedScale = Int(pow(10.0, Double(digits)))
        #expect(MoneyFormat.minorUnitScale == expectedScale)
    }
}
