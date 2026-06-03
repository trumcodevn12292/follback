import Foundation

struct FilmLab: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let city: String
    let description: String
    let logoUrl: String?
    let services: [String]

    static let allLabs: [FilmLab] = hanoi + hue + hoChiMinh + daLat + daNang

    static let groupedByCity: [(city: String, labs: [FilmLab])] = [
        (city: "Hà Nội", labs: hanoi),
        (city: "Huế", labs: hue),
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
            logoUrl: "https://scontent.fsgn5-11.fna.fbcdn.net/v/t39.30808-6/306998830_652109126276809_7965248998487023211_n.jpg?_nc_cat=110&ccb=1-7&_nc_sid=6ee11a&_nc_ohc=SSRW50nN9F4Q7kNvwH9oQx6&_nc_oc=AdosUUSFbHv_Y6xzNgru6_hsRIHnyFJ2EQgaw8ncKqLhLD9jCq1fQjGlkRFdgV7TQAw&_nc_zt=23&_nc_ht=scontent.fsgn5-11.fna&_nc_gid=W3i7FU9pHek29c5Q7X5prQ&_nc_ss=7b2a8&oh=00_Af97t12IM2Ul5mJrRJ4vEOiEJuYYeTZO47RyhIGwLN3K2g&oe=6A255A69",
            services: ["C-41", "B&W", "E-6", "Scan"]
        ),
        FilmLab(
            name: "Croplab",
            city: "Hà Nội",
            description: "Được nhiều người chơi film sử dụng, có Noritsu và Frontier.",
            logoUrl: "https://scontent.fsgn5-14.fna.fbcdn.net/v/t1.6435-9/104924090_103921018041633_9015258058678056582_n.jpg?_nc_cat=101&ccb=1-7&_nc_sid=6ee11a&_nc_ohc=j5My2Kfhix8Q7kNvwH6VYrh&_nc_oc=Adp2tYqQWDU8HxnlJuFkcUEp4lLO_9shLEjP9_599L1xRIYL7kr39daKufi4XxcCo4k&_nc_zt=23&_nc_ht=scontent.fsgn5-14.fna&_nc_gid=FBLGLLdZoNsMzVjzr5zL8g&_nc_ss=7b2a8&oh=00_Af_Hgao1k5opHkf1n8spJdE5uc6zZFdet7ud983JDXjUxA&oe=6A471715",
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

    // MARK: - Huế

    static let hue: [FilmLab] = [
        FilmLab(
            name: "LLab Huế",
            city: "Huế",
            description: "Chi nhánh Huế của LLab.",
            logoUrl: "https://scontent.fsgn5-11.fna.fbcdn.net/v/t39.30808-6/306998830_652109126276809_7965248998487023211_n.jpg?_nc_cat=110&ccb=1-7&_nc_sid=6ee11a&_nc_ohc=SSRW50nN9F4Q7kNvwH9oQx6&_nc_oc=AdosUUSFbHv_Y6xzNgru6_hsRIHnyFJ2EQgaw8ncKqLhLD9jCq1fQjGlkRFdgV7TQAw&_nc_zt=23&_nc_ht=scontent.fsgn5-11.fna&_nc_gid=W3i7FU9pHek29c5Q7X5prQ&_nc_ss=7b2a8&oh=00_Af97t12IM2Ul5mJrRJ4vEOiEJuYYeTZO47RyhIGwLN3K2g&oe=6A255A69",
            services: ["C-41", "B&W", "E-6", "Scan"]
        )
    ]

    // MARK: - TP. Hồ Chí Minh

    static let hoChiMinh: [FilmLab] = [
        FilmLab(
            name: "LLAB",
            city: "TP. Hồ Chí Minh",
            description: "Một trong những lab lớn và chuyên nghiệp nhất Việt Nam, hoạt động từ năm 2014.",
            logoUrl: "https://scontent.fsgn5-11.fna.fbcdn.net/v/t39.30808-6/306998830_652109126276809_7965248998487023211_n.jpg?_nc_cat=110&ccb=1-7&_nc_sid=6ee11a&_nc_ohc=SSRW50nN9F4Q7kNvwH9oQx6&_nc_oc=AdosUUSFbHv_Y6xzNgru6_hsRIHnyFJ2EQgaw8ncKqLhLD9jCq1fQjGlkRFdgV7TQAw&_nc_zt=23&_nc_ht=scontent.fsgn5-11.fna&_nc_gid=W3i7FU9pHek29c5Q7X5prQ&_nc_ss=7b2a8&oh=00_Af97t12IM2Ul5mJrRJ4vEOiEJuYYeTZO47RyhIGwLN3K2g&oe=6A255A69",
            services: ["C-41", "E-6", "B&W", "ECN-2", "120", "Scan"]
        ),
        FilmLab(
            name: "Crop Lab",
            city: "TP. Hồ Chí Minh",
            description: "Rất phổ biến trong cộng đồng film Sài Gòn.",
            logoUrl: "https://scontent.fsgn5-14.fna.fbcdn.net/v/t1.6435-9/104924090_103921018041633_9015258058678056582_n.jpg?_nc_cat=101&ccb=1-7&_nc_sid=6ee11a&_nc_ohc=j5My2Kfhix8Q7kNvwH6VYrh&_nc_oc=Adp2tYqQWDU8HxnlJuFkcUEp4lLO_9shLEjP9_599L1xRIYL7kr39daKufi4XxcCo4k&_nc_zt=23&_nc_ht=scontent.fsgn5-14.fna&_nc_gid=FBLGLLdZoNsMzVjzr5zL8g&_nc_ss=7b2a8&oh=00_Af_Hgao1k5opHkf1n8spJdE5uc6zZFdet7ud983JDXjUxA&oe=6A471715",
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
            logoUrl: "https://scontent.fsgn5-12.fna.fbcdn.net/v/t39.30808-6/326650117_914905869867506_1500949283072318098_n.jpg?_nc_cat=103&ccb=1-7&_nc_sid=6ee11a&_nc_ohc=XGpMpgKYGdMQ7kNvwG-mRS5&_nc_oc=AdruoqjppoLxEOe8BsVaOozuDGQgOQjk9g83rB-nIDlGkh6qIQxg3-GH9UeA-Gp2FTo&_nc_zt=23&_nc_ht=scontent.fsgn5-12.fna&_nc_gid=8AYYgHQI6LNrskVWACwucQ&_nc_ss=7b2a8&oh=00_Af9RxROZTEyJkSzpqUHChbwzX0i56IjFFuJiZ3vBGUf4IA&oe=6A2568AE",
            services: ["C-41", "Scan"]
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
            logoUrl: "https://scontent.fsgn5-2.fna.fbcdn.net/v/t39.30808-6/303049593_489233736544731_757367740569944853_n.png?_nc_cat=105&ccb=1-7&_nc_sid=6ee11a&_nc_ohc=vr_nsLokFPoQ7kNvwHv95VP&_nc_oc=Ado-6Iaw-Ch5XBQAPoPXSgjsOhWP9g4mu5jzHCiVosTJ9WrvnUPoay2W0qIhPUA9bko&_nc_zt=23&_nc_ht=scontent.fsgn5-2.fna&_nc_gid=Sut88B4swJK5U6Tk1UFUSg&_nc_ss=7b2a8&oh=00_Af_jt4FShAEuegqYU8tAaEFUuRdtXKvnZdH2Vq4qp30r9Q&oe=6A2553B5",
            services: ["Film Sales"]
        ),
        FilmLab(
            name: "Phở Film",
            city: "Đà Nẵng",
            description: "Địa điểm liên quan film đang hoạt động tại Đà Nẵng.",
            logoUrl: "https://scontent.fsgn5-3.fna.fbcdn.net/v/t39.30808-6/271164217_149551144090960_2964162253392984572_n.jpg?_nc_cat=104&ccb=1-7&_nc_sid=6ee11a&_nc_ohc=e9bsttGTLW8Q7kNvwGArLr0&_nc_oc=Adqrb4l3PfNzV_ED3iYGxlY9C-oRbHQz9d8SG2ijkub8pZnLRtlF3-jnpeaRP8tbmX4&_nc_zt=23&_nc_ht=scontent.fsgn5-3.fna&_nc_gid=yzNvTwM7IwsFfOHRsrt13g&_nc_ss=7b2a8&oh=00_Af9ShhLRXCz1xR0qABeclaNl42MGsmTsSK622l-i7Ko7bA&oe=6A2557AC",
            services: ["Film Sales"]
        )
    ]
}
