# PasarPro - KitaHack 2026

**The "One-Click" Marketing Agency & OS for Every Hawker**

## 🎯 Project Overview

PasarPro is an AI-powered ecosystem designed to bridge the digital divide for Malaysia's underserved micro-SMEs (hawkers and roadside stall owners). By leveraging Google's latest multimodal AI, we transform humble hawker stalls into data-driven businesses.

### SDG Alignment
- **Primary:** SDG 8 (Decent Work & Economic Growth)
- **Secondary:** SDG 1 (No Poverty), SDG 12 (Responsible Consumption)

## 🛠️ Tech Stack

- **Frontend:** Flutter 3.38.8
- **AI:** Google Gemini 3 Pro, Nano Banana Pro, Veo
- **Backend:** Firebase (Auth, Firestore, Storage, Cloud Functions)
- **Maps:** Google Maps Platform
- **Design:** Material Design 3, Google Fonts (Poppins, Inter)

## 📱 Current Implementation Status

### ✅ Completed (Basic UI)

**Design System**
- Custom color scheme (Malaysian street food theme)
- Typography with Poppins (headings) and Inter (body)
- Reusable theme configuration

**Bottom Navigation (5 tabs)**
1. 🏠 **Home** - Morning briefing with smart suggestions, stats, and viral forecasts
2. 🔥 **Templates** - Pre-made video styles (Flash Sale, Sold Out, Rainy Day, etc.)
3. 📸 **Camera** - Primary creation tool (center button) for Module A features
4. 🎬 **Gallery** - Digital storage for marketing materials
5. 👤 **Profile** - Business details and settings

**Module A: Pasar-Growth (AI Marketing Agency)**
- Camera screen UI with feature descriptions:
  - **AI Food Stylist** (Nano Banana Pro) - Photo enhancement placeholder
  - **Instant Viral Reels** (Veo) - Video generation placeholder
  - **The Hype Man** (Gemini 3 Pro) - Caption generation placeholder

### 🚧 Next Steps (Implementation Phase)

1. **Firebase Setup**
   - Create Firebase project
   - Add google-services.json
   - Configure Authentication and Firestore

2. **Camera Integration**
   - Add `camera` and `image_picker` packages
   - Implement photo capture and gallery picker
   - Image upload to Firebase Storage

3. **AI Integration (Module A)**
   - Gemini API for caption generation (3 languages)
   - Image enhancement with Vertex AI (Nano Banana Pro)
   - Video generation with Veo

4. **Additional Modules**
   - Module B: Pasar-Ops (Receipt OCR, P&L dashboard)
   - Module C: Pasar-Green (Flash sales, geofencing with Google Maps)

## 🚀 Getting Started

### Prerequisites
- Flutter 3.38.8 or higher
- Dart 3.10.7 or higher
- Android Studio / VS Code

### Installation

```bash
# Navigate to project directory
cd pasarpro

# Install dependencies
flutter pub get

# Run the app
flutter run
```

## 📂 Project Structure

```
lib/
├── main.dart                 # App entry point
├── app.dart                  # Root app widget with theme
├── core/
│   ├── constants/
│   │   └── app_colors.dart   # Color palette
│   └── theme/
│       └── app_theme.dart    # Theme configuration
└── features/
    ├── main_shell.dart       # Bottom nav shell
    ├── home/
    │   └── home_screen.dart  # Dashboard
    ├── templates/
    │   └── templates_screen.dart
    ├── camera/
    │   └── camera_screen.dart    # Module A primary screen
    ├── gallery/
    │   └── gallery_screen.dart
    └── profile/
        └── profile_screen.dart
```

## 🎨 Design System

### Colors
- **Primary:** `#FF6B35` (Warm Orange) - Energy, food
- **Secondary:** `#004E3E` (Deep Green) - Sustainability
- **Accent:** `#FFB81C` (Gold) - Premium feel
- **Surface:** `#F5F5F0` (Warm off-white)

### Typography
- **Headings:** Poppins Bold
- **Body:** Inter Regular
- **Support:** Malay, English, Mandarin

## 🏆 KitaHack 2026 Compliance

### Required Technologies
- ✅ Google AI (Gemini 3 Pro - planned)
- ✅ Google Technology (Firebase, Google Maps - planned)
- ✅ Flutter (current implementation)
- ✅ AI Integration (Module A design ready)

### Submission Deadline
**Preliminary Round:** February 28, 2026

## 👥 Team

- **Member 1:** Frontend Lead (UI/UX)
- **Member 2:** Backend/AI Lead
- **Member 3:** Features Lead (Full-stack)

## 📄 License

See [LICENSE](../LICENSE) file for details.

---

**Built with ❤️ for Malaysian Hawkers**

*Powered by Google Gemini, Vertex AI, Firebase & Flutter*
