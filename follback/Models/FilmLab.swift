import Foundation

struct FilmLab: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let city: String
    let description: String
    let logoUrl: String?
    let services: [String]

    static let allLabs: [FilmLab] = hanoi + hoChiMinh + daLat + daNang

    static let groupedByCity: [(city: String, labs: [FilmLab])] = [
        (city: "Hà Nội", labs: hanoi),
        (city: "TP. Hồ Chí Minh", labs: hoChiMinh),
        (city: "Đà Lạt", labs: daLat),
        (city: "Đà Nẵng", labs: daNang)
    ]

    // MARK: - Hà Nội

    static let hanoi: [FilmLab] = [
        FilmLab(
            name: "Lab 36",
            city: "Hà Nội",
            description: "Một trong những lab nổi tiếng nhất Hà Nội, có dịch vụ tráng, scan, bán film và phụ kiện.",
            logoUrl: nil,
            services: ["C-41", "B&W", "Scan"]
        ),
        FilmLab(
            name: "LLab Giảng Võ",
            city: "Hà Nội",
            description: "Chi nhánh Hà Nội của LLab.",
            logoUrl: nil,
            services: ["C-41", "B&W", "E-6", "Scan"]
        ),
        FilmLab(
            name: "Croplab",
            city: "Hà Nội",
            description: "Được nhiều người chơi film sử dụng, có Noritsu và Frontier.",
            logoUrl: nil,
            services: ["C-41", "B&W", "Scan", "Noritsu", "Frontier"]
        ),
        FilmLab(
            name: "AEG Lab",
            city: "Hà Nội",
            description: "Hỗ trợ C-41, E-6, B&W, 120 và Large Format.",
            logoUrl: nil,
            services: ["C-41", "E-6", "B&W", "120", "Large Format"]
        ),
        FilmLab(
            name: "X-Lab",
            city: "Hà Nội",
            description: "Một lab lâu năm trong cộng đồng film Hà Nội.",
            logoUrl: nil,
            services: ["C-41", "B&W", "Scan"]
        ),
        FilmLab(
            name: "Hanoi Film Store",
            city: "Hà Nội",
            description: "Vừa bán film vừa nhận tráng scan.",
            logoUrl: nil,
            services: ["C-41", "B&W", "Scan", "Film Sales"]
        ),
        FilmLab(
            name: "Nadar Lab",
            city: "Hà Nội",
            description: "Được cộng đồng film Hà Nội nhắc đến khá thường xuyên.",
            logoUrl: nil,
            services: ["C-41", "B&W", "Scan"]
        ),
        FilmLab(
            name: "ChiuLab",
            city: "Hà Nội",
            description: "Xuất hiện trong danh sách lab được người chơi film tại Hà Nội giới thiệu.",
            logoUrl: nil,
            services: ["C-41", "B&W", "Scan"]
        )
    ]

    // MARK: - TP. Hồ Chí Minh

    static let hoChiMinh: [FilmLab] = [
        FilmLab(
            name: "LLAB",
            city: "TP. Hồ Chí Minh",
            description: "Một trong những lab lớn và chuyên nghiệp nhất Việt Nam, hoạt động từ năm 2014.",
            logoUrl: nil,
            services: ["C-41", "E-6", "B&W", "ECN-2", "120", "Scan"]
        ),
        FilmLab(
            name: "Crop Lab",
            city: "TP. Hồ Chí Minh",
            description: "Rất phổ biến trong cộng đồng film Sài Gòn.",
            logoUrl: nil,
            services: ["C-41", "B&W", "Scan"]
        ),
        FilmLab(
            name: "Thuong Xanh Film & Camera",
            city: "TP. Hồ Chí Minh",
            description: "Hỗ trợ B&W, C41, ECN-2.",
            logoUrl: nil,
            services: ["C-41", "B&W", "ECN-2", "Scan"]
        ),
        FilmLab(
            name: "47plus minilab",
            city: "TP. Hồ Chí Minh",
            description: "Lab được nhiều người dùng film màu lựa chọn.",
            logoUrl: nil,
            services: ["C-41", "Scan"]
        ),
        FilmLab(
            name: "Fox Spirit Film",
            city: "TP. Hồ Chí Minh",
            description: "Ngoài dịch vụ film còn có darkroom cho người chơi tự tráng ảnh.",
            logoUrl: nil,
            services: ["C-41", "B&W", "Darkroom", "Scan"]
        )
    ]

    // MARK: - Đà Lạt

    static let daLat: [FilmLab] = [
        FilmLab(
            name: "Cinephile FilmLab",
            city: "Đà Lạt",
            description: "Lab film nổi tiếng nhất Đà Lạt hiện nay, thường nhận film gửi từ các tỉnh khác.",
            logoUrl: nil,
            services: ["C-41", "B&W", "Scan"]
        )
    ]

    // MARK: - Đà Nẵng

    static let daNang: [FilmLab] = [
        FilmLab(
            name: "Rolling Film",
            city: "Đà Nẵng",
            description: "Địa điểm liên quan film đang hoạt động tại Đà Nẵng.",
            logoUrl: nil,
            services: ["Film Sales"]
        ),
        FilmLab(
            name: "Phở Film",
            city: "Đà Nẵng",
            description: "Địa điểm liên quan film đang hoạt động tại Đà Nẵng.",
            logoUrl: nil,
            services: ["Film Sales"]
        )
    ]
}
