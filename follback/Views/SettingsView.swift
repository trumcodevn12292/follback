import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query(sort: \Roll.createdAt, order: .reverse) var rolls: [Roll]
    @Query(sort: \Camera.name) var cameras: [Camera]
    @State private var appeared = false
    @AppStorage("photoImportMode") private var photoImportModeRaw: String = PhotoImportMode.copy.rawValue

    private var photoImportMode: Binding<PhotoImportMode> {
        Binding(
            get: { PhotoImportMode(rawValue: photoImportModeRaw) ?? .copy },
            set: { photoImportModeRaw = $0.rawValue }
        )
    }
    @State private var showClearCacheAlert = false
    @State private var cacheCleared = false
    @State private var cacheSizeText = "Calculating..."

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
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                    appeared = true
                }
            }
            .alert("Clear Cache", isPresented: $showClearCacheAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    clearCache()
                }
            } message: {
                Text("This will clear temporary files and URL cache. Cover images will be kept.")
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
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: appeared)
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

                    Picker("", selection: photoImportMode) {
                        ForEach(PhotoImportMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(photoImportMode.wrappedValue.description)
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
                                .transition(.opacity.combined(with: .scale))
                        } else {
                            Text(cacheSizeText)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.filmTertiary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color.filmTertiary.opacity(0.5))
                        }
                    }
                    .padding(16)
                }
                .buttonStyle(.plain)
                .onAppear { calculateCacheSize() }
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.filmSurface)
            )
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
        .scaleEffect(appeared ? 1 : 0.97)
        .animation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.05), value: appeared)
    }

    private func calculateCacheSize() {
        var totalSize: UInt64 = 0

        // URL cache
        totalSize += UInt64(URLCache.shared.currentDiskUsage)

        // Tmp directory
        let tmpDir = FileManager.default.temporaryDirectory
        if let files = try? FileManager.default.contentsOfDirectory(at: tmpDir, includingPropertiesForKeys: [.fileSizeKey]) {
            for file in files {
                if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += UInt64(size)
                }
            }
        }

        cacheSizeText = formatBytes(totalSize)
    }

    private func folderSize(at url: URL) -> UInt64 {
        var size: UInt64 = 0
        if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    size += UInt64(fileSize)
                }
            }
        }
        return size
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let mb = Double(bytes) / (1024 * 1024)
        if mb < 1 {
            let kb = Double(bytes) / 1024
            return String(format: "%.0f KB", kb)
        } else if mb >= 1024 {
            let gb = mb / 1024
            return String(format: "%.1f GB", gb)
        }
        return String(format: "%.1f MB", mb)
    }

    private func clearCache() {
        // Only clear URL cache and temp files — keep Kingfisher image cache
        // so cover images for films and cameras don't need to reload
        URLCache.shared.removeAllCachedResponses()

        let tmpDir = FileManager.default.temporaryDirectory
        if let files = try? FileManager.default.contentsOfDirectory(at: tmpDir, includingPropertiesForKeys: nil) {
            for file in files {
                try? FileManager.default.removeItem(at: file)
            }
        }

        withAnimation(.spring(response: 0.4)) { cacheCleared = true }
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.spring(response: 0.4)) {
                cacheCleared = false
            }
            calculateCacheSize()
        }
    }
}
