import SwiftUI

struct PhotoDetectionView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var detector = YOLODetector()
    @ObservedObject private var settings = AppSettings.shared

    @State private var capturedImage: UIImage?
    @State private var detections: [DetectedObject] = []
    @State private var isProcessing = false
    @State private var showResult = false

    var body: some View {
        ZStack {
            if showResult, let image = capturedImage {
                resultView(image: image)
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

                if !detector.isModelLoaded {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        Text("YOLOモデル未検出")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .padding(8)
                    .background(.black.opacity(0.6))
                    .cornerRadius(8)
                }

                // Capture button
                Button(action: captureAndDetect) {
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
                ProgressView("検出中...")
                    .tint(.white)
                    .foregroundColor(.white)
                    .padding()
                    .background(.black.opacity(0.6))
                    .cornerRadius(10)
            }
        }
    }

    // MARK: - Result View

    private func resultView(image: UIImage) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("検出結果")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(detections.count) 件検出")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding()
                .background(.black)

                // Image with bounding boxes
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()

                    GeometryReader { geometry in
                        let imageSize = CGSize(
                            width: image.size.width,
                            height: image.size.height
                        )
                        let viewSize = geometry.size

                        // Compute aspect-fit mapping for the displayed image
                        let scale = min(
                            viewSize.width / imageSize.width,
                            viewSize.height / imageSize.height
                        )
                        let displayWidth = imageSize.width * scale
                        let displayHeight = imageSize.height * scale
                        let offsetX = (viewSize.width - displayWidth) / 2
                        let offsetY = (viewSize.height - displayHeight) / 2

                        ForEach(detections) { detection in
                            let box = detection.boundingBox
                            // Convert Vision coords (bottom-left origin) to view coords
                            let x = box.origin.x * displayWidth + offsetX
                            let y = (1.0 - box.origin.y - box.height) * displayHeight + offsetY
                            let w = box.width * displayWidth
                            let h = box.height * displayHeight
                            let rect = CGRect(x: x, y: y, width: w, height: h)

                            Rectangle()
                                .stroke(boxColor(for: detection.label), lineWidth: 2.5)
                                .frame(width: rect.width, height: rect.height)
                                .position(x: rect.midX, y: rect.midY)

                            Text("\(detection.label) \(Int(detection.confidence * 100))%")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(boxColor(for: detection.label).opacity(0.85))
                                .cornerRadius(4)
                                .position(x: rect.midX, y: rect.minY - 10)
                        }
                    }
                }

                // Detection list
                if !detections.isEmpty {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 6) {
                            ForEach(detections) { detection in
                                HStack {
                                    Circle()
                                        .fill(boxColor(for: detection.label))
                                        .frame(width: 10, height: 10)
                                    Text(detection.label)
                                        .font(.subheadline)
                                    Spacer()
                                    Text("\(Int(detection.confidence * 100))%")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .frame(maxHeight: 150)
                    .background(Color(.systemBackground))
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

                    Button(action: { saveImage(image) }) {
                        Label("保存", systemImage: "square.and.arrow.down")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(.green)
                            .cornerRadius(12)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
            }
        }
    }

    // MARK: - Actions

    private func captureAndDetect() {
        isProcessing = true
        Task {
            guard let image = await cameraManager.takePhoto() else {
                await MainActor.run { isProcessing = false }
                return
            }

            let threshold = Float(settings.confidenceThreshold)
            let results = await detector.detect(
                image: image,
                confidenceThreshold: threshold
            )

            await MainActor.run {
                capturedImage = image
                detections = results
                isProcessing = false
                showResult = true
                cameraManager.stop()
            }
        }
    }

    private func retake() {
        showResult = false
        capturedImage = nil
        detections = []
        cameraManager.start()
    }

    private func saveImage(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }

    private func boxColor(for label: String) -> Color {
        let hash = abs(label.hashValue)
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.8, brightness: 0.9)
    }
}
