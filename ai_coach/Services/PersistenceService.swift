import Foundation

final class PersistenceService {
    static let shared = PersistenceService()
    private init() {}

    private let defaults = UserDefaults.standard

    // MARK: – Onboarding
    var onboardingComplete: Bool {
        get { defaults.bool(forKey: "onboardingComplete") }
        set { defaults.set(newValue, forKey: "onboardingComplete") }
    }

    // MARK: – User Profile
    var userProfile: UserProfile {
        get {
            guard let data = defaults.data(forKey: "userProfile"),
                  let p = try? JSONDecoder().decode(UserProfile.self, from: data) else {
                return UserProfile()
            }
            return p
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "userProfile")
            }
        }
    }

    // MARK: – Vector DB built flag
    var vectorDBBuilt: Bool {
        get { defaults.bool(forKey: "vectorDBBuilt") }
        set { defaults.set(newValue, forKey: "vectorDBBuilt") }
    }

    // MARK: – Reset
    func resetAll() {
        let keys = ["onboardingComplete", "userProfile", "vectorDBBuilt"]
        keys.forEach { defaults.removeObject(forKey: $0) }
    }
}
