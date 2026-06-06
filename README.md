# FilmVault

> Track your film photography journey — rolls, cameras, lenses, labs, and spending.

FilmVault is a private iOS app for film photographers who want to log every roll, track their gear, monitor lab orders, and visualize their shooting habits. Built with SwiftUI + SwiftData, targeting iOS 17+.

## Features

| Feature | Description |
|---|---|
| **🎞️ Roll Tracking** | Log every roll with film stock, camera, lens, lab, and frame-by-frame notes. Track exposure, development date, and cost. |
| **📷 Photo Import** | Import photos from your Photo Library, Camera, Files, or Google Drive. Link each photo to a specific frame. |
| **🖤 Darkroom** | Built-in photo editor: brightness, contrast, saturation, temperature, grain, vignette, and more. |
| **☀️ Light Meter** | Incident light metering with zone-based EV readings. Dial-based UI for aperture/shutter/ISO. |
| **📊 Statistics** | Spending insights, roll counts, gear usage, and achievements. Unlock milestones as you shoot more. |
| **🧪 LLab Integration** | Sign in to LLab (Vietnamese film lab) to track your developing orders in real time. Push notifications when an order is done. |
| **☁️ Google Drive Backup** | Upload and restore your entire roll and camera database to Google Drive. |
| **🗺️ Maps** | See where your frames were shot on an interactive MapKit view. Frame-level location editing. |
| **⏰ Reminders** | Get notified when rolls need developing, gear sits idle, or you hit photography milestones. |
| **🔒 Live Activity** | Show your current in-progress roll on the Lock Screen and Dynamic Island via WidgetKit. |
| **🌍 Localization** | 8 languages with in-app language picker + Follow System option. Runtime switching without restart. |

## Tech Stack

- **SwiftUI** — Declarative UI with `@ObservableObject`, `@AppStorage`, `@Query`
- **SwiftData** — First-party persistence with `@Model` macros and `#Index`
- **Kingfisher** — Image caching and async loading for film cover art
- **URLSession** — Networking for Google Drive API and LLab API
- **UserNotifications** — Local notifications for reminders and LLab order status
- **WidgetKit** — Lock Screen and Dynamic Island Live Activities
- **AuthenticationServices** — `ASWebAuthenticationSession` for Google OAuth
- **ARKit + RealityKit** — AR photo gallery viewer
- **MapKit** — Map annotations for photo locations

## Project Structure

```
follback/
├── FilmVaultApp.swift                  # App entry point, SwiftData container setup
├── PrivacyInfo.xcprivacy               # Privacy manifest (App Store requirement)
│
├── Models/                             # SwiftData models + data models
│   ├── Roll.swift                      # Core roll model (film stock, frames, cost, lab)
│   ├── Frame.swift                     # Individual frame (photo asset, number, notes)
│   ├── Camera.swift                    # Camera model (make, model, lens mount)
│   ├── FilmStock.swift                 # Film stock model (ISO, format, brand)
│   ├── FilmLab.swift                   # Lab model (name, location, notes)
│   ├── CustomFilmModel.swift           # User-created film stock entries
│   ├── CustomLab.swift                 # User-created lab entries
│   ├── Enums.swift                     # Shared enums (film format, development status)
│   └── LLabModels.swift                # LLab API response models
│
├── Services/                           # Networking, persistence, notifications
│   ├── GoogleDriveService.swift        # Google Drive OAuth + upload/download
│   ├── LLabService.swift               # LLab API: auth, orders, polling, notifications
│   ├── KeychainService.swift           # Secure token storage via Security framework
│   ├── BackupService.swift             # JSON export/import for roll & camera data
│   ├── LocalizationManager.swift       # In-app language switching (8 languages)
│   ├── ReminderService.swift           # UNNotification scheduling for reminders
│   ├── LiveActivityManager.swift       # WidgetKit Live Activity management
│   └── WidgetDataService.swift         # Shared data for widget extension
│
├── Views/                              # SwiftUI views
│   ├── Components/                     # Reusable UI components
│   │   ├── RollCard.swift              # Roll list card with physics animation
│   │   ├── PhotoThumbnail.swift        # Frame photo thumbnail grid
│   │   ├── FilmFrameProgress.swift     # Circular progress indicator for roll capacity
│   │   ├── FilmStockPickerView.swift   # Film stock search/picker sheet
│   │   ├── PhotoShareCardView.swift    # Share card for social media export
│   │   ├── BarChartView.swift          # Spending/statistics bar chart
│   │   ├── DialPicker.swift            # Light meter dial control
│   │   ├── Color+Film.swift            # Custom color palette (filmSurface, filmAccent, etc.)
│   │   └── ThemeProvider.swift         # Accent color + locale & layout direction
│   │
│   ├── ARGallery/                      # AR photo gallery
│   │   ├── ARGalleryView.swift         # AR gallery with photo walls
│   │   └── ARPhotoGalleryView.swift    # Per-roll AR photo viewer
│   │
│   ├── ContentView.swift               # Tab-based root navigation
│   ├── RollsView.swift                 # Main roll list (search, filter, archive)
│   ├── RollDetailView.swift            # Full roll detail with photo grid, editor
│   ├── AddRollView.swift               # New roll creation form
│   ├── FrameEditorView.swift           # Per-frame notes editor
│   ├── FrameViewerView.swift           # Full-screen frame photo viewer
│   ├── CamerasView.swift               # Camera & lens library
│   ├── AddCameraView.swift             # New camera entry form
│   ├── DarkroomView.swift              # Photo editing (brightness, curves, filters)
│   ├── LightMeterView.swift            # Zone-based exposure meter
│   ├── SettingsView.swift              # All settings: Drive, LLab, reminders, theme, language
│   ├── LLabOrderTrackerView.swift      # LLab login + order list with polling
│   ├── StatisticsView.swift            # Charts, spending, achievements
│   ├── RollsMapView.swift              # Map with frame location annotations
│   ├── LabsView.swift                  # Lab directory
│   ├── SearchView.swift                # Global search across rolls/cameras
│   ├── OnboardingView.swift            # First-launch onboarding
│   └── ...                             # Additional support views
│
├── Assets.xcassets/
│   ├── AppIcon.appiconset/
│   ├── AccentColor.colorset/
│   └── LLabLogo.imageset/
│
├── *.lproj/                            # Localized strings (8 languages)
│   ├── en.lproj/
│   ├── vi.lproj/
│   ├── zh-Hans.lproj/
│   ├── ja.lproj/
│   ├── hi.lproj/
│   ├── ar.lproj/
│   ├── ru.lproj/
│   └── es.lproj/
│
├── Intents/                            # App Intents for Siri/Shortcuts
│   └── FilmVaultIntents.swift
│
└── follback.xcodeproj                  # Xcode project
```

## Setup

### Requirements

- Xcode 15+ (iOS 17+ SDK)
- iOS 17+ device or simulator

### Build & Run

```bash
open follback.xcodeproj
# Select an iOS 17+ simulator or device, then Product → Run (⌘R)
```

Or via command line:

```bash
xcodebuild -scheme FilmVault -destination 'platform=iOS Simulator,name=iPhone 16' build
xcrun simctl install <device-uuid> <path-to-FilmVault.app>
xcrun simctl launch <device-uuid> com.williamcachamwri.FilmVault
```

### Dependencies

Managed via Swift Package Manager:
- [Kingfisher](https://github.com/onevcat/Kingfisher) — Image caching

## Architecture

**Pattern**: MV-ish with SwiftData as the persistence layer and `@ObservableObject` services for networking.

- **Models** are SwiftData `@Model` classes with `#Index` and `#Unique` for efficient queries.
- **Services** are singletons (`GoogleDriveService`, `LLabService`, `ReminderManager`) that conform to `ObservableObject` and publish state.
- **Views** observe services via `@ObservedObject` and use `@Query` for SwiftData fetch.
- **Localization** uses `.strings` files per language, loaded dynamically via `LocalizationManager` with runtime bundle swizzling — no app restart needed on language change.
- **LLab API flow**: Guest token → user token → JWT-based auth, with 30s polling for order updates and push notifications on status changes.

## License

© 2025 William Cachamwri. All rights reserved.

---

*Built with SwiftUI for film photography enthusiasts.*
