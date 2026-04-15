import SwiftUI

/// パネルフレーム — ガラスモーフィズム試験版
struct BrassFrame<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppSettings.self) private var settings
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        let bright = Double(settings.panelBrightness) / 100.0
        let tintOpacity = max(0.06, min(0.34, 0.22 + bright * 0.45))
        let topStrong = max(0.35, min(0.90, 0.72 + bright * 0.55))
        let topSoft = max(0.12, min(0.45, 0.28 + bright * 0.30))
        let rimTop = max(0.55, min(0.95, 0.90 + bright * 0.25))
        let rimMid = max(0.20, min(0.55, 0.40 + bright * 0.20))
        let rimBottom = max(0.12, min(0.34, 0.20 - bright * 0.18))
        let outerShadow = max(0.18, min(0.44, 0.32 - bright * 0.28))
        content()
            .background(
                ZStack {
                    // ① ブラー＋ホワイトティント（明るさ底上げ）
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.white.opacity(tintOpacity))

                    // ② 上部スペキュラ（強い光反射で上半分を明るく）
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(topStrong),
                                    .white.opacity(topSoft),
                                    .white.opacity(0.04),
                                    .clear,
                                ],
                                startPoint: .top,
                                endPoint: UnitPoint(x: 0.5, y: 0.65)
                            )
                        )

                    // ③ 下部インナーシャドウ（軽めにして暗くなりすぎを防ぐ）
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .clear,
                                    .black.opacity(0.04),
                                    .black.opacity(0.10),
                                ],
                                startPoint: UnitPoint(x: 0.5, y: 0.65),
                                endPoint: .bottom
                            )
                        )

                    // ④ ガラス縁（上端に強いリム光）
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.90),
                                    .white.opacity(rimTop),
                                    .white.opacity(rimMid),
                                    .white.opacity(0.08),
                                    .black.opacity(rimBottom),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.2
                        )
                }
            )
            // ⑤ 3層シャドウ（柔らかい大＋鋭い小＋環境光）
            .shadow(color: .black.opacity(outerShadow), radius: 18, x: 0, y:  9)
            .shadow(color: .black.opacity(0.14), radius:  4, x: 0, y:  2)
            .shadow(color: .white.opacity(0.06), radius:  2, x: 0, y: -1)
    }
}

/*
 // ─── 元のスキューモーフィック版（復元用）───────────────────────────────
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

     private var panelGradient: LinearGradient {
         if colorScheme == .light {
             return LinearGradient(
                 colors: [
                     Color(red: 0.88, green: 0.87, blue: 0.85),
                     Color(red: 0.80, green: 0.79, blue: 0.77),
                 ],
                 startPoint: .top, endPoint: .bottom
             )
         } else {
             return LinearGradient(
                 colors: [
                     Color(red: 0.12, green: 0.10, blue: 0.08).opacity(0.85),
                     Color(red: 0.08, green: 0.06, blue: 0.05).opacity(0.90),
                 ],
                 startPoint: .top, endPoint: .bottom
             )
         }
     }

     private var brassGradient: LinearGradient {
         LinearGradient(
             colors: [
                 Color(red: 0.85, green: 0.70, blue: 0.30),
                 Color(red: 0.65, green: 0.52, blue: 0.20),
                 Color(red: 0.90, green: 0.78, blue: 0.40),
                 Color(red: 0.60, green: 0.48, blue: 0.18),
             ],
             startPoint: .topLeading, endPoint: .bottomTrailing
         )
     }
 }
 */
