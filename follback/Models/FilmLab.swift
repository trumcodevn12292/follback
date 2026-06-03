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
            logoUrl: "https://scontent.fsgn5-2.fna.fbcdn.net/v/t39.30808-6/475985063_940241038236436_7952073699626594917_n.jpg?_nc_cat=105&ccb=1-7&_nc_sid=6ee11a&_nc_ohc=LrnQcDBC1PsQ7kNvwGmjs9P&_nc_oc=Adr6F1u58V49vEo_Rq4CeHPPhSOaYzOIjNsK7iCxAnbAq984Qe1ivvvKQk2ASDv5Nv0&_nc_zt=23&_nc_ht=scontent.fsgn5-2.fna&_nc_gid=8ugE2I9B3d2-w1I_11APMA&_nc_ss=7b2a8&oh=00_Af__rg7_BGXgNP0lysPmPXF65N-E34p5EDV0r0sB6ucIFw&oe=6A255813",
            services: ["C-41", "B&W", "Scan"]
        ),
        FilmLab(
            name: "LLab Giảng Võ",
            city: "Hà Nội",
            description: "Chi nhánh Hà Nội của LLab.",
            logoUrl: "https://llab.vn/wp-content/themes/llab-premium-services/assets/images/logo.png",
            services: ["C-41", "B&W", "E-6", "Scan"]
        ),
        FilmLab(
            name: "Croplab",
            city: "Hà Nội",
            description: "Được nhiều người chơi film sử dụng, có Noritsu và Frontier.",
            logoUrl: "https://croplab.vn/wp-content/uploads/2018/09/logo-1.png",
            services: ["C-41", "B&W", "Scan", "Noritsu", "Frontier"]
        ),
        FilmLab(
            name: "AEG Lab",
            city: "Hà Nội",
            description: "Hỗ trợ C-41, E-6, B&W, 120 và Large Format.",
            logoUrl: "https://scontent.fsgn5-6.fna.fbcdn.net/v/t39.30808-6/306781086_456163009879234_6381843454073904485_n.jpg?_nc_cat=108&ccb=1-7&_nc_sid=6ee11a&_nc_ohc=UAOTQNlpfhkQ7kNvwGgiAPT&_nc_oc=Adq4_pYeTLw-zrTn9-MLRwW1IsX1iud8bzLUhMjiOvyuyuXiaNdH30gJ3AAjR314o30&_nc_zt=23&_nc_ht=scontent.fsgn5-6.fna&_nc_gid=6iLlMpbiGv-9v4EhKuXLQw&_nc_ss=7b2a8&oh=00_Af9G_86Gdbey0QgCea-oM-CJG61zKwV7Ml5v8wFc3PXgbA&oe=6A2565F5",
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
            logoUrl: "https://scontent.fsgn5-3.fna.fbcdn.net/v/t39.30808-6/309499188_118302034346271_1504725466397931101_n.jpg?_nc_cat=104&ccb=1-7&_nc_sid=6ee11a&_nc_ohc=EL22nZ4P0YIQ7kNvwGpqvQZ&_nc_oc=Adr-CZgniSNaLoGc0cU8moGSWWAQPY5X2CxTbau55npThvFUIyNYY6FjYYEPEybjcFs&_nc_zt=23&_nc_ht=scontent.fsgn5-3.fna&_nc_gid=9qeYsCle5XuTXU0hCdX3Fg&_nc_ss=7b2a8&oh=00_Af_8KuzlpJPoSmK7IYPArq7P06KVtq25d_tCTdacnsOoRg&oe=6A2567EE",
            services: ["C-41", "B&W", "Scan"]
        ),
        FilmLab(
            name: "ChiuLab",
            city: "Hà Nội",
            description: "Xuất hiện trong danh sách lab được người chơi film tại Hà Nội giới thiệu.",
            logoUrl: "https://scontent.fsgn5-21.fna.fbcdn.net/v/t1.6435-9/66216683_100582544591948_6107495730304253952_n.jpg?_nc_cat=109&ccb=1-7&_nc_sid=6ee11a&_nc_ohc=FoDfGmhzjA8Q7kNvwFmWsRa&_nc_oc=Adr08NyauJxxphVxGrNSQndxkDbvm-qOPhrJz1-QEBrrGmmmoxpynofxDyXpMVTxudE&_nc_zt=23&_nc_ht=scontent.fsgn5-21.fna&_nc_gid=Z67SCBkRlrNClvUuvaCNTg&_nc_ss=7b2a8&oh=00_Af_OBYf3SZkCpMCAYHWXyM0OMsDny7mQAdnyjsr8pgXVLw&oe=6A4701FD",
            services: ["C-41", "B&W", "Scan"]
        )
    ]

    // MARK: - TP. Hồ Chí Minh

    static let hoChiMinh: [FilmLab] = [
        FilmLab(
            name: "LLAB",
            city: "TP. Hồ Chí Minh",
            description: "Một trong những lab lớn và chuyên nghiệp nhất Việt Nam, hoạt động từ năm 2014.",
            logoUrl: "https://llab.vn/wp-content/themes/llab-premium-services/assets/images/logo.png",
            services: ["C-41", "E-6", "B&W", "ECN-2", "120", "Scan"]
        ),
        FilmLab(
            name: "Crop Lab",
            city: "TP. Hồ Chí Minh",
            description: "Rất phổ biến trong cộng đồng film Sài Gòn.",
            logoUrl: "https://croplab.vn/wp-content/uploads/2018/09/logo-1.png",
            services: ["C-41", "B&W", "Scan"]
        ),
        FilmLab(
            name: "Thuong Xanh Film & Camera",
            city: "TP. Hồ Chí Minh",
            description: "Hỗ trợ B&W, C41, ECN-2.",
            logoUrl: "https://scontent.fsgn5-9.fna.fbcdn.net/v/t39.30808-6/330383076_1229325691008676_5016722682667411371_n.jpg?_nc_cat=102&ccb=1-7&_nc_sid=6ee11a&_nc_ohc=4X67URbC8lYQ7kNvwHYW16d&_nc_oc=Ado7GYNIM1399sQXtEVHQa6wVZc2VkPj0hgU9ZUgrODpHCEML54VofNgYqgliyQTln4&_nc_zt=23&_nc_ht=scontent.fsgn5-9.fna&_nc_gid=-gXWojWwmQOUxXss9dv65g&_nc_ss=7b2a8&oh=00_Af_TMKNe2OBj-EQlUuCRzamn0xj_rS2HQV4LkmSSWTo4pA&oe=6A257F8A",
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
            logoUrl: "https://scontent.fsgn5-2.fna.fbcdn.net/v/t39.30808-6/320440581_996842127942762_6041659370944079945_n.jpg?_nc_cat=105&ccb=1-7&_nc_sid=6ee11a&_nc_ohc=50PSoonHvXQQ7kNvwFSGxQk&_nc_oc=AdqkhHTviqYz5nUYFTev5QzZ9-t8AmAFdt6XVrkjLzeuv9hSrYfDrcoh2J-au0nzC9k&_nc_zt=23&_nc_ht=scontent.fsgn5-2.fna&_nc_gid=eqTtUMBkcI20rmHaM03KjQ&_nc_ss=7b2a8&oh=00_Af-r32M_dooWxnFUQ2LR5IbWKWYEFJSkUvLaPxIYOGmdFQ&oe=6A25549D",
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
