import SwiftUI

/// Brass/gold skeuomorphic frame around dial panels
struct BrassFrame<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.12, green: 0.10, blue: 0.08).opacity(0.85),
                                Color(red: 0.08, green: 0.06, blue: 0.05).opacity(0.90)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(brassGradient, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.5), radius: 6, x: 0, y: 3)
    }

    private var brassGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.85, green: 0.70, blue: 0.30),
                Color(red: 0.65, green: 0.52, blue: 0.20),
                Color(red: 0.90, green: 0.78, blue: 0.40),
                Color(red: 0.60, green: 0.48, blue: 0.18)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
