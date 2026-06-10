//
//  PanelView.swift
//  DialSplit
//
//  全パネル共通レイアウト:
//  ┌──────────────────────────────────────────────┐
//  │  [xx人]   [  区分名(固定)  ]       [¥999,999]│ ← 情報行
//  ├──────────────────────────────────────────────┤
//  │  [人数Dal] [======= 金額Dal(220pt) =========]│ ← ダイアル行
//  └──────────────────────────────────────────────┘
//
//  列幅は panelWidth から動的算出（SE〜Pro Max まで対応）
//  H_PAD:  16pt（人数の左マージンを確保）
//
//  Panel0View（A）: 人数のみダイアル操作（A金額は表示専用）
//  PanelSubView（B/C/D）: 右列ダイアルは通常のインタラクティブ
//
//  テンキー: 人数・金額テキストをタップすると NumpadView がポップアップ
//

import SwiftUI
import AZDial

private func localizedPeopleCompact(_ count: Int) -> String {
    let format = NSLocalizedString("format.people.long", comment: "")
    return String(format: format, locale: Locale.current, count)
}

private func localizedPeopleTitle(_ name: String) -> String {
    let format = NSLocalizedString("format.people.title", comment: "")
    return String(format: format, locale: Locale.current, name)
}

private func localizedAmountTitle(_ name: String) -> String {
    let format = NSLocalizedString("format.amount.title", comment: "")
    return String(format: format, locale: Locale.current, name)
}

private func localizedAmount(_ value: Int, placeholder: String = "---") -> String {
    MoneyFormat.localizedAmount(value, placeholder: placeholder)
}

// MARK: - レイアウト定数

private let H_PAD:         CGFloat = 16    // 左右パディング（人数の左マージンを確保）
private let H_GAP:         CGFloat = 8     // 列間スペーシング
private let DIAL_MIN_GAP:  CGFloat = 32    // 人数ダイアルと金額ダイアルの最小間隔

private struct PanelLayout {
    let personsDialW: CGFloat
    let amountDialW: CGFloat
    let personsTextW: CGFloat
    let nameW: CGFloat
    let amountTextW: CGFloat

    static func make(panelWidth: CGFloat) -> PanelLayout {
        let inner = max(220, panelWidth - H_PAD * 2)
        let personsDialW = min(115, max(84, inner * 0.32))
        let amountDialW = max(96, inner - personsDialW - DIAL_MIN_GAP)

        // 2桁人数（例：99人 / 12p）が .title.bold() で欠けない幅を確保
        let personsTextW = min(88, max(72, personsDialW * 0.78))
        let nameW = min(110, max(62, inner * 0.26))
        let amountTextW = max(88, inner - personsTextW - nameW - (H_GAP * 3 + 4))

        return PanelLayout(
            personsDialW: personsDialW,
            amountDialW: amountDialW,
            personsTextW: personsTextW,
            nameW: nameW,
            amountTextW: amountTextW
        )
    }
}

// MARK: - カラーテーマ

private struct PanelColors {
    let primary:   Color   // パネル名
    let secondary: Color   // 人数・サブラベル
    let accent:    Color   // 金額強調

    static func make(_ cs: ColorScheme, textHue: Int, textTone: Int) -> PanelColors {
        let linked = linkedTextColor(hue: textHue, tone: textTone, for: cs)
        return PanelColors(
            // 区分名は「合計」ラベルと同等の濃淡へ
            primary: cs == .dark ? .white.opacity(0.62) : Color(.secondaryLabel),
            secondary: linked.opacity(cs == .dark ? 0.62 : 0.72),
            accent: linked
        )
    }
}

// MARK: - 大富豪（A）パネル — 人数ダイアル + 自動計算金額（読み取り専用ダイアル）

struct Panel0View: View {
    let name: String
    @Binding var persons0: Int
    let split0: Int
    let split0RealMinor: Double
    let status: Split0Status
    let totalRaw: Int
    let panelWidth: CGFloat
    let isPeopleLocked: Bool
    @Binding var isAllLocked: Bool

    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var cs
    @State private var numpadConfig: NumpadConfig?

    private var colors: PanelColors { .make(cs, textHue: settings.textHue, textTone: settings.textTone) }
    private var layout: PanelLayout { .make(panelWidth: panelWidth) }

    private var amountColor: Color {
        status == .negative ? .red : colors.accent
    }

    var body: some View {
        BrassFrame {
            VStack(spacing: 0) {
                // 情報行
                infoRow
                    .padding(.horizontal, H_PAD)
                    .padding(.top, 16)
                    .padding(.bottom, 4)

                LeatherDivider()

                // ダイアル行: 人数（左）のみ（A金額は表示専用）
                HStack(spacing: H_GAP) {
                    AZDialView(
                        value: $persons0,
                        min: 1, max: 99,
                        step: 1,
                        stepperStep: settings.showDialStepper ? 1 : 0,
                        stepperPosition: .bottom,
                        style: settings.dialStyle,
                        dialWidth: layout.personsDialW,
                        tuning: settings.dialTuning
                    )
                    .frame(width: layout.personsDialW)
                    .allowsHitTesting(!isPeopleLocked)
                    .opacity(isPeopleLocked ? 0.45 : 1)
                    Spacer(minLength: 0)
                    LockToggleButton(
                        isLocked: $isAllLocked,
                        lockedSystemImage: "lock.badge.checkmark.fill",
                        unlockedSystemImage: "lock.open.fill",
                        accessibilityLabel: String(localized: "lock.allControls"),
                        size: 44,
                        symbolSize: 28,
                        onToggle: { locked in
                            Telemetry.event(.allLockToggled(locked: locked))
                        }
                    )
                    .frame(width: layout.amountTextW, height: 44, alignment: .center)
                }
                .padding(.horizontal, H_PAD)
                .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .sheet(item: $numpadConfig) { NumpadView(config: $0) }
    }

    @ViewBuilder private var infoRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: H_GAP) {
            // 人数（左固定）— タップでテンキー
            Text(localizedPeopleCompact(persons0))
                .font(.title.bold().monospacedDigit())
                .foregroundStyle(colors.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: layout.personsTextW, alignment: .trailing)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !isPeopleLocked else { return }
                    numpadConfig = NumpadConfig(
                        title: localizedPeopleTitle(name),
                        initialValue: persons0,
                        maxValue: 99,
                        minValue: 1,
                        isAmount: false,
                        onConfirm: { persons0 = $0 }
                    )
                }

            // 名称（固定幅）
            Text(name)
                .font(.subheadline.bold())
                .foregroundStyle(colors.primary)
                .lineLimit(1)
                .frame(width: layout.nameW, alignment: .center)

            // 金額（残り全幅・右端揃え）— 端数発生時は1桁追加表示（追加分を赤字）
            Text(attributedAmount)
                .font(.title.bold().monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    /// 金額の表示テキスト：切上時は追加桁を赤字で結合した AttributedString
    private var attributedAmount: AttributedString {
        if totalRaw == 0 {
            var attr = AttributedString(localizedAmount(0))
            attr.foregroundColor = colors.secondary
            return attr
        }
        if status == .rounded {
            let r = MoneyFormat.extendedTruncated(realMinor: split0RealMinor)
            var main = AttributedString(r.main)
            main.foregroundColor = amountColor
            var extra = AttributedString(r.extra)
            extra.foregroundColor = Color(red: 0.95, green: 0.45, blue: 0.05)
            return main + extra
        }
        var attr = AttributedString(localizedAmount(split0))
        attr.foregroundColor = amountColor
        return attr
    }
}

// MARK: - 富豪/平民/貧民（B/C/D）パネル — 人数ダイアル + 金額ダイアル

struct PanelSubView: View {
    let name: String
    @Binding var persons: Int
    @Binding var split: Int
    let dialUnit: Int
    let panelWidth: CGFloat
    let isPeopleLocked: Bool
    let isAmountLocked: Bool

    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var cs
    @State private var numpadConfig: NumpadConfig?

    private var colors: PanelColors { .make(cs, textHue: settings.textHue, textTone: settings.textTone) }
    private var layout: PanelLayout { .make(panelWidth: panelWidth) }

    var body: some View {
        BrassFrame {
            VStack(spacing: 0) {
                // 情報行
                infoRow
                    .padding(.horizontal, H_PAD)
                    .padding(.top, persons > 0 ? 16 : 6)
                    .padding(.bottom, persons > 0 ? 4 : 6)

                if persons > 0 {
                    LeatherDivider()

                    // ダイアル行: 人数（左）+ 金額（右）
                    HStack(alignment: .top, spacing: DIAL_MIN_GAP) {
                        AZDialView(
                            value: $persons,
                            min: 0, max: 99,
                            step: 1,
                            stepperStep: settings.showDialStepper ? 1 : 0,
                            stepperPosition: .bottom,
                            style: settings.dialStyle,
                            dialWidth: layout.personsDialW,
                            tuning: settings.dialTuning
                        )
                        .frame(width: layout.personsDialW)
                        .allowsHitTesting(!isPeopleLocked)
                        .opacity(isPeopleLocked ? 0.45 : 1)

                        AZDialView(
                            value: $split,
                            min: 0, max: MoneyFormat.maxMinorValue,
                            step: dialUnit,
                            stepperStep: settings.showDialStepper ? dialUnit : 0,
                            stepperPosition: .bottom,
                            style: settings.dialStyle,
                            dialWidth: layout.amountDialW,
                            tuning: settings.dialTuning
                        )
                        .frame(maxWidth: .infinity)
                        .allowsHitTesting(!isAmountLocked)
                        .opacity(isAmountLocked ? 0.45 : 1)
                    }
                    .padding(.horizontal, H_PAD)
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .sheet(item: $numpadConfig) { NumpadView(config: $0) }
    }

    @ViewBuilder private var infoRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: H_GAP) {
            // 人数（左固定）— タップでテンキー
            Text(localizedPeopleCompact(persons))
                .font(.title.bold().monospacedDigit())
                .foregroundStyle(colors.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: layout.personsTextW, alignment: .trailing)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !isPeopleLocked else { return }
                    numpadConfig = NumpadConfig(
                        title: localizedPeopleTitle(name),
                        initialValue: persons,
                        maxValue: 99,
                        minValue: 0,
                        isAmount: false,
                        onConfirm: { persons = $0 }
                    )
                }

            // 名称（固定幅 → 位置が変わらない）
            Text(name)
                .font(.subheadline.bold())
                .foregroundStyle(colors.primary)
                .lineLimit(1)
                .frame(width: layout.nameW, alignment: .center)

            // 柔軟スペーサー（名称と金額の間）
            Spacer(minLength: 4)

            if persons > 0 {
                // 金額（右端に固定）— タップでテンキー
                Text(localizedAmount(split))
                    .font(.title.bold().monospacedDigit())
                    .foregroundStyle(colors.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .frame(width: layout.amountTextW, alignment: .trailing)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !isAmountLocked else { return }
                        numpadConfig = NumpadConfig(
                            title: localizedAmountTitle(name),
                            initialValue: split,
                            maxValue: MoneyFormat.maxMinorValue,
                            minValue: 0,
                            isAmount: true,
                            onConfirm: { split = $0 }
                        )
                    }
            } else {
                // OFF スイッチ — タップで人数を1に戻してパネルを展開
                Toggle("", isOn: Binding(
                    get: { persons > 0 },
                    set: { newValue in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            persons = newValue ? 1 : 0
                        }
                    }
                ))
                .labelsHidden()
                .scaleEffect(0.85)
                // テキストの baseline ≒ height * 0.78 に合わせる
                .alignmentGuide(.firstTextBaseline) { d in d.height * 0.78 }
                .frame(width: layout.amountTextW, alignment: .trailing)
                .disabled(isPeopleLocked || isAmountLocked)
                .opacity((isPeopleLocked || isAmountLocked) ? 0.45 : 1)
            }

        }
    }
}
