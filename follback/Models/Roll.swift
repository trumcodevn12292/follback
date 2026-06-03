import Foundation
import SwiftData

@Model
class Roll {
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

    @Relationship(deleteRule: .nullify)
    var camera: Camera?

    @Relationship(deleteRule: .cascade, inverse: \Frame.roll)
    var frames: [Frame]?

    init(
        id: UUID = UUID(),
        filmName: String,
        camera: Camera? = nil,
        capacity: Int = 36,
        iso: Int = 400,
        format: FilmFormat = .mm35,
        evCompensation: Float = 0,
        pushPull: Float = 0,
        startDate: Date = Date(),
        status: RollStatus = .inProgress,
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
        self.format = format.rawValue
        self.evCompensation = evCompensation
        self.pushPull = pushPull
        self.startDate = startDate
        self.status = status.rawValue
        self.notes = notes
        self.locationName = locationName
        self.latitude = latitude
        self.longitude = longitude
        self.labName = labName
        self.createdAt = Date()
        self.updatedAt = Date()
        self.camera = camera
    }

    var rollStatus: RollStatus {
        RollStatus(rawValue: status) ?? .inProgress
    }

    var filmFormat: FilmFormat {
        FilmFormat(rawValue: format) ?? .mm35
    }

    var filledFrames: Int {
        frames?.filter { $0.photoAssetID != nil }.count ?? 0
    }

    var isCompleted: Bool {
        filledFrames >= capacity
    }

    func checkAutoComplete() {
        if filledFrames >= capacity && rollStatus == .inProgress {
            updateStatus(.completed)
        }
    }

    func updateStatus(_ newStatus: RollStatus) {
        status = newStatus.rawValue
        updatedAt = Date()
    }
}
