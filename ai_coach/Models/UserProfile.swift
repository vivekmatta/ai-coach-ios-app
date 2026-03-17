import Foundation

struct UserProfile: Codable, Equatable {
    var name: String         = ""
    var goals: String        = ""
    var exerciseDays: String = ""
    var exerciseType: String = ""
    var sleepTime: String    = ""
    var caffeine: String     = ""
    var workStress: String   = ""

    var firstName: String {
        name.split(separator: " ").first.map(String.init) ?? name
    }

    var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }
}
