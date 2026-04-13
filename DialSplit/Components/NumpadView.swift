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

import SwiftUI
import UIKit

// MARK: - ハプティクス

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
    let step: Int        // 1 = そのまま確定、>1 = stepの倍数に丸める
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
            return config.isAmount ? "¥ \(n.formatted())" : "\(n)"
        }
        guard !inputStr.isEmpty else {
            return config.isAmount ? "¥ 0" : "0"
        }
        return config.isAmount ? "¥ \(n.formatted())" : "\(n)"
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
            Text(displayText)
                .font(.system(size: 42, weight: .bold, design: .monospaced))
                .foregroundStyle(
                    isOverMax    ? AnyShapeStyle(.red) :
                    isPlaceholder ? AnyShapeStyle(.tertiary) :
                                    AnyShapeStyle(.primary)
                )
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

            Divider()

            // テンキーグリッド
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
                        label: "⌫",
                        icon: "delete.left",
                        color: .primary,
                        background: Color(.tertiarySystemBackground),
                        enabled: true
                    ) { deleteDigit() }

                    digitKey("0")

                    actionKey(
                        label: "完了",
                        icon: nil,
                        color: .white,
                        background: canConfirm ? Color.accentColor : Color.accentColor.opacity(0.35),
                        enabled: canConfirm
                    ) { confirm() }
                }
            }
            .background(Color(.separator))
            .padding(.bottom, 0)
        }
        .background(Color(.systemBackground))
        .presentationDetents([.height(350)])
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
                .frame(height: 58)
                .background(Color(.secondarySystemBackground))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func actionKey(
        label: String,
        icon: String?,
        color: Color,
        background: Color,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
            selectionHaptic()
        } label: {
            Group {
                if let icon {
                    Image(systemName: icon)
                        .font(.title3.bold())
                } else {
                    Text(label)
                        .font(.headline.bold())
                }
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(background)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    // MARK: ロジック

    private func appendDigit(_ d: String) {
        // プレースホルダー中は入力をリセットしてから1桁目を受け付ける
        if isPlaceholder {
            isPlaceholder = false
            inputStr = d == "0" ? "" : d
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
        var n = max(config.minValue, min(config.maxValue, currentInt))
        if config.step > 1 {
            n = (n / config.step) * config.step   // step の倍数に切り捨て
        }
        config.onConfirm(n)
        dismiss()
    }
}
