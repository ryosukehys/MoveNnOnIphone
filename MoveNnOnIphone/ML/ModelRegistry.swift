import Foundation

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
