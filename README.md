# FilmVault

Track your film photography journey — rolls, cameras, lenses, labs, and spending. iOS 17+.

## Features

- **Roll tracking** — Log every roll with film stock, camera, lens, lab, and frame-by-frame notes
- **Photo import** — Import photos from your library or Google Drive, link them to frames
- **Camera & lens database** — Browse built-in cameras or add your own
- **Darkroom** — Edit photos with brightness, contrast, saturation, temperature, and more
- **Light meter** — Incident light metering with zone-based EV readings
- **Statistics** — Spending insights, roll counts, and gear usage
- **LLab integration** — Sign in to LLab (Vietnamese film lab) to track your developing orders in real time
- **Google Drive backup** — Upload and restore roll data to Drive
- **Maps** — See where your frames were shot on an interactive map
- **Reminders** — Get notified when rolls need developing or gear sits idle
- **Localization** — English, Vietnamese, Chinese, Japanese, Korean, Hindi, Arabic, Russian, Spanish

## Tech Stack

- SwiftUI + SwiftData (iOS 17+)
- `@Query` / `@Model` for persistence
- Kingfisher for image caching
- URLSession-based networking (Google Drive, LLab API)
- UserNotifications for reminders & order alerts
- WidgetKit for Lock Screen + Dynamic Island live activities

## Architecture

```
follback/
├── Models/           # SwiftData models & API models
├── Services/         # Networking, auth, notifications, backup
├── Views/            # SwiftUI views
│   ├── Components/   # Reusable UI components
│   └── ARGallery/    # AR photo gallery
├── Assets.xcassets/  # Images, colors, icons
├── *.lproj/          # Localized strings (9 languages)
└── FilmVaultApp.swift
```

## Build

```bash
open follback.xcodeproj
# Select iOS 17+ simulator/device, then Build & Run
```

## License

© 2025 William Cachamwri. All rights reserved.
