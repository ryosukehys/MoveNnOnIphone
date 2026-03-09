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
        Bundle.main.url(forResource: modelFileName, withExtension: "mlmodelc") != nil
    }
}

// MARK: - Depth Model Variants

enum DepthModelVariant: String, CaseIterable, Identifiable, Codable {
    case smallF16 = "DepthAnythingV2SmallF16"

    var id: String { rawValue }

    var modelFileName: String { rawValue }

    var displayName: String {
        switch self {
        case .smallF16: return "Depth Anything V2 Small (F16)"
        }
    }

    var description: String {
        switch self {
        case .smallF16: return "軽量・高速な深度推定モデル"
        }
    }

    var isAvailable: Bool {
        Bundle.main.url(forResource: modelFileName, withExtension: "mlmodelc") != nil
    }
}

// MARK: - Model Categories

enum ModelCategory: String, CaseIterable {
    case objectDetection
    case depthEstimation
    // 将来: .semanticSegmentation, .poseEstimation

    var displayName: String {
        switch self {
        case .objectDetection: return "物体検出"
        case .depthEstimation: return "深度推定"
        }
    }
}
