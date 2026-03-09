import SwiftUI

struct SegmentationView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var estimator = SegmentationEstimator(variant: AppSettings.shared.segmentationVariant)
    @ObservedObject private var settings = AppSettings.shared

    @State private var capturedImage: UIImage?
    @State private var segResult: SegmentationResult?
    @State private var isProcessing = false
    @State private var showResult = false
    @State private var showOverlay = true

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
        .onChange(of: settings.selectedSegmentationModel) { _ in
            estimator.switchModel(to: settings.segmentationVariant)
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
                        Text("セグメンテーションモデル未検出")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .padding(8)
                    .background(.black.opacity(0.6))
                    .cornerRadius(8)
                }

                Button(action: captureAndSegment) {
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
                    Text("セグメンテーション中...")
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
                // Header
                HStack {
                    Text("セグメンテーション結果")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding()
                .background(.black)

                // Image display
                if let capturedImage, let segResult {
                    ZStack {
                        Image(uiImage: capturedImage)
                            .resizable()
                            .scaledToFit()

                        if showOverlay {
                            Image(uiImage: segResult.image)
                                .resizable()
                                .scaledToFit()
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: showOverlay)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Toggle
                    Picker("表示", selection: $showOverlay) {
                        Text("オーバーレイ").tag(true)
                        Text("元画像").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    // Detected classes legend
                    if !segResult.detectedClasses.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(segResult.detectedClasses) { cls in
                                    HStack(spacing: 4) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color(
                                                red: Double(cls.color.0) / 255,
                                                green: Double(cls.color.1) / 255,
                                                blue: Double(cls.color.2) / 255
                                            ))
                                            .frame(width: 14, height: 14)
                                        Text(cls.label)
                                            .font(.caption)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 6)
                        }
                        .background(Color(.systemBackground))
                    }
                } else if capturedImage != nil {
                    VStack {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.yellow)
                        Text("セグメンテーションに失敗しました")
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

                    if segResult != nil {
                        Button(action: saveResult) {
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

    private func captureAndSegment() {
        isProcessing = true
        Task {
            guard let image = await cameraManager.takePhoto() else {
                await MainActor.run { isProcessing = false }
                return
            }

            let result = await estimator.segment(image: image)

            await MainActor.run {
                capturedImage = image
                segResult = result
                isProcessing = false
                showResult = true
                showOverlay = true
                cameraManager.stop()
            }
        }
    }

    private func retake() {
        showResult = false
        capturedImage = nil
        segResult = nil
        cameraManager.start()
    }

    private func saveResult() {
        guard let capturedImage, let segResult else { return }
        // Composite the overlay onto the original
        let renderer = UIGraphicsImageRenderer(size: capturedImage.size)
        let composited = renderer.image { context in
            capturedImage.draw(in: CGRect(origin: .zero, size: capturedImage.size))
            segResult.image.draw(in: CGRect(origin: .zero, size: capturedImage.size))
        }
        UIImageWriteToSavedPhotosAlbum(composited, nil, nil, nil)
    }
}
