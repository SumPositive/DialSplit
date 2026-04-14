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
//  人数列: PERSONS_COL_W = 96pt
//  名称列: NAME_W = 110pt（固定）→ 金額桁数に関係なく位置が変わらない
//  金額:   Spacer() で右端に固定、fixedSize() で自然幅
//  H_PAD:  16pt（人数の左マージンを確保）
//
//  Panel0View（A）: 右列ダイアルは読み取り専用（.allowsHitTesting(false)）
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

private let PERSONS_COL_W: CGFloat = 115   // 人数列幅（×1.2 拡大）
private let NAME_W:        CGFloat = 110   // 名称列幅（固定 → 位置が金額桁数で動かない）
private let H_PAD:         CGFloat = 16    // 左右パディング（人数の左マージンを確保）
private let H_GAP:         CGFloat = 8     // 列間スペーシング

// MARK: - カラーテーマ

private struct PanelColors {
    let primary:   Color   // パネル名
    let secondary: Color   // 人数・サブラベル
    let accent:    Color   // 金額強調

    static func make(_ cs: ColorScheme) -> PanelColors {
        cs == .dark
            ? PanelColors(
                primary:   .white,
                secondary: .white.opacity(0.50),
                accent:    .yellow.opacity(0.95)
              )
            : PanelColors(
                primary:   Color(.label),
                secondary: Color(.secondaryLabel),
                accent:    Color(red: 0.50, green: 0.35, blue: 0.00)
              )
    }
}

// MARK: - 大富豪（A）パネル — 人数ダイアル + 自動計算金額（読み取り専用ダイアル）

struct Panel0View: View {
    let name: String
    @Binding var persons0: Int
    @Binding var split0: Int
    let canEditA: Bool
    let dialUnit: Int
    let status: Split0Status
    let totalRaw: Int

    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var cs
    @State private var numpadConfig: NumpadConfig?

    private var colors: PanelColors { .make(cs) }

    private var amountColor: Color {
        switch status {
        case .exact:
            return cs == .dark ? .yellow.opacity(0.95)
                               : Color(red: 0.50, green: 0.35, blue: 0.00)
        case .rounded:
            return cs == .dark ? Color(red: 0.45, green: 0.75, blue: 1.00)
                               : Color(red: 0.10, green: 0.45, blue: 0.80)
        case .negative:
            return .red.opacity(cs == .dark ? 0.90 : 0.80)
        }
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

                // ダイアル行: 人数（左）+ 自動計算金額・読み取り専用（右）
                HStack(spacing: H_GAP) {
                    AZDialView(
                        value: $persons0,
                        min: 1, max: 99,
                        step: 1, stepperStep: 0,
                        style: settings.dialStyle,
                        dialWidth: PERSONS_COL_W
                    )
                    .frame(width: PERSONS_COL_W)

                    // canEditA のときインタラクティブ、そうでなければ表示専用
                    AZDialView(
                        value: Binding(
                            get: { max(0, split0) },
                            set: { if canEditA { split0 = $0 } }
                        ),
                        min: 0, max: 999_900,
                        step: dialUnit, stepperStep: 0,
                        style: settings.dialStyle,
                        dialWidth: 200
                    )
                    .frame(maxWidth: .infinity)
                    .allowsHitTesting(canEditA)
                }
                .padding(.horizontal, H_PAD)
                .padding(.vertical, 8)
            }
        }
        .sheet(item: $numpadConfig) { NumpadView(config: $0) }
    }

    @ViewBuilder private var infoRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: H_GAP) {
            // 人数（左固定）— タップでテンキー
            Text(localizedPeopleCompact(persons0))
                .font(.title.bold().monospacedDigit())
                .foregroundStyle(colors.secondary)
                .lineLimit(1)
                .frame(width: PERSONS_COL_W/3*2, alignment: .trailing)
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
                .frame(width: NAME_W, alignment: .center)

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
            .fixedSize()
            .overlay(alignment: .bottomTrailing) {
                if status == .rounded {
                    Text("端数切り上げ")
                        .font(.caption2.bold())
                        .foregroundStyle(amountColor)
                        .fixedSize()
                        .offset(y: -30)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard canEditA else { return }
                numpadConfig = NumpadConfig(
                    title: localizedNamedTitle("金額（%@）", name),
                    initialValue: split0,
                    maxValue: 999_900,
                    minValue: 0,
                    isAmount: true,
                    onConfirm: { split0 = $0 }
                )
            }

            Spacer(minLength: 16)
        }
    }
}

// MARK: - 富豪/平民/貧民（B/C/D）パネル — 人数ダイアル + 金額ダイアル

struct PanelSubView: View {
    let name: String
    @Binding var persons: Int
    @Binding var split: Int
    let dialUnit: Int

    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var cs
    @State private var numpadConfig: NumpadConfig?

    private var colors: PanelColors { .make(cs) }

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
                HStack(spacing: H_GAP) {
                    AZDialView(
                        value: $persons,
                        min: 0, max: 99,
                        step: 1, stepperStep: 0,
                        style: settings.dialStyle,
                        dialWidth: PERSONS_COL_W
                    )
                    .frame(width: PERSONS_COL_W)

                    AZDialView(
                        value: $split,
                        min: 0, max: 999_900,
                        step: dialUnit, stepperStep: 0,
                        style: settings.dialStyle,
                        dialWidth: 200
                    )
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, H_PAD)
                .padding(.vertical, 8)
            }
        }
        .sheet(item: $numpadConfig) { NumpadView(config: $0) }
    }

    @ViewBuilder private var infoRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: H_GAP) {
            // 人数（左固定）— タップでテンキー
            Text(localizedPeopleCompact(persons))
                .font(.title.bold().monospacedDigit())
                .foregroundStyle(colors.secondary)
                .lineLimit(1)
                .frame(width: PERSONS_COL_W/3*2, alignment: .trailing)
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
                .frame(width: NAME_W, alignment: .center)

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
            .fixedSize()
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

            Spacer(minLength: 16)
        }
    }
}
