//
//  テンキーの入力状態。
//
//  View から切り離してあるので、キーを押した時の状態遷移を単体で確かめられる。
//  「0を入力して確定」「0で割る」のような境目は、ここを直接叩いて検証する。
//

import Foundation

/// テンキーが受け取るキー
enum AZTenkeyKey: Equatable {
    case digit(String)
    case doubleZero
    case delete
}

/// テンキーの入力状態と、その遷移。
///
/// 未入力（初期値をプレースホルダー表示中）と 0 の入力は別の状態として扱う。
/// 混ぜると 0 を確定できなくなる。
struct AZTenkeyInput {
    /// 入力できる値の範囲と初期値
    let initialValue: Int
    let minValue: Int
    let maxValue: Int

    /// 入力中の数字。空文字は「右辺をまだ打っていない」ことだけを表す
    private(set) var digits: String = ""
    /// 初期値をそのまま見せている（まだ一度も入力していない）状態か
    private(set) var isPlaceholder: Bool = true

    /// 左辺（未丸めの途中結果）
    private(set) var accumulator: Decimal?
    private(set) var pendingOperator: AZTenkeyOperator?
    /// 右辺入力中の途中結果
    private(set) var calculationResult: Decimal?
    /// 計算できなかった理由の文字列キー
    private(set) var errorKey: String?

    init(initialValue: Int, minValue: Int, maxValue: Int) {
        self.initialValue = initialValue
        self.minValue = minValue
        self.maxValue = maxValue
    }

    // MARK: 読み取り

    /// いま打ち込んでいる数値。未入力なら nil。
    /// 0 を打った場合は 0 を返す（nil にしない）
    var enteredValue: Decimal? {
        guard !isPlaceholder, !digits.isEmpty else { return nil }
        return Decimal(string: digits)
    }

    /// 画面に出す値。式の途中なら計算結果、そうでなければ入力値
    var activeValue: Decimal {
        if pendingOperator != nil, let calculationResult { return calculationResult }
        if let enteredValue { return enteredValue }
        if let calculationResult { return calculationResult }
        if let accumulator { return accumulator }
        return Decimal(initialValue)
    }

    /// まだ何も操作していない（初期値をそのまま見せている）状態か
    var isPristine: Bool {
        isPlaceholder && accumulator == nil && calculationResult == nil
    }

    /// 確定時の値。ここで初めて整数へ丸める
    func committedValue(rounding: AZTenkeyRounding) -> Int {
        NSDecimalNumber(decimal: rounding.roundToInt(activeValue)).intValue
    }

    /// 端数があり、丸め方法によって結果が変わる状態か
    var needsRounding: Bool {
        AZTenkeyRounding.down.roundToInt(activeValue) != activeValue
    }

    func isOutOfRange(rounding: AZTenkeyRounding) -> Bool {
        guard !isPristine else { return false }
        let value = committedValue(rounding: rounding)
        return value < minValue || maxValue < value
    }

    func canConfirm(rounding: AZTenkeyRounding) -> Bool {
        errorKey == nil && !isOutOfRange(rounding: rounding)
    }

    /// 範囲へ収めた確定値
    func clampedValue(rounding: AZTenkeyRounding) -> Int {
        max(minValue, min(maxValue, committedValue(rounding: rounding)))
    }

    // MARK: 遷移

    mutating func handle(_ key: AZTenkeyKey, rounding: AZTenkeyRounding) {
        switch key {
        case .digit(let d):   append(d, rounding: rounding)
        case .doubleZero:     append("00", rounding: rounding)
        case .delete:         deleteLast(rounding: rounding)
        }
    }

    mutating func append(_ d: String, rounding: AZTenkeyRounding) {
        errorKey = nil

        // プレースホルダー中は入力をリセットしてから1桁目を受け付ける。
        // 0 も「入力された値」なので "0" を残す（空にすると未入力と区別できない）
        if isPlaceholder {
            isPlaceholder = false
            digits = (d == "00") ? "0" : d
            updatePreview()
            return
        }
        // "00" は "0" を2回追加
        if d == "00" {
            append("0", rounding: rounding)
            append("0", rounding: rounding)
            return
        }
        // 先頭ゼロは重ねない。"0" のあとに数字が来たら置き換える
        let next: String
        if digits.isEmpty || digits == "0" {
            next = d
        } else {
            next = digits + d
        }
        guard next.count <= maxDigits else { return }
        digits = next
        updatePreview()
    }

    mutating func deleteLast(rounding: AZTenkeyRounding) {
        errorKey = nil

        // プレースホルダー中は ⌫ でクリアし、0 を入力した状態にする
        if isPlaceholder {
            isPlaceholder = false
            digits = "0"
            updatePreview()
            return
        }
        if !digits.isEmpty {
            digits.removeLast()
            // 式を組み立てていない時は、最後の1桁を消しても 0 として残す。
            // 空にすると未入力と区別できず、初期値へ戻ったように見えてしまう。
            // 右辺の入力中は空に戻し、続けて押せば演算子を外せるようにする
            if digits.isEmpty, pendingOperator == nil {
                digits = "0"
            }
            updatePreview()
            return
        }
        // 右辺を消し終えた次の ⌫ で演算子を外し、左辺を再編集できる形へ戻す。
        // 左辺は未丸めの途中結果なので、表示していた値と食い違わないよう
        // 選択中の丸め方法で確定してから入力欄へ戻す
        guard pendingOperator != nil, let left = accumulator else { return }
        pendingOperator = nil
        calculationResult = nil
        accumulator = nil
        digits = NSDecimalNumber(decimal: rounding.roundToInt(left)).stringValue
    }

    mutating func selectOperator(_ newOperator: AZTenkeyOperator) {
        errorKey = nil

        if let currentOperator = pendingOperator,
           let left = accumulator,
           let right = enteredValue {
            // 式が揃っていれば、まず今の式を畳んでから次の演算子を受ける
            guard let result = calculate(left, currentOperator, right) else { return }
            accumulator = result
            calculationResult = result
        } else if accumulator == nil {
            accumulator = activeValue
        }
        pendingOperator = newOperator
        // 左辺を取り込んだので、右辺の入力欄を空にする
        isPlaceholder = false
        digits = ""
    }

    /// 確定前に、組み立て途中の式を畳む。
    /// - Returns: 畳めたか（0 除算などで失敗したら false）
    @discardableResult
    mutating func finalizeExpression() -> Bool {
        guard let left = accumulator,
              let pendingOperator,
              let right = enteredValue else { return true }
        guard let result = calculate(left, pendingOperator, right) else { return false }
        calculationResult = result
        return true
    }

    // MARK: 内部

    /// 入力できる桁数。乗除算の右辺は金額ではなく倍率なので別に抑える
    private var maxDigits: Int {
        if pendingOperator == .multiply || pendingOperator == .divide {
            return 4
        }
        return String(maxValue).count + 1
    }

    private mutating func updatePreview() {
        guard let left = accumulator,
              let pendingOperator,
              let right = enteredValue else {
            calculationResult = nil
            return
        }
        calculationResult = calculate(left, pendingOperator, right)
    }

    /// 計算規則は AZTenkeyCalculator に持たせ、ここでは結果を状態へ反映する
    private mutating func calculate(
        _ left: Decimal,
        _ operation: AZTenkeyOperator,
        _ right: Decimal
    ) -> Decimal? {
        switch AZTenkeyCalculator.calculate(
            left, operation, right,
            minValue: minValue,
            maxValue: maxValue
        ) {
        case .success(let result):
            errorKey = nil
            return result
        case .failure(let error):
            errorKey = error.titleKey
            return nil
        }
    }
}
