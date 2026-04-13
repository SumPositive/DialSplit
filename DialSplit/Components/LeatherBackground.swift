import SwiftUI

/// Full-screen background（モノトーン / ブラウンレザー / ブラックレザー）
struct LeatherBackground: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let style = settings.leatherStyle
        let imageName = style.backgroundImage

        Group {
            if !imageName.isEmpty, UIImage(named: imageName) != nil {
                Image(imageName)
                    .resizable()
                    .ignoresSafeArea()
            } else {
                // テクスチャ画像が無い場合のフォールバックグラデーション
                LinearGradient(
                    colors: style.fallbackColors(for: colorScheme),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .overlay {
                    if style.showsStitch {
                        LeatherStitchOverlay()
                    }
                }
            }
        }
    }
}

/// 装飾ステッチライン（レザー系のみ表示）
private struct LeatherStitchOverlay: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                let margin: CGFloat = 12
                let corner: CGFloat = 8
                let rect = CGRect(
                    x: margin, y: margin,
                    width: geo.size.width - margin * 2,
                    height: geo.size.height - margin * 2
                )
                path.addRoundedRect(in: rect, cornerSize: CGSize(width: corner, height: corner))
            }
            .stroke(
                Color.white.opacity(0.08),
                style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
            )
        }
        .ignoresSafeArea()
    }
}

/// パネル内の水平区切り線
struct LeatherDivider: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let midOpacity: Double = colorScheme == .dark ? 0.40 : 0.25
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, .black.opacity(midOpacity), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .frame(height: 1)
    }
}
