import SwiftUI

import FirebaseCore

@main
struct DialSplitApp: App {
    @State private var settings = AppSettings.shared
    @Environment(\.dynamicTypeSize) private var systemDynamicTypeSize
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    private let iPhoneSE3Width: CGFloat = 375
    private let iPadDefaultWindowSize = CGSize(width: 375, height: 300)

    init() {
        FirebaseApp.configure()
        Telemetry.setup()
        Telemetry.snapshotSettings(AppSettings.shared)
    }

    private var effectiveDynamicTypeSize: DynamicTypeSize {
        settings.fontScale.followsSystem ? systemDynamicTypeSize : settings.fontScale.dynamicTypeSize
    }

    var body: some Scene {
        WindowGroup {
            SplitView()
                .environment(settings)
                .frame(minWidth: isPad ? iPhoneSE3Width : 0)
                .preferredColorScheme(settings.appearanceMode.colorScheme)
                .dynamicTypeSize(effectiveDynamicTypeSize)
        }
        .defaultSize(
            width: isPad ? iPadDefaultWindowSize.width : UIScreen.main.bounds.width,
            height: isPad ? iPadDefaultWindowSize.height : UIScreen.main.bounds.height
        )
        .windowResizability(.automatic)
    }
}
