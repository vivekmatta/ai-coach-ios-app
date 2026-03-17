import SwiftUI

struct HealthLogView: View {
    @ObservedObject var vm: ActivityViewModel
    @State private var expandedEntry: UUID? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Collapsible header
            Button(action: { withAnimation { vm.healthLogExpanded.toggle() } }) {
                HStack {
                    Text("Health Log")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.appText)
                    Spacer()
                    Image(systemName: vm.healthLogExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13))
                        .foregroundColor(.appText.opacity(0.5))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.appCard)
                .cornerRadius(vm.healthLogExpanded ? 0 : AppRadius.card)
                .cornerRadius(AppRadius.card, corners: [.topLeft, .topRight])
            }
            .buttonStyle(.plain)

            if vm.healthLogExpanded {
                VStack(spacing: 0) {
                    // Column headers
                    HStack(spacing: 4) {
                        Text("Date").frame(width: 52, alignment: .leading)
                        Text("HRV").frame(minWidth: 36, alignment: .leading)
                        Text("Sleep").frame(minWidth: 44, alignment: .leading)
                        Text("Rec.").frame(minWidth: 44, alignment: .leading)
                        Text("RHR").frame(minWidth: 46, alignment: .leading)
                        Text("Steps").frame(minWidth: 48, alignment: .leading)
                        Text("Stress").frame(minWidth: 50, alignment: .trailing)
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.appText.opacity(0.5))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.appBgSecondary)

                    ForEach(vm.healthLog) { entry in
                        VStack(spacing: 0) {
                            Button(action: {
                                withAnimation { expandedEntry = expandedEntry == entry.id ? nil : entry.id }
                            }) {
                                HStack(spacing: 4) {
                                    Text(shortDate(entry.date)).frame(width: 52, alignment: .leading)
                                    Text(entry.hrv).frame(minWidth: 36, alignment: .leading)
                                    Text(entry.sleep).frame(minWidth: 44, alignment: .leading)
                                    Text(entry.recovery).frame(minWidth: 44, alignment: .leading)
                                    Text(entry.rhr).frame(minWidth: 46, alignment: .leading)
                                    Text(entry.steps).frame(minWidth: 48, alignment: .leading)
                                    Text(entry.stress).frame(minWidth: 50, alignment: .trailing)
                                }
                                .font(.system(size: 11))
                                .foregroundColor(.appText.opacity(0.8))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                            }
                            .buttonStyle(.plain)

                            if expandedEntry == entry.id {
                                Text(entry.notes)
                                    .font(.system(size: 12))
                                    .foregroundColor(.appText.opacity(0.65))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 14)
                                    .padding(.bottom, 8)
                            }

                            Divider().background(Color.appBorder)
                        }
                    }
                }
                .background(Color.appCard)
                .cornerRadius(AppRadius.card, corners: [.bottomLeft, .bottomRight])
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(Color.appBorder, lineWidth: 1)
        )
    }

    private func shortDate(_ s: String) -> String {
        let parts = s.split(separator: " ")
        guard parts.count == 2 else { return s }
        let month = String(parts[0].prefix(3))
        return "\(month) \(parts[1])"
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
