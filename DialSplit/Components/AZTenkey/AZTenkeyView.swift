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

    /// 入力の状態遷移は View から切り離してある（AZTenkeyInput で単体検証できる）
    @State private var input: AZTenkeyInput
    @State private var isRoundingExpanded = false

    /// 丸め方法の保存先。アプリ側の設定キーとぶつかる時はここだけ変える
    static let roundingStorageKey = "azTenkey.rounding"

    /// 丸め方法はシートを閉じても選んだものを引き継ぐ。既定は四捨五入
    @AppStorage(AZTenkeyView.roundingStorageKey) private var rounding: AZTenkeyRounding = .halfUp

    init(config: AZTenkeyConfig) {
        self.config = config
        _input = State(initialValue: AZTenkeyInput(
            initialValue: config.initialValue,
            minValue: config.minValue,
            maxValue: config.maxValue
        ))
    }

    // MARK: 寸法

    /// 縦に余裕のない端末では、キーと余白を一段詰める
    static var isCompactScreen: Bool { UIScreen.main.bounds.height <= 700 }

    private var isCompact: Bool { Self.isCompactScreen }

    /// 文字サイズ設定に応じた寸法の倍率。
    /// キーの高さや余白は Font のように自動では伸びないので、ここで掛ける。
    /// アクセシビリティサイズまで素直に追うとテンキーが画面へ収まらなくなるため、
    /// 伸びしろは頭打ちにしている
    static func uiScale(for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small, .medium:      return 0.95
        case .large:                        return 1.0
        case .xLarge:                       return 1.06
        case .xxLarge:                      return 1.12
        case .xxxLarge:                     return 1.18
        default:                            return 1.26   // アクセシビリティサイズ
        }
    }

    private var uiScale: CGFloat { Self.uiScale(for: dynamicTypeSize) }

    /// 金額表示だけは伸びを抑える。大きく出したいが、行から溢れさせたくない
    private var displayScale: CGFloat { min(uiScale, 1.12) }

    private var keySpacing: CGFloat { (isCompact ? 8 : 10) * uiScale }
    private var sheetSpacing: CGFloat { (isCompact ? 10 : 14) * uiScale }
    private var displayFontSize: CGFloat { (isCompact ? 48 : 56) * displayScale }
    private var checkmarkSize: CGFloat { (isCompact ? 34 : 38) * displayScale }
    /// 式と丸めを並べた1行の高さ。背の高い方（title3 の行高）で決まる
    private var statusRowHeight: CGFloat { 26 * uiScale }

    /// テンキーの高さ。寸法の組み立てはここ1箇所にまとめる。
    ///
    /// シートに載せる側は、最初のレイアウト計測が終わる前でもこれを呼んで
    /// 初期の detent を決められる（0 で開くと一瞬つぶれて見えるため）。
    /// - Parameter hasStatusRow: 計算式か、エラーの行が出ているか
    static func height(
        dynamicTypeSize: DynamicTypeSize,
        isCompact: Bool,
        hasStatusRow: Bool
    ) -> CGFloat {
        let scale = uiScale(for: dynamicTypeSize)
        let displayScale = min(scale, 1.12)

        let top: CGFloat = 8 * scale
        let amountRow = (isCompact ? 48 : 56) * displayScale * 1.25 + 8
        let keyHeight = (isCompact ? 52 : 56) * scale
        let keySpacing = (isCompact ? 8 : 10) * scale
        let sheetSpacing = (isCompact ? 10 : 14) * scale
        let bottom: CGFloat = 12 * scale

        // この View 自身の高さだけを返す。ナビゲーションバーは載せる側が足す
        var height = top + amountRow + sheetSpacing + (keyHeight * 4 + keySpacing * 3) + bottom
        // 式と丸めは同じ行に並ぶので、増えるのは1行ぶんだけ
        if hasStatusRow {
            height += sheetSpacing + 26 * scale
        }
        return height
    }

    /// いまの状態で必要な高さ。`AZTenkeyHeightKey` で親へも伝えている
    var preferredHeight: CGFloat {
        Self.height(
            dynamicTypeSize: dynamicTypeSize,
            isCompact: isCompact,
            hasStatusRow: errorKey != nil || expressionText != nil
        )
    }

    // MARK: 計算プロパティ

    private var activeValue: Decimal { input.activeValue }
    private var needsRounding: Bool { input.needsRounding }
    private var isPristine: Bool { input.isPristine }
    private var isOutOfRange: Bool { input.isOutOfRange(rounding: rounding) }
    private var errorKey: String? { input.errorKey }
    private var pendingOperator: AZTenkeyOperator? { input.pendingOperator }

    private var displayText: String {
        config.format.display(input.committedValue(rounding: rounding))
    }

    private var displayColor: Color {
        if isOutOfRange { return .red }
        if isPristine { return Color(.tertiaryLabel) }
        return Color(.label)
    }

    private var canConfirm: Bool { input.canConfirm(rounding: rounding) }

    /// 確定アイコンの色。
    /// まだ何も入力していない間は淡くして、値を変えていないことを示す。
    /// ただし押せば初期値のまま確定できるので、タップ自体は有効に保つ
    private var checkmarkColor: Color {
        guard canConfirm, !isPristine else { return Color(.tertiaryLabel) }
        return Color.accentColor
    }

    /// 「78,500 ÷ 3」のような途中式。左辺が無ければ出さない
    private var expressionText: String? {
        guard let accumulator = input.accumulator, let pendingOperator else { return nil }
        let left = plainNumberText(accumulator)
        guard let entered = input.enteredValue else { return "\(left) \(pendingOperator.symbol)" }
        return "\(left) \(pendingOperator.symbol) \(rightOperandText(entered))"
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
            guard input.calculationResult != nil else { return "" }
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

    /// ⌫ と演算子キーの地。
    ///
    /// tertiarySystemGroupedBackground はライトだと地の
    /// systemGroupedBackground と同じ色になり、キーの輪郭が消えてしまう。
    /// ライトでは数字キー（白）より一段暗く、ダークでは地より一段明るい灰を
    /// 明示して、どちらのモードでもキーとして見えるようにする
    private var subKeyBackground: Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(white: 0.22, alpha: 1)
                : UIColor(white: 0.88, alpha: 1)
        })
    }

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
                .background(subKeyBackground)
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
                .background(isSelected ? Color.accentColor : subKeyBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(AZTenkeyKeyStyle())
        .accessibilityLabel(Text(operation.symbol))
    }

    // MARK: ロジック

    private func handleKey(_ key: AZTenkeyKey) {
        input.handle(key, rounding: rounding)
    }

    private func selectOperator(_ newOperator: AZTenkeyOperator) {
        input.selectOperator(newOperator)
    }

    private func confirm() {
        // 式が途中なら、確定前に畳む
        guard input.finalizeExpression() else { return }
        guard input.canConfirm(rounding: rounding) else { return }
        // 閉じるかどうかは置いた側で決める（シートなら dismiss、埋め込みなら据え置き）
        config.onConfirm(input.clampedValue(rounding: rounding))
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
