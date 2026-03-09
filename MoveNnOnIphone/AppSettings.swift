import SwiftUI

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @AppStorage("yoloConfidenceThreshold") var confidenceThreshold: Double = 0.5
    @AppStorage("selectedYOLOVariant") var selectedYOLOVariant: String = YOLOVariant.nano.rawValue
    @AppStorage("selectedDepthModel") var selectedDepthModel: String = DepthModelVariant.smallF16.rawValue
    @AppStorage("selectedSegmentationModel") var selectedSegmentationModel: String = SegmentationModelVariant.deeplabV3FP16.rawValue

    var yoloVariant: YOLOVariant {
        YOLOVariant(rawValue: selectedYOLOVariant) ?? .nano
    }

    var depthVariant: DepthModelVariant {
        DepthModelVariant(rawValue: selectedDepthModel) ?? .smallF16
    }

    var segmentationVariant: SegmentationModelVariant {
        SegmentationModelVariant(rawValue: selectedSegmentationModel) ?? .deeplabV3FP16
    }

    private init() {}
}
