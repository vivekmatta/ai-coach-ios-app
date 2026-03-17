import SwiftUI

struct RHRDetailView: View {
    private let actual:   [Double] = [51,52,54,56,55,57,58,59,58,57,56,58]
    private let baseline: [Double] = [52,52,52,52,52,52,52,52,52,52,52,52]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Dual-line chart
            Text("Actual RHR vs Baseline")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.appText)

            GeometryReader { geo in
                let actualPts  = points(actual,   width: geo.size.width, height: 80)
                let baselinePts = points(baseline, width: geo.size.width, height: 80)

                ZStack {
                    Path { p in
                        guard !baselinePts.isEmpty else { return }
                        p.move(to: baselinePts[0])
                        baselinePts.dropFirst().forEach { p.addLine(to: $0) }
                    }
                    .stroke(Color.appMint.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [5,3]))

                    Path { p in
                        guard !actualPts.isEmpty else { return }
                        p.move(to: actualPts[0])
                        actualPts.dropFirst().forEach { p.addLine(to: $0) }
                    }
                    .stroke(Color.appPurple, lineWidth: 2)
                }
            }
            .frame(height: 80)

            HStack(spacing: 16) {
                legendDot(color: .appPurple, label: "Actual RHR")
                legendDot(color: .appMint.opacity(0.5), label: "Baseline 52 bpm")
            }

            Divider().background(Color.appBorder)

            Text("Elevated RHR (+12% above baseline) is a classic sign of incomplete recovery or sympathetic nervous system dominance. For endurance athletes, every beat above baseline matters.")
                .font(.system(size: 12))
                .foregroundColor(.appText.opacity(0.65))
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.system(size: 11)).foregroundColor(.appText.opacity(0.6))
        }
    }

    private func points(_ data: [Double], width: CGFloat, height: CGFloat) -> [CGPoint] {
        guard data.count >= 2 else { return [] }
        let all = actual + baseline
        let minV = all.min()! - 1
        let maxV = all.max()! + 1
        let range = maxV - minV
        let step = width / CGFloat(data.count - 1)
        return data.enumerated().map { i, v in
            CGPoint(x: CGFloat(i) * step,
                    y: height - CGFloat((v - minV) / range) * height * 0.85 - height * 0.075)
        }
    }
}
