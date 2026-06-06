import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import Kingfisher

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Query(sort: \Roll.createdAt, order: .reverse) var rolls: [Roll]
    @Query(sort: \Camera.name) var cameras: [Camera]
    @State private var appeared = false
    @State private var showExporter = false
    @State private var backupDocument: BackupDocument?
    @State private var showImporter = false
    @State private var backupResultMessage: String?
    @State private var showBackupResult = false
    @AppStorage("photoImportMode") private var photoImportModeRaw: String = PhotoImportMode.copy.rawValue
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showResetOnboardingAlert = false
    @ObservedObject private var driveService = GoogleDriveService.shared
    @ObservedObject private var lLab = LLabService.shared
    @ObservedObject private var reminderManager = ReminderManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var l10n = LocalizationManager.shared
    @AppStorage(ReminderDefaults.enabledKey) private var remindersEnabled = false
    @AppStorage(ReminderDefaults.staleDaysKey) private var staleDays = ReminderDefaults.defaultStaleDays
    @AppStorage(ReminderDefaults.developDaysKey) private var developDays = ReminderDefaults.defaultDevelopDays
    @AppStorage(ReminderDefaults.hourKey) private var reminderHour = ReminderDefaults.defaultHour
    @AppStorage(LiveActivityManager.enabledKey) private var liveActivityEnabled = true
    @AppStorage(Money.currencyKey) private var currencyCode = Money.defaultCode
    @State private var showNotifPermissionAlert = false

    private var photoImportMode: Binding<PhotoImportMode> {
        Binding(
            get: { PhotoImportMode(rawValue: photoImportModeRaw) ?? .copy },
            set: { photoImportModeRaw = $0.rawValue }
        )
    }
    @State private var showClearCacheAlert = false
    @State private var cacheCleared = false
    @State private var cacheSizeText = "Calculating..."
    @State private var versionCopied = false
    @State private var showSignOutAlert = false

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

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.48"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "48"
        return "v\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerSection
                    appearanceCard
                    languageCard
                    spendingCard
                    storageCard
                    remindersCard
                    liveActivityCard
                    googleDriveCard
                    llabCard
                    dataCard
                    generalCard
                    aboutCard
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
                reminderManager.refreshAuthorizationStatus()
            }
            .alert("Clear Cache", isPresented: $showClearCacheAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    clearCache()
                }
            } message: {
                Text("This will clear temporary files and URL cache. Cover images will be kept.")
            }
            .alert("Reset Onboarding", isPresented: $showResetOnboardingAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    hasSeenOnboarding = false
                }
            } message: {
                Text("The onboarding screen will show again next time you open the app.")
            }
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    driveService.signOut()
                }
            } message: {
                Text("You will be signed out of Google Drive. Photos already uploaded will remain on Drive.")
            }
            .fileExporter(
                isPresented: $showExporter,
                document: backupDocument,
                contentType: .json,
                defaultFilename: BackupService.suggestedFileName()
            ) { result in
                switch result {
                case .success:
                    backupResultMessage = "Backup saved successfully."
                case .failure(let error):
                    backupResultMessage = "Export failed: \(error.localizedDescription)"
                }
                showBackupResult = true
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.json]
            ) { result in
                handleImport(result)
            }
            .alert("Data", isPresented: $showBackupResult) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(backupResultMessage ?? "")
            }
            .alert("Notifications Off", isPresented: $showNotifPermissionAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Enable notifications for FilmVault in iOS Settings to receive roll reminders.")
            }
        }
        .background(Color.filmBackground.ignoresSafeArea())
    }

    private var headerSection: some View {
        HStack {
            HStack(spacing: 8) {
                Image("AppIconSmall")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                Text("SETTINGS")
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(Color.filmText)
                    .kerning(1.5)
            }
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

    // MARK: - Google Drive Card

    private var googleDriveCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GOOGLE DRIVE")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.filmTertiary)
                .kerning(0.8)

            VStack(spacing: 0) {
                if driveService.isSignedIn {
                    // Account info
                    HStack(spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(Color.filmAccent)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(driveService.userName ?? "Google Account")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color.filmText)
                            Text(driveService.userEmail ?? "")
                                .font(.system(size: 13))
                                .foregroundColor(Color.filmTertiary)
                        }
                        Spacer()
                    }
                    .padding(16)

                    Divider().background(Color.filmBorder.opacity(0.3))

                    // Storage info
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Storage")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.filmSecondary)
                            Spacer()
                            Text("\(driveService.usedStorageFormatted) / \(driveService.totalStorageFormatted)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.filmTertiary)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.filmBorder.opacity(0.3))
                                    .frame(height: 6)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.filmAccent)
                                    .frame(width: driveService.totalStorage > 0
                                        ? geo.size.width * CGFloat(Double(driveService.usedStorage) / Double(driveService.totalStorage))
                                        : 0,
                                        height: 6)
                            }
                        }
                        .frame(height: 6)

                        Text("\(driveService.remainingStorageFormatted) remaining")
                            .font(.system(size: 12))
                            .foregroundColor(Color.filmTertiary)
                    }
                    .padding(16)

                    Divider().background(Color.filmBorder.opacity(0.3))

                    // Sign out
                    Button {
                        showSignOutAlert = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 15))
                                .foregroundColor(.red.opacity(0.8))
                                .frame(width: 24)
                            Text("Sign Out")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.red.opacity(0.8))
                            Spacer()
                        }
                        .padding(16)
                    }
                    .buttonStyle(.plain)
                } else {
                    // Sign in button
                    Button {
                        Task { await driveService.signIn() }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "externaldrive.badge.plus")
                                .font(.system(size: 18))
                                .foregroundColor(Color.filmAccent)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sign in to Google Drive")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color.filmText)
                                Text("Upload film photos to your Drive")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color.filmTertiary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color.filmTertiary.opacity(0.5))
                        }
                        .padding(16)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.filmSurface)
            )
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
        .animation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.07), value: appeared)
    }

    private var llabCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LLAB")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.filmTertiary)
                .kerning(0.8)

            VStack(spacing: 0) {
                if lLab.isSignedIn {
                    NavigationLink {
                        LLabOrderTrackerView()
                    } label: {
                        HStack(spacing: 12) {
                            Image("LLabLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(lLab.user?.fullName ?? "LLab")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color.filmText)
                                Text(L("%d points · %d orders", lLab.user?.rewardPoints ?? 0, lLab.orders.count))
                                    .font(.system(size: 13))
                                    .foregroundColor(Color.filmTertiary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color.filmTertiary.opacity(0.5))
                        }
                        .padding(16)
                    }
                    .buttonStyle(.plain)
                } else {
                    NavigationLink {
                        LLabOrderTrackerView()
                    } label: {
                        HStack(spacing: 12) {
                            Image("LLabLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sign in to LLab")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color.filmText)
                                Text("Track your film developing orders")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color.filmTertiary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color.filmTertiary.opacity(0.5))
                        }
                        .padding(16)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.filmSurface)
            )
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
        .animation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.08), value: appeared)
    }

    // MARK: - General Card

    private var generalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GENERAL")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.filmTertiary)
                .kerning(0.8)

            VStack(spacing: 0) {
                Button {
                    showResetOnboardingAlert = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 15))
                            .foregroundColor(Color.filmAccent)
                            .frame(width: 24)
                        Text("Reset Onboarding")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.filmText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color.filmTertiary.opacity(0.5))
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
        .animation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.1), value: appeared)
    }

    // MARK: - Live Activity Card
    private var liveActivityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LOCK SCREEN")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.filmTertiary)
                .kerning(0.8)

            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: $liveActivityEnabled) {
                    Text("Live Activity")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.filmText)
                }
                .tint(Color.filmAccent)
                .onChange(of: liveActivityEnabled) { _, newValue in
                    LiveActivityManager.shared.setFeatureEnabled(newValue, rolls: rolls)
                }

                Text("Show the roll you're currently shooting on the Lock Screen and Dynamic Island.")
                    .font(.system(size: 13))
                    .foregroundColor(Color.filmTertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.filmSurface)
            )
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
        .animation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.07), value: appeared)
    }

    // MARK: - Appearance Card
    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("APPEARANCE")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.filmTertiary)
                .kerning(0.8)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accent Color")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.filmText)
                        Text("Used for highlights and buttons across the app")
                            .font(.system(size: 13))
                            .foregroundColor(Color.filmTertiary)
                    }
                    Spacer()
                }

                let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: hSizeClass == .regular ? 6 : 4)
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(AccentOption.all) { option in
                        let isSelected = themeManager.accentHex.lowercased() == option.hex.lowercased()
                        Button {
                            selectAccent(option)
                        } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(option.color)
                                        .frame(width: 38, height: 38)
                                    Circle()
                                        .stroke(Color.filmText, lineWidth: isSelected ? 2.5 : 0)
                                        .frame(width: 46, height: 46)
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(width: 46, height: 46)
                                Text(option.name)
                                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                                    .foregroundColor(isSelected ? Color.filmText : Color.filmTertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.filmSurface)
            )
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
        .animation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.04), value: appeared)
    }

    private func selectAccent(_ option: AccentOption) {
        guard themeManager.accentHex.lowercased() != option.hex.lowercased() else { return }
        themeManager.accentHex = option.hex
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Language Card
    private var languageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("LANGUAGE"))
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.filmTertiary)
                .kerning(0.8)

            VStack(spacing: 0) {
                // Follow System
                Button {
                    selectFollowSystem()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "globe")
                            .font(.system(size: 20))
                            .foregroundColor(Color.filmAccent)
                            .frame(width: 26)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(L("FOLLOW_SYSTEM"))
                                .font(.system(size: 16, weight: l10n.isFollowingSystem ? .semibold : .regular))
                                .foregroundColor(Color.filmText)
                            Text(systemLanguageName)
                                .font(.system(size: 12))
                                .foregroundColor(Color.filmTertiary)
                        }
                        Spacer()
                        if l10n.isFollowingSystem {
                            Image(systemName: "checkmark")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(Color.filmAccent)
                        }
                    }
                    .padding(.vertical, 13)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider().background(Color.filmBorder.opacity(0.3))

                ForEach(Array(AppLanguage.allCases.enumerated()), id: \.element.id) { index, lang in
                    let isSelected = !l10n.isFollowingSystem && l10n.language == lang
                    Button {
                        selectLanguage(lang)
                    } label: {
                        HStack(spacing: 12) {
                            Text(lang.flag)
                                .font(.system(size: 22))
                            Text(lang.nativeName)
                                .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                                .foregroundColor(Color.filmText)
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(Color.filmAccent)
                            }
                        }
                        .padding(.vertical, 13)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < AppLanguage.allCases.count - 1 {
                        Divider().background(Color.filmBorder.opacity(0.3))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.filmSurface)
            )
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
        .animation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.05), value: appeared)
    }

    private var systemLanguageName: String {
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        let locale = Locale(identifier: code)
        return locale.localizedString(forLanguageCode: code) ?? code.uppercased()
    }

    private func selectFollowSystem() {
        guard !l10n.isFollowingSystem else { return }
        l10n.isFollowingSystem = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func selectLanguage(_ lang: AppLanguage) {
        guard l10n.language != lang else { return }
        l10n.isFollowingSystem = false
        l10n.language = lang
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Spending Card

    private var grandTotalSpent: Double {
        rolls.compactMap { $0.totalCost }.reduce(0, +)
            + cameras.compactMap { $0.purchasePrice }.reduce(0, +)
    }

    private var spendingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("SPENDING"))
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.filmTertiary)
                .kerning(0.8)

            VStack(spacing: 0) {
                // Currency picker
                HStack {
                    Text(L("Currency"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.filmText)
                    Spacer()
                    Menu {
                        ForEach(Money.commonCodes, id: \.self) { code in
                            Button {
                                currencyCode = code
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                if code == currencyCode {
                                    Label(code, systemImage: "checkmark")
                                } else {
                                    Text(code)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(currencyCode)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color.filmAccent)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color.filmTertiary)
                        }
                    }
                }
                .padding(16)

                Divider().background(Color.filmBorder.opacity(0.3))

                HStack {
                    Text(L("Insights"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.filmText)
                    Spacer()
                    if grandTotalSpent > 0 {
                        Text(Money.format(grandTotalSpent))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color.filmAccent)
                    }
                    Image(systemName: "chart.bar")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.filmTertiary)
                }
                .padding(16)
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.filmSurface)
            )
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
        .animation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.05), value: appeared)
    }

    // MARK: - Reminders Card

    private var remindersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("REMINDERS")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.filmTertiary)
                .kerning(0.8)

            VStack(spacing: 0) {
                // Master toggle
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: $remindersEnabled) {
                        Text("Enable Reminders")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.filmText)
                    }
                    .tint(Color.filmAccent)
                    .onChange(of: remindersEnabled) { _, newValue in
                        handleRemindersToggle(newValue)
                    }

                    Text("Get notified about rolls you're still shooting and finished rolls waiting to be developed.")
                        .font(.system(size: 13))
                        .foregroundColor(Color.filmTertiary)
                }
                .padding(16)

                if remindersEnabled {
                    Divider().background(Color.filmBorder.opacity(0.3))

                    reminderStepperRow(
                        title: "Shooting nudge",
                        subtitle: "After a roll stays in progress",
                        value: $staleDays,
                        range: 3...120,
                        unit: "days"
                    )

                    Divider().background(Color.filmBorder.opacity(0.3))

                    reminderStepperRow(
                        title: "Develop reminder",
                        subtitle: "After a roll is finished",
                        value: $developDays,
                        range: 1...60,
                        unit: "days"
                    )

                    Divider().background(Color.filmBorder.opacity(0.3))

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Time of day")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color.filmText)
                            Text("When reminders are delivered")
                                .font(.system(size: 13))
                                .foregroundColor(Color.filmTertiary)
                        }
                        Spacer()
                        Picker("", selection: $reminderHour) {
                            ForEach(0..<24, id: \.self) { hour in
                                Text(String(format: "%02d:00", hour)).tag(hour)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Color.filmAccent)
                        .onChange(of: reminderHour) { _, _ in
                            reminderManager.reschedule(rolls: rolls)
                        }
                    }
                    .padding(16)

                    if remindersEnabled {
                        Divider().background(Color.filmBorder.opacity(0.3))
                            .padding(.horizontal, 16)
                        Button {
                            Task {
                                let granted = await reminderManager.requestAuthorization()
                                if granted {
                                    reminderManager.sendTestNotification()
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "bell.badge.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color.filmAccent)
                                Text("Send Test Notification")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color.filmAccent)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.filmSurface)
            )
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
        .animation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.06), value: appeared)
    }

    private func reminderStepperRow(title: String, subtitle: String, value: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(title))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.filmText)
                Text(LocalizedStringKey(subtitle))
                    .font(.system(size: 13))
                    .foregroundColor(Color.filmTertiary)
            }
            Spacer()
            HStack(spacing: 0) {
                Button {
                    adjustStepper(value, by: -1, in: range)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(value.wrappedValue > range.lowerBound ? Color.filmAccent : Color.filmTertiary)
                        .frame(width: 38, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(value.wrappedValue <= range.lowerBound)

                Text("\(value.wrappedValue) \(L(unit))")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color.filmAccent)
                    .frame(minWidth: 64)

                Button {
                    adjustStepper(value, by: 1, in: range)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(value.wrappedValue < range.upperBound ? Color.filmAccent : Color.filmTertiary)
                        .frame(width: 38, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(value.wrappedValue >= range.upperBound)
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.filmSurfaceSecondary)
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.filmBorder, lineWidth: 0.5))
            )
        }
        .padding(16)
    }

    private func adjustStepper(_ value: Binding<Int>, by delta: Int, in range: ClosedRange<Int>) {
        let newValue = min(max(value.wrappedValue + delta, range.lowerBound), range.upperBound)
        guard newValue != value.wrappedValue else { return }
        value.wrappedValue = newValue
        reminderManager.reschedule(rolls: rolls)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func handleRemindersToggle(_ newValue: Bool) {
        if newValue {
            Task {
                let granted = await reminderManager.requestAuthorization()
                if granted {
                    reminderManager.reschedule(rolls: rolls)
                } else {
                    remindersEnabled = false
                    showNotifPermissionAlert = true
                }
            }
        } else {
            reminderManager.cancelAll()
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Data Card

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DATA")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.filmTertiary)
                .kerning(0.8)

            VStack(spacing: 0) {
                Button {
                    exportBackup()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15))
                            .foregroundColor(Color.filmAccent)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Export Data")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color.filmText)
                            Text("\(rolls.count) rolls · \(cameras.count) cameras")
                                .font(.system(size: 13))
                                .foregroundColor(Color.filmTertiary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color.filmTertiary.opacity(0.5))
                    }
                    .padding(16)
                }
                .buttonStyle(.plain)

                Divider().background(Color.filmBorder.opacity(0.3))

                Button {
                    showImporter = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 15))
                            .foregroundColor(Color.filmAccent)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Import Data")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color.filmText)
                            Text("Restore from a backup file")
                                .font(.system(size: 13))
                                .foregroundColor(Color.filmTertiary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color.filmTertiary.opacity(0.5))
                    }
                    .padding(16)
                }
                .buttonStyle(.plain)
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.filmSurface)
            )

            Text("Photos stay linked to your Photo Library, so a backup keeps everything after reinstalling. Importing merges into existing data.")
                .font(.system(size: 12))
                .foregroundColor(Color.filmTertiary)
                .padding(.horizontal, 4)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
        .animation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.09), value: appeared)
    }

    private func exportBackup() {
        let backup = BackupService.makeBackup(rolls: rolls, cameras: cameras)
        do {
            let data = try BackupService.encode(backup)
            backupDocument = BackupDocument(data: data)
            showExporter = true
        } catch {
            backupResultMessage = "Export failed: \(error.localizedDescription)"
            showBackupResult = true
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let needsStop = url.startAccessingSecurityScopedResource()
            defer { if needsStop { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let backup = try BackupService.decode(data)
                let summary = BackupService.restore(backup, into: modelContext)
                backupResultMessage = L("Imported %d rolls, %d cameras, %d custom films, %d labs.", summary.rollsAdded, summary.camerasAdded, summary.customFilmsAdded, summary.customLabsAdded)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                backupResultMessage = L("Import failed: %@", error.localizedDescription)
            }
        case .failure(let error):
            backupResultMessage = L("Import failed: %@", error.localizedDescription)
        }
        showBackupResult = true
    }

    // MARK: - About Card

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ABOUT")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.filmTertiary)
                .kerning(0.8)

            VStack(spacing: 0) {
                Button {
                    UIPasteboard.general.string = appVersion
                    withAnimation(.spring(response: 0.3)) { versionCopied = true }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation(.spring(response: 0.3)) { versionCopied = false }
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 15))
                            .foregroundColor(Color.filmAccent)
                            .frame(width: 24)
                        Text("Version")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.filmText)
                        Spacer()
                        if versionCopied {
                            Text("Copied!")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.filmAccent)
                                .transition(.opacity.combined(with: .scale))
                        } else {
                            Text(appVersion)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.filmTertiary)
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 11))
                                .foregroundColor(Color.filmTertiary.opacity(0.5))
                        }
                    }
                    .padding(16)
                }
                .buttonStyle(.plain)

                Divider().background(Color.filmBorder.opacity(0.3))

                // Copyright
                HStack(spacing: 12) {
                    Image(systemName: "c.circle")
                        .font(.system(size: 15))
                        .foregroundColor(Color.filmAccent)
                        .frame(width: 24)
                    Text("Copyright")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.filmText)
                    Spacer()
                    Text("\(Calendar.current.component(.year, from: Date())) FilmVault")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.filmTertiary)
                }
                .padding(16)
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.filmSurface)
            )
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
        .animation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.12), value: appeared)
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


