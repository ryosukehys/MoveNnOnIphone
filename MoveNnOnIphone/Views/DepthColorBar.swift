import SwiftUI

struct DepthColorBar: View {
    // Turbo colormap key stops matching DepthEstimator.turboColormap()
    private static let gradientStops: [Gradient.Stop] = [
        .init(color: Color(red: 0.190, green: 0.072, blue: 0.232), location: 0.00),
        .init(color: Color(red: 0.563, green: 0.431, blue: 0.858), location: 0.25),
        .init(color: Color(red: 0.951, green: 0.817, blue: 0.243), location: 0.50),
        .init(color: Color(red: 0.983, green: 0.497, blue: 0.012), location: 0.75),
        .init(color: Color(red: 0.530, green: 0.130, blue: 0.206), location: 1.00),
    ]

    var body: some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        stops: Self.gradientStops,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 12)

            HStack {
                Text("遠い")
                    .font(.caption2)
                    .fontWeight(.medium)
                Spacer()
                Text("近い")
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.black.opacity(0.5))
        .cornerRadius(8)
    }
}
