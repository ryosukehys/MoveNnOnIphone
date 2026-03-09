import Vision
import CoreML
import UIKit

final class SegmentationEstimator: ObservableObject {
    private var model: VNCoreMLModel?
    @Published var isModelLoaded = false
    @Published var isLoading = false
    @Published var loadError: String?
    private(set) var currentVariant: SegmentationModelVariant

    // PASCAL VOC 21 classes
    static let classLabels = [
        "背景", "飛行機", "自転車", "鳥", "ボート",
        "ボトル", "バス", "車", "猫", "椅子",
        "牛", "テーブル", "犬", "馬", "バイク",
        "人", "鉢植え", "羊", "ソファ", "電車", "テレビ"
    ]

    // Distinct colors for each class
    static let classColors: [(UInt8, UInt8, UInt8)] = [
        (0, 0, 0),         // background - black
        (128, 0, 0),       // aeroplane
        (0, 128, 0),       // bicycle
        (128, 128, 0),     // bird
        (0, 0, 128),       // boat
        (128, 0, 128),     // bottle
        (0, 128, 128),     // bus
        (128, 128, 128),   // car
        (64, 0, 0),        // cat
        (192, 0, 0),       // chair
        (64, 128, 0),      // cow
        (192, 128, 0),     // diningtable
        (64, 0, 128),      // dog
        (192, 0, 128),     // horse
        (64, 128, 128),    // motorbike
        (192, 128, 128),   // person
        (0, 64, 0),        // pottedplant
        (128, 64, 0),      // sheep
        (0, 192, 0),       // sofa
        (128, 192, 0),     // train
        (0, 64, 128),      // tv
    ]

    init(variant: SegmentationModelVariant = .deeplabV3FP16) {
        currentVariant = variant
    }

    func prepareIfNeeded() {
        guard model == nil, !isLoading else { return }
        loadModel()
    }

    func unloadModel() {
        model = nil
        DispatchQueue.main.async {
            self.isModelLoaded = false
        }
        print("[SegmentationEstimator] Model unloaded to free memory")
    }

    func switchModel(to variant: SegmentationModelVariant) {
        guard variant != currentVariant else { return }
        currentVariant = variant
        model = nil
        DispatchQueue.main.async {
            self.isModelLoaded = false
            self.loadError = nil
        }
        loadModel()
    }

    private func loadModel() {
        guard let modelURL = ModelDownloadManager.shared.modelURL(
            fileName: currentVariant.modelFileName
        ) else {
            print("[SegmentationEstimator] \(currentVariant.modelFileName).mlmodelc not found")
            DispatchQueue.main.async {
                self.loadError = "モデルファイルが見つかりません"
            }
            return
        }

        DispatchQueue.main.async {
            self.isLoading = true
            self.loadError = nil
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            do {
                let config = MLModelConfiguration()
                config.computeUnits = .cpuAndNeuralEngine
                let mlModel = try MLModel(contentsOf: modelURL, configuration: config)
                let vncoreModel = try VNCoreMLModel(for: mlModel)
                DispatchQueue.main.async {
                    self.model = vncoreModel
                    self.isModelLoaded = true
                    self.isLoading = false
                }
                print("[SegmentationEstimator] Model loaded successfully: \(self.currentVariant.displayName)")
            } catch {
                print("[SegmentationEstimator] Failed to load model: \(error)")
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.loadError = "モデルの読み込みに失敗: \(error.localizedDescription)"
                }
            }
        }
    }

    /// Segment an image and return a colorized segmentation map
    func segment(image: UIImage) async -> SegmentationResult? {
        guard let model, let cgImage = image.cgImage else { return nil }

        return await withCheckedContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { request, error in
                guard let results = request.results as? [VNCoreMLFeatureValueObservation],
                      let firstResult = results.first,
                      let multiArray = firstResult.featureValue.multiArrayValue else {
                    continuation.resume(returning: nil)
                    return
                }

                let result = Self.renderSegmentationMap(multiArray)
                continuation.resume(returning: result)
            }
            request.imageCropAndScaleOption = .scaleFill

            let orientation = CGImagePropertyOrientation(image.imageOrientation)
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
            do {
                try handler.perform([request])
            } catch {
                print("[SegmentationEstimator] Inference error: \(error)")
                continuation.resume(returning: nil)
            }
        }
    }

    // MARK: - Segmentation Map Rendering

    /// Render MLMultiArray segmentation output to a colorized UIImage
    /// DeepLabV3 output shape: [1, 21, H, W] (class probabilities) or [H, W] (class indices)
    private static func renderSegmentationMap(_ multiArray: MLMultiArray) -> SegmentationResult? {
        let shape = multiArray.shape.map { $0.intValue }

        let height: Int
        let width: Int
        let classMap: [Int]

        if shape.count == 2 {
            // Direct class index map [H, W]
            height = shape[0]
            width = shape[1]
            let count = height * width
            var map = [Int](repeating: 0, count: count)
            for i in 0..<count {
                map[i] = multiArray[i].intValue
            }
            classMap = map
        } else if shape.count == 3 {
            // [C, H, W] - need argmax over classes
            let numClasses = shape[0]
            height = shape[1]
            width = shape[2]
            let count = height * width
            var map = [Int](repeating: 0, count: count)
            for i in 0..<count {
                var maxVal: Float = -Float.greatestFiniteMagnitude
                var maxIdx = 0
                for c in 0..<numClasses {
                    let idx = c * count + i
                    let val = multiArray[idx].floatValue
                    if val > maxVal {
                        maxVal = val
                        maxIdx = c
                    }
                }
                map[i] = maxIdx
            }
            classMap = map
        } else if shape.count == 4 {
            // [1, C, H, W]
            let numClasses = shape[1]
            height = shape[2]
            width = shape[3]
            let count = height * width
            var map = [Int](repeating: 0, count: count)
            for i in 0..<count {
                var maxVal: Float = -Float.greatestFiniteMagnitude
                var maxIdx = 0
                for c in 0..<numClasses {
                    let idx = c * count + i
                    let val = multiArray[idx].floatValue
                    if val > maxVal {
                        maxVal = val
                        maxIdx = c
                    }
                }
                map[i] = maxIdx
            }
            classMap = map
        } else {
            print("[SegmentationEstimator] Unexpected shape: \(shape)")
            return nil
        }

        let count = height * width
        guard count > 0 else { return nil }

        // Collect detected classes
        var detectedClassIndices = Set<Int>()

        // Generate RGBA pixels
        var pixels = [UInt8](repeating: 0, count: count * 4)
        for i in 0..<count {
            let classIdx = min(classMap[i], classColors.count - 1)
            if classIdx > 0 {
                detectedClassIndices.insert(classIdx)
            }
            let (r, g, b) = classColors[max(0, classIdx)]
            let idx = i * 4
            pixels[idx] = r
            pixels[idx + 1] = g
            pixels[idx + 2] = b
            pixels[idx + 3] = classIdx == 0 ? 0 : 200 // semi-transparent for overlay
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let cgImage = context.makeImage() else {
            return nil
        }

        let segImage = UIImage(cgImage: cgImage)
        let detectedClasses = detectedClassIndices.sorted().map { idx in
            DetectedClass(
                index: idx,
                label: idx < classLabels.count ? classLabels[idx] : "class_\(idx)",
                color: classColors[min(idx, classColors.count - 1)]
            )
        }

        return SegmentationResult(image: segImage, detectedClasses: detectedClasses)
    }
}

// MARK: - Result Types

struct DetectedClass: Identifiable {
    let id = UUID()
    let index: Int
    let label: String
    let color: (UInt8, UInt8, UInt8)
}

struct SegmentationResult {
    let image: UIImage
    let detectedClasses: [DetectedClass]
}
