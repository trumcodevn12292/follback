import Foundation
import SwiftData

@Model
class Frame {
    var id: UUID
    var number: Int
    var photoAssetID: String?
    var aperture: Float?
    var shutterSpeed: String?
    var focusDistance: String?
    var flashUsed: Bool
    var locationName: String?
    var latitude: Double?
    var longitude: Double?
    var notes: String
    var capturedAt: Date?
    var createdAt: Date

    @Relationship(deleteRule: .nullify)
    var roll: Roll?

    init(
        id: UUID = UUID(),
        number: Int,
        roll: Roll? = nil,
        photoAssetID: String? = nil,
        aperture: Float? = nil,
        shutterSpeed: ShutterSpeed? = nil,
        focusDistance: String? = nil,
        flashUsed: Bool = false,
        locationName: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        notes: String = "",
        capturedAt: Date? = nil
    ) {
        self.id = id
        self.number = number
        self.roll = roll
        self.photoAssetID = photoAssetID
        self.aperture = aperture
        self.shutterSpeed = shutterSpeed?.rawValue
        self.focusDistance = focusDistance
        self.flashUsed = flashUsed
        self.locationName = locationName
        self.latitude = latitude
        self.longitude = longitude
        self.notes = notes
        self.capturedAt = capturedAt
        self.createdAt = Date()
    }

    var shutter: ShutterSpeed? {
        guard let raw = shutterSpeed else { return nil }
        return ShutterSpeed(rawValue: raw)
    }

    var apertureDisplay: String? {
        guard let a = aperture else { return nil }
        if let known = Aperture(rawValue: a) {
            return known.displayName
        }
        if abs(Double(a) - Double(a).rounded()) < 0.05 {
            return "f/\(Int(a.rounded()))"
        }
        return String(format: "f/%.1f", a)
    }

    var shutterDisplay: String? {
        shutter?.displayName
    }
}
