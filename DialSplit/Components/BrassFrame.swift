import SwiftUI

/// Skeuomorphic frame around dial panels.
/// ダークモード: 濃いブラウン / ライトモード: ウォームグレー
struct BrassFrame<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(panelGradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(brassGradient, lineWidth: 2)
            )
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.50 : 0.15),
                radius: 6, x: 0, y: 3
            )
    }

    // MARK: - パネル背景

    private var panelGradient: LinearGradient {
        if colorScheme == .light {
            // ライトモード: ウォームグレー
            return LinearGradient(
                colors: [
                    Color(red: 0.88, green: 0.87, blue: 0.85),
                    Color(red: 0.80, green: 0.79, blue: 0.77),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            // ダークモード: 濃いブラウン（従来）
            return LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.10, blue: 0.08).opacity(0.85),
                    Color(red: 0.08, green: 0.06, blue: 0.05).opacity(0.90),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: - 真鍮フレーム（共通）

    private var brassGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.85, green: 0.70, blue: 0.30),
                Color(red: 0.65, green: 0.52, blue: 0.20),
                Color(red: 0.90, green: 0.78, blue: 0.40),
                Color(red: 0.60, green: 0.48, blue: 0.18),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
