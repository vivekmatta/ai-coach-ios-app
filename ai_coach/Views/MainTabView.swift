import SwiftUI

struct MainTabView: View {
    @StateObject private var chatVM = ChatViewModel()
    @State private var selectedTab: Int = 0

    var profile: UserProfile { PersistenceService.shared.userProfile }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView(chatVM: chatVM)
                    .navigationTitle(headerTitle)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarColorScheme(.dark, for: .navigationBar)
                    .toolbar { profileToolbarItem }
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(0)

            NavigationStack {
                ActivityView()
                    .navigationTitle("Activity Log")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarColorScheme(.dark, for: .navigationBar)
                    .toolbar { profileToolbarItem }
            }
            .tabItem {
                Label("Activity", systemImage: "chart.bar.fill")
            }
            .tag(1)

            NavigationStack {
                PlanView { refineText in
                    chatVM.prefill(refineText)
                    selectedTab = 0  // switch to Home where chat is
                }
                .navigationTitle("Personalized Plan")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbar { profileToolbarItem }
            }
            .tabItem {
                Label("Plan", systemImage: "list.clipboard.fill")
            }
            .tag(2)
        }
        .preferredColorScheme(.dark)
        .tint(.appAccent)
    }

    private var headerTitle: String {
        let firstName = profile.firstName
        return firstName.isEmpty ? "Today's Dashboard" : "Hey \(firstName) 👋"
    }

    private var profileToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            NavigationLink(destination: ProfileSettingsView()) {
                ZStack {
                    Circle()
                        .fill(Color.appAccent.opacity(0.2))
                        .frame(width: 32, height: 32)
                    Text(profile.initials.isEmpty ? "?" : profile.initials)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.appAccent)
                }
            }
        }
    }
}

// MARK: – Profile / Settings mini screen
struct ProfileSettingsView: View {
    @State private var apiKey: String = UserDefaults.standard.string(forKey: "geminiAPIKey") ?? ""
    @State private var showResetConfirm = false

    var profile: UserProfile { PersistenceService.shared.userProfile }

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()

            Form {
                Section("Profile") {
                    LabeledContent("Name",  value: profile.name.isEmpty  ? "—" : profile.name)
                    LabeledContent("Goals", value: profile.goals.isEmpty  ? "—" : profile.goals)
                    LabeledContent("Exercise \(profile.exerciseDays) days/wk", value: profile.exerciseType)
                }

                Section("API Key") {
                    SecureField("Gemini API Key", text: $apiKey)
                        .foregroundColor(.appText)
                        .onSubmit { saveAPIKey() }

                    Button("Save Key", action: saveAPIKey)
                        .foregroundColor(.appAccent)
                }

                Section("Reset") {
                    Button("Reset Onboarding", role: .destructive) {
                        showResetConfirm = true
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Profile & Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Reset onboarding?", isPresented: $showResetConfirm) {
            Button("Reset", role: .destructive) {
                PersistenceService.shared.resetAll()
                Task { await VectorDBService.shared.reset() }
                // Force app restart behavior by navigating to root
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will clear your profile and restart the onboarding flow on next launch.")
        }
    }

    private func saveAPIKey() {
        GeminiService.shared.setAPIKey(apiKey)
    }
}
