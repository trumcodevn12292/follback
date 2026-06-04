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

    // MARK: - Development recipe log
    var devDeveloper: String?       // e.g. "Kodak D-76", "Rodinal"
    var devDilution: String?        // e.g. "1+1", "1+50"
    var devTempC: Double?           // temperature in °C
    var devTimeSeconds: Int?        // development time in seconds
    var devAgitation: String?       // e.g. "30s initial, 3 inversions / 30s"
    var devNotes: String?           // free-form recipe notes
    var developedDate: Date?        // when it was developed

    // MARK: - Cost tracking
    var filmCost: Double?           // price paid to buy the film
    var devCost: Double?            // price paid to develop / scan the roll

    /// Total money spent on this roll (film + developing), or nil when nothing
    /// has been recorded yet.
    var totalCost: Double? {
        let values = [filmCost, devCost].compactMap { $0 }
        return values.isEmpty ? nil : values.reduce(0, +)
    }

    /// True when any cost field has been filled in.
    var hasCost: Bool {
        filmCost != nil || devCost != nil
    }

    /// True when any development recipe field has been filled in.
    var hasDevRecipe: Bool {
        (devDeveloper?.isEmpty == false) ||
        (devDilution?.isEmpty == false) ||
        devTempC != nil ||
        devTimeSeconds != nil ||
        (devAgitation?.isEmpty == false) ||
        (devNotes?.isEmpty == false) ||
        developedDate != nil
    }

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
