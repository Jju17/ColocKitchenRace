import Foundation

enum CKREnvironment {
    private static let productionProjectId = "colocskitchenrace-prod"

    static var isProduction: Bool {
        guard let plistPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: plistPath),
              let projectId = plist["PROJECT_ID"] as? String else {
            return false
        }
        return projectId == productionProjectId
    }

    static var fcmTopicAllUsers: String {
        isProduction ? "all_users_prod" : "all_users_staging"
    }

    /// Prefix for edition-specific FCM topics (e.g. "edition_{gameId}_prod").
    static var fcmTopicPrefix: String {
        ""  // edition topics are formatted as "edition_{gameId}_{env}" by the server
    }

    /// Build the full FCM topic name for a specific edition.
    static func fcmTopicEdition(_ gameId: String) -> String {
        let env = isProduction ? "prod" : "staging"
        return "edition_\(gameId)_\(env)"
    }
}
