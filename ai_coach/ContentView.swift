import SwiftUI

struct ContentView: View {
    @State private var onboardingDone: Bool = PersistenceService.shared.onboardingComplete

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()

            if onboardingDone {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        onboardingDone = true
                    }
                }
                .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
