import Foundation

struct CastMember: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
    let character: String
    let profilePath: String?

    var profileURL: URL? {
        guard let profilePath else { return nil }
        return AppConfiguration.tmdbProfileBaseURL.appending(path: profilePath)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, character
        case profilePath = "profile_path"
    }
}
