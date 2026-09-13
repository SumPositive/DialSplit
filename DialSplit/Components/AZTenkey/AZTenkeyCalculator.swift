//
//  テンキーの簡易電卓の計算部分
//  View から切り離し、四則演算・上限判定・丸めを単体で確かめられるようにする
//

import Foundation

/// 簡易電卓で使う四則演算子
enum AZTenkeyOperator: CaseIterable, Identifiable {
    case divide
    case multiply
    case subtract
    case add

    var id: Self { self }

    var symbol: String {
        switch self {
        case .divide:   "÷"
        case .multiply: "×"
        case .subtract: "−"
        case .add:      "+"
        }
    }
}

/// 割り算などで生じた端数を整数へそろえる方法。
/// 選択を保存できるよう、保存名を持つ
enum AZTenkeyRounding: String, CaseIterable, Hashable, Identifiable {
    case up      = "up"
    case halfUp  = "halfUp"
    case bankers = "bankers"
    case down    = "down"

    var id: Self { self }

    var titleKey: String {
        switch self {
        case .up:      "azTenkey.rounding.up"
        case .halfUp:  "azTenkey.rounding.halfUp"
        case .bankers: "azTenkey.rounding.bankers"
        case .down:    "azTenkey.rounding.down"
        }
    }

    private var decimalMode: Decimal.RoundingMode {
        switch self {
        case .up:      .up
        case .halfUp:  .plain
        case .bankers: .bankers
        case .down:    .down
        }
    }

    /// 整数へ、選択中の方法で丸める
    func roundToInt(_ value: Decimal) -> Decimal {
        var source = value
        var result = Decimal()
        NSDecimalRound(&result, &source, 0, decimalMode)
        return result
    }
}

/// 計算できなかった理由。View 側でエラー文言に対応づける
enum AZTenkeyCalculatorError: Error, Equatable {
    /// 0 で割ろうとした
    case divideByZero
    /// 結果が扱える範囲を超えた
    case outOfRange

    /// 表示に使う文字列カタログのキー
    var titleKey: String {
        switch self {
        case .divideByZero: "azTenkey.error.divideByZero"
        case .outOfRange:   "azTenkey.error.outOfRange"
        }
    }
}

/// テンキーの計算規則をまとめた入れ物。状態を持たないので単体で検証できる
enum AZTenkeyCalculator {

    /// 二項演算を行い、扱える範囲に収まっているか確かめる。
    ///
    /// 途中結果は `Decimal` のまま返す。`78,500 ÷ 3` のように割り切れない値を
    /// ここで整数へ丸めてしまうと、続けて `× 3` した時に元へ戻らなくなるため。
    /// 整数化は確定時に一度だけ行う。
    ///
    /// - Parameters:
    ///   - left: 左辺（計算途中の値は丸めずに渡す）
    ///   - operation: 演算子
    ///   - right: 右辺
    ///   - minValue: 確定できる値の下限
    ///   - maxValue: 確定できる値の上限
    /// - Returns: 計算結果。0 除算と範囲外は `AZTenkeyCalculatorError` を返す
    static func calculate(
        _ left: Decimal,
        _ operation: AZTenkeyOperator,
        _ right: Decimal,
        minValue: Int,
        maxValue: Int
    ) -> Result<Decimal, AZTenkeyCalculatorError> {
        let result: Decimal
        switch operation {
        case .divide:
            guard right != 0 else { return .failure(.divideByZero) }
            result = left / right
        case .multiply:
            result = left * right
        case .subtract:
            result = left - right
        case .add:
            result = left + right
        }

        // 途中式は端数を持ちうるので、範囲判定は整数へ丸めた値で行う。
        // 丸め方法によらず弾かれ方が変わらないよう、ここは切り捨てで見る
        var truncated = Decimal()
        var source = result
        NSDecimalRound(&truncated, &source, 0, .down)
        guard Decimal(minValue) <= truncated, truncated <= Decimal(maxValue) else {
            return .failure(.outOfRange)
        }
        return .success(result)
    }
}
