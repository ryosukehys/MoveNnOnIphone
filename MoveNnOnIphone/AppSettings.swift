import SwiftUI

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @AppStorage("yoloConfidenceThreshold") var confidenceThreshold: Double = 0.5

    private init() {}
}
