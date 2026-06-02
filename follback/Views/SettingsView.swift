import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query(sort: \Roll.createdAt, order: .reverse) var rolls: [Roll]
    @Query(sort: \Camera.name) var cameras: [Camera]
    @State private var appeared = false
    @State private var photoImportMode: PhotoImportMode = .copy
    @State private var showClearCacheAlert = false
    @State private var cacheCleared = false

    enum PhotoImportMode: String, CaseIterable {
        case copy = "Copy"
        case reference = "Reference"

        var description: String {
            switch self {
            case .copy: return "Photos are copied into the app's storage"
            case .reference: return "Photos are referenced from your Photo Library"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerSection
                    storageCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .padding(.bottom, 20)
            }
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear {
                withAnimation(.easeOut(duration: 0.4)) {
                    appeared = true
                }
            }
            .alert("Clear Cache", isPresented: $showClearCacheAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    clearCache()
                }
            } message: {
                Text("This will remove all cached images. They will be re-downloaded when needed.")
            }
        }
        .background(Color.filmBackground.ignoresSafeArea())
    }

    private var headerSection: some View {
        HStack {
            Text("SETTINGS")
                .font(.system(size: 28, weight: .black))
                .foregroundColor(Color.filmText)
                .kerning(1.5)
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -10)
        .animation(.easeOut(duration: 0.3), value: appeared)
    }

    private var storageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("STORAGE")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.filmTertiary)
                .kerning(0.8)

            VStack(spacing: 0) {
                // Photo Import Mode
                VStack(alignment: .leading, spacing: 10) {
                    Text("Photo Import")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.filmText)

                    Picker("", selection: $photoImportMode) {
                        ForEach(PhotoImportMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(photoImportMode.description)
                        .font(.system(size: 13))
                        .foregroundColor(Color.filmTertiary)
                }
                .padding(16)

                Divider().background(Color.filmBorder.opacity(0.3))

                // Clear Cache
                Button {
                    showClearCacheAlert = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "trash")
                            .font(.system(size: 15))
                            .foregroundColor(.red.opacity(0.8))
                            .frame(width: 24)
                        Text("Clear Cache")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.filmText)
                        Spacer()
                        if cacheCleared {
                            Text("Cleared")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.filmAccent)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color.filmTertiary.opacity(0.5))
                        }
                    }
                    .padding(16)
                }
                .buttonStyle(.plain)
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.filmSurface)
            )
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
        .animation(.easeOut(duration: 0.35).delay(0.05), value: appeared)
    }

    private func clearCache() {
        // Clear Kingfisher image cache
        let cache = URLCache.shared
        cache.removeAllCachedResponses()

        // Clear tmp directory
        let tmpDir = FileManager.default.temporaryDirectory
        if let files = try? FileManager.default.contentsOfDirectory(at: tmpDir, includingPropertiesForKeys: nil) {
            for file in files {
                try? FileManager.default.removeItem(at: file)
            }
        }

        withAnimation { cacheCleared = true }
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { cacheCleared = false }
        }
    }
}
