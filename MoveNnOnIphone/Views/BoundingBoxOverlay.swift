import SwiftUI

/// Overlay that draws bounding boxes and labels for detected objects.
///
/// Converts Vision's normalized coordinates (origin at bottom-left)
/// to SwiftUI coordinates (origin at top-left) and accounts for
/// aspect-fill scaling between the video dimensions and the view.
struct BoundingBoxOverlay: View {
    let detections: [DetectedObject]
    let imageSize: CGSize // Original image/video dimensions

    var body: some View {
        GeometryReader { geometry in
            let viewSize = geometry.size
            let transform = aspectFillTransform(
                imageSize: imageSize,
                viewSize: viewSize
            )

            ForEach(detections) { detection in
                let rect = convertBoundingBox(
                    detection.boundingBox,
                    transform: transform,
                    viewSize: viewSize
                )

                // Bounding box rectangle
                Rectangle()
                    .stroke(colorForLabel(detection.label), lineWidth: 2.5)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)

                // Label background + text
                labelView(detection: detection)
                    .position(x: rect.midX, y: rect.minY - 12)
            }
        }
    }

    // MARK: - Label View

    private func labelView(detection: DetectedObject) -> some View {
        let percentage = Int(detection.confidence * 100)
        return Text("\(detection.label) \(percentage)%")
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(colorForLabel(detection.label).opacity(0.85))
            .cornerRadius(4)
    }

    // MARK: - Coordinate Conversion

    /// Compute scale and offset for aspect-fill mapping
    private func aspectFillTransform(
        imageSize: CGSize,
        viewSize: CGSize
    ) -> (scaleX: CGFloat, scaleY: CGFloat, offsetX: CGFloat, offsetY: CGFloat) {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return (1, 1, 0, 0)
        }

        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height

        let displayWidth: CGFloat
        let displayHeight: CGFloat

        if imageAspect > viewAspect {
            // Image wider than view → crop sides
            displayHeight = viewSize.height
            displayWidth = viewSize.height * imageAspect
        } else {
            // Image taller than view → crop top/bottom
            displayWidth = viewSize.width
            displayHeight = viewSize.width / imageAspect
        }

        let offsetX = (displayWidth - viewSize.width) / 2
        let offsetY = (displayHeight - viewSize.height) / 2

        return (displayWidth, displayHeight, offsetX, offsetY)
    }

    /// Convert Vision bounding box to view coordinates
    private func convertBoundingBox(
        _ box: CGRect,
        transform: (scaleX: CGFloat, scaleY: CGFloat, offsetX: CGFloat, offsetY: CGFloat),
        viewSize: CGSize
    ) -> CGRect {
        // Vision coordinates: origin at bottom-left, normalized 0..1
        // SwiftUI coordinates: origin at top-left, in points
        let x = box.origin.x * transform.scaleX - transform.offsetX
        let y = (1.0 - box.origin.y - box.size.height) * transform.scaleY - transform.offsetY
        let w = box.size.width * transform.scaleX
        let h = box.size.height * transform.scaleY

        return CGRect(x: x, y: y, width: w, height: h)
    }

    // MARK: - Color for Label

    /// Generate a consistent color for each label string
    private func colorForLabel(_ label: String) -> Color {
        let hash = abs(label.hashValue)
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.8, brightness: 0.9)
    }
}
