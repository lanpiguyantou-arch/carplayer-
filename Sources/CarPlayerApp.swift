import SwiftUI
import AVFoundation

@main
struct CarPlayerApp: App {
    @StateObject private var library = Library.shared

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, policy: .longFormVideo)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                LibraryView()
                    .tabItem { Label("首页", systemImage: "house") }
                DiscoverView()
                    .tabItem { Label("发现", systemImage: "safari") }
            }
            .tint(.green)
            .environmentObject(library)
            .preferredColorScheme(.dark)
            .onAppear { DLNARenderer.shared.start() }
        }
    }
}
