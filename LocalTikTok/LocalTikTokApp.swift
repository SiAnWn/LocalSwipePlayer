import SwiftUI

@main
struct LocalTikTokApp: App {
    @StateObject private var videoModel = VideoModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(videoModel)
        }
    }
}
