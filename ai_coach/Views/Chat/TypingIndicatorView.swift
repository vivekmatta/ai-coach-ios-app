import SwiftUI

struct TypingIndicatorView: View {
    @State private var phase: Double = 0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.appAccent)
                    .frame(width: 8, height: 8)
                    .offset(y: dotOffset(index: i))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.appCard)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.appBorder, lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever().delay(0)) {
                phase = 1
            }
        }
    }

    private func dotOffset(index: Int) -> CGFloat {
        let delay = Double(index) * 0.2
        let t = (phase + delay).truncatingRemainder(dividingBy: 1.0)
        return -CGFloat(sin(t * .pi * 2)) * 4
    }
}
