import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @StateObject private var detector = YOLODetector(variant: AppSettings.shared.yoloVariant)
    @StateObject private var estimator = DepthEstimator(variant: AppSettings.shared.depthVariant)
    @StateObject private var segEstimator = SegmentationEstimator(variant: AppSettings.shared.segmentationVariant)

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

                // YOLO Model Selection
                Section {
                    ForEach(YOLOVariant.allCases) { variant in
                        Button {
                            settings.selectedYOLOVariant = variant.rawValue
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(variant.displayName)
                                        .foregroundColor(.primary)
                                    Text(variant.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if settings.selectedYOLOVariant == variant.rawValue {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                                modelAvailabilityBadge(
                                    isAvailable: variant.isAvailable
                                )
                            }
                        }
                    }
                } header: {
                    Text("YOLO モデル選択")
                } footer: {
                    Text("使用するモデルは事前に変換が必要です。未変換のモデルは赤で表示されます。")
                }

                // Depth Model Selection
                Section {
                    ForEach(DepthModelVariant.allCases) { variant in
                        Button {
                            settings.selectedDepthModel = variant.rawValue
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(variant.displayName)
                                        .foregroundColor(.primary)
                                    Text(variant.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if settings.selectedDepthModel == variant.rawValue {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                                modelAvailabilityBadge(
                                    isAvailable: variant.isAvailable
                                )
                            }
                        }
                    }
                } header: {
                    Text("深度推定モデル選択")
                }

                // Segmentation Model Selection
                Section {
                    ForEach(SegmentationModelVariant.allCases) { variant in
                        Button {
                            settings.selectedSegmentationModel = variant.rawValue
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(variant.displayName)
                                        .foregroundColor(.primary)
                                    Text(variant.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if settings.selectedSegmentationModel == variant.rawValue {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                                modelAvailabilityBadge(
                                    isAvailable: variant.isAvailable
                                )
                            }
                        }
                    }
                } header: {
                    Text("セグメンテーションモデル選択")
                } footer: {
                    Text("DeepLabV3 (PASCAL VOC 21クラス) によるセマンティックセグメンテーション")
                }

                // Model Status
                Section {
                    HStack {
                        Label(settings.yoloVariant.displayName, systemImage: "cpu")
                        Spacer()
                        modelStatusBadge(isLoaded: detector.isModelLoaded)
                    }

                    HStack {
                        Label(settings.depthVariant.displayName, systemImage: "cpu")
                        Spacer()
                        modelStatusBadge(isLoaded: estimator.isModelLoaded)
                    }

                    HStack {
                        Label(settings.segmentationVariant.displayName, systemImage: "cpu")
                        Spacer()
                        modelStatusBadge(isLoaded: segEstimator.isModelLoaded)
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
                        Text("1.2.0")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("対応モデル")
                        Spacer()
                        Text("YOLOv8, Depth Anything V2, DeepLabV3")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("アプリについて")
                }
            }
            .navigationTitle("設定")
            .onChange(of: settings.selectedYOLOVariant) { _ in
                detector.switchModel(to: settings.yoloVariant)
            }
            .onChange(of: settings.selectedDepthModel) { _ in
                estimator.switchModel(to: settings.depthVariant)
            }
            .onChange(of: settings.selectedSegmentationModel) { _ in
                segEstimator.switchModel(to: settings.segmentationVariant)
            }
        }
    }

    // MARK: - Badges

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

    private func modelAvailabilityBadge(isAvailable: Bool) -> some View {
        Circle()
            .fill(isAvailable ? .green : .red.opacity(0.6))
            .frame(width: 8, height: 8)
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
                    icon: "square.on.square.dashed",
                    title: "セグメンテーション",
                    description: "DeepLabV3 を使用してピクセル単位でシーンを分類します。21カテゴリ（人、車、動物等）に対応。"
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

                Text("1. bash scripts/setup_and_convert.sh を実行\n2. 追加のYOLOバリアントが必要な場合:\n   python scripts/convert_models.py --yolo-variant yolov8s\n3. XcodeGenでプロジェクト生成: xcodegen generate\n4. ビルドして実行")
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
