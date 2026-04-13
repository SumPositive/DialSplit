import SwiftUI

/// Full-screen leather texture background
struct LeatherBackground: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        let imageName = settings.leatherStyle.backgroundImage
        Group {
            if let _ = UIImage(named: imageName) {
                Image(imageName)
                    .resizable()
                    .ignoresSafeArea()
            } else {
                // Fallback gradient when texture image is not available
                LinearGradient(
                    colors: settings.leatherStyle == .brown
                        ? [Color(red: 0.35, green: 0.22, blue: 0.12), Color(red: 0.22, green: 0.13, blue: 0.07)]
                        : [Color(red: 0.18, green: 0.18, blue: 0.18), Color(red: 0.08, green: 0.08, blue: 0.08)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .overlay {
                    // Subtle stitch pattern overlay
                    LeatherStitchOverlay()
                }
            }
        }
    }
}

/// Decorative stitch line overlay for fallback leather look
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

/// Horizontal divider that blends with the panel background
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
