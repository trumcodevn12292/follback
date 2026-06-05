import Foundation

// MARK: - API Response Wrapper

struct LLabAPIResponse<T: Decodable>: Decodable {
    let data: T?
    let isSuccess: Bool
    let statusCode: Int
    let message: String?

    enum CodingKeys: String, CodingKey {
        case data, isSuccess, statusCode, message
    }
}

// MARK: - Auth

struct LLabLoginData: Decodable {
    let token: String
    let refreshToken: String?
    let userId: String
}

// MARK: - User

struct LLabUser: Codable {
    let id: String
    let fullName: String
    let email: String
    let phone: String
    let rewardPoints: Int

    enum CodingKeys: String, CodingKey {
        case id, email, phone
        case fullName = "full_name"
    }

    init(id: String, fullName: String, email: String, phone: String, rewardPoints: Int) {
        self.id = id
        self.fullName = fullName
        self.email = email
        self.phone = phone
        self.rewardPoints = rewardPoints
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        fullName = try container.decode(String.self, forKey: .fullName)
        email = try container.decode(String.self, forKey: .email)
        phone = try container.decodeIfPresent(String.self, forKey: .phone) ?? ""
        rewardPoints = 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(fullName, forKey: .fullName)
        try container.encode(email, forKey: .email)
        try container.encode(phone, forKey: .phone)
    }
}

struct LLabUserMeResponse: Decodable {
    let id: String
    let fullName: String
    let email: String
    let phone: String?
    let reward: LLabReward?

    enum CodingKeys: String, CodingKey {
        case id, email, phone, reward
        case fullName = "full_name"
    }
}

struct LLabReward: Decodable {
    let points: Int
}

// MARK: - Order Items

struct LLabFilmType: Decodable {
    let name: String
}

struct LLabFilmSize: Decodable {
    let name: String
}

struct LLabFilmItem: Decodable {
    let filmType: LLabFilmType?
    let filmSize: LLabFilmSize?

    enum CodingKeys: String, CodingKey {
        case filmType = "film_type"
        case filmSize = "film_size"
    }
}

struct LLabProcessingTime: Decodable {
    let time: Int?
    let unit: String?
}

struct LLabRawOrderItem: Decodable {
    let id: String
    let quantity: Int
    let done: Bool
    let filmItem: LLabFilmItem?
    let processingTime: LLabProcessingTime?

    enum CodingKeys: String, CodingKey {
        case id, quantity, done
        case filmItem = "film_item"
        case processingTime = "processing_time"
    }
}

struct LLabOrderItem: Identifiable, Codable {
    let id: String
    let quantity: Int
    let done: Bool
    let filmType: String?
    let filmSize: String?
    let processingHours: Int?

    init(raw: LLabRawOrderItem) {
        id = raw.id
        quantity = raw.quantity
        done = raw.done
        filmType = raw.filmItem?.filmType?.name
        filmSize = raw.filmItem?.filmSize?.name
        processingHours = raw.processingTime?.time
    }
}

// MARK: - Order

struct LLabOrder: Identifiable, Codable {
    let id: String
    let orderNumber: String
    let status: String
    let totalRolls: Int
    let totalPrice: Int
    let rewardPoints: Int
    let scanner: String?
    let orderType: String?
    let retrievalMethod: String?
    let location: String?
    let negativeStatus: String?
    let createdAt: String?
    let expiryDate: String?
    let doneAt: String?
    let orderItems: [LLabOrderItem]?

    enum CodingKeys: String, CodingKey {
        case id, status, location, scanner
        case orderNumber = "order_number"
        case totalRolls = "total_rolls"
        case totalPrice = "total_price"
        case rewardPoints = "reward_points"
        case orderType = "order_type"
        case retrievalMethod = "retrieval_method"
        case negativeStatus = "negative_status"
        case createdAt = "created_at"
        case expiryDate = "expiry_date"
        case doneAt = "done_at"
        case orderItems = "order_items"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        orderNumber = try container.decode(String.self, forKey: .orderNumber)
        status = try container.decode(String.self, forKey: .status)
        totalRolls = try container.decodeIfPresent(Int.self, forKey: .totalRolls) ?? 1
        totalPrice = try container.decodeIfPresent(Int.self, forKey: .totalPrice) ?? 0
        rewardPoints = try container.decodeIfPresent(Int.self, forKey: .rewardPoints) ?? 0
        scanner = try container.decodeIfPresent(String.self, forKey: .scanner)
        orderType = try container.decodeIfPresent(String.self, forKey: .orderType)
        retrievalMethod = try container.decodeIfPresent(String.self, forKey: .retrievalMethod)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        negativeStatus = try container.decodeIfPresent(String.self, forKey: .negativeStatus)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        expiryDate = try container.decodeIfPresent(String.self, forKey: .expiryDate)
        doneAt = try container.decodeIfPresent(String.self, forKey: .doneAt)

        if let rawItems = try? container.decode([LLabRawOrderItem].self, forKey: .orderItems) {
            orderItems = rawItems.map(LLabOrderItem.init)
        } else {
            orderItems = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(orderNumber, forKey: .orderNumber)
        try container.encode(status, forKey: .status)
        try container.encode(totalRolls, forKey: .totalRolls)
        try container.encode(totalPrice, forKey: .totalPrice)
        try container.encode(rewardPoints, forKey: .rewardPoints)
        try container.encodeIfPresent(scanner, forKey: .scanner)
        try container.encodeIfPresent(orderType, forKey: .orderType)
        try container.encodeIfPresent(retrievalMethod, forKey: .retrievalMethod)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encodeIfPresent(negativeStatus, forKey: .negativeStatus)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(expiryDate, forKey: .expiryDate)
        try container.encodeIfPresent(doneAt, forKey: .doneAt)
    }
}

// MARK: - Order List

struct LLabOrderListData: Decodable {
    let items: [LLabOrder]
    let total: Int
}

// MARK: - Pickup Order

struct LLabPickupOrder: Identifiable, Codable {
    let id: String
    let code: String
    let status: String
    let totalFilm: Int?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, code, status
        case totalFilm = "total_film"
        case createdAt = "created_at"
    }
}

struct LLabPickupOrderListData: Decodable {
    let items: [LLabPickupOrder]
    let total: Int
}
