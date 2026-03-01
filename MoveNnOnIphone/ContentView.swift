import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            RealTimeDetectionView()
                .tabItem {
                    Label("リアルタイム", systemImage: "camera.fill")
                }

            PhotoDetectionView()
                .tabItem {
                    Label("写真検出", systemImage: "photo.fill")
                }

            DepthEstimationView()
                .tabItem {
                    Label("深度推定", systemImage: "cube.fill")
                }

            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gear")
                }
        }
    }
}

#Preview {
    ContentView()
}
