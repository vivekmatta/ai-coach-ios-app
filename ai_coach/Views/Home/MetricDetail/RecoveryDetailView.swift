import SwiftUI

struct RecoveryDetailView: View {
    private let contributions: [(String, Double, Color)] = [
        ("HRV",   0.38, .appAccent),
        ("Sleep", 0.45, .appPurple),
        ("Stress",0.30, .appCoral),
        ("RHR",   0.72, .appMint)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recovery Contributors")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.appText)

            ForEach(contributions, id: \.0) { name, pct, color in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(name).font(.system(size: 12)).foregroundColor(.appText.opacity(0.7))
                        Spacer()
                        Text("\(Int(pct * 100))%")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(color)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4).fill(Color.appBorder).frame(height: 6)
                            RoundedRectangle(cornerRadius: 4).fill(color)
                                .frame(width: geo.size.width * pct, height: 6)
                        }
                    }
                    .frame(height: 6)
                }
            }

            Divider().background(Color.appBorder)

            Text("Recovery at 44/100 indicates red zone — hard training risks deepening your deficit. Prioritize sleep and light movement today.")
                .font(.system(size: 12))
                .foregroundColor(.appText.opacity(0.65))
        }
    }
}
