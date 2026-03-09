import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            LazyView(RealTimeDetectionView())
                .tabItem {
                    Label("リアルタイム", systemImage: "camera.fill")
                }

            LazyView(PhotoDetectionView())
                .tabItem {
                    Label("写真検出", systemImage: "photo.fill")
                }

            LazyView(DepthEstimationView())
                .tabItem {
                    Label("深度推定", systemImage: "cube.fill")
                }

            LazyView(SegmentationView())
                .tabItem {
                    Label("セグメント", systemImage: "square.on.square.dashed")
                }

            LazyView(SettingsView())
                .tabItem {
                    Label("設定", systemImage: "gear")
                }
        }
    }
}

#Preview {
    ContentView()
}
