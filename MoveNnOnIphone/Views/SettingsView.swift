import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @StateObject private var detector = YOLODetector()
    @StateObject private var estimator = DepthEstimator()

    var body: some View {
        NavigationView {
            Form {
                // YOLO Settings
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("信頼度閾値")
                            Spacer()
                            Text("\(Int(settings.confidenceThreshold * 100))%")
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                        Slider(
                            value: $settings.confidenceThreshold,
                            in: 0.05...0.95,
                            step: 0.05
                        )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("閾値の説明")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("値を高くすると信頼度の高い検出のみ表示します。低くすると多くの検出結果を表示しますが、誤検出が増える場合があります。")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("YOLO 設定")
                }

                // Model Status
                Section {
                    HStack {
                        Label("YOLOv8n", systemImage: "cpu")
                        Spacer()
                        modelStatusBadge(isLoaded: detector.isModelLoaded)
                    }

                    HStack {
                        Label("Depth Anything V2", systemImage: "cpu")
                        Spacer()
                        modelStatusBadge(isLoaded: estimator.isModelLoaded)
                    }
                } header: {
                    Text("モデル状態")
                } footer: {
                    Text("モデルが「未検出」の場合は、CoreMLモデルファイルをXcodeプロジェクトに追加してください。")
                }

                // Usage Guide
                Section {
                    NavigationLink {
                        usageGuideView
                    } label: {
                        Label("使い方", systemImage: "questionmark.circle")
                    }
                } header: {
                    Text("ヘルプ")
                }

                // About
                Section {
                    HStack {
                        Text("バージョン")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("対応モデル")
                        Spacer()
                        Text("YOLOv8, Depth Anything V2")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("アプリについて")
                }
            }
            .navigationTitle("設定")
        }
    }

    // MARK: - Model Status Badge

    private func modelStatusBadge(isLoaded: Bool) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isLoaded ? .green : .red)
                .frame(width: 8, height: 8)
            Text(isLoaded ? "読み込み済み" : "未検出")
                .font(.caption)
                .foregroundColor(isLoaded ? .green : .red)
        }
    }

    // MARK: - Usage Guide

    private var usageGuideView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                guideSection(
                    icon: "camera.fill",
                    title: "リアルタイム検出",
                    description: "カメラ映像からリアルタイムで物体を検出します。検出された物体は矩形とカテゴリ名で表示されます。"
                )

                guideSection(
                    icon: "photo.fill",
                    title: "写真検出",
                    description: "撮影した写真に対して物体検出を実行します。撮影ボタンを押すと自動的に検出が開始されます。"
                )

                guideSection(
                    icon: "cube.fill",
                    title: "深度推定",
                    description: "Depth Anything V2 を使用して撮影した写真の深度マップを生成します。処理に時間がかかる場合があります。"
                )

                guideSection(
                    icon: "gear",
                    title: "設定",
                    description: "信頼度閾値を調整して、検出の感度を変更できます。閾値を上げると信頼度の高い結果のみ表示されます。"
                )

                Divider()

                Text("モデルのセットアップ")
                    .font(.headline)
                    .padding(.top)

                Text("1. YOLOv8n CoreMLモデル (yolov8n.mlmodel) を取得\n2. Depth Anything V2 CoreMLモデル (DepthAnythingV2SmallF16.mlmodel) を取得\n3. 各モデルファイルをXcodeプロジェクトにドラッグ＆ドロップ\n4. ビルドして実行")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .navigationTitle("使い方")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func guideSection(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}
