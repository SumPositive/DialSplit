//
//  NumpadView.swift
//  DialSplit
//
//  テンキー入力シート
//  .sheet(item: $numpadConfig) { NumpadView(config: $0) } で呼び出す
//
//  初期値はプレースホルダー表示（薄いカラー）。
//  数字キーを押した瞬間にクリアされ、1桁目から入力開始。
//
//  レイアウト:
//  ┌─────────────────────────┐
//  │  7  │  8  │  9          │
//  │  4  │  5  │  6          │
//  │  1  │  2  │  3          │
//  │  ⌫  │  0  │  00         │
//  │        完 了             │  ← 全幅
//  └─────────────────────────┘
//

import SwiftUI
import UIKit

private func isEnglishUI() -> Bool {
    Locale.preferredLanguages.first?.hasPrefix("en") == true
}

private func localizedAmountText(_ value: Int) -> String {
    if isEnglishUI() {
        return "$ \(value.formatted()).00"
    }
    return "¥ \(value.formatted())"
}

// MARK: - ハプティクス

@MainActor
private func selectionHaptic() {
    UISelectionFeedbackGenerator().selectionChanged()
}

// MARK: - 設定 (Identifiable で sheet(item:) に使用)

struct NumpadConfig: Identifiable {
    let id = UUID()
    let title: String
    let initialValue: Int
    let maxValue: Int
    let minValue: Int
    let isAmount: Bool   // true → "¥" 表示
    let onConfirm: (Int) -> Void
}

// MARK: - テンキービュー

struct NumpadView: View {
    let config: NumpadConfig

    @Environment(\.dismiss) private var dismiss
    @State private var inputStr: String = ""
    @State private var isPlaceholder: Bool = true   // true = 初期値をプレースホルダー表示中

    init(config: NumpadConfig) {
        self.config = config
    }

    // MARK: 計算プロパティ

    /// 実際の入力値（プレースホルダー中は initialValue を返す）
    private var currentInt: Int {
        isPlaceholder ? config.initialValue : (Int(inputStr) ?? 0)
    }

    private var isOverMax: Bool { !isPlaceholder && currentInt > config.maxValue }

    private var displayText: String {
        let n = currentInt
        if isPlaceholder {
            return config.isAmount ? localizedAmountText(n) : "\(n)"
        }
        guard !inputStr.isEmpty else {
            return config.isAmount ? localizedAmountText(0) : "0"
        }
        return config.isAmount ? localizedAmountText(n) : "\(n)"
    }

    private var displayAmountMainText: String {
        let n = currentInt
        if isEnglishUI() {
            return "$ \(n.formatted())"
        }
        return "¥ \(n.formatted())"
    }

    private var displayColorStyle: AnyShapeStyle {
        if isOverMax { return AnyShapeStyle(.red) }
        if isPlaceholder { return AnyShapeStyle(.tertiary) }
        return AnyShapeStyle(.primary)
    }

    private var canConfirm: Bool {
        currentInt >= config.minValue && !isOverMax
    }

    // MARK: ビュー

    var body: some View {
        VStack(spacing: 0) {

            // ヘッダー
            HStack {
                Text(config.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 4)

            // 入力値表示（プレースホルダー中は薄く表示）
            Group {
                if config.isAmount && isEnglishUI() {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text(displayAmountMainText)
                            .font(.system(size: 42, weight: .bold, design: .monospaced))
                        Text(".00")
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(displayColorStyle)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                } else {
                    Text(displayText)
                        .font(.system(size: 42, weight: .bold, design: .monospaced))
                        .foregroundStyle(displayColorStyle)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            Divider()

            // テンキーグリッド（7〜3 + ⌫/0/00）
            Grid(horizontalSpacing: 1, verticalSpacing: 1) {
                GridRow {
                    digitKey("7"); digitKey("8"); digitKey("9")
                }
                GridRow {
                    digitKey("4"); digitKey("5"); digitKey("6")
                }
                GridRow {
                    digitKey("1"); digitKey("2"); digitKey("3")
                }
                GridRow {
                    actionKey(
                        icon: "delete.left",
                        color: .primary,
                        background: Color(.tertiarySystemBackground)
                    ) { deleteDigit() }

                    digitKey("0")
                    digitKey("00")
                }
            }
            .background(Color(.separator))

            // 完了ボタン（全幅）
            Button {
                confirm()
                selectionHaptic()
            } label: {
                Text("完了")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(canConfirm ? Color.accentColor : Color.accentColor.opacity(0.35))
            }
            .buttonStyle(.plain)
            .disabled(!canConfirm)
        }
        .background(Color(.systemBackground))
        .presentationDetents([.height(390)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
    }

    // MARK: キー部品

    @ViewBuilder
    private func digitKey(_ d: String) -> some View {
        Button {
            appendDigit(d)
            selectionHaptic()
        } label: {
            Text(d)
                .font(.title2.bold())
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color(.secondarySystemBackground))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func actionKey(
        icon: String,
        color: Color,
        background: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
            selectionHaptic()
        } label: {
            Image(systemName: icon)
                .font(.title3.bold())
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(background)
        }
        .buttonStyle(.plain)
    }

    // MARK: ロジック

    private func appendDigit(_ d: String) {
        // プレースホルダー中は入力をリセットしてから1桁目を受け付ける
        if isPlaceholder {
            isPlaceholder = false
            inputStr = (d == "0" || d == "00") ? "" : d
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
        // 最大桁数制限（maxValue の桁数 + 1 まで許可してはみ出しを赤表示）
        let maxDigits = String(config.maxValue).count + 1
        guard newStr.count <= maxDigits else { return }
        inputStr = newStr
    }

    private func deleteDigit() {
        // プレースホルダー中は ⌫ でクリア（0 入力状態へ）
        if isPlaceholder {
            isPlaceholder = false
            inputStr = ""
            return
        }
        guard !inputStr.isEmpty else { return }
        inputStr.removeLast()
    }

    private func confirm() {
        guard canConfirm else { return }
        let n = max(config.minValue, min(config.maxValue, currentInt))
        config.onConfirm(n)
        dismiss()
    }
}
