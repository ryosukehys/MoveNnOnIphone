import Foundation

// MARK: - Device Memory Helper

enum DeviceCapability {
    /// Device physical memory in GB
    static var memoryGB: Double {
        Double(ProcessInfo.processInfo.physicalMemory) / (1024 * 1024 * 1024)
    }

    /// Estimated model memory usage in MB for a given model
    static func estimatedMemoryMB(for modelFileName: String) -> Int {
        switch modelFileName {
        case "yolov8n": return 25
        case "yolov8s": return 45
        case "yolov8m": return 100
        case "yolov8x": return 260
        case "DepthAnythingV2SmallF16": return 200
        case "DepthAnythingV2BaseF16": return 400
        case "DepthAnythingV2LargeF16": return 1200
        case "DeepLabV3": return 20
        case "DeepLabV3FP16": return 10
        case "DeepLabV3Int8LUT": return 5
        default: return 100
        }
    }

    /// Whether the device can safely run a model (needs ~50% of RAM free for system)
    static func canRun(modelFileName: String) -> Bool {
        let requiredMB = estimatedMemoryMB(for: modelFileName)
        let availableMB = Int(memoryGB * 1024 * 0.5) // Use at most 50% of total RAM
        return requiredMB < availableMB
    }

    /// Warning message if the model may be too large
    static func memoryWarning(for modelFileName: String) -> String? {
        let requiredMB = estimatedMemoryMB(for: modelFileName)
        let totalMB = Int(memoryGB * 1024)

        if requiredMB > Int(Double(totalMB) * 0.4) {
            return "このモデルはデバイスのメモリ(\(totalMB)MB)に対して大きすぎる可能性があります（推定\(requiredMB)MB使用）。アプリがクラッシュする場合は軽量モデルをお使いください。"
        }
        return nil
    }
}

// MARK: - YOLO Variants

enum YOLOVariant: String, CaseIterable, Identifiable, Codable {
    case nano = "yolov8n"
    case small = "yolov8s"
    case medium = "yolov8m"
    case extraLarge = "yolov8x"

    var id: String { rawValue }

    var modelFileName: String { rawValue }

    var displayName: String {
        switch self {
        case .nano: return "YOLOv8n (Nano)"
        case .small: return "YOLOv8s (Small)"
        case .medium: return "YOLOv8m (Medium)"
        case .extraLarge: return "YOLOv8x (Extra Large)"
        }
    }

    var description: String {
        switch self {
        case .nano: return "最速・軽量。リアルタイム向き"
        case .small: return "速度と精度のバランス型"
        case .medium: return "高精度。やや遅い"
        case .extraLarge: return "最高精度。処理が重い"
        }
    }

    var isAvailable: Bool {
        ModelDownloadManager.shared.modelURL(fileName: modelFileName) != nil
    }

    var canRunOnDevice: Bool {
        DeviceCapability.canRun(modelFileName: modelFileName)
    }

    var memoryWarning: String? {
        DeviceCapability.memoryWarning(for: modelFileName)
    }

    var downloadState: ModelDownloadState {
        ModelDownloadManager.shared.state(for: modelFileName)
    }
}

// MARK: - Depth Model Variants

enum DepthModelVariant: String, CaseIterable, Identifiable, Codable {
    case smallF16 = "DepthAnythingV2SmallF16"
    case baseF16 = "DepthAnythingV2BaseF16"
    case largeF16 = "DepthAnythingV2LargeF16"

    var id: String { rawValue }

    var modelFileName: String { rawValue }

    var displayName: String {
        switch self {
        case .smallF16: return "Depth Anything V2 Small (F16)"
        case .baseF16: return "Depth Anything V2 Base (F16)"
        case .largeF16: return "Depth Anything V2 Large (F16)"
        }
    }

    var description: String {
        switch self {
        case .smallF16: return "軽量・高速。約100MB"
        case .baseF16: return "バランス型。約200MB"
        case .largeF16: return "最高精度。約600MB"
        }
    }

    var isAvailable: Bool {
        ModelDownloadManager.shared.modelURL(fileName: modelFileName) != nil
    }

    var canRunOnDevice: Bool {
        DeviceCapability.canRun(modelFileName: modelFileName)
    }

    var memoryWarning: String? {
        DeviceCapability.memoryWarning(for: modelFileName)
    }

    var downloadState: ModelDownloadState {
        ModelDownloadManager.shared.state(for: modelFileName)
    }
}

// MARK: - Segmentation Model Variants

enum SegmentationModelVariant: String, CaseIterable, Identifiable, Codable {
    case deeplabV3 = "DeepLabV3"
    case deeplabV3FP16 = "DeepLabV3FP16"
    case deeplabV3Int8LUT = "DeepLabV3Int8LUT"

    var id: String { rawValue }

    var modelFileName: String { rawValue }

    var displayName: String {
        switch self {
        case .deeplabV3: return "DeepLabV3 (Full)"
        case .deeplabV3FP16: return "DeepLabV3 (FP16)"
        case .deeplabV3Int8LUT: return "DeepLabV3 (Int8)"
        }
    }

    var description: String {
        switch self {
        case .deeplabV3: return "最高精度。8.6MB"
        case .deeplabV3FP16: return "精度と速度のバランス。4.3MB"
        case .deeplabV3Int8LUT: return "最軽量・最速。2.3MB"
        }
    }

    var isAvailable: Bool {
        ModelDownloadManager.shared.modelURL(fileName: modelFileName) != nil
    }

    var canRunOnDevice: Bool {
        DeviceCapability.canRun(modelFileName: modelFileName)
    }

    var memoryWarning: String? {
        DeviceCapability.memoryWarning(for: modelFileName)
    }

    var downloadState: ModelDownloadState {
        ModelDownloadManager.shared.state(for: modelFileName)
    }
}

// MARK: - Model Categories

enum ModelCategory: String, CaseIterable {
    case objectDetection
    case depthEstimation
    case semanticSegmentation

    var displayName: String {
        switch self {
        case .objectDetection: return "物体検出"
        case .depthEstimation: return "深度推定"
        case .semanticSegmentation: return "セマンティックセグメンテーション"
        }
    }
}
