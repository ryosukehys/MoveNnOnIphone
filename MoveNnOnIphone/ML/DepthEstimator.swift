import Vision
import CoreML
import UIKit

final class DepthEstimator: ObservableObject {
    private var model: VNCoreMLModel?
    @Published var isModelLoaded = false
    private(set) var currentVariant: DepthModelVariant

    init(variant: DepthModelVariant = .smallF16) {
        currentVariant = variant
        loadModel()
    }

    func switchModel(to variant: DepthModelVariant) {
        guard variant != currentVariant else { return }
        currentVariant = variant
        model = nil
        DispatchQueue.main.async {
            self.isModelLoaded = false
        }
        loadModel()
    }

    private func loadModel() {
        guard let modelURL = Bundle.main.url(
            forResource: currentVariant.modelFileName,
            withExtension: "mlmodelc"
        ) else {
            print("[DepthEstimator] \(currentVariant.modelFileName).mlmodelc not found in bundle")
            return
        }

        do {
            let config = MLModelConfiguration()
            config.computeUnits = .cpuAndNeuralEngine
            let mlModel = try MLModel(contentsOf: modelURL, configuration: config)
            model = try VNCoreMLModel(for: mlModel)
            DispatchQueue.main.async {
                self.isModelLoaded = true
            }
            print("[DepthEstimator] Model loaded successfully")
        } catch {
            print("[DepthEstimator] Failed to load model: \(error)")
        }
    }

    /// Estimate depth from a UIImage and return a colorized depth map
    func estimateDepth(image: UIImage) async -> UIImage? {
        guard let model, let cgImage = image.cgImage else { return nil }

        return await withCheckedContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { request, error in
                guard let results = request.results as? [VNCoreMLFeatureValueObservation],
                      let firstResult = results.first,
                      let multiArray = firstResult.featureValue.multiArrayValue else {
                    continuation.resume(returning: nil)
                    return
                }

                let depthImage = Self.renderDepthMap(multiArray)
                continuation.resume(returning: depthImage)
            }
            request.imageCropAndScaleOption = .scaleFill

            let orientation = CGImagePropertyOrientation(image.imageOrientation)
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
            do {
                try handler.perform([request])
            } catch {
                print("[DepthEstimator] Inference error: \(error)")
                continuation.resume(returning: nil)
            }
        }
    }

    // MARK: - Depth Map Rendering

    /// Convert MLMultiArray depth output to a colorized UIImage
    private static func renderDepthMap(_ multiArray: MLMultiArray) -> UIImage? {
        let shape = multiArray.shape.map { $0.intValue }

        // Determine height and width from shape
        // Common shapes: [1, H, W], [H, W], [1, 1, H, W]
        let height: Int
        let width: Int

        switch shape.count {
        case 2:
            height = shape[0]
            width = shape[1]
        case 3:
            height = shape[1]
            width = shape[2]
        case 4:
            height = shape[2]
            width = shape[3]
        default:
            print("[DepthEstimator] Unexpected shape: \(shape)")
            return nil
        }

        let count = height * width
        guard count > 0 else { return nil }

        // Read values and find min/max for normalization
        var values = [Float](repeating: 0, count: count)

        for i in 0..<count {
            values[i] = multiArray[i].floatValue
        }

        guard let minVal = values.min(), let maxVal = values.max() else { return nil }
        let range = maxVal - minVal
        guard range > 0 else { return nil }

        // Generate RGBA pixels with turbo colormap
        var pixels = [UInt8](repeating: 0, count: count * 4)

        for i in 0..<count {
            let normalized = (values[i] - minVal) / range
            let (r, g, b) = turboColormap(normalized)
            let idx = i * 4
            pixels[idx] = r
            pixels[idx + 1] = g
            pixels[idx + 2] = b
            pixels[idx + 3] = 255
        }

        // Create CGImage
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

        return UIImage(cgImage: cgImage)
    }

    /// Turbo colormap: maps 0.0...1.0 to (R, G, B)
    /// Approximation of the Turbo colormap by Google
    private static func turboColormap(_ value: Float) -> (UInt8, UInt8, UInt8) {
        let v = max(0, min(1, value))

        // Simplified turbo colormap using piecewise linear interpolation
        let r: Float
        let g: Float
        let b: Float

        if v < 0.25 {
            let t = v / 0.25
            r = 0.18995 + t * (0.56293 - 0.18995)
            g = 0.07176 + t * (0.43110 - 0.07176)
            b = 0.23217 + t * (0.85802 - 0.23217)
        } else if v < 0.5 {
            let t = (v - 0.25) / 0.25
            r = 0.56293 + t * (0.95074 - 0.56293)
            g = 0.43110 + t * (0.81680 - 0.43110)
            b = 0.85802 + t * (0.24290 - 0.85802)
        } else if v < 0.75 {
            let t = (v - 0.5) / 0.25
            r = 0.95074 + t * (0.98320 - 0.95074)
            g = 0.81680 + t * (0.49673 - 0.81680)
            b = 0.24290 + t * (0.01239 - 0.24290)
        } else {
            let t = (v - 0.75) / 0.25
            r = 0.98320 + t * (0.53000 - 0.98320)
            g = 0.49673 + t * (0.13015 - 0.49673)
            b = 0.01239 + t * (0.20572 - 0.01239)
        }

        return (
            UInt8(max(0, min(255, r * 255))),
            UInt8(max(0, min(255, g * 255))),
            UInt8(max(0, min(255, b * 255)))
        )
    }
}
