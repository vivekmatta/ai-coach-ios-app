import SwiftUI

struct TempDetailView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Temp–Glucose Connection", systemImage: "thermometer")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.appText)

                Text("High blood glucose can push body temperature upward — similar to a mild infection response. Currently **Normal**, meaning no elevated glucose signal today.")
                    .font(.system(size: 12))
                    .foregroundColor(.appText.opacity(0.65))
            }

            Divider().background(Color.appBorder)

            VStack(alignment: .leading, spacing: 8) {
                Label("Temp–Recovery Connection", systemImage: "heart.text.square")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.appText)

                Text("Slightly elevated temperature during sleep correlates with reduced HRV and poor deep sleep. Today's normal temp suggests no fever or illness as a recovery factor.")
                    .font(.system(size: 12))
                    .foregroundColor(.appText.opacity(0.65))
            }

            Divider().background(Color.appBorder)

            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .foregroundColor(.appText.opacity(0.4))
                Text("Future wearable sensor will provide continuous temperature readings")
                    .font(.system(size: 12))
                    .foregroundColor(.appText.opacity(0.45))
            }
            .padding(10)
            .background(Color.appBgSecondary)
            .cornerRadius(8)
        }
    }
}
