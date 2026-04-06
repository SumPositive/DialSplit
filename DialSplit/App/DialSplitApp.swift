import SwiftUI

@main
struct DialSplitApp: App {
    @State private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            SplitView()
                .environment(settings)
        }
    }
}
