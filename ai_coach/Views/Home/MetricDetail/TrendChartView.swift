import SwiftUI

struct TrendChartView: View {
    let data: [Double]
    let color: Color
    var height: CGFloat = 100

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("14-Day Trend")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.appText.opacity(0.6))

            GeometryReader { geo in
                let pts = normalizedPoints(width: geo.size.width, height: height)
                if pts.count >= 2 {
                    ZStack(alignment: .topLeading) {
                        // Fill
                        Path { path in
                            path.move(to: CGPoint(x: pts[0].x, y: height))
                            for pt in pts { path.addLine(to: pt) }
                            path.addLine(to: CGPoint(x: pts.last!.x, y: height))
                        }
                        .fill(LinearGradient(
                            colors: [color.opacity(0.3), color.opacity(0)],
                            startPoint: .top, endPoint: .bottom
                        ))

                        // Line
                        Path { path in
                            path.move(to: pts[0])
                            for pt in pts.dropFirst() { path.addLine(to: pt) }
                        }
                        .stroke(color, lineWidth: 2)

                        // Last point dot
                        if let last = pts.last {
                            Circle()
                                .fill(color)
                                .frame(width: 8, height: 8)
                                .position(last)
                        }
                    }
                }
            }
            .frame(height: height)
        }
        .padding(.vertical, 8)
    }

    private func normalizedPoints(width: CGFloat, height: CGFloat) -> [CGPoint] {
        guard data.count >= 2 else { return [] }
        let minV = data.min()!
        let maxV = data.max()!
        let range = maxV - minV == 0 ? 1 : maxV - minV
        let step = width / CGFloat(data.count - 1)
        return data.enumerated().map { i, v in
            CGPoint(
                x: CGFloat(i) * step,
                y: height - CGFloat((v - minV) / range) * height * 0.85 - height * 0.075
            )
        }
    }
}
