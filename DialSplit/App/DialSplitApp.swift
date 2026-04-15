import SwiftUI

@main
struct DialSplitApp: App {
    @State private var settings = AppSettings()
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    private let iPhoneSE3Width: CGFloat = 375
    private let iPadDefaultWindowSize = CGSize(width: 375, height: 300)

    var body: some Scene {
        WindowGroup {
            SplitView()
                .environment(settings)
                .frame(minWidth: isPad ? iPhoneSE3Width : 0)
        }
        .defaultSize(
            width: isPad ? iPadDefaultWindowSize.width : UIScreen.main.bounds.width,
            height: isPad ? iPadDefaultWindowSize.height : UIScreen.main.bounds.height
        )
        .windowResizability(.automatic)
    }
}
