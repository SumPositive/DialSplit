//
//  PanelView.swift
//  DialSplit
//
//  AZDialView のステッパー幅 94pt + spacing 12pt + dialWidth のため
//  2本横並びは ~400pt 超えでオーバーフローする。
//  → 縦積み（情報ヘッダー / 人数ダイアル / 金額ダイアル）レイアウトを採用。
//

import SwiftUI
import AZDial

// MARK: - 大富豪パネル（自動計算・切上表示）

struct Panel0View: View {
    let name: String
    @Binding var persons0: Int
    let split0: Int
    let status: Split0Status
    let totalRaw: Int

    private var amountColor: Color {
        switch status {
        case .exact:    return .yellow.opacity(0.95)
        case .rounded:  return Color(red: 0.45, green: 0.75, blue: 1.0)  // 青（切上）
        case .negative: return .red.opacity(0.9)
        }
    }

    private var statusLabel: String {
        switch status {
        case .exact:    return String(localized: "1人あたり")
        case .rounded:  return String(localized: "1人あたり（切上）")
        case .negative: return totalRaw <= 0
                        ? String(localized: "合計額を入力してください")
                        : String(localized: "金額が不足しています")
        }
    }

    var body: some View {
        BrassFrame {
            VStack(alignment: .leading, spacing: 8) {
                // 情報ヘッダー行
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.70))
                        Text(statusLabel)
                            .font(.caption2)
                            .foregroundStyle(amountColor.opacity(0.80))
                    }
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("¥")
                            .font(.callout)
                            .foregroundStyle(amountColor.opacity(0.8))
                        Text(totalRaw == 0 ? "---" : split0.formatted())
                            .font(.title2.bold().monospacedDigit())
                            .foregroundStyle(amountColor)
                            .shadow(color: .black.opacity(0.5), radius: 2)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                    }
                    Text("\(persons0)人")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.leading, 6)
                }

                // 人数ダイアル行
                dialRow(label: "人数") {
                    AZDialView(
                        value: $persons0,
                        min: 1, max: 99,
                        step: 1, stepperStep: 1,
                        style: .brass, dialWidth: 155
                    )
                }
            }
            .padding(12)
        }
    }
}

// MARK: - 富豪/平民パネル（人数 + 金額 ダイアル）

struct PanelSubView: View {
    let name: String
    @Binding var persons: Int
    @Binding var split: Int
    let dialUnit: Int

    var body: some View {
        BrassFrame {
            VStack(alignment: .leading, spacing: 8) {
                // 情報ヘッダー行
                HStack(alignment: .center) {
                    Text(name)
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.70))
                    Spacer()
                    if persons == 0 {
                        Text("0人（対象外）")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.35))
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text("¥")
                                .font(.caption)
                                .foregroundStyle(.yellow.opacity(0.7))
                            Text(split.formatted())
                                .font(.title3.bold().monospacedDigit())
                                .foregroundStyle(.yellow.opacity(0.85))
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                        }
                        Text("\(persons)人")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.55))
                            .padding(.leading, 6)
                    }
                }

                // 人数ダイアル行
                dialRow(label: "人数") {
                    AZDialView(
                        value: $persons,
                        min: 0, max: 99,
                        step: 1, stepperStep: 1,
                        style: .brass, dialWidth: 155
                    )
                }

                // 金額ダイアル行
                dialRow(label: "金額") {
                    AZDialView(
                        value: $split,
                        min: 0, max: 100_000,
                        step: dialUnit, stepperStep: dialUnit,
                        style: .brass, dialWidth: 155
                    )
                }
            }
            .padding(12)
            .opacity(persons == 0 ? 0.45 : 1.0)
            .animation(.easeInOut(duration: 0.3), value: persons == 0)
        }
    }
}

// MARK: - ダイアル行ヘルパー

/// ラベル（28pt幅）+ AZDialView の1行レイアウト
/// AZDialView は .frame(maxWidth:.infinity, alignment:.trailing) を内部で持つため
/// 残り幅に収まりラベルと干渉しない
@ViewBuilder
private func dialRow<D: View>(label: String, @ViewBuilder dial: () -> D) -> some View {
    HStack(spacing: 4) {
        Text(label)
            .font(.system(size: 10))
            .foregroundStyle(.white.opacity(0.40))
            .frame(width: 28, alignment: .leading)
        dial()
    }
}
