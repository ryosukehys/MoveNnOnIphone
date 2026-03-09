import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var showMemoryWarning = false
    @State private var memoryWarningText = ""

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
                        modelSelectionRow(
                            displayName: variant.displayName,
                            description: variant.description,
                            isSelected: settings.selectedYOLOVariant == variant.rawValue,
                            isAvailable: variant.isAvailable,
                            canRunOnDevice: variant.canRunOnDevice,
                            memoryWarning: variant.memoryWarning
                        ) {
                            selectModelWithWarning(
                                warning: variant.memoryWarning
                            ) {
                                settings.selectedYOLOVariant = variant.rawValue
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
                        modelSelectionRow(
                            displayName: variant.displayName,
                            description: variant.description,
                            isSelected: settings.selectedDepthModel == variant.rawValue,
                            isAvailable: variant.isAvailable,
                            canRunOnDevice: variant.canRunOnDevice,
                            memoryWarning: variant.memoryWarning
                        ) {
                            selectModelWithWarning(
                                warning: variant.memoryWarning
                            ) {
                                settings.selectedDepthModel = variant.rawValue
                            }
                        }
                    }
                } header: {
                    Text("深度推定モデル選択")
                }

                // Segmentation Model Selection
                Section {
                    ForEach(SegmentationModelVariant.allCases) { variant in
                        modelSelectionRow(
                            displayName: variant.displayName,
                            description: variant.description,
                            isSelected: settings.selectedSegmentationModel == variant.rawValue,
                            isAvailable: variant.isAvailable,
                            canRunOnDevice: variant.canRunOnDevice,
                            memoryWarning: variant.memoryWarning
                        ) {
                            selectModelWithWarning(
                                warning: variant.memoryWarning
                            ) {
                                settings.selectedSegmentationModel = variant.rawValue
                            }
                        }
                    }
                } header: {
                    Text("セグメンテーションモデル選択")
                } footer: {
                    Text("DeepLabV3 (PASCAL VOC 21クラス) によるセマンティックセグメンテーション")
                }

                // Device Info
                Section {
                    HStack {
                        Text("デバイスメモリ")
                        Spacer()
                        Text(String(format: "%.1f GB", DeviceCapability.memoryGB))
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("デバイス情報")
                } footer: {
                    Text("大きなモデルはメモリ不足でクラッシュする場合があります。デバイスのメモリに合ったモデルを選択してください。")
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
                        Text("1.3.0")
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
            .alert("メモリ警告", isPresented: $showMemoryWarning) {
                Button("それでも使用する", role: .destructive) {}
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text(memoryWarningText)
            }
        }
    }

    // MARK: - Model Selection Row

    private func modelSelectionRow(
        displayName: String,
        description: String,
        isSelected: Bool,
        isAvailable: Bool,
        canRunOnDevice: Bool,
        memoryWarning: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(displayName)
                            .foregroundColor(.primary)
                        if !canRunOnDevice {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let memoryWarning {
                        Text(memoryWarning)
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
                modelAvailabilityBadge(isAvailable: isAvailable)
            }
        }
    }

    private func selectModelWithWarning(warning: String?, action: @escaping () -> Void) {
        if let warning {
            memoryWarningText = warning
            showMemoryWarning = true
            action()
        } else {
            action()
        }
    }

    // MARK: - Badges

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
