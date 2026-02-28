# 🛒 PasarPro — KitaHack 2026

> **"The One-Click Marketing Agency & OS for Every Hawker"**

PasarPro is an AI-powered mobile ecosystem that bridges the digital divide for Malaysia's hawker stall owners. Using Google's latest multimodal AI stack (Gemini, Nano Banana, Veo), it gives every uncle and auntie running a gerai the power of a full marketing agency, accountant, and business analyst — all from a cheap Android phone.

---

## 🎯 Problem Statement

Malaysia's hawker culture is legendary, but it faces a silent extinction:

| Problem | Impact |
|---|---|
| 🎯 **Visibility Trap** | 69% of Gen-Z discovers food via TikTok/Instagram. Hawkers with no digital presence are invisible. |
| 🎨 **Marketing Barrier** | Uncle Ah Meng cooks world-class Char Kway Teow but can't design a poster or edit a video. |
| 📋 **Financial Exclusion** | Cash-based hawkers have no paper trail → ineligible for micro-loans. |
| 🗑️ **Food Waste** | 23% of Malaysia's daily food waste comes from markets/eateries due to no demand prediction. |

**SDG Alignment:** SDG 8 (Decent Work), SDG 1 (No Poverty), SDG 12 (Responsible Consumption)

---

## ✅ Features Implemented

### Module A — Pasar-Growth (AI Marketing Agency)

| Feature | Description | Google Tech |
|---|---|---|
| 🖼️ **AI Food Stylist** | Transforms a messy stall photo into a professional, studio-quality image with aesthetic background | `gemini-2.5-flash-image` (Nano Banana) |
| 🎬 **Instant Viral Reels** | Converts the enhanced photo into a cinematic short video (steam rising, sauce glistening) with AI-generated narration | `veo-3.1-generate-preview` (Google AI Studio) |
| ✍️ **AI Caption Generator** | Writes localized, catchy social captions in Malay, English & Mandarin with trending hashtags | `gemini-2.5-flash` |
| 📲 **One-Click Instagram Post** | Posts the generated Reel directly to the hawker's Instagram with zero manual steps | Firebase Storage + n8n automation |

### Module B — Pasar-Ops (KiraKira Ledger)

| Feature | Description | Google Tech |
|---|---|---|
| 🎙️ **Voice Ledger** | Hawker speaks their daily summary (*"Beli ayam RM50, jual 30 mangkuk mee RM6 sorang"*) and it auto-updates the P&L chart | `gemini-2.5-flash` (audio multimodal) |
| 📸 **Snap-Ledger (Receipt OCR)** | Snap or upload a receipt (even messy handwritten ones) and Gemini Vision extracts all costs automatically | `gemini-2.5-flash` (vision multimodal) |
| 📊 **P&L Dashboard** | Daily bar chart of Revenue vs Expense with date picker filtering | Firebase Firestore |
| 🔍 **Itemized Breakdown** | Tap any record to see a color-coded table breaking down every individual item, quantity, unit price and net profit | `gemini-2.5-flash` (structured JSON output) |
| 🗑️ **Swipe-to-Delete** | Swipe left on any record to delete it with a confirmation dialog | Flutter UI |

---

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        FLUTTER APP (Android/iOS)                │
├──────────────────┬──────────────────┬───────────────────────────┤
│  Module A        │  Module B        │  Shared                   │
│  Pasar-Growth    │  Pasar-Ops       │  Infrastructure            │
│                  │  (KiraKira)      │                           │
│  ┌────────────┐  │  ┌────────────┐  │  ┌──────────────────────┐ │
│  │ Camera UI  │  │  │  Mic UI   │  │  │  Firebase Auth       │ │
│  │ Gallery UI │  │  │  P&L Chart│  │  │  Firestore DB        │ │
│  │ Reel View  │  │  │  Entry    │  │  │  Firebase Storage    │ │
│  └─────┬──────┘  │  │  List     │  │  └──────────┬───────────┘ │
│        │         │  └─────┬─────┘  │             │             │
└────────┼─────────┴────────┼────────┴─────────────┼─────────────┘
         │                  │                       │
         ▼                  ▼                       ▼
┌────────────────┐  ┌───────────────┐   ┌─────────────────────┐
│  AiService     │  │KiraKiraService│   │  InstagramService   │
│  (ai_service)  │  │(kira_kira_svc)│   │  (n8n webhook)      │
└───────┬────────┘  └───────┬───────┘   └──────────┬──────────┘
        │                   │                       │
        ▼                   ▼                       ▼
┌──────────────────────────────────────────────────────────────┐
│                  GOOGLE AI STUDIO REST API                    │
│          (generativelanguage.googleapis.com)                  │
├──────────────────┬──────────────────┬────────────────────────┤
│  gemini-2.5-     │  gemini-2.5-     │  veo-3.1-generate-     │
│  flash           │  flash-image     │  preview               │
│                  │  (Nano Banana)   │                        │
│  • Audio STT     │                  │  • predictLongRunning  │
│  • JSON parsing  │  • Image output  │  • Poll until done     │
│  • Receipt OCR   │  • 3 styled      │  • Download .mp4       │
│  • Captions      │    variations    │  • 9:16 portrait       │
│  • Breakdown     │                  │                        │
└──────────────────┴──────────────────┴────────────────────────┘
         │                  │                       │
         └──────────────────┴───────────────────────┘
                            │
                            ▼
              ┌─────────────────────────┐
              │  n8n + Instagram API    │
              │  • Facebook Graph API   │
              │  • Reel upload & post   │
              │  Firebase Storage       │
              │  (public CDN URL)       │
              └─────────────────────────┘
```

### Data Flow — Voice Ledger

```
User speaks → AudioRecorder (.m4a) → base64 encode
    → gemini-2.5-flash (transcribeAudio — audio multimodal)
        → Plain text transcript
            → gemini-2.5-flash (parseTranscript — structured JSON output)
                → { expense, revenue, profit }
                    → Firestore (kira_kira_ledgers)
                        → UI state update + P&L chart refresh
```

### Data Flow — Snap Receipt OCR

```
User snaps receipt → Image file → base64 encode
    → gemini-2.5-flash (parseReceiptImage — vision multimodal)
        → JSON: { expense, revenue, profit, transcript }
            → Firestore (kira_kira_ledgers) with 📸 prefix
                → UI state update
```

### Data Flow — AI Food Stylist + Reel

```
User picks food photo
    → gemini-2.5-flash (analyzeFood) → food name, cuisine, description
        → gemini-2.5-flash-image / Nano Banana (enhanceImage) → enhanced photo bytes
            → veo-3.1-generate-preview (generateReel via AI Studio) → video .mp4
                → Firebase Storage (upload) → public URL
                    → n8n webhook → Instagram Graph API → Posted! ✅

```

---

## 🤖 AI Integration Details

### 1. Gemini 2.5 Flash — Text & Multimodal Reasoning
**Endpoint:** `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent`

Used for:
- **Audio transcription** — Sends base64-encoded `.m4a` audio with a Malaysian hawker-tuned system prompt. Returns a plain text Malaysian English/Manglish transcript.
- **Financial parsing** — Strictly structured JSON output (`responseMimeType: "application/json"` + `responseSchema`) extracts `expense`, `revenue`, `profit` from free-form speech.
- **Itemized breakdown** — Re-parses raw transcripts into individual line items (item, qty, unitPrice, total, type) for the detail view.
- **Receipt OCR** — Sends base64-encoded receipt image and returns structured financial data.
- **Caption generation** — Generates localized social media captions in 3 languages.
- **Food analysis** — Identifies food type, suggests enhancement style and poster angle.

### 2. Gemini 2.5 Flash Image — "Nano Banana"
**Endpoint:** `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent`

Used for:
- **AI Food Stylist** — Takes the original food photo and a multi-style enhancement prompt, returns up to 3 professionally styled food images using `responseModalities: ["TEXT", "IMAGE"]`. Image bytes are base64-decoded from `inlineData` in the response. Called internally via `_callNanaBanana()`.

### 3. Veo 3.1 (Google AI Studio)
**Endpoint:** `https://generativelanguage.googleapis.com/v1beta/models/veo-3.1-generate-preview:predictLongRunning`

Used for:
- **Instant Viral Reels** — Sends a cinematic text prompt (with narrator dialogue cues) to generate a 9:16 portrait video. Uses a long-running operation polling pattern: POST to start → GET to poll `done == true` → download video bytes from the returned URI → save as `.mp4`.

### 4. Firebase Firestore
- **Collection:** `kira_kira_ledgers` — stores each voice/receipt entry with `expense`, `revenue`, `profit`, `rawTranscript`, and `timestamp`.
- Real-time filtered queries by date range for the date picker.

### 5. Firebase Storage + n8n + Instagram Graph API
- Enhanced images/reels are uploaded to Firebase Storage to get a public CDN URL.
- n8n webhook is triggered with the URL + AI-generated caption.
- n8n calls the Instagram Graph API (`/me/media`, `/me/media_publish`) to post directly.

---

## 🚀 Setup Instructions

### Prerequisites

| Tool | Version |
|---|---|
| Flutter | ≥ 3.22.0 |
| Dart | ≥ 3.4.0 |
| Android Studio / VS Code | Latest |
| Java (for Android builds) | 17+ |

### 1. Clone & Install

```bash
git clone https://github.com/your-repo/HappyFamily_PasarPro.git
cd HappyFamily_PasarPro/pasarpro
flutter pub get
```

### 2. Firebase Setup

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable **Firestore**, **Storage**, and **Authentication** (Google Sign-In)
3. Download `google-services.json` → place in `android/app/`
4. Download `GoogleService-Info.plist` → place in `ios/Runner/`

### 3. Environment Variables

Create a `.env` file in the `pasarpro/` root:

```env
# Google AI Studio API Key (for Gemini text, audio, vision, image gen)
GEMINI_API_KEY=AIza...

# n8n Instagram webhook
N8N_WEBHOOK_URL=https://your-n8n-instance.com/webhook/...
```

> **Get API Keys:**
> - Gemini key: [aistudio.google.com/app/apikey](https://aistudio.google.com/app/apikey)
> - Vertex AI: Enable the API in GCP Console, use Service Account or `gcloud auth application-default login`
> - n8n: Self-host or use [n8n.cloud](https://n8n.cloud)

### 4. Android Permissions

The following are already configured in `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.INTERNET" />
```

### 5. Run the App

```bash
# Debug mode on connected device/emulator
flutter run

# Release build
flutter build apk --release
```

---

## 📂 Project Structure

```
pasarpro/lib/
├── main.dart                         # App entry + Firebase init + dotenv
├── app.dart                          # Root MaterialApp with theme
├── firebase_options.dart             # Auto-generated Firebase config
├── core/
│   ├── constants/
│   │   └── app_colors.dart           # Brand color palette
│   └── theme/
│       └── app_theme.dart            # Material 3 theme config
├── models/                           # Shared data models
├── services/
│   ├── ai_service.dart               # Gemini (text, image, vision) + Veo 2
│   ├── kira_kira_service.dart        # KiraKira ledger: audio STT, parsing, Firestore
│   ├── instagram_service.dart        # n8n webhook → Instagram API
│   ├── background_reel_service.dart  # Veo polling / background job
│   ├── database_service.dart         # Firestore helpers
│   ├── image_service.dart            # Firebase Storage uploads
│   ├── poster_service.dart           # Poster/template generation
│   ├── notification_service.dart     # Local notifications
│   └── stt_service.dart              # Speech-to-text wrapper
└── features/
    ├── main_shell.dart               # Bottom nav scaffold
    ├── home/                         # Dashboard & morning briefing
    ├── camera/                       # Module A entry point
    ├── growth/                       # AI Food Stylist + Reel generation
    ├── gallery/                      # Marketing material storage
    ├── templates/                    # Pre-made poster templates
    ├── kira_kira/                    # Module B: Voice ledger + OCR
    ├── ops/                          # Module B supplementary screens
    ├── green/                        # Module C: Flash sale (planned)
    └── profile/                      # Business profile settings
```

---

## 🎨 Design System

| Token | Value | Usage |
|---|---|---|
| Primary | `#FF6B35` Warm Orange | CTAs, brand |
| Secondary | `#004E3E` Deep Green | Sustainability accent |
| Accent | `#FFB81C` Gold | Premium highlights |
| Success | `#22C55E` Green | Revenue, profit |
| Error | `#EF4444` Red | Expense, loss |
| Surface | `#F5F5F0` Warm off-white | Card backgrounds |

**Typography:** Poppins (headings) · Inter (body) — via Google Fonts

---

## 🏆 KitaHack 2026 Compliance

| Requirement | Status | Implementation |
|---|---|---|
| Google AI (Gemini) | ✅ | `gemini-2.5-flash` for STT, parsing, OCR, captions, breakdown |
| Google GenMedia (Image) | ✅ | `gemini-2.5-flash-image` (Nano Banana) for food photo enhancement |
| Google GenMedia (Video) | ✅ | `veo-3.1-generate-preview` for cinematic reel generation |
| Firebase | ✅ | Firestore, Storage, Analytics, Crashlytics |
| Flutter | ✅ | Single codebase, Android + iOS |

---

## 👥 Team — Happy Family

**KitaHack 2026** ·

---


