import Foundation
import SwiftUI

/// A lab the user adds by hand (name, optional description, optional avatar image).
/// Stored in UserDefaults via `CustomLabStore` (same approach as `CustomFilm`),
/// so it survives reinstall through the JSON backup.
struct CustomLab: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var labDescription: String
    var avatarImageData: Data?

    init(id: String = UUID().uuidString, name: String, labDescription: String = "", avatarImageData: Data? = nil) {
        self.id = id
        self.name = name
        self.labDescription = labDescription
        self.avatarImageData = avatarImageData
    }
}

final class CustomLabStore: ObservableObject {
    static let shared = CustomLabStore()
    @Published var labs: [CustomLab] = []

    private let key = "customLabs"

    init() { load() }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([CustomLab].self, from: data) else { return }
        labs = decoded
    }

    func save() {
        if let data = try? JSONEncoder().encode(labs) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func add(_ lab: CustomLab) {
        labs.append(lab)
        save()
    }

    func update(_ lab: CustomLab) {
        if let idx = labs.firstIndex(where: { $0.id == lab.id }) {
            labs[idx] = lab
            save()
        }
    }

    func remove(_ lab: CustomLab) {
        labs.removeAll { $0.id == lab.id }
        save()
    }

    func lab(named name: String) -> CustomLab? {
        labs.first { $0.name == name }
    }
}
