import Foundation
import Combine
import AuthenticationServices

final class GoogleDriveService: NSObject, ObservableObject {
    static let shared = GoogleDriveService()

    @Published var isSignedIn = false
    @Published var userEmail: String?
    @Published var userName: String?
    @Published var totalStorage: Int64 = 0
    @Published var usedStorage: Int64 = 0
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0

    private var accessToken: String?
    private var refreshToken: String?

    private let clientID = "1055225448670-mq2hlq85lp6gvn0rh8nsh1qj4e5s4dmc.apps.googleusercontent.com"
    private let redirectURI = "com.googleusercontent.apps.1055225448670-mq2hlq85lp6gvn0rh8nsh1qj4e5s4dmc:/oauth2redirect"
    private let tokenURL = "https://oauth2.googleapis.com/token"
    private let driveUploadURL = "https://www.googleapis.com/upload/drive/v3/files"

    private let accessTokenKey = "google_drive_access_token"
    private let refreshTokenKey = "google_drive_refresh_token"
    private let userEmailKey = "google_drive_email"
    private let userNameKey = "google_drive_name"

    var remainingStorage: Int64 { max(0, totalStorage - usedStorage) }

    var totalStorageFormatted: String { formatBytes(totalStorage) }
    var usedStorageFormatted: String { formatBytes(usedStorage) }
    var remainingStorageFormatted: String { formatBytes(remainingStorage) }

    override init() {
        super.init()
        loadSavedCredentials()
    }

    // MARK: - Auth

    func signIn() async {
        guard !clientID.isEmpty else {
            await MainActor.run {
                self.isSignedIn = false
            }
            return
        }
        let scopes = "https://www.googleapis.com/auth/drive.file https://www.googleapis.com/auth/drive.readonly https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/userinfo.profile"
        let authURL = "https://accounts.google.com/o/oauth2/v2/auth?client_id=\(clientID)&redirect_uri=\(redirectURI)&response_type=code&scope=\(scopes.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? scopes)&access_type=offline&prompt=consent"

        guard let url = URL(string: authURL) else { return }

        await MainActor.run {
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "com.googleusercontent.apps.1055225448670-mq2hlq85lp6gvn0rh8nsh1qj4e5s4dmc") { [weak self] callbackURL, error in
                guard let self, let callbackURL, error == nil else { return }
                if let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "code" })?.value {
                    Task { await self.exchangeCodeForToken(code) }
                }
            }
            session.prefersEphemeralWebBrowserSession = false
            session.presentationContextProvider = self
            session.start()
        }
    }

    func signOut() {
        accessToken = nil
        refreshToken = nil
        isSignedIn = false
        userEmail = nil
        userName = nil
        totalStorage = 0
        usedStorage = 0

        UserDefaults.standard.removeObject(forKey: accessTokenKey)
        UserDefaults.standard.removeObject(forKey: refreshTokenKey)
        UserDefaults.standard.removeObject(forKey: userEmailKey)
        UserDefaults.standard.removeObject(forKey: userNameKey)
    }

    // MARK: - Token Exchange

    private func exchangeCodeForToken(_ code: String) async {
        let params = [
            "code": code,
            "client_id": clientID,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code"
        ]

        guard let data = try? await postForm(url: tokenURL, params: params),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = json["access_token"] as? String else { return }

        await MainActor.run {
            self.accessToken = access
            self.refreshToken = (json["refresh_token"] as? String) ?? self.refreshToken
            self.isSignedIn = true
            UserDefaults.standard.set(access, forKey: accessTokenKey)
            if let refresh = self.refreshToken {
                UserDefaults.standard.set(refresh, forKey: refreshTokenKey)
            }
        }

        await fetchUserInfo()
        await fetchStorageQuota()
    }

    private func refreshAccessToken() async -> Bool {
        guard let refresh = refreshToken else { return false }
        let params = [
            "refresh_token": refresh,
            "client_id": clientID,
            "grant_type": "refresh_token"
        ]

        guard let data = try? await postForm(url: tokenURL, params: params),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = json["access_token"] as? String else { return false }

        await MainActor.run {
            self.accessToken = access
            UserDefaults.standard.set(access, forKey: accessTokenKey)
        }
        return true
    }

    // MARK: - User Info

    func fetchUserInfo() async {
        guard let token = accessToken else { return }
        var request = URLRequest(url: URL(string: "https://www.googleapis.com/oauth2/v2/userinfo")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        await MainActor.run {
            self.userEmail = json["email"] as? String
            self.userName = json["name"] as? String
            if let email = self.userEmail {
                UserDefaults.standard.set(email, forKey: userEmailKey)
            }
            if let name = self.userName {
                UserDefaults.standard.set(name, forKey: userNameKey)
            }
        }
    }

    func fetchStorageQuota() async {
        guard let token = accessToken else { return }
        var request = URLRequest(url: URL(string: "https://www.googleapis.com/drive/v3/about?fields=storageQuota")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        guard let (data, response) = try? await URLSession.shared.data(for: request) else { return }

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            if await refreshAccessToken() {
                await fetchStorageQuota()
            }
            return
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let quota = json["storageQuota"] as? [String: Any] else { return }

        await MainActor.run {
            if let limit = quota["limit"] as? String, let l = Int64(limit) { self.totalStorage = l }
            if let usage = quota["usage"] as? String, let u = Int64(usage) { self.usedStorage = u }
        }
    }

    // MARK: - Upload

    func uploadPhoto(data: Data, filename: String, folderId: String? = nil) async -> String? {
        guard let token = accessToken else { return nil }

        let boundary = UUID().uuidString
        var body = Data()

        let metadata: [String: Any] = {
            var m: [String: Any] = ["name": filename, "mimeType": "image/jpeg"]
            if let fid = folderId { m["parents"] = [fid] }
            return m
        }()

        guard let metadataJson = try? JSONSerialization.data(withJSONObject: metadata) else { return nil }

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/json; charset=UTF-8\r\n\r\n".data(using: .utf8)!)
        body.append(metadataJson)
        body.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: URL(string: "\(driveUploadURL)?uploadType=multipart")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/related; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        guard let (responseData, response) = try? await URLSession.shared.data(for: request) else { return nil }

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            if await refreshAccessToken() {
                return await uploadPhoto(data: data, filename: filename, folderId: folderId)
            }
            return nil
        }

        guard let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] else { return nil }
        return json["id"] as? String
    }

    func createFolder(name: String, parentId: String? = nil) async -> String? {
        guard let token = accessToken else { return nil }

        var metadata: [String: Any] = [
            "name": name,
            "mimeType": "application/vnd.google-apps.folder"
        ]
        if let pid = parentId { metadata["parents"] = [pid] }

        guard let body = try? JSONSerialization.data(withJSONObject: metadata) else { return nil }

        var request = URLRequest(url: URL(string: "https://www.googleapis.com/drive/v3/files")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json["id"] as? String
    }

    // MARK: - Download from shared link

    func downloadFromLink(_ link: String) async -> [(filename: String, data: Data)] {
        guard let token = accessToken else { return [] }
        var fileId: String?

        if link.contains("/folders/") {
            if let range = link.range(of: "/folders/") {
                let afterFolders = link[range.upperBound...]
                fileId = String(afterFolders.prefix(while: { $0 != "?" && $0 != "/" }))
            }
            guard let folderId = fileId else { return [] }
            return await downloadFolderContents(folderId: folderId, token: token)
        } else if link.contains("/file/d/") {
            if let range = link.range(of: "/file/d/") {
                let afterFile = link[range.upperBound...]
                fileId = String(afterFile.prefix(while: { $0 != "?" && $0 != "/" }))
            }
            guard let fid = fileId else { return [] }
            if let data = await downloadFile(fileId: fid, token: token) {
                return [(filename: "drive_photo.jpg", data: data)]
            }
        } else if link.contains("id=") {
            if let components = URLComponents(string: link),
               let id = components.queryItems?.first(where: { $0.name == "id" })?.value {
                fileId = id
            }
            guard let fid = fileId else { return [] }
            if let data = await downloadFile(fileId: fid, token: token) {
                return [(filename: "drive_photo.jpg", data: data)]
            }
        }
        return []
    }

    private func downloadFolderContents(folderId: String, token: String) async -> [(filename: String, data: Data)] {
        let query = "'\(folderId)' in parents and (mimeType contains 'image/')".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let listURL = "https://www.googleapis.com/drive/v3/files?q=\(query)&fields=files(id,name,mimeType)"

        var request = URLRequest(url: URL(string: listURL)!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let files = json["files"] as? [[String: Any]] else { return [] }

        var results: [(filename: String, data: Data)] = []
        for file in files {
            guard let id = file["id"] as? String,
                  let name = file["name"] as? String else { continue }
            if let fileData = await downloadFile(fileId: id, token: token) {
                results.append((filename: name, data: fileData))
            }
        }
        return results
    }

    private func downloadFile(fileId: String, token: String) async -> Data? {
        let downloadURL = "https://www.googleapis.com/drive/v3/files/\(fileId)?alt=media"
        var request = URLRequest(url: URL(string: downloadURL)!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else { return nil }
        return data
    }

    // MARK: - Helpers

    private func postForm(url: String, params: [String: String]) async throws -> Data {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = params.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&").data(using: .utf8)
        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }

    private func loadSavedCredentials() {
        accessToken = UserDefaults.standard.string(forKey: accessTokenKey)
        refreshToken = UserDefaults.standard.string(forKey: refreshTokenKey)
        userEmail = UserDefaults.standard.string(forKey: userEmailKey)
        userName = UserDefaults.standard.string(forKey: userNameKey)
        isSignedIn = accessToken != nil && refreshToken != nil
        if isSignedIn {
            Task { await fetchStorageQuota() }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let gb = Double(bytes) / (1024 * 1024 * 1024)
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        let mb = Double(bytes) / (1024 * 1024)
        if mb >= 1 { return String(format: "%.1f MB", mb) }
        let kb = Double(bytes) / 1024
        return String(format: "%.0f KB", kb)
    }
}

extension GoogleDriveService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }
}
