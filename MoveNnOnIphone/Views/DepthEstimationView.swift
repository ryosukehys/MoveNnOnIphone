import SwiftUI

struct DepthEstimationView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var estimator = DepthEstimator()

    @State private var capturedImage: UIImage?
    @State private var depthImage: UIImage?
    @State private var isProcessing = false
    @State private var showResult = false
    @State private var showDepthMap = true

    var body: some View {
        ZStack {
            if showResult {
                resultView
            } else {
                cameraView
            }
        }
        .onAppear {
            cameraManager.checkPermission()
            cameraManager.start()
        }
        .onDisappear {
            cameraManager.stop()
        }
    }

    // MARK: - Camera View

    private var cameraView: some View {
        ZStack {
            if cameraManager.permissionGranted {
                CameraPreviewView(session: cameraManager.session)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
                Text("カメラへのアクセスが必要です")
                    .foregroundColor(.white)
            }

            VStack {
                Spacer()

                if !estimator.isModelLoaded {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        Text("Depth Anythingモデル未検出")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .padding(8)
                    .background(.black.opacity(0.6))
                    .cornerRadius(8)
                }

                Button(action: captureAndEstimate) {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 70, height: 70)
                        Circle()
                            .stroke(.white, lineWidth: 3)
                            .frame(width: 80, height: 80)
                    }
                }
                .disabled(isProcessing)
                .padding(.bottom, 30)
            }

            if isProcessing {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                    Text("深度推定中...")
                        .foregroundColor(.white)
                        .font(.headline)
                    Text("しばらくお待ちください")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.caption)
                }
                .padding(24)
                .background(.black.opacity(0.7))
                .cornerRadius(16)
            }
        }
    }

    // MARK: - Result View

    private var resultView: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with toggle
                HStack {
                    Text("深度推定結果")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding()
                .background(.black)

                // Image display
                if let capturedImage, let depthImage {
                    ZStack {
                        if showDepthMap {
                            Image(uiImage: depthImage)
                                .resizable()
                                .scaledToFit()
                        } else {
                            Image(uiImage: capturedImage)
                                .resizable()
                                .scaledToFit()
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: showDepthMap)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Toggle buttons
                    Picker("表示", selection: $showDepthMap) {
                        Text("深度マップ").tag(true)
                        Text("元画像").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                } else if capturedImage != nil {
                    VStack {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.yellow)
                        Text("深度推定に失敗しました")
                            .foregroundColor(.white)
                        Spacer()
                    }
                }

                // Action buttons
                HStack(spacing: 20) {
                    Button(action: retake) {
                        Label("撮り直す", systemImage: "camera.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(.blue)
                            .cornerRadius(12)
                    }

                    if let depthImage {
                        Button(action: { saveImage(depthImage) }) {
                            Label("保存", systemImage: "square.and.arrow.down")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(.green)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
            }
        }
    }

    // MARK: - Actions

    private func captureAndEstimate() {
        isProcessing = true
        Task {
            guard let image = await cameraManager.takePhoto() else {
                await MainActor.run { isProcessing = false }
                return
            }

            let depth = await estimator.estimateDepth(image: image)

            await MainActor.run {
                capturedImage = image
                depthImage = depth
                isProcessing = false
                showResult = true
                showDepthMap = true
                cameraManager.stop()
            }
        }
    }

    private func retake() {
        showResult = false
        capturedImage = nil
        depthImage = nil
        cameraManager.start()
    }

    private func saveImage(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
}
