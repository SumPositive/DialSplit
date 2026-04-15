//
//  PanelView.swift
//  DialSplit
//
//  全パネル共通レイアウト:
//  ┌──────────────────────────────────────────────┐
//  │  [xx人]   [  パネル名(固定)  ]     [¥999,999]│ ← 情報行
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

private func isEnglishUI() -> Bool {
    Locale.preferredLanguages.first?.hasPrefix("en") == true
}

private func localizedPeopleCompact(_ count: Int) -> String {
    let format = NSLocalizedString("%lld人短", comment: "")
    return String(format: format, locale: Locale.current, count)
}

private func localizedNamedTitle(_ formatKey: String, _ name: String) -> String {
    let format = NSLocalizedString(formatKey, comment: "")
    return String(format: format, locale: Locale.current, name)
}

private func localizedAmount(_ value: Int, placeholder: String = "---") -> String {
    if value == 0 { return placeholder }
    if isEnglishUI() { return "$\(value.formatted())" }
    return "¥\(value.formatted())"
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

        let personsTextW = min(76, max(52, personsDialW * 0.66))
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
    let status: Split0Status
    let totalRaw: Int
    let panelWidth: CGFloat

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
                        step: 1, stepperStep: 0,
                        style: settings.dialStyle,
                        dialWidth: layout.personsDialW
                    )
                    .frame(width: layout.personsDialW)
                    Spacer(minLength: 0)
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
                .frame(width: layout.personsTextW, alignment: .trailing)
                .contentShape(Rectangle())
                .onTapGesture {
                    numpadConfig = NumpadConfig(
                        title: localizedNamedTitle("人数（%@）", name),
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

            // 柔軟スペーサー
            Spacer(minLength: 4)

            // 金額（右端固定）— 端数切り上げラベルを上に overlay
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(localizedAmount(totalRaw == 0 ? 0 : split0))
                    .font(.title.bold().monospacedDigit())
                if isEnglishUI() && totalRaw > 0 {
                    Text(".00")
                        .font(.caption.bold().monospacedDigit())
                }
            }
            .foregroundStyle(totalRaw == 0 ? colors.secondary : amountColor)
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .frame(width: layout.amountTextW, alignment: .trailing)
            .overlay(alignment: .bottomTrailing) {
                if status == .rounded {
                    Text("端数切り上げ")
                        .font(.caption2.bold())
                        .foregroundStyle(amountColor)
                        .fixedSize()
                        .offset(y: -30)
                }
            }

        }
    }
}

// MARK: - 富豪/平民/貧民（B/C/D）パネル — 人数ダイアル + 金額ダイアル

struct PanelSubView: View {
    let name: String
    @Binding var persons: Int
    @Binding var split: Int
    let dialUnit: Int
    let panelWidth: CGFloat

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
                    .padding(.top, 16)
                    .padding(.bottom, 4)

                LeatherDivider()

                // ダイアル行: 人数（左）+ 金額（右）
                HStack(spacing: DIAL_MIN_GAP) {
                    AZDialView(
                        value: $persons,
                        min: 0, max: 99,
                        step: 1, stepperStep: 0,
                        style: settings.dialStyle,
                        dialWidth: layout.personsDialW
                    )
                    .frame(width: layout.personsDialW)

                    AZDialView(
                        value: $split,
                        min: 0, max: 999_900,
                        step: dialUnit, stepperStep: 0,
                        style: settings.dialStyle,
                        dialWidth: layout.amountDialW
                    )
                    .frame(maxWidth: .infinity)
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
            Text(localizedPeopleCompact(persons))
                .font(.title.bold().monospacedDigit())
                .foregroundStyle(colors.secondary)
                .lineLimit(1)
                .frame(width: layout.personsTextW, alignment: .trailing)
                .contentShape(Rectangle())
                .onTapGesture {
                    numpadConfig = NumpadConfig(
                        title: localizedNamedTitle("人数（%@）", name),
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

            // 金額（右端に固定）— 人数>0 のときタップでテンキー
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(persons == 0 ? "---" : localizedAmount(split))
                    .font(.title.bold().monospacedDigit())
                if isEnglishUI() && persons > 0 {
                    Text(".00")
                        .font(.caption.bold().monospacedDigit())
                }
            }
            .foregroundStyle(persons == 0 ? colors.secondary : colors.accent)
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .frame(width: layout.amountTextW, alignment: .trailing)
            .contentShape(Rectangle())
            .onTapGesture {
                guard persons > 0 else { return }
                numpadConfig = NumpadConfig(
                    title: localizedNamedTitle("金額（%@）", name),
                    initialValue: split,
                    maxValue: 999_900,
                    minValue: 0,
                    isAmount: true,
                    onConfirm: { split = $0 }
                )
            }

        }
    }
}
