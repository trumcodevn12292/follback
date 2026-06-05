import Foundation
import Combine
import UserNotifications

final class LLabService: ObservableObject {
    static let shared = LLabService()

    @Published var isSignedIn = false
    @Published var user: LLabUser?
    @Published var orders: [LLabOrder] = []
    @Published var pickupOrders: [LLabPickupOrder] = []
    @Published var isLoading = false
    @Published var error: String?

    private let baseURL = "https://api.llab.vn"
    private var accessToken: String?
    private var refreshToken: String?
    private var previousOrderStatuses: [String: String] = [:]
    private var notifiedDoneOrders: Set<String> = []

    private let accessTokenKey = "llab_access_token"
    private let refreshTokenKey = "llab_refresh_token"
    private let userDataKey = "llab_user_data"
    private let savedEmailKey = "llab_saved_email"

    private init() {
        loadSavedCredentials()
    }

    // MARK: - Sign In

    @MainActor
    func signIn(email: String, password: String) async {
        isLoading = true
        error = nil

        guard let guestToken = await fetchGuestToken(email: email) else {
            isLoading = false
            error = L("Failed to connect to LLab")
            return
        }

        guard let result = await loginWithPassword(email: email, password: password, guestToken: guestToken) else {
            isLoading = false
            error = L("Invalid email or password")
            return
        }

        accessToken = result.token
        refreshToken = result.refreshToken

        KeychainService.save(key: accessTokenKey, value: result.token)
        if let refresh = result.refreshToken, !refresh.isEmpty {
            KeychainService.save(key: refreshTokenKey, value: refresh)
        }
        UserDefaults.standard.set(email, forKey: savedEmailKey)

        // Fetch user info
        await fetchUser()
        isLoading = false
    }

    // MARK: - Sign Out

    @MainActor
    func signOut() {
        accessToken = nil
        refreshToken = nil
        user = nil
        orders = []
        pickupOrders = []
        isSignedIn = false
        error = nil

        KeychainService.delete(key: accessTokenKey)
        KeychainService.delete(key: refreshTokenKey)
        UserDefaults.standard.removeObject(forKey: userDataKey)
    }

    // MARK: - Fetch Data

    @MainActor
    func fetchOrders() async {
        guard let token = accessToken else { return }
        isLoading = true
        error = nil

        async let ordersResult = fetchJSON(endpoint: "/v1/p/orders?page=0&limit=30", token: token)
        async let pickupResult = fetchJSON(endpoint: "/v1/p/pickup-orders?page=0&limit=30", token: token)

        let (ordersData, pickupData) = await (ordersResult, pickupResult)

        if let ordersData {
            if let list = try? JSONDecoder().decode(LLabAPIResponse<LLabOrderListData>.self, from: ordersData),
               list.isSuccess, let data = list.data {
                checkOrderStatusChanges(data.items)
                orders = data.items
            }
        }

        if let pickupData {
            if let list = try? JSONDecoder().decode(LLabAPIResponse<LLabPickupOrderListData>.self, from: pickupData),
               list.isSuccess, let data = list.data {
                pickupOrders = data.items
            }
        }

        isLoading = false
    }

    @MainActor
    private func fetchUser() async {
        guard let token = accessToken else { return }

        if let data = await fetchJSON(endpoint: "/v1/p/user/me", token: token) {
            let decoder = JSONDecoder()
            if let response = try? decoder.decode(LLabAPIResponse<LLabUserMeResponse>.self, from: data),
               response.isSuccess, let me = response.data {
                let u = LLabUser(
                    id: me.id,
                    fullName: me.fullName,
                    email: me.email,
                    phone: me.phone ?? "",
                    rewardPoints: me.reward?.points ?? 0
                )
                user = u
                isSignedIn = true
                if let encoded = try? JSONEncoder().encode(u) {
                    UserDefaults.standard.set(encoded, forKey: userDataKey)
                }
                await fetchOrders()
                return
            }
        }

        // Fallback: try decoding token payload for basic info
        if let payload = decodeJWTPayload(token) {
            let u = LLabUser(
                id: payload.id,
                fullName: "",
                email: payload.email,
                phone: "",
                rewardPoints: 0
            )
            user = u
            isSignedIn = true
        }
    }

    // MARK: - Public Helpers

    func getSavedEmail() -> String? {
        UserDefaults.standard.string(forKey: savedEmailKey)
    }

    // MARK: - Private

    private func fetchGuestToken(email: String) async -> String? {
        let body = ["email": email]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body),
              let data = try? await postJSON(path: "/v1/g/user/login", body: bodyData, token: nil),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let token = dataObj["token"] as? String, !token.isEmpty else { return nil }
        return token
    }

    private func loginWithPassword(email: String, password: String, guestToken: String) async -> LLabLoginData? {
        let body = ["email": email, "password": password]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body),
              let data = try? await postJSON(path: "/v1/p/user/login", body: bodyData, token: guestToken),
              let loginData = try? JSONDecoder().decode(LLabAPIResponse<LLabLoginData>.self, from: data),
              loginData.isSuccess,
              let result = loginData.data else { return nil }
        return result
    }

    private func fetchJSON(endpoint: String, token: String) async -> Data? {
        guard let url = URL(string: baseURL + endpoint) else { return nil }
        var request = URLRequest(url: url)
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }
        return data
    }

    private func postJSON(path: String, body: Data, token: String?) async throws -> Data? {
        guard let url = URL(string: baseURL + path) else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body
        request.timeoutInterval = 30
        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }

    private func decodeJWTPayload(_ token: String) -> (id: String, email: String)? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var base64 = String(parts[1])
        base64 = base64.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let rem = base64.count % 4
        if rem > 0 { base64 += String(repeating: "=", count: 4 - rem) }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["id"] as? String,
              let email = json["email"] as? String else { return nil }
        return (id, email)
    }

    private func checkOrderStatusChanges(_ newOrders: [LLabOrder]) {
        let doneStatuses: Set<String> = ["done", "completed"]

        for order in newOrders {
            let newStatus = order.status.lowercased()
            let oldStatus = previousOrderStatuses[order.id]?.lowercased()

            if doneStatuses.contains(newStatus), oldStatus != newStatus, !notifiedDoneOrders.contains(order.id) {
                notifiedDoneOrders.insert(order.id)
                fireOrderDoneNotification(order)
            }

            previousOrderStatuses[order.id] = order.status
        }
    }

    private func fireOrderDoneNotification(_ order: LLabOrder) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    guard granted else { return }
                    self.scheduleDoneNotification(order)
                }
                return
            }
            self.scheduleDoneNotification(order)
        }
    }

    private func scheduleDoneNotification(_ order: LLabOrder) {
        let content = UNMutableNotificationContent()
        content.title = L("Order #%@ is ready!", order.orderNumber)
        content.body = L("Your film order at LLab is complete. Time to pick it up!")
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "llab_done_\(order.id)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func loadSavedCredentials() {
        accessToken = KeychainService.read(key: accessTokenKey)
        refreshToken = KeychainService.read(key: refreshTokenKey)

        if let userData = UserDefaults.standard.data(forKey: userDataKey),
           let savedUser = try? JSONDecoder().decode(LLabUser.self, from: userData) {
            user = savedUser
        }

        isSignedIn = accessToken != nil && user != nil
    }
}
