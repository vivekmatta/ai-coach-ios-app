import SwiftUI

struct SparklineView: View {
    let data: [Double]
    let color: Color
    var height: CGFloat = 36
    var lineWidth: CGFloat = 1.5

    var body: some View {
        GeometryReader { geo in
            let pts = normalizedPoints(width: geo.size.width, height: geo.size.height)
            if pts.count >= 2 {
                // Fill area
                Path { path in
                    path.move(to: CGPoint(x: pts[0].x, y: geo.size.height))
                    for pt in pts { path.addLine(to: pt) }
                    path.addLine(to: CGPoint(x: pts.last!.x, y: geo.size.height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(colors: [color.opacity(0.3), color.opacity(0)],
                                   startPoint: .top, endPoint: .bottom)
                )

                // Line
                Path { path in
                    path.move(to: pts[0])
                    for pt in pts.dropFirst() { path.addLine(to: pt) }
                }
                .stroke(color, lineWidth: lineWidth)
            }
        }
        .frame(height: height)
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
