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

// MARK: - レイアウト定数

private let PERSONS_COL_W: CGFloat = 96    // 人数列幅（×1.2 拡大）
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
    let split0: Int
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
                    .padding(.vertical, 9)

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

                    // split0 を視覚的に表示するだけ（操作不可）
                    AZDialView(
                        value: Binding(get: { max(0, split0) }, set: { _ in }),
                        min: 0, max: 999_900,
                        step: 100, stepperStep: 0,
                        style: settings.dialStyle,
                        dialWidth: 220
                    )
                    .frame(maxWidth: .infinity)
                    .allowsHitTesting(false)
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
            Text("\(persons0)人")
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(colors.secondary)
                .lineLimit(1)
                .frame(width: PERSONS_COL_W, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    numpadConfig = NumpadConfig(
                        title: "人数（\(name)）",
                        initialValue: persons0,
                        maxValue: 99,
                        minValue: 1,
                        step: 1,
                        isAmount: false,
                        onConfirm: { persons0 = $0 }
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

            // 金額（右端に固定・自動計算のためタップ不可）
            Text(totalRaw == 0 ? "---" : "¥\(split0.formatted())")
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(totalRaw == 0 ? colors.secondary : amountColor)
                .lineLimit(1)
                .fixedSize()
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
                    .padding(.vertical, 9)

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
                        dialWidth: 220
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
            Text("\(persons)人")
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(colors.secondary)
                .lineLimit(1)
                .frame(width: PERSONS_COL_W, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    numpadConfig = NumpadConfig(
                        title: "人数（\(name)）",
                        initialValue: persons,
                        maxValue: 99,
                        minValue: 0,
                        step: 1,
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
            Text(persons == 0 ? "---" : "¥\(split.formatted())")
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(persons == 0 ? colors.secondary : colors.accent)
                .lineLimit(1)
                .fixedSize()
                .contentShape(Rectangle())
                .onTapGesture {
                    guard persons > 0 else { return }
                    numpadConfig = NumpadConfig(
                        title: "金額（\(name)）",
                        initialValue: split,
                        maxValue: 999_900,
                        minValue: 0,
                        step: dialUnit,
                        isAmount: true,
                        onConfirm: { split = $0 }
                    )
                }
        }
    }
}
