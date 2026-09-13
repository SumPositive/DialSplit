//
//  AZTenkeyView.swift
//  DialSplit
//
//  テンキー入力シート（簡易電卓つき）
//  .sheet(item: $tenkeyConfig) { AZTenkeyView(config: $0) } で呼び出す
//
//  初期値はプレースホルダー表示（薄いカラー）。
//  数字キーを押した瞬間にクリアされ、1桁目から入力開始。
//
//  レイアウト（パネル設定シートに合わせた NavigationStack + 角丸キー）:
//  ┌─────────────────────────┐
//  │      タイトル          ⌄  │  ← 標準のナビゲーションバー
//  │      1,234,567    ✓      │  ← 中央寄せ・行ごとタップで確定
//  │ 78,500÷3=26,166.7 [四捨五入]│  ← 式がある時だけ／無ければ畳む
//  │  7   8   9  │  ÷         │
//  │  4   5   6  │  ×         │
//  │  1   2   3  │  −         │
//  │  0   00  ⌫  │  +         │
//  └─────────────────────────┘
//
//  確定は金額行のタップに集約し、完了ボタンへの往復をなくしている。
//  閉じるはナビゲーションバー右の ⌄ か、下へのスライド。
//
//  式や丸めの行が増減すると、シートの高さ自体を変えて上へ伸ばす。
//  シートは下端が固定なので、こうするとテンキーの位置が動かない。
//
//  計算途中の値は Decimal のまま持ち、確定時に一度だけ整数へ丸める。
//  「78,500 ÷ 3 × 3」で元へ戻せるようにするため。
//

import SwiftUI
import UIKit

// MARK: - ハプティクス

/// キーを叩くたびに生成すると初回に引っかかるため、1つを使い回して鳴らす。
/// prepare() でハードウェアを起こしておき、押した瞬間の遅れをなくす
@MainActor
private enum AZTenkeyHaptics {
    static let generator = UISelectionFeedbackGenerator()

    static func prepare() {
        generator.prepare()
    }

    static func tap() {
        generator.selectionChanged()
        // 続けて押されることが多いので、次の一打に備えて起こしたままにする
        generator.prepare()
    }
}

// MARK: - 設定 (Identifiable で sheet(item:) に使用)

struct AZTenkeyConfig: Identifiable {
    let id: UUID
    let title: String
    let initialValue: Int
    let maxValue: Int
    let minValue: Int
    /// 値の見せ方。通貨か、ただの整数かをここで決める
    let format: AZTenkeyFormat
    let onConfirm: (Int) -> Void

    init(
        id: UUID = UUID(),
        title: String,
        initialValue: Int,
        maxValue: Int,
        minValue: Int,
        format: AZTenkeyFormat,
        onConfirm: @escaping (Int) -> Void
    ) {
        self.id = id
        self.title = title
        self.initialValue = initialValue
        self.maxValue = maxValue
        self.minValue = minValue
        self.format = format
        self.onConfirm = onConfirm
    }

    /// 通貨として扱うか（式の桁の直し方を分けるのに使う）
    var isAmount: Bool { format.minorUnitScale != 1 || format.fractionDigits != 0 }

    /// 確定時の処理だけを差し替えた設定を作る。
    /// シートに載せる時に「確定したら閉じる」を足すのに使う
    func replacingOnConfirm(_ newValue: @escaping (Int) -> Void) -> AZTenkeyConfig {
        AZTenkeyConfig(
            id: id,
            title: title,
            initialValue: initialValue,
            maxValue: maxValue,
            minValue: minValue,
            format: format,
            onConfirm: newValue
        )
    }
}

// MARK: - キー種別

private enum AZTenkeyKey {
    case digit(String)
    case doubleZero
    case delete
}

// MARK: - キーのボタンスタイル

/// 押しても見た目を変えないボタンスタイル。
/// .plain でも押下中は文字が薄くなるフェードが入るため、それも止める。
/// 連打する電卓キーでは、明滅より即時に値が変わる方が速く見える
private struct AZTenkeyKeyStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

// MARK: - テンキービュー

struct AZTenkeyView: View {
    let config: AZTenkeyConfig

    /// キーや余白は Font に任せられないので、文字サイズ設定を寸法へ自前で反映する
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var inputStr: String = ""
    @State private var isPlaceholder: Bool = true   // true = 初期値をプレースホルダー表示中

    // 電卓の状態
    @State private var accumulator: Decimal?          // 左辺（未丸めの途中結果）
    @State private var pendingOperator: AZTenkeyOperator?
    @State private var calculationResult: Decimal?    // 右辺入力中の途中結果
    @State private var errorKey: String?
    @State private var isRoundingExpanded = false

    /// 丸め方法の保存先。アプリ側の設定キーとぶつかる時はここだけ変える
    static let roundingStorageKey = "azTenkey.rounding"

    /// 丸め方法はシートを閉じても選んだものを引き継ぐ。既定は四捨五入
    @AppStorage(AZTenkeyView.roundingStorageKey) private var rounding: AZTenkeyRounding = .halfUp

    init(config: AZTenkeyConfig) {
        self.config = config
    }

    // MARK: 寸法

    /// 縦に余裕のない端末では、キーと余白を一段詰める
    private var isCompact: Bool { UIScreen.main.bounds.height <= 700 }

    /// 文字サイズ設定に応じた寸法の倍率。
    /// キーの高さや余白は Font のように自動では伸びないので、ここで掛ける。
    /// アクセシビリティサイズまで素直に追うとテンキーが画面へ収まらなくなるため、
    /// 伸びしろは頭打ちにしている
    private var uiScale: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small, .medium:      return 0.95
        case .large:                        return 1.0
        case .xLarge:                       return 1.06
        case .xxLarge:                      return 1.12
        case .xxxLarge:                     return 1.18
        default:                            return 1.26   // アクセシビリティサイズ
        }
    }

    /// 金額表示だけは伸びを抑える。大きく出したいが、行から溢れさせたくない
    private var displayScale: CGFloat { min(uiScale, 1.12) }

    private var keySpacing: CGFloat { (isCompact ? 8 : 10) * uiScale }
    private var sheetSpacing: CGFloat { (isCompact ? 10 : 14) * uiScale }
    private var displayFontSize: CGFloat { (isCompact ? 48 : 56) * displayScale }
    private var checkmarkSize: CGFloat { (isCompact ? 34 : 38) * displayScale }
    /// 式と丸めを並べた1行の高さ。背の高い方（title3 の行高）で決まる
    private var statusRowHeight: CGFloat { 26 * uiScale }

    /// このテンキーを表示するのに要る高さ。
    ///
    /// シートに載せる時は、これを detent へ渡すと中身の増減に追従して
    /// 上へ伸び、テンキーの位置が動かない（シートは下端が固定のため）。
    /// 固定値にすると、式が出た分だけテンキーが押し下げられてしまう。
    /// 値は `AZTenkeyHeightKey` でも親へ伝えている
    var preferredHeight: CGFloat {
        let top: CGFloat = 8 * uiScale
        let amountRow = displayFontSize * 1.25 + 8
        let keypad = keyHeight * 4 + keySpacing * 3
        let bottom: CGFloat = 12 * uiScale

        // この View 自身の高さだけを返す。ナビゲーションバーは載せる側が足す
        var height = top + amountRow + sheetSpacing + keypad + bottom
        // 式と丸めは同じ行に並ぶので、増えるのは1行ぶんだけ
        if errorKey != nil || expressionText != nil {
            height += sheetSpacing + statusRowHeight
        }
        return height
    }

    // MARK: 計算プロパティ

    /// いま入力中の数値（右辺）。未入力なら nil
    private var enteredValue: Decimal? {
        guard !isPlaceholder, !inputStr.isEmpty else { return nil }
        return Decimal(string: inputStr)
    }

    /// 画面に出す値。式の途中なら計算結果、そうでなければ入力値
    private var activeValue: Decimal {
        if pendingOperator != nil, let calculationResult { return calculationResult }
        if let enteredValue { return enteredValue }
        if let calculationResult { return calculationResult }
        if let accumulator { return accumulator }
        return Decimal(config.initialValue)
    }

    /// 確定時の値。ここで初めて整数へ丸める
    private var committedValue: Int {
        let rounded = rounding.roundToInt(activeValue)
        return NSDecimalNumber(decimal: rounded).intValue
    }

    /// 端数があり、丸め方法によって結果が変わる状態か
    private var needsRounding: Bool {
        AZTenkeyRounding.down.roundToInt(activeValue) != activeValue
    }

    /// まだ何も操作していない（初期値をそのまま見せている）状態か
    private var isPristine: Bool {
        isPlaceholder && accumulator == nil && calculationResult == nil
    }

    private var isOutOfRange: Bool {
        !isPristine && (committedValue < config.minValue || committedValue > config.maxValue)
    }

    private var displayText: String {
        config.format.display(committedValue)
    }

    private var displayColor: Color {
        if isOutOfRange { return .red }
        if isPristine { return Color(.tertiaryLabel) }
        return Color(.label)
    }

    private var canConfirm: Bool {
        errorKey == nil && !isOutOfRange
    }

    /// 確定アイコンの色。
    /// まだ何も入力していない間は淡くして、値を変えていないことを示す。
    /// ただし押せば初期値のまま確定できるので、タップ自体は有効に保つ
    private var checkmarkColor: Color {
        guard canConfirm, !isPristine else { return Color(.tertiaryLabel) }
        return Color.accentColor
    }

    /// 「78,500 ÷ 3」のような途中式。左辺が無ければ出さない
    private var expressionText: String? {
        guard let accumulator, let pendingOperator else { return nil }
        let left = plainNumberText(accumulator)
        guard let enteredValue else { return "\(left) \(pendingOperator.symbol)" }
        return "\(left) \(pendingOperator.symbol) \(rightOperandText(enteredValue))"
    }

    // MARK: ビュー

    var body: some View {
        // 畳んだ行の spacing が残らないよう、VStack 自体は詰めて置き、
        // 行間はそれぞれの行に持たせる
        VStack(spacing: 0) {
            amountDisplayRow

            statusRow

            HStack(alignment: .top, spacing: keySpacing) {
                keypadGrid
                operatorColumn
            }
            .padding(.horizontal, (isCompact ? 16 : 20) * uiScale)
            .padding(.top, sheetSpacing)
            .padding(.bottom, 12 * uiScale)
        }
        .padding(.top, 8 * uiScale)
        .frame(maxWidth: .infinity, alignment: .top)
        // キーの地（secondarySystemGroupedBackground）と同色にならないよう、
        // 一段沈んだグループ背景を敷いてキーの輪郭を出す
        .background(Color(uiColor: .systemGroupedBackground))
        .onAppear { AZTenkeyHaptics.prepare() }
        // シートに載せた親が detent を追従できるよう、必要な高さを伝える
        .preference(key: AZTenkeyHeightKey.self, value: preferredHeight)
        // 入力・演算子選択・式の出現をアニメーションさせず、即時に切り替える
        .transaction { transaction in
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
    }

    /// 丸め後の最終値と確定ボタン。
    /// 行のどこを押しても確定できるようにして、完了ボタンの往復をなくす
    private var amountDisplayRow: some View {
        Button {
            confirm()
            AZTenkeyHaptics.tap()
        } label: {
            // 金額とチェックをひと組にして中央へ置く。
            // チェックは行の右端ではなく、金額のすぐ右に添える
            HStack(spacing: 12 * uiScale) {
                Text(displayText)
                    .font(.system(size: displayFontSize, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(displayColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.38)
                    .allowsTightening(true)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: checkmarkSize))
                    .foregroundStyle(checkmarkColor)
                    .frame(width: checkmarkSize, height: checkmarkSize)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16 * uiScale)
            .padding(.vertical, 4 * uiScale)
            // 数字と数字の隙間も押せるよう、行全体を当たり判定にする
            .contentShape(Rectangle())
        }
        .buttonStyle(AZTenkeyKeyStyle())
        .disabled(!canConfirm)
        .accessibilityLabel(Text("azTenkey.done"))
        .accessibilityValue(Text(displayText))
    }

    /// 計算式（左）と丸め選択（右）を1行に並べた塊。
    /// 出すものが無い時は行ごと畳み、余った高さをテンキー側へ渡す
    @ViewBuilder
    private var statusRow: some View {
        if let errorKey {
            Text(LocalizedStringKey(errorKey))
                .font(.footnote)
                .foregroundStyle(.red)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, sheetSpacing)
        } else if expressionText != nil {
            // 式と丸めをひと組にして中央へ置く。
            // 式に幅いっぱいを取らせると、丸めだけが右端へ離れてしまう
            HStack(spacing: 8 * uiScale) {
                calculationLine

                // 端数が出ない式では丸めを選ぶ意味がないので、その分を畳む
                if needsRounding {
                    roundingPicker
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16 * uiScale)
            .padding(.top, sheetSpacing)
        }
    }

    /// 選択中の丸め方法を計算式の右へ小さく添える
    private var roundingPicker: some View {
        Group {
            // 端数が出て、丸め方で結果が変わるときだけ選ばせる
            AZDropdownPicker(
                options: AZTenkeyRounding.allCases,
                selection: $rounding,
                isExpanded: $isRoundingExpanded,
                minWidth: 0,
                style: roundingPickerStyle,
                collapsedLabelOverride: { option in
                    // 選択結果だけを小さくし、吹き出し内の文字サイズは維持する。
                    // 長い名称は縮小して1行に収め、行からはみ出さないようにする
                    AnyView(
                        Text(LocalizedStringKey(option.titleKey))
                            .font(.footnote.weight(.medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    )
                }
            ) { option in
                Text(LocalizedStringKey(option.titleKey))
            }
        }
        // 式に幅を譲り、ピッカーは名称ぶんだけ確保する
        .layoutPriority(1)
    }

    /// 計算式と丸め前の結果を一行にまとめる
    private var calculationLine: some View {
        let resultSuffix: String = {
            guard calculationResult != nil else { return "" }
            return " = \(resultNumberText(activeValue))"
        }()
        return Text((expressionText ?? "") + resultSuffix)
            .font(.title3.weight(.medium).monospacedDigit())
            .foregroundStyle(.secondary)
            .lineLimit(1)
            // 最大額同士の式でも省略せず一行へ収める
            .minimumScaleFactor(0.42)
            .allowsTightening(true)
    }

    private var roundingPickerStyle: AZPickerStyle {
        var style = AZPickerStyle.form
        style.cornerRadius = 16
        // 金額と計算式の間に小さく添えるだけなので、枠内の上下は詰める
        style.collapsedVerticalPadding = 2
        style.dropdownTextFitMode = .scale(minimumScaleFactor: 0.55)
        style.dropdownOptionAlignment = .center
        style.dropdownOptionStackAlignment = .center
        style.dropdownOptionTextAlignment = .center
        // 小型表示では丸め名称だけを見せ、右端の矢印は表示しない
        style.dropdownIndicator = .none
        return style
    }

    // MARK: キー配置

    private var keypadGrid: some View {
        VStack(spacing: keySpacing) {
            ForEach([["7", "8", "9"], ["4", "5", "6"], ["1", "2", "3"]], id: \.self) { row in
                HStack(spacing: keySpacing) {
                    ForEach(row, id: \.self) { digit in
                        digitKey(digit, key: .digit(digit))
                    }
                }
            }
            // 底行も他の行と同じ3分割にして、キーの大きさを揃える
            HStack(spacing: keySpacing) {
                digitKey("0", key: .digit("0"))
                digitKey("00", key: .doubleZero)
                deleteKey
            }
        }
    }

    /// 演算子は数字と取り違えないよう、右端へ1列にまとめる
    private var operatorColumn: some View {
        VStack(spacing: keySpacing) {
            ForEach(AZTenkeyOperator.allCases) { operation in
                operatorKey(operation)
            }
        }
    }

    // MARK: キー部品

    private var keyHeight: CGFloat { (isCompact ? 52 : 56) * uiScale }
    private var keyFont: Font { isCompact ? .title2.weight(.medium) : .title.weight(.medium) }

    private func digitKey(_ label: String, key: AZTenkeyKey) -> some View {
        Button {
            handleKey(key)
            AZTenkeyHaptics.tap()
        } label: {
            Text(label)
                .font(keyFont)
                .foregroundStyle(Color(.label))
                .frame(maxWidth: .infinity, minHeight: keyHeight)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(AZTenkeyKeyStyle())
    }

    private var deleteKey: some View {
        Button {
            handleKey(.delete)
            AZTenkeyHaptics.tap()
        } label: {
            Image(systemName: "delete.left")
                .font(isCompact ? .title3 : .title2)
                .foregroundStyle(Color(.label))
                .frame(maxWidth: .infinity, minHeight: keyHeight)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(AZTenkeyKeyStyle())
    }

    private func operatorKey(_ operation: AZTenkeyOperator) -> some View {
        let isSelected = pendingOperator == operation
        return Button {
            selectOperator(operation)
            AZTenkeyHaptics.tap()
        } label: {
            Text(operation.symbol)
                .font(isCompact ? .title2.weight(.semibold) : .title.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : Color.accentColor)
                .frame(width: keyHeight, height: keyHeight)
                .background(isSelected ? Color.accentColor : Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(AZTenkeyKeyStyle())
        .accessibilityLabel(Text(operation.symbol))
    }

    // MARK: ロジック

    private func handleKey(_ key: AZTenkeyKey) {
        switch key {
        case .digit(let d):   appendDigit(d)
        case .doubleZero:     appendDigit("00")
        case .delete:         deleteDigit()
        }
    }

    private func appendDigit(_ d: String) {
        errorKey = nil

        // プレースホルダー中は入力をリセットしてから1桁目を受け付ける
        if isPlaceholder {
            isPlaceholder = false
            inputStr = (d == "0" || d == "00") ? "" : d
            updateCalculationPreview()
            return
        }
        // "00" は "0" を2回追加
        if d == "00" {
            appendDigit("0")
            appendDigit("0")
            return
        }
        // 先頭ゼロを除去
        let newStr: String
        if inputStr.isEmpty || inputStr == "0" {
            newStr = d == "0" ? "" : d
        } else {
            newStr = inputStr + d
        }
        // 最大桁数制限（maxValue の桁数 + 1 まで許可してはみ出しを赤表示）。
        // 乗除算の右辺は金額ではなく倍率なので、桁数は別に抑える
        let maxDigits: Int
        if pendingOperator == .multiply || pendingOperator == .divide {
            maxDigits = 4
        } else {
            maxDigits = String(config.maxValue).count + 1
        }
        guard newStr.count <= maxDigits else { return }
        inputStr = newStr
        updateCalculationPreview()
    }

    private func deleteDigit() {
        errorKey = nil

        // プレースホルダー中は ⌫ でクリア（0 入力状態へ）
        if isPlaceholder {
            isPlaceholder = false
            inputStr = ""
            return
        }
        if !inputStr.isEmpty {
            inputStr.removeLast()
            updateCalculationPreview()
            return
        }
        // 右辺を消し終えた次のBSで演算子を外し、左辺を再編集できる形へ戻す。
        // 左辺は未丸めの途中結果なので、表示していた値と食い違わないよう
        // 選択中の丸め方法で確定してから入力欄へ戻す
        guard pendingOperator != nil, let left = accumulator else { return }
        pendingOperator = nil
        calculationResult = nil
        accumulator = nil
        let settled = rounding.roundToInt(left)
        inputStr = NSDecimalNumber(decimal: settled).stringValue
    }

    private func selectOperator(_ newOperator: AZTenkeyOperator) {
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
        inputStr = ""
    }

    private func updateCalculationPreview() {
        guard let left = accumulator,
              let pendingOperator,
              let right = enteredValue else {
            calculationResult = nil
            return
        }
        calculationResult = calculate(left, pendingOperator, right)
    }

    private func confirm() {
        // 式が途中なら、確定前に畳む
        if let left = accumulator,
           let pendingOperator,
           let right = enteredValue {
            guard let result = calculate(left, pendingOperator, right) else { return }
            calculationResult = result
        }
        guard canConfirm else { return }
        let n = max(config.minValue, min(config.maxValue, committedValue))
        // 閉じるかどうかは置いた側で決める（シートなら dismiss、埋め込みなら据え置き）
        config.onConfirm(n)
    }

    /// 計算規則は AZTenkeyCalculator に持たせ、ここでは結果を画面状態へ反映する
    private func calculate(
        _ left: Decimal,
        _ operation: AZTenkeyOperator,
        _ right: Decimal
    ) -> Decimal? {
        switch AZTenkeyCalculator.calculate(
            left, operation, right,
            minValue: config.minValue,
            maxValue: config.maxValue
        ) {
        case .success(let result):
            errorKey = nil
            return result
        case .failure(let error):
            errorKey = error.titleKey
            return nil
        }
    }

    /// 式の左辺に出す数値。
    /// 金額は内部では最小単位（セント等）の整数なので、式でも通貨の単位へ直して見せる。
    /// そうしないとドルなどで「7850000 ÷ 3」のような桁で出てしまう
    private func plainNumberText(_ value: Decimal) -> String {
        let scale = config.format.minorUnitScale
        let shown = scale == 1 ? value : value / Decimal(scale)

        // 端数があるときだけ小数を見せる。金額は通貨の小数桁も足して見る
        let baseDigits = config.format.fractionDigits
        let hasFraction = AZTenkeyRounding.down.roundToInt(value) != value
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = config.format.locale
        formatter.maximumFractionDigits = hasFraction ? baseDigits + 2 : baseDigits
        return formatter.string(from: shown as NSDecimalNumber) ?? "\(shown)"
    }

    /// 式の末尾に出す「= 結果」の数値。
    /// 丸める前の値なので、端数があるときは小数を見せて丸めとの差が分かるようにする
    private func resultNumberText(_ value: Decimal) -> String {
        let scale = config.format.minorUnitScale
        let shown = scale == 1 ? value : value / Decimal(scale)

        let baseDigits = config.format.fractionDigits
        let digits = needsRounding ? baseDigits + 1 : baseDigits
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = config.format.locale
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        return formatter.string(from: shown as NSDecimalNumber) ?? "\(shown)"
    }

    /// 式の右辺に出す数値。
    /// 乗除算の右辺は金額ではなく「何倍・何分割か」なので、通貨へ直さずそのまま見せる
    private func rightOperandText(_ value: Decimal) -> String {
        guard let pendingOperator else { return plainNumberText(value) }
        switch pendingOperator {
        case .multiply, .divide:
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.locale = config.format.locale
            formatter.maximumFractionDigits = 0
            return formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
        case .add, .subtract:
            return plainNumberText(value)
        }
    }
}
