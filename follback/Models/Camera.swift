import Foundation
import SwiftData

@Model
class Camera {
    var id: UUID
    var name: String
    var brand: String
    var format: String
    var type: String
    var fixedFocalLength: Int?
    var photoAssetID: String?
    var notes: String
    var addedAt: Date

    @Relationship(inverse: \Roll.camera)
    var rolls: [Roll]?

    init(
        id: UUID = UUID(),
        name: String,
        brand: String,
        format: FilmFormat = .mm35,
        type: CameraType = .slr,
        fixedFocalLength: Int? = nil,
        photoAssetID: String? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.format = format.rawValue
        self.type = type.rawValue
        self.fixedFocalLength = fixedFocalLength
        self.photoAssetID = photoAssetID
        self.notes = notes
        self.addedAt = Date()
    }

    var filmFormat: FilmFormat {
        FilmFormat(rawValue: format) ?? .mm35
    }

    var cameraType: CameraType {
        CameraType(rawValue: type) ?? .slr
    }
}
