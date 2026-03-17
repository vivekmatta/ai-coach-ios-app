import SwiftUI

struct GlucoseInsightView: View {
    var onAskCoach: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🩸 Glucose Risk Estimate")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appText)
                Spacer()
                Text("Elevated Risk")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.appCoral)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.appCoral.opacity(0.15))
                    .cornerRadius(6)
            }

            Text("Biometric-based inference — no sensor required")
                .font(.system(size: 12))
                .foregroundColor(.appText.opacity(0.55))

            VStack(spacing: 8) {
                signalRow(color: .appCoral, label: "Sleep", note: "Poor sleep raises insulin resistance")
                signalRow(color: .appCoral, label: "Stress", note: "High cortisol elevates blood glucose")
                signalRow(color: .appAccent, label: "HRV",   note: "Low HRV correlates with glucose variability")
            }

            Text("No sensor required · qualitative estimate only")
                .font(.system(size: 11))
                .foregroundColor(.appText.opacity(0.35))

            Button(action: {
                onAskCoach("How does my sleep and stress affect my glucose stability? What should I do?")
            }) {
                Text("Ask Coach")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.appMint)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.appMint.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appMint.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.appCard)
        .cornerRadius(AppRadius.card)
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(Color.appBorder, lineWidth: 1))
    }

    private func signalRow(color: Color, label: String, note: String) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.appText)
            Text(note)
                .font(.system(size: 12))
                .foregroundColor(.appText.opacity(0.55))
            Spacer()
        }
    }
}
