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

struct LLabFilmName: Codable {
    let id: String
    let name: String
    let iso: String?
    let brand: String?
    let origin: String?
}

struct LLabFilmOption: Codable {
    let id: String
    let name: String
    let code: String
    let order: Int?
}

struct LLabOrderItemDetail: Codable {
    let id: String
    let quantity: Int?
    let note: String?
    let error: Bool?
    let orderItemId: String?
    let filmName: LLabFilmName?

    enum CodingKeys: String, CodingKey {
        case id, quantity, note, error
        case orderItemId = "order_item_id"
        case filmName = "film_name"
    }
}

struct LLabOrderItemMeta: Codable {
    let id: String?
    let value: Int?
    let filmOption: LLabFilmOption?

    enum CodingKeys: String, CodingKey {
        case id, value
        case filmOption = "film_option"
    }
}

struct LLabRawOrderItem: Decodable {
    let id: String
    let quantity: Int
    let done: Bool
    let filmItem: LLabFilmItem?
    let processingTime: LLabProcessingTime?
    let scanType: String?
    let serviceType: String?
    let unitPrice: Int?
    let note: String?
    let frameCount: Int?
    let details: [LLabOrderItemDetail]?
    let metas: [LLabOrderItemMeta]?

    enum CodingKeys: String, CodingKey {
        case id, quantity, done, note
        case filmItem = "film_item"
        case processingTime = "processing_time"
        case scanType = "scan_type"
        case serviceType = "service_type"
        case unitPrice = "unit_price"
        case frameCount = "frame_count"
        case details = "order_item_details"
        case metas = "order_itemmetas"
    }
}

struct LLabOrderItem: Identifiable, Codable {
    let id: String
    let quantity: Int
    let done: Bool
    let filmType: String?
    let filmSize: String?
    let processingHours: Int?
    let scanType: String?
    let serviceType: String?
    let unitPrice: Int?
    let note: String?
    let frameCount: Int?
    let details: [LLabOrderItemDetail]?
    let options: [LLabOrderItemMeta]?

    init(raw: LLabRawOrderItem) {
        id = raw.id
        quantity = raw.quantity
        done = raw.done
        filmType = raw.filmItem?.filmType?.name
        filmSize = raw.filmItem?.filmSize?.name
        processingHours = raw.processingTime?.time
        scanType = raw.scanType
        serviceType = raw.serviceType
        unitPrice = raw.unitPrice
        note = raw.note
        frameCount = raw.frameCount
        details = raw.details
        options = raw.metas
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
    let customerNote: String?
    let updatedAt: String?
    let customerName: String?
    let customerPhone: String?
    let totalFrame: Int?
    let scanType: String?
    let paymentStatus: String?
    let totalPaid: Int?
    let discount: Int?
    let urgent: Bool?
    let filmReturn: Bool?
    let deliveryMethod: String?
    let deliveryAddress: String?
    let orderId: Int?
    let subTotal: Int?
    let discountRolls: Int?
    let shippingFee: Int?
    let paymentMethod: String?
    let email: String?
    let fullAddress: String?
    let note: String?
    let noteForLab: String?
    let noteForShipper: String?
    let deliveryService: String?
    let deliveryBranch: String?
    let deliveryShift: String?
    let parcelCode: String?
    let expectedDeliveryTime: String?
    let expectedDeliveryDate: String?
    let paidAt: String?
    let actualFinishDate: String?
    let statusCode: Int?
    let statusText: String?

    enum CodingKeys: String, CodingKey {
        case id, status, location, scanner, email, urgent
        case orderNumber = "order_number"
        case totalRolls = "total_rolls"
        case totalPrice = "total_price"
        case rewardPoints, orderType, retrievalMethod, negativeStatus
        case createdAt, expiryDate, doneAt, paidAt, deliveryAddress
        case orderItems = "order_items"
        case note = "order_note"
        case customerNote = "customer_note"
        case customerName = "customer_name"
        case customerPhone = "customer_phone"
        case deliveryMethod = "delivery_method"
        case orderId = "order_id"
        case shippingFee = "shipping_fee"
        case paymentMethod = "payment_method"
        case fullAddress = "full_address"
        case noteForLab = "note_for_lab"
        case noteForShipper = "note_for_shipper"
        case deliveryService = "delivery_service"
        case deliveryBranch = "delivery_branch"
        case deliveryShift = "delivery_shift"
        case parcelCode = "parcel_code"
        case expectedDeliveryTime = "expected_delivery_time"
        case expectedDeliveryDate = "expected_delivery_date"
        case actualFinishDate = "actual_finish_date"
        case updatedAt = "updated_at"
        case totalFrame = "total_frame"
        case scanType = "scan_type"
        case paymentStatus = "payment_status"
        case totalPaid = "total_paid"
        case discount
        case filmReturn = "film_return"
        case subTotal = "sub_total"
        case discountRolls = "discount_rolls"
        case statusCode = "status_code"
        case statusText = "status_text"
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
        note = try container.decodeIfPresent(String.self, forKey: .note)
        customerNote = try container.decodeIfPresent(String.self, forKey: .customerNote)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        customerName = try container.decodeIfPresent(String.self, forKey: .customerName)
        customerPhone = try container.decodeIfPresent(String.self, forKey: .customerPhone)
        totalFrame = try container.decodeIfPresent(Int.self, forKey: .totalFrame)
        scanType = try container.decodeIfPresent(String.self, forKey: .scanType)
        paymentStatus = try container.decodeIfPresent(String.self, forKey: .paymentStatus)
        totalPaid = try container.decodeIfPresent(Int.self, forKey: .totalPaid)
        discount = try container.decodeIfPresent(Int.self, forKey: .discount)
        urgent = try container.decodeIfPresent(Bool.self, forKey: .urgent)
        filmReturn = try container.decodeIfPresent(Bool.self, forKey: .filmReturn)
        deliveryMethod = try container.decodeIfPresent(String.self, forKey: .deliveryMethod)
        deliveryAddress = try container.decodeIfPresent(String.self, forKey: .deliveryAddress)
        orderId = try container.decodeIfPresent(Int.self, forKey: .orderId)
        subTotal = try container.decodeIfPresent(Int.self, forKey: .subTotal)
        discountRolls = try container.decodeIfPresent(Int.self, forKey: .discountRolls)
        shippingFee = try container.decodeIfPresent(Int.self, forKey: .shippingFee)
        paymentMethod = try container.decodeIfPresent(String.self, forKey: .paymentMethod)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        fullAddress = try container.decodeIfPresent(String.self, forKey: .fullAddress)
        noteForLab = try container.decodeIfPresent(String.self, forKey: .noteForLab)
        noteForShipper = try container.decodeIfPresent(String.self, forKey: .noteForShipper)
        deliveryService = try container.decodeIfPresent(String.self, forKey: .deliveryService)
        deliveryBranch = try container.decodeIfPresent(String.self, forKey: .deliveryBranch)
        deliveryShift = try container.decodeIfPresent(String.self, forKey: .deliveryShift)
        parcelCode = try container.decodeIfPresent(String.self, forKey: .parcelCode)
        expectedDeliveryTime = try container.decodeIfPresent(String.self, forKey: .expectedDeliveryTime)
        expectedDeliveryDate = try container.decodeIfPresent(String.self, forKey: .expectedDeliveryDate)
        paidAt = try container.decodeIfPresent(String.self, forKey: .paidAt)
        actualFinishDate = try container.decodeIfPresent(String.self, forKey: .actualFinishDate)
        statusCode = try container.decodeIfPresent(Int.self, forKey: .statusCode)
        statusText = try container.decodeIfPresent(String.self, forKey: .statusText)

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
        try container.encodeIfPresent(note, forKey: .note)
        try container.encodeIfPresent(customerNote, forKey: .customerNote)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(customerName, forKey: .customerName)
        try container.encodeIfPresent(customerPhone, forKey: .customerPhone)
        try container.encodeIfPresent(totalFrame, forKey: .totalFrame)
        try container.encodeIfPresent(scanType, forKey: .scanType)
        try container.encodeIfPresent(paymentStatus, forKey: .paymentStatus)
        try container.encodeIfPresent(totalPaid, forKey: .totalPaid)
        try container.encodeIfPresent(discount, forKey: .discount)
        try container.encodeIfPresent(urgent, forKey: .urgent)
        try container.encodeIfPresent(filmReturn, forKey: .filmReturn)
        try container.encodeIfPresent(deliveryMethod, forKey: .deliveryMethod)
        try container.encodeIfPresent(deliveryAddress, forKey: .deliveryAddress)
        try container.encodeIfPresent(orderId, forKey: .orderId)
        try container.encodeIfPresent(subTotal, forKey: .subTotal)
        try container.encodeIfPresent(discountRolls, forKey: .discountRolls)
        try container.encodeIfPresent(shippingFee, forKey: .shippingFee)
        try container.encodeIfPresent(paymentMethod, forKey: .paymentMethod)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(fullAddress, forKey: .fullAddress)
        try container.encodeIfPresent(noteForLab, forKey: .noteForLab)
        try container.encodeIfPresent(noteForShipper, forKey: .noteForShipper)
        try container.encodeIfPresent(deliveryService, forKey: .deliveryService)
        try container.encodeIfPresent(deliveryBranch, forKey: .deliveryBranch)
        try container.encodeIfPresent(deliveryShift, forKey: .deliveryShift)
        try container.encodeIfPresent(parcelCode, forKey: .parcelCode)
        try container.encodeIfPresent(expectedDeliveryTime, forKey: .expectedDeliveryTime)
        try container.encodeIfPresent(expectedDeliveryDate, forKey: .expectedDeliveryDate)
        try container.encodeIfPresent(paidAt, forKey: .paidAt)
        try container.encodeIfPresent(actualFinishDate, forKey: .actualFinishDate)
        try container.encodeIfPresent(statusCode, forKey: .statusCode)
        try container.encodeIfPresent(statusText, forKey: .statusText)
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
