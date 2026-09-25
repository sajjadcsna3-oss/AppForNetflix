import Foundation
import SwiftData

@Model
final class LibraryCollection {
    @Attribute(.unique) var id: UUID
    var name: String
    var movieIDs: [Int]
    var createdAt: Date
    var updatedAt: Date

    init(name: String, movieIDs: [Int] = [], createdAt: Date = .now) {
        self.id = UUID()
        self.name = name
        self.movieIDs = Array(Set(movieIDs))
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    func contains(movieID: Int) -> Bool {
        movieIDs.contains(movieID)
    }
}
