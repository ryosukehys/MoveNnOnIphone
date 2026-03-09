import SwiftUI

struct RealTimeDetectionView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var detector = YOLODetector(variant: AppSettings.shared.yoloVariant)
    @ObservedObject private var settings = AppSettings.shared

    @State private var detections: [DetectedObject] = []
    @State private var isProcessing = false
    @State private var fps: Double = 0
    @State private var lastFrameTime = Date()

    var body: some View {
        ZStack {
            // Camera preview
            if cameraManager.permissionGranted {
                CameraPreviewView(session: cameraManager.session)
                    .ignoresSafeArea()

                // Bounding box overlay
                BoundingBoxOverlay(
                    detections: detections,
                    imageSize: cameraManager.videoSize
                )
                .ignoresSafeArea()
            } else {
                permissionDeniedView
            }

            // HUD overlay
            VStack {
                hudView
                Spacer()
                if detector.isLoading {
                    loadingBanner
                } else if !detector.isModelLoaded {
                    modelNotLoadedBanner
                }
            }
            .padding()
        }
        .onAppear {
            cameraManager.checkPermission()
            detector.prepareIfNeeded()
            setupFrameProcessing()
            cameraManager.start()
        }
        .onDisappear {
            cameraManager.stop()
            detector.unloadModel()
        }
        .onChange(of: settings.selectedYOLOVariant) { _ in
            detector.switchModel(to: settings.yoloVariant)
        }
    }

    // MARK: - HUD

    private var hudView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("リアルタイム検出")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("検出数: \(detections.count) | FPS: \(String(format: "%.1f", fps))")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(10)
            .background(.black.opacity(0.5))
            .cornerRadius(10)

            Spacer()
        }
    }

    // MARK: - Loading Banner

    private var loadingBanner: some View {
        VStack(spacing: 8) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.3)
            Text("モデル読み込み中...")
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding()
        .background(.black.opacity(0.7))
        .cornerRadius(12)
    }

    // MARK: - Model Not Loaded

    private var modelNotLoadedBanner: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title)
                .foregroundColor(.yellow)
            Text("YOLOモデル未検出")
                .font(.headline)
                .foregroundColor(.white)
            Text("yolov8n.mlmodel をプロジェクトに\n追加してください")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(.black.opacity(0.7))
        .cornerRadius(12)
    }

    // MARK: - Permission Denied

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("カメラへのアクセスが必要です")
                .font(.headline)
            Text("設定アプリからカメラの使用を\n許可してください")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Frame Processing

    private func setupFrameProcessing() {
        cameraManager.onFrameCaptured = { [self] pixelBuffer in
            guard !isProcessing, detector.isModelLoaded else { return }
            isProcessing = true

            let threshold = Float(settings.confidenceThreshold)

            Task {
                let results = await detector.detect(
                    pixelBuffer: pixelBuffer,
                    confidenceThreshold: threshold
                )

                let now = Date()
                let elapsed = now.timeIntervalSince(lastFrameTime)

                await MainActor.run {
                    detections = results
                    if elapsed > 0 {
                        fps = 1.0 / elapsed
                    }
                    lastFrameTime = now
                    isProcessing = false
                }
            }
        }
    }
}
