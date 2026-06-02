import Foundation
import UIKit
import Kingfisher

final class FilmerImageAuth: @unchecked Sendable {
    static let shared = FilmerImageAuth()

    private var token: String?
    private let lock = NSLock()
    private let bootstrapURL = URL(string: "https://api.getfilmer.com/api/device/bootstrap")!

    private init() {
        token = UserDefaults.standard.string(forKey: "filmerAPIToken")
    }

    func ensureToken() async {
        lock.lock()
        let existing = token
        lock.unlock()
        if existing != nil { return }
        await fetchToken()
    }

    private func fetchToken() async {
        var request = URLRequest(url: bootstrapURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Filmer/1.0.22", forHTTPHeaderField: "User-Agent")
        request.setValue("1.0.22", forHTTPHeaderField: "x-filmer-app-version")
        request.setValue("ios", forHTTPHeaderField: "x-filmer-platform")

        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let body: [String: String] = ["debugDeviceId": deviceId]
        request.httpBody = try? JSONEncoder().encode(body)

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newToken = json["token"] as? String else {
            return
        }

        lock.lock()
        token = newToken
        lock.unlock()
        UserDefaults.standard.set(newToken, forKey: "filmerAPIToken")
    }

    var modifier: AnyModifier {
        let currentToken = { [weak self] () -> String? in
            self?.lock.lock()
            defer { self?.lock.unlock() }
            return self?.token
        }
        return AnyModifier { request in
            var r = request
            if let t = currentToken() {
                r.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
            }
            r.setValue("Filmer/1.0.22", forHTTPHeaderField: "User-Agent")
            return r
        }
    }

    func clearToken() {
        lock.lock()
        token = nil
        lock.unlock()
        UserDefaults.standard.removeObject(forKey: "filmerAPIToken")
    }
}
