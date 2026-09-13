//
//  AZTenkeyInputTests.swift
//  DialSplitTests
//
//  テンキーの入力状態遷移。
//  とくに「未入力」と「0を入力した」の区別が崩れていないかを見る。
//

import Testing
import Foundation
@testable import DialSplit

struct AZTenkeyInputTests {

    /// 金額入力を想定した状態を作る
    private func makeInput(initial: Int = 78_500, min: Int = 0, max: Int = 999_900) -> AZTenkeyInput {
        AZTenkeyInput(initialValue: initial, minValue: min, maxValue: max)
    }

    // MARK: 0 の入力

    @Test func 初期状態は初期値を見せる() {
        let input = makeInput()
        #expect(input.isPristine)
        #expect(input.activeValue == Decimal(78_500))
        #expect(input.enteredValue == nil)
    }

    @Test func ゼロを押すと0が入力された状態になる() {
        var input = makeInput()
        input.append("0", rounding: .halfUp)

        #expect(!input.isPristine)
        #expect(input.enteredValue == Decimal(0))
        #expect(input.activeValue == Decimal(0))
        #expect(input.committedValue(rounding: .halfUp) == 0)
    }

    @Test func ダブルゼロを押しても0が入力された状態になる() {
        var input = makeInput()
        input.append("00", rounding: .halfUp)

        #expect(!input.isPristine)
        #expect(input.enteredValue == Decimal(0))
        #expect(input.activeValue == Decimal(0))
    }

    @Test func ゼロを入力してから確定すると0になる() {
        var input = makeInput()
        input.append("0", rounding: .halfUp)

        #expect(input.canConfirm(rounding: .halfUp))
        #expect(input.clampedValue(rounding: .halfUp) == 0)
    }

    @Test func 下限が1なら0は確定できない() {
        var input = makeInput(initial: 4, min: 1, max: 99)
        input.append("0", rounding: .halfUp)

        #expect(input.isOutOfRange(rounding: .halfUp))
        #expect(!input.canConfirm(rounding: .halfUp))
    }

    @Test func ゼロの次の数字は先頭ゼロを重ねない() {
        var input = makeInput()
        input.append("0", rounding: .halfUp)
        input.append("5", rounding: .halfUp)

        #expect(input.digits == "5")
        #expect(input.enteredValue == Decimal(5))
    }

    // MARK: 0 除算

    @Test func ゼロで割るとエラーになる() {
        var input = makeInput()
        input.append("6", rounding: .halfUp)
        input.selectOperator(.divide)
        input.append("0", rounding: .halfUp)

        // 右辺に 0 が入っていること自体を先に確かめる
        #expect(input.enteredValue == Decimal(0))
        #expect(input.errorKey == "azTenkey.error.divideByZero")
        #expect(!input.canConfirm(rounding: .halfUp))
    }

    @Test func ゼロ除算のあと右辺を入れ直せば計算できる() {
        var input = makeInput()
        input.append("6", rounding: .halfUp)
        input.selectOperator(.divide)
        input.append("0", rounding: .halfUp)
        #expect(input.errorKey != nil)

        input.append("2", rounding: .halfUp)   // "0" → "2" へ置き換わる
        #expect(input.errorKey == nil)
        #expect(input.activeValue == Decimal(3))
    }

    // MARK: 削除

    @Test func プレースホルダー中の削除で0入力になる() {
        var input = makeInput()
        input.deleteLast(rounding: .halfUp)

        #expect(!input.isPristine)
        #expect(input.enteredValue == Decimal(0))
    }

    @Test func 最後の桁を消しても0として残る() {
        var input = makeInput()
        input.append("7", rounding: .halfUp)
        input.deleteLast(rounding: .halfUp)

        // 空へ戻すと初期値へ戻ったように見えるので 0 にする
        #expect(input.enteredValue == Decimal(0))
        #expect(input.activeValue == Decimal(0))
    }

    @Test func 右辺を消し切ると演算子が外れる() {
        var input = makeInput(initial: 100)
        input.append("6", rounding: .halfUp)
        input.selectOperator(.add)
        input.append("3", rounding: .halfUp)

        input.deleteLast(rounding: .halfUp)   // 右辺が空になる
        #expect(input.pendingOperator == .add)

        input.deleteLast(rounding: .halfUp)   // 演算子が外れ、左辺へ戻る
        #expect(input.pendingOperator == nil)
        #expect(input.enteredValue == Decimal(6))
    }

    @Test func 演算子を外したあと別の演算子で計算し直せる() {
        var input = makeInput(initial: 100)
        input.append("8", rounding: .halfUp)
        input.selectOperator(.divide)
        input.append("2", rounding: .halfUp)
        #expect(input.activeValue == Decimal(4))

        // 右辺を消し、続けて押して演算子も外す
        input.deleteLast(rounding: .halfUp)
        input.deleteLast(rounding: .halfUp)
        #expect(input.pendingOperator == nil)
        #expect(input.enteredValue == Decimal(8))

        // 左辺はそのまま残っているので、別の演算子で組み直せる
        input.selectOperator(.multiply)
        input.append("3", rounding: .halfUp)
        #expect(input.activeValue == Decimal(24))
    }

    @Test func 右辺を入れ直すと計算結果も追従する() {
        var input = makeInput(initial: 0)
        input.append("9", rounding: .halfUp)
        input.selectOperator(.add)
        input.append("1", rounding: .halfUp)
        #expect(input.activeValue == Decimal(10))

        // 桁を足す
        input.append("0", rounding: .halfUp)
        #expect(input.activeValue == Decimal(19))

        // 消して入れ直す
        input.deleteLast(rounding: .halfUp)
        #expect(input.activeValue == Decimal(10))
    }

    // MARK: 計算

    @Test func 割り切れない値は丸めずに保つ() {
        var input = makeInput()
        for d in ["7", "8", "5", "0", "0"] {
            input.append(d, rounding: .halfUp)
        }
        input.selectOperator(.divide)
        input.append("3", rounding: .halfUp)

        #expect(input.needsRounding)

        // 途中で丸めていないので、3 を掛け戻せば確定値は元へ戻る。
        // Decimal の除算は有限桁で打ち切られるため、途中値そのものは
        // 78,499.999… とわずかにずれる。確定時の丸めで吸収される範囲に収まっていればよい
        input.selectOperator(.multiply)
        input.append("3", rounding: .halfUp)
        #expect(input.committedValue(rounding: .halfUp) == 78_500)
    }

    @Test func 途中で丸めると誤差が残ることの対比() {
        // 都度丸める実装なら 26,167 × 3 = 78,501 になってしまう。
        // 丸めを確定時の一度きりにしている理由がこれ
        let roundedStep = AZTenkeyRounding.halfUp.roundToInt(Decimal(78_500) / Decimal(3))
        #expect(NSDecimalNumber(decimal: roundedStep * 3).intValue == 78_501)
    }

    @Test func 丸め方法で確定値が変わる() {
        var input = makeInput()
        input.append("1", rounding: .halfUp)
        input.append("0", rounding: .halfUp)
        input.selectOperator(.divide)
        input.append("3", rounding: .halfUp)

        #expect(input.committedValue(rounding: .down) == 3)
        #expect(input.committedValue(rounding: .up) == 4)
        #expect(input.committedValue(rounding: .halfUp) == 3)
    }

    @Test func 上限を超える計算はエラーになる() {
        var input = makeInput(initial: 0, min: 0, max: 99)
        input.append("9", rounding: .halfUp)
        input.append("9", rounding: .halfUp)
        input.selectOperator(.multiply)
        input.append("9", rounding: .halfUp)

        #expect(input.errorKey == "azTenkey.error.outOfRange")
    }
}
