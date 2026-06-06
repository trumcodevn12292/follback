import Foundation
import SwiftData

// MARK: - V1 — Initial schema (shipped in 1.0.x)

enum FilmVaultSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version = .init(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [RollV1.self, FrameV1.self, CameraV1.self, CustomFilmModelV1.self]
    }

    @Model
    final class RollV1 {
        var id: UUID
        var filmName: String
        var capacity: Int
        var iso: Int
        var format: String
        var evCompensation: Float
        var pushPull: Float
        var startDate: Date
        var status: String
        var notes: String
        var locationName: String?
        var latitude: Double?
        var longitude: Double?
        var labName: String?
        var driveFolderLink: String?
        var createdAt: Date
        var updatedAt: Date
        var devDeveloper: String?
        var devDilution: String?
        var devTempC: Double?
        var devTimeSeconds: Int?
        var devAgitation: String?
        var devNotes: String?
        var developedDate: Date?
        var isHalfFrame: Bool = false
        var filmCost: Double?
        var devCost: Double?

        @Relationship(deleteRule: .nullify)
        var camera: CameraV1?

        @Relationship(deleteRule: .cascade, inverse: \FrameV1.roll)
        var frames: [FrameV1]?

        init(
            id: UUID = UUID(),
            filmName: String,
            camera: CameraV1? = nil,
            capacity: Int = 36,
            iso: Int = 400,
            format: String = "35mm",
            evCompensation: Float = 0,
            pushPull: Float = 0,
            startDate: Date = Date(),
            status: String = "In Progress",
            notes: String = "",
            locationName: String? = nil,
            latitude: Double? = nil,
            longitude: Double? = nil,
            labName: String? = nil
        ) {
            self.id = id
            self.filmName = filmName
            self.capacity = capacity
            self.iso = iso
            self.format = format
            self.evCompensation = evCompensation
            self.pushPull = pushPull
            self.startDate = startDate
            self.status = status
            self.notes = notes
            self.locationName = locationName
            self.latitude = latitude
            self.longitude = longitude
            self.labName = labName
            self.createdAt = Date()
            self.updatedAt = Date()
            self.camera = camera
        }
    }

    @Model
    final class FrameV1 {
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
        var roll: RollV1?

        init(
            id: UUID = UUID(),
            number: Int,
            roll: RollV1? = nil,
            photoAssetID: String? = nil,
            aperture: Float? = nil,
            shutterSpeed: String? = nil,
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
            self.shutterSpeed = shutterSpeed
            self.focusDistance = focusDistance
            self.flashUsed = flashUsed
            self.locationName = locationName
            self.latitude = latitude
            self.longitude = longitude
            self.notes = notes
            self.capturedAt = capturedAt
            self.createdAt = Date()
        }
    }

    @Model
    final class CameraV1 {
        var id: UUID
        var name: String
        var brand: String
        var format: String
        var type: String
        var fixedFocalLength: Int?
        var photoAssetID: String?
        var notes: String
        var lens: String?
        var addedAt: Date
        var purchasePrice: Double?

        @Relationship(inverse: \RollV1.camera)
        var rolls: [RollV1]?

        init(
            id: UUID = UUID(),
            name: String,
            brand: String,
            format: String = "35mm",
            type: String = "SLR",
            fixedFocalLength: Int? = nil,
            photoAssetID: String? = nil,
            notes: String = "",
            lens: String? = nil
        ) {
            self.id = id
            self.name = name
            self.brand = brand
            self.format = format
            self.type = type
            self.fixedFocalLength = fixedFocalLength
            self.photoAssetID = photoAssetID
            self.notes = notes
            self.lens = lens
            self.addedAt = Date()
        }
    }

    @Model
    final class CustomFilmModelV1 {
        var id: String
        var name: String
        var brand: String = ""
        var iso: Int
        var filmType: String
        var format: String = "35mm"
        var coverImageData: Data?
        var createdAt: Date

        init(
            id: String = UUID().uuidString,
            name: String,
            brand: String = "",
            iso: Int = 400,
            filmType: String = "COLOR_NEGATIVE",
            format: String = "35mm",
            coverImageData: Data? = nil
        ) {
            self.id = id
            self.name = name
            self.brand = brand
            self.iso = iso
            self.filmType = filmType
            self.format = format
            self.coverImageData = coverImageData
            self.createdAt = Date()
        }
    }
}

// MARK: - Migration Plan

enum FilmVaultMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [FilmVaultSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
