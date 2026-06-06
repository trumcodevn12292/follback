import Foundation

enum FilmFormat: String, Codable, CaseIterable {
    case mm35 = "35mm"
    case mm120 = "120"
    case sheet4x5 = "4×5"
    case sheet8x10 = "8×10"
    case aps = "APS"

    var displayName: String { rawValue }

    var isSheet: Bool {
        switch self {
        case .sheet4x5, .sheet8x10: return true
        default: return false
        }
    }

    var defaultCapacity: Int {
        switch self {
        case .mm35: return 36
        case .mm120: return 12
        case .sheet4x5: return 10
        case .sheet8x10: return 10
        case .aps: return 25
        }
    }

    var capacityOptions: [Int] {
        switch self {
        case .mm35: return [12, 24, 36]
        case .mm120: return [8, 10, 12, 16]
        case .sheet4x5, .sheet8x10: return [1, 2, 5, 10, 25, 50]
        case .aps: return [15, 25, 40]
        }
    }
}

enum RollStatus: String, Codable, CaseIterable {
    case inProgress = "In Progress"
    case completed = "Completed"
    case developed = "Developed"
    case archived = "Archived"

    var displayName: String {
        switch self {
        case .inProgress: return "Shooting"
        case .completed: return "Shot"
        case .developed: return "Developed"
        case .archived: return "Archived"
        }
    }
}

enum CameraType: String, Codable, CaseIterable {
    case slr = "SLR"
    case rangefinder = "Rangefinder"
    case tlr = "TLR"
    case pointAndShoot = "Point & Shoot"
    case viewCamera = "View Camera"
    
    var displayName: String { rawValue }
}

enum ShutterSpeed: String, Codable, CaseIterable {
    case s1 = "1"
    case s1_2 = "1/2"
    case s1_4 = "1/4"
    case s1_8 = "1/8"
    case s1_15 = "1/15"
    case s1_30 = "1/30"
    case s1_60 = "1/60"
    case s1_125 = "1/125"
    case s1_250 = "1/250"
    case s1_500 = "1/500"
    case s1_1000 = "1/1000"
    case s1_2000 = "1/2000"
    case s1_4000 = "1/4000"
    
    var displayName: String { rawValue }
}

enum Aperture: Float, Codable, CaseIterable {
    case f1_4 = 1.4
    case f1_8 = 1.8
    case f2 = 2.0
    case f2_8 = 2.8
    case f4 = 4.0
    case f5_6 = 5.6
    case f8 = 8.0
    case f11 = 11.0
    case f16 = 16.0
    case f22 = 22.0
    
    var displayName: String {
        switch self {
        case .f1_4: return "f/1.4"
        case .f1_8: return "f/1.8"
        case .f2: return "f/2"
        case .f2_8: return "f/2.8"
        case .f4: return "f/4"
        case .f5_6: return "f/5.6"
        case .f8: return "f/8"
        case .f11: return "f/11"
        case .f16: return "f/16"
        case .f22: return "f/22"
        }
    }
}
