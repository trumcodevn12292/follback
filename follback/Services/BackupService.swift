import Foundation
import SwiftData
import UniformTypeIdentifiers
import SwiftUI

// MARK: - Codable DTOs

struct FrameBackup: Codable {
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
}

struct CameraBackup: Codable {
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
}

struct RollBackup: Codable {
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
    var cameraID: UUID?
    var frames: [FrameBackup]
    // Development recipe (optional for backward compatibility)
    var devDeveloper: String?
    var devDilution: String?
    var devTempC: Double?
    var devTimeSeconds: Int?
    var devAgitation: String?
    var devNotes: String?
    var developedDate: Date?
}

struct FilmVaultBackup: Codable {
    var schemaVersion: Int
    var appVersion: String
    var exportedAt: Date
    var rolls: [RollBackup]
    var cameras: [CameraBackup]
    var customFilms: [CustomFilm]
}

struct BackupImportSummary {
    var rollsAdded: Int
    var camerasAdded: Int
    var customFilmsAdded: Int
}

// MARK: - Service

enum BackupService {
    static let currentSchemaVersion = 1

    static func appVersionString() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    // MARK: Export

    static func makeBackup(rolls: [Roll], cameras: [Camera]) -> FilmVaultBackup {
        let rollBackups: [RollBackup] = rolls.map { roll in
            let frames = (roll.frames ?? [])
                .sorted { $0.number < $1.number }
                .map { f in
                    FrameBackup(
                        id: f.id,
                        number: f.number,
                        photoAssetID: f.photoAssetID,
                        aperture: f.aperture,
                        shutterSpeed: f.shutterSpeed,
                        focusDistance: f.focusDistance,
                        flashUsed: f.flashUsed,
                        locationName: f.locationName,
                        latitude: f.latitude,
                        longitude: f.longitude,
                        notes: f.notes,
                        capturedAt: f.capturedAt,
                        createdAt: f.createdAt
                    )
                }
            return RollBackup(
                id: roll.id,
                filmName: roll.filmName,
                capacity: roll.capacity,
                iso: roll.iso,
                format: roll.format,
                evCompensation: roll.evCompensation,
                pushPull: roll.pushPull,
                startDate: roll.startDate,
                status: roll.status,
                notes: roll.notes,
                locationName: roll.locationName,
                latitude: roll.latitude,
                longitude: roll.longitude,
                labName: roll.labName,
                driveFolderLink: roll.driveFolderLink,
                createdAt: roll.createdAt,
                updatedAt: roll.updatedAt,
                cameraID: roll.camera?.id,
                frames: frames,
                devDeveloper: roll.devDeveloper,
                devDilution: roll.devDilution,
                devTempC: roll.devTempC,
                devTimeSeconds: roll.devTimeSeconds,
                devAgitation: roll.devAgitation,
                devNotes: roll.devNotes,
                developedDate: roll.developedDate
            )
        }

        let cameraBackups: [CameraBackup] = cameras.map { c in
            CameraBackup(
                id: c.id,
                name: c.name,
                brand: c.brand,
                format: c.format,
                type: c.type,
                fixedFocalLength: c.fixedFocalLength,
                photoAssetID: c.photoAssetID,
                notes: c.notes,
                lens: c.lens,
                addedAt: c.addedAt
            )
        }

        return FilmVaultBackup(
            schemaVersion: currentSchemaVersion,
            appVersion: appVersionString(),
            exportedAt: Date(),
            rolls: rollBackups,
            cameras: cameraBackups,
            customFilms: CustomFilmStore.shared.films
        )
    }

    static func encode(_ backup: FilmVaultBackup) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    static func decode(_ data: Data) throws -> FilmVaultBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(FilmVaultBackup.self, from: data)
    }

    static func suggestedFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return "FilmVault-Backup-\(formatter.string(from: Date())).json"
    }

    // MARK: Import / Restore

    @discardableResult
    static func restore(_ backup: FilmVaultBackup, into context: ModelContext) -> BackupImportSummary {
        // Existing IDs so re-importing merges instead of duplicating.
        let existingCameras = (try? context.fetch(FetchDescriptor<Camera>())) ?? []
        let existingRolls = (try? context.fetch(FetchDescriptor<Roll>())) ?? []
        var camerasByID: [UUID: Camera] = Dictionary(uniqueKeysWithValues: existingCameras.map { ($0.id, $0) })
        let existingRollIDs = Set(existingRolls.map { $0.id })

        var camerasAdded = 0
        for cb in backup.cameras where camerasByID[cb.id] == nil {
            let camera = Camera(name: cb.name, brand: cb.brand)
            camera.id = cb.id
            camera.format = cb.format
            camera.type = cb.type
            camera.fixedFocalLength = cb.fixedFocalLength
            camera.photoAssetID = cb.photoAssetID
            camera.notes = cb.notes
            camera.lens = cb.lens
            camera.addedAt = cb.addedAt
            context.insert(camera)
            camerasByID[cb.id] = camera
            camerasAdded += 1
        }

        var rollsAdded = 0
        for rb in backup.rolls where !existingRollIDs.contains(rb.id) {
            let roll = Roll(filmName: rb.filmName)
            roll.id = rb.id
            roll.capacity = rb.capacity
            roll.iso = rb.iso
            roll.format = rb.format
            roll.evCompensation = rb.evCompensation
            roll.pushPull = rb.pushPull
            roll.startDate = rb.startDate
            roll.status = rb.status
            roll.notes = rb.notes
            roll.locationName = rb.locationName
            roll.latitude = rb.latitude
            roll.longitude = rb.longitude
            roll.labName = rb.labName
            roll.driveFolderLink = rb.driveFolderLink
            roll.createdAt = rb.createdAt
            roll.updatedAt = rb.updatedAt
            roll.camera = rb.cameraID.flatMap { camerasByID[$0] }
            roll.devDeveloper = rb.devDeveloper
            roll.devDilution = rb.devDilution
            roll.devTempC = rb.devTempC
            roll.devTimeSeconds = rb.devTimeSeconds
            roll.devAgitation = rb.devAgitation
            roll.devNotes = rb.devNotes
            roll.developedDate = rb.developedDate

            var frames: [Frame] = []
            for fb in rb.frames {
                let frame = Frame(number: fb.number)
                frame.id = fb.id
                frame.photoAssetID = fb.photoAssetID
                frame.aperture = fb.aperture
                frame.shutterSpeed = fb.shutterSpeed
                frame.focusDistance = fb.focusDistance
                frame.flashUsed = fb.flashUsed
                frame.locationName = fb.locationName
                frame.latitude = fb.latitude
                frame.longitude = fb.longitude
                frame.notes = fb.notes
                frame.capturedAt = fb.capturedAt
                frame.createdAt = fb.createdAt
                frame.roll = roll
                context.insert(frame)
                frames.append(frame)
            }
            roll.frames = frames
            context.insert(roll)
            rollsAdded += 1
        }

        // Custom films live in UserDefaults via CustomFilmStore.
        var customFilmsAdded = 0
        let store = CustomFilmStore.shared
        let existingFilmIDs = Set(store.films.map { $0.id })
        for film in backup.customFilms where !existingFilmIDs.contains(film.id) {
            store.films.append(film)
            customFilmsAdded += 1
        }
        if customFilmsAdded > 0 { store.save() }

        try? context.save()
        NotificationCenter.default.post(name: .widgetDataDidChange, object: nil)

        return BackupImportSummary(
            rollsAdded: rollsAdded,
            camerasAdded: camerasAdded,
            customFilmsAdded: customFilmsAdded
        )
    }
}

// MARK: - File Document for .fileExporter

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = contents
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
