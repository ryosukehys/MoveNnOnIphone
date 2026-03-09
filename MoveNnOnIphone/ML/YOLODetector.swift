import Vision
import CoreML
import UIKit

struct DetectedObject: Identifiable {
    let id = UUID()
    let label: String
    let confidence: Float
    /// Bounding box in Vision normalized coordinates (origin at bottom-left)
    let boundingBox: CGRect
}

final class YOLODetector: ObservableObject {
    private var model: VNCoreMLModel?
    @Published var isModelLoaded = false
    private(set) var currentVariant: YOLOVariant

    init(variant: YOLOVariant = .nano) {
        currentVariant = variant
        loadModel()
    }

    func switchModel(to variant: YOLOVariant) {
        guard variant != currentVariant else { return }
        currentVariant = variant
        model = nil
        DispatchQueue.main.async {
            self.isModelLoaded = false
        }
        loadModel()
    }

    private func loadModel() {
        guard let modelURL = Bundle.main.url(forResource: currentVariant.modelFileName, withExtension: "mlmodelc") else {
            print("[YOLODetector] \(currentVariant.modelFileName).mlmodelc not found in bundle")
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
            print("[YOLODetector] Model loaded successfully")
        } catch {
            print("[YOLODetector] Failed to load model: \(error)")
        }
    }

    /// Detect objects in a CVPixelBuffer (for real-time mode)
    func detect(pixelBuffer: CVPixelBuffer, confidenceThreshold: Float) async -> [DetectedObject] {
        guard let model else { return [] }

        return await withCheckedContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { request, error in
                let detections = Self.parseResults(request.results, threshold: confidenceThreshold)
                continuation.resume(returning: detections)
            }
            request.imageCropAndScaleOption = .scaleFill

            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
            do {
                try handler.perform([request])
            } catch {
                print("[YOLODetector] Inference error: \(error)")
                continuation.resume(returning: [])
            }
        }
    }

    /// Detect objects in a UIImage (for photo mode)
    func detect(image: UIImage, confidenceThreshold: Float) async -> [DetectedObject] {
        guard let model, let cgImage = image.cgImage else { return [] }

        return await withCheckedContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { request, error in
                let detections = Self.parseResults(request.results, threshold: confidenceThreshold)
                continuation.resume(returning: detections)
            }
            request.imageCropAndScaleOption = .scaleFill

            let orientation = CGImagePropertyOrientation(image.imageOrientation)
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
            do {
                try handler.perform([request])
            } catch {
                print("[YOLODetector] Inference error: \(error)")
                continuation.resume(returning: [])
            }
        }
    }

    private static func parseResults(_ results: [Any]?, threshold: Float) -> [DetectedObject] {
        guard let observations = results as? [VNRecognizedObjectObservation] else { return [] }

        return observations.compactMap { observation in
            guard let topLabel = observation.labels.first,
                  topLabel.confidence >= threshold else { return nil }

            return DetectedObject(
                label: topLabel.identifier,
                confidence: topLabel.confidence,
                boundingBox: observation.boundingBox
            )
        }
    }
}

// MARK: - CGImagePropertyOrientation helper

extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
