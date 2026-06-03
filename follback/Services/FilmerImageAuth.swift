import Foundation
import UIKit
import Kingfisher
import os

final class FilmerImageAuth: @unchecked Sendable {
    static let shared = FilmerImageAuth()

    private let _token = OSAllocatedUnfairLock<String?>(initialState: nil)
    private let bootstrapURL = URL(string: "https://api.getfilmer.com/api/device/bootstrap")!

    private init() {
        let saved = UserDefaults.standard.string(forKey: "filmerAPIToken")
        _token.withLock { $0 = saved }
    }

    func ensureToken() async {
        let existing = _token.withLock { $0 }
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

        _token.withLock { $0 = newToken }
        UserDefaults.standard.set(newToken, forKey: "filmerAPIToken")
    }

    var modifier: AnyModifier {
        return AnyModifier { [weak self] request in
            var r = request
            if let t = self?._token.withLock({ $0 }) {
                r.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
            }
            r.setValue("Filmer/1.0.22", forHTTPHeaderField: "User-Agent")
            return r
        }
    }

    func clearToken() {
        _token.withLock { $0 = nil }
        UserDefaults.standard.removeObject(forKey: "filmerAPIToken")
    }
}
