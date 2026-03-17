import SwiftUI

struct HRVDetailView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Autonomic balance bar
            VStack(alignment: .leading, spacing: 8) {
                Text("Autonomic Balance")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.appText)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.appMint.opacity(0.3))
                            .frame(height: 12)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.appCoral.opacity(0.7))
                            .frame(width: geo.size.width * 0.65, height: 12)
                    }
                }
                .frame(height: 12)

                HStack {
                    Text("Sympathetic 65%")
                        .font(.system(size: 11))
                        .foregroundColor(.appCoral)
                    Spacer()
                    Text("Parasympathetic 35%")
                        .font(.system(size: 11))
                        .foregroundColor(.appMint)
                }
            }

            Divider().background(Color.appBorder)

            // 7-day table
            VStack(alignment: .leading, spacing: 6) {
                Text("7-Day HRV Readings")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.appText)

                ForEach([
                    ("Mar 6", "39ms"), ("Mar 7", "37ms"), ("Mar 8", "38ms"),
                    ("Mar 9", "38ms"), ("Mar 10", "39ms"), ("Mar 11", "40ms"), ("Mar 12", "38ms")
                ], id: \.0) { date, val in
                    HStack {
                        Text(date).font(.system(size: 12)).foregroundColor(.appText.opacity(0.6))
                        Spacer()
                        Text(val).font(.system(size: 12, weight: .semibold)).foregroundColor(.appAccent)
                    }
                }
            }

            Divider().background(Color.appBorder)

            VStack(alignment: .leading, spacing: 6) {
                Text("Contributing Factors")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.appText)

                ForEach([
                    "Accumulated training load (3 weeks build phase)",
                    "Poor sleep quality last 5 nights (avg 65/100)",
                    "Work stress driving cortisol elevation",
                    "Early 5am wake-up disrupting recovery window"
                ], id: \.self) { factor in
                    Label(factor, systemImage: "circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.appText.opacity(0.7))
                        .labelStyle(BulletLabelStyle())
                }
            }
        }
    }
}
