import SwiftUI

struct SleepDetailView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 20) {
                // Donut chart
                DonutChartView(
                    segments: [
                        DonutSegment(label: "Deep",  value: 0.18, color: .appAccent),
                        DonutSegment(label: "REM",   value: 0.22, color: .appPurple),
                        DonutSegment(label: "Light",  value: 0.45, color: Color(hex: "#2cb7b0")),
                        DonutSegment(label: "Awake",  value: 0.15, color: .appCoral.opacity(0.7))
                    ]
                )
                .frame(width: 110, height: 110)

                // Legend
                VStack(alignment: .leading, spacing: 6) {
                    legendRow(color: .appAccent,             label: "Deep",  pct: "18%")
                    legendRow(color: .appPurple,             label: "REM",   pct: "22%")
                    legendRow(color: Color(hex: "#2cb7b0"),  label: "Light", pct: "45%")
                    legendRow(color: .appCoral.opacity(0.7), label: "Awake", pct: "15%")
                }
            }

            Divider().background(Color.appBorder)

            VStack(spacing: 8) {
                infoRow("Bedtime", "11:14 PM")
                infoRow("Sleep onset", "~15 min")
                infoRow("Wake time", "5:00 AM")
                infoRow("Total sleep", "6.2 hrs")
                infoRow("Consistency streak", "3 days")
            }
        }
    }

    private func legendRow(color: Color, label: String, pct: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.system(size: 12)).foregroundColor(.appText.opacity(0.7))
            Spacer()
            Text(pct).font(.system(size: 12, weight: .semibold)).foregroundColor(.appText)
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundColor(.appText.opacity(0.6))
            Spacer()
            Text(value).font(.system(size: 12, weight: .semibold)).foregroundColor(.appText)
        }
    }
}

struct DonutSegment {
    let label: String
    let value: Double
    let color: Color
}

struct DonutChartView: View {
    let segments: [DonutSegment]

    var body: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 * 0.9
            let inner  = radius * 0.55
            var start: Double = -90

            for seg in segments {
                let sweep = seg.value * 360
                var path = Path()
                path.addArc(center: center, radius: radius,
                            startAngle: .degrees(start),
                            endAngle:   .degrees(start + sweep),
                            clockwise: false)
                path.addArc(center: center, radius: inner,
                            startAngle: .degrees(start + sweep),
                            endAngle:   .degrees(start),
                            clockwise: true)
                path.closeSubpath()
                ctx.fill(path, with: .color(seg.color))
                start += sweep
            }
        }
    }
}
