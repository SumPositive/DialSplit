//
//  AZTenkeyCalculatorTests.swift
//  DialSplitTests
//
//  テンキーの計算規則。四則演算・0除算・丸め・範囲判定を単体で確かめる。
//  入力の状態遷移は AZTenkeyInputTests が受け持つ。
//

import Testing
import Foundation
@testable import DialSplit

struct AZTenkeyCalculatorTests {

    /// 成功した結果を取り出す。失敗ならテストを落とす
    private func value(
        _ left: Decimal,
        _ op: AZTenkeyOperator,
        _ right: Decimal,
        min: Int = 0,
        max: Int = 999_900
    ) throws -> Decimal {
        let result = AZTenkeyCalculator.calculate(left, op, right, minValue: min, maxValue: max)
        switch result {
        case .success(let v): return v
        case .failure(let e): throw TestFailure.unexpected(e)
        }
    }

    private func error(
        _ left: Decimal,
        _ op: AZTenkeyOperator,
        _ right: Decimal,
        min: Int = 0,
        max: Int = 999_900
    ) -> AZTenkeyCalculatorError? {
        switch AZTenkeyCalculator.calculate(left, op, right, minValue: min, maxValue: max) {
        case .success: return nil
        case .failure(let e): return e
        }
    }

    private enum TestFailure: Error {
        case unexpected(AZTenkeyCalculatorError)
    }

    // MARK: 四則演算

    @Test func 加算() throws {
        #expect(try value(1_200, .add, 800) == Decimal(2_000))
    }

    @Test func 減算() throws {
        #expect(try value(1_200, .subtract, 800) == Decimal(400))
    }

    @Test func 乗算() throws {
        #expect(try value(1_200, .multiply, 3) == Decimal(3_600))
    }

    @Test func 除算() throws {
        #expect(try value(1_200, .divide, 4) == Decimal(300))
    }

    @Test func 割り切れない除算は端数を保つ() throws {
        let result = try value(10, .divide, 3)
        // 確定時まで丸めない。ここで整数化すると掛け戻しで元へ戻らなくなる
        #expect(result != Decimal(3))
        #expect(AZTenkeyRounding.down.roundToInt(result) == Decimal(3))
    }

    // MARK: 0 除算

    @Test func ゼロ除算はエラー() {
        #expect(error(1_200, .divide, 0) == .divideByZero)
    }

    @Test func ゼロを掛けるのは通る() throws {
        #expect(try value(1_200, .multiply, 0) == Decimal(0))
    }

    @Test func ゼロを足し引きするのは通る() throws {
        #expect(try value(1_200, .add, 0) == Decimal(1_200))
        #expect(try value(1_200, .subtract, 0) == Decimal(1_200))
    }

    // MARK: 丸め

    @Test func 切り上げは正の無限大方向() {
        #expect(AZTenkeyRounding.up.roundToInt(Decimal(string: "2.1")!) == Decimal(3))
        // ゼロから離れる方向ではないので、負の値は 0 へ近づく
        #expect(AZTenkeyRounding.up.roundToInt(Decimal(string: "-2.5")!) == Decimal(-2))
    }

    @Test func 切り捨ては負の無限大方向() {
        #expect(AZTenkeyRounding.down.roundToInt(Decimal(string: "2.9")!) == Decimal(2))
        #expect(AZTenkeyRounding.down.roundToInt(Decimal(string: "-2.5")!) == Decimal(-3))
    }

    @Test("四捨五入は 0.5 を上へ")
    func halfUpRounding() {
        #expect(AZTenkeyRounding.halfUp.roundToInt(Decimal(string: "2.4")!) == Decimal(2))
        #expect(AZTenkeyRounding.halfUp.roundToInt(Decimal(string: "2.5")!) == Decimal(3))
        #expect(AZTenkeyRounding.halfUp.roundToInt(Decimal(string: "3.5")!) == Decimal(4))
    }

    @Test("偶数丸めは 0.5 を偶数側へ")
    func bankersRounding() {
        // 四捨五入との違いが出るのはちょうど 0.5 の時だけ
        #expect(AZTenkeyRounding.bankers.roundToInt(Decimal(string: "2.5")!) == Decimal(2))
        #expect(AZTenkeyRounding.bankers.roundToInt(Decimal(string: "3.5")!) == Decimal(4))
        #expect(AZTenkeyRounding.bankers.roundToInt(Decimal(string: "2.4")!) == Decimal(2))
    }

    @Test func 丸め方法は保存名を持つ() {
        // AppStorage へ書くので、名前が変わると設定を引き継げなくなる
        #expect(AZTenkeyRounding.up.rawValue == "up")
        #expect(AZTenkeyRounding.halfUp.rawValue == "halfUp")
        #expect(AZTenkeyRounding.bankers.rawValue == "bankers")
        #expect(AZTenkeyRounding.down.rawValue == "down")
    }

    // MARK: 連続演算

    @Test func 割って掛け戻すと確定値が元へ戻る() throws {
        let divided = try value(78_500, .divide, 3)
        let restored = try value(divided, .multiply, 3)

        // Decimal の除算は有限桁で打ち切られるので、途中値は 78,499.999… とわずかにずれる。
        // 丸めを確定時の一度きりにしているので、確定値では元へ戻る
        #expect(restored != Decimal(78_500))
        #expect(AZTenkeyRounding.halfUp.roundToInt(restored) == Decimal(78_500))
    }

    @Test func 都度丸めると誤差が残ることの対比() throws {
        let divided = try value(78_500, .divide, 3)
        // 途中で丸めてしまう実装だと 26,167 × 3 = 78,501 になる。
        // これを避けるために Decimal のまま持ち回している
        let roundedStep = AZTenkeyRounding.halfUp.roundToInt(divided)
        #expect(NSDecimalNumber(decimal: roundedStep * 3).intValue == 78_501)
    }

    // MARK: 範囲の境界

    @Test func 上限ちょうどは通る() throws {
        #expect(try value(99, .add, 0, min: 0, max: 99) == Decimal(99))
    }

    @Test func 上限を1超えるとエラー() {
        #expect(error(99, .add, 1, min: 0, max: 99) == .outOfRange)
    }

    @Test func 下限ちょうどは通る() throws {
        #expect(try value(1, .subtract, 0, min: 1, max: 99) == Decimal(1))
    }

    @Test func 下限を1下回るとエラー() {
        #expect(error(1, .subtract, 1, min: 1, max: 99) == .outOfRange)
    }

    @Test func 負の結果は下限0で弾かれる() {
        #expect(error(0, .subtract, 1, min: 0, max: 99) == .outOfRange)
    }

    @Test func 範囲判定は切り捨てで見るので端数は上限内に収まる() throws {
        // 99.6 は切り捨てれば 99 なので、計算そのものは通る。
        // 丸め方法によって弾かれ方が変わらないようにするための決まり
        let result = try value(Decimal(string: "99.6")!, .add, 0, min: 0, max: 99)
        #expect(result == Decimal(string: "99.6")!)
    }

    // MARK: 丸めで上限を超える場合（確定側との連携）

    @Test func 端数の四捨五入で上限を超える値は確定できない() {
        // 計算は通るが、四捨五入すると 100 になり上限 99 を超える。
        // ここを弾くのは確定側（AZTenkeyInput）の役目
        // 598 / 6 = 99.66… で端数を作る
        var input = AZTenkeyInput(initialValue: 0, minValue: 0, maxValue: 99)
        input.append("5", rounding: .halfUp)
        input.append("9", rounding: .halfUp)
        input.append("8", rounding: .halfUp)
        input.selectOperator(.divide)
        input.append("6", rounding: .halfUp)

        #expect(input.errorKey == nil)                       // 計算自体は通る
        #expect(input.committedValue(rounding: .halfUp) == 100)
        #expect(input.isOutOfRange(rounding: .halfUp))       // 確定側が弾く
        #expect(!input.canConfirm(rounding: .halfUp))

        // 切り捨てなら 99 に収まるので確定できる
        #expect(input.committedValue(rounding: .down) == 99)
        #expect(!input.isOutOfRange(rounding: .down))
    }
}
