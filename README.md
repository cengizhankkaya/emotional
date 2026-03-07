<div align="center">
  <img src="assets/logo/logo.png" alt="Emotional Logo" width="150"/>
  <h1>Emotional</h1>
  <p>A modern, highly scalable Flutter application featuring real-time WebRTC communication, advanced media playback, and a secure Firebase-powered backend.</p>

  <p>
    <a href="https://flutter.dev/"><img src="https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white" alt="Flutter"></a>
    <a href="https://dart.dev/"><img src="https://img.shields.io/badge/Dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white" alt="Dart"></a>
    <a href="https://firebase.google.com/"><img src="https://img.shields.io/badge/Firebase-%23FFCA28.svg?style=for-the-badge&logo=firebase&logoColor=black" alt="Firebase"></a>
    <a href="https://webrtc.org/"><img src="https://img.shields.io/badge/WebRTC-%23333333.svg?style=for-the-badge&logo=webrtc&logoColor=white" alt="WebRTC"></a>
    <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge" alt="License"></a>
  </p>
</div>

---

## 🌟 Key Features

*   **Real-Time Audio & Video Calls**: Built with `flutter_webrtc` for seamless peer-to-peer (P2P) communication and room management.
*   **Secure Environment Management**: Uncompromised security utilizing the `envied` package to encrypt and obfuscate sensitive API keys (`.env` files are never exposed in compiled code).
*   **Robust Backend integration**: Powered by Firebase (Authentication, Realtime Database, Firestore, Remote Config, Analytics).
*   **Media & Video Playback**: High-performance video and media handling using `media_kit`.
*   **Clean Architecture**: Designed with scalability in mind, separating presentation, business logic (BLoC), and data layers.
*   **Localization Support**: Fully localized with `easy_localization` to support multiple languages effortlessly.

---

## 🛠 Tech Stack & Dependencies

*   **Framework**: [Flutter](https://flutter.dev/) (SDK ^3.10.4)
*   **State Management**: `flutter_bloc`, `equatable`
*   **Backend & Cloud**: `firebase_core`, `firebase_auth`, `firebase_database`, `firebase_remote_config`
*   **Security & Config**: `envied` (Environment obfuscation)
*   **Media & Real-time**: `flutter_webrtc`, `media_kit`, `camera`
*   **UI/UX**: `google_fonts`, `font_awesome_flutter`, `lottie`, `flutter_svg`
*   **Local Storage**: `shared_preferences`
*   **Background Services**: `background_downloader`, `wakelock_plus`

---

## 🚀 Getting Started

Follow these detailed instructions to get your local development environment up and running.

### 📋 Prerequisites

Before you begin, ensure you have met the following requirements:
*   [Flutter SDK](https://docs.flutter.dev/get-started/install) installed on your machine.
*   An IDE such as [VS Code](https://code.visualstudio.com/) or [Android Studio](https://developer.android.com/studio).
*   A [Firebase](https://console.firebase.google.com/) account.
*   Git for version control.

### 1️⃣ Clone the Repository

```bash
git clone https://github.com/cengizhankkaya/emotional.git
cd emotional
```

### 2️⃣ Install Dependencies

Fetch all the required Dart and Flutter packages:
```bash
flutter pub get
```

### 3️⃣ Setup Environment Variables (Critical for Security)

This project strictly follows security best practices and does **not** commit API keys to version control. We use the `envied` package to safely obfuscate keys.

1.  Navigate to your `assets/` folder and create an `env` directory:
    ```bash
    mkdir -p assets/env
    ```
2.  Create two files inside `assets/env/`: `.env` (for dev) and `.prod.env` (for production).
3.  Add your API variables to both files. For example:
    ```env
    BASE_URL=https://api.yourdomain.com
    API_KEY=YOUR_SECRET_API_KEY
    ```
4.  Run the build runner to generate the obfuscated Dart configuration files:
    ```bash
    dart run build_runner build --delete-conflicting-outputs
    ```
    *If this is successful, you will notice dynamically generated files (e.g., `dev_env.g.dart`) in `lib/product/init/config/` which encrypts your values.*

### 4️⃣ Setup Firebase

Because this is a Firebase-powered application, you need to connect it to your own Firebase project.

1.  Create a project on the [Firebase Console](https://console.firebase.google.com/).
2.  Register your Android (`build.gradle` application ID) and iOS (`Runner.xcodeproj` bundle ID) applications.
3.  Download and place the required configuration files:
    *   **Android:** Place `google-services.json` inside `android/app/`.
    *   **iOS:** Place `GoogleService-Info.plist` inside `ios/Runner/`.
4.  *(Alternative)* Use the [FlutterFire CLI](https://firebase.google.com/docs/flutter/setup) to automatically configure:
    ```bash
    dart pub global activate flutterfire_cli
    flutterfire configure
    ```

### 5️⃣ Run the Application

Now you are ready to launch the app:

```bash
# Run on an attached device or emulator
flutter run
```

---

## 🏗 Architecture & Folder Structure

This project adopts a **Clean Architecture** combined with a **Feature-First** (Feature-driven) approach. This structure ensures that the codebase remains highly modular, easily testable, and scalable as new features are added.

The source code inside the `lib/` directory is organized as follows:

```text
lib/
├── core/
│   ├── base/           # Base classes (BaseView, BaseViewModel, BaseState)
│   ├── constants/      # App-wide constants (enums, styling assets, API endpoints)
│   ├── init/           # Core initializers (Localization setup, Network setup)
│   └── services/       # Global services (DownloadService, StorageServices)
│
├── features/           # Each feature contains its own presentation and logic layers
│   ├── app.dart        # Main app entry structure
│   ├── auth/           # Authentication feature (Login, Register flows)
│   ├── call/           # Call management (Signaling, WebRTC connection states)
│   ├── room/           # Room feature (UI, Camera/Mic controls, Messaging)
│   └── video_player/   # Video playback feature (MediaKit integration)
│
├── product/            # Application & Product level setup
│   ├── init/           
│   │   ├── config/             # Environment configs (envied implementation)
│   │   ├── application_init.dart # Async boot tasks (Firebase, Localization, Orientations)
│   │   └── product_scope.dart  # MultiBlocProvider and MultiRepositoryProvider wraps
│   ├── widget/         # Shared, product-specific UI widgets (Dialogs, Buttons)
│   └── util/           # Utility/Helper functions (Date formatters, Validators)
│
└── main.dart           # Clean entry point. Only calls ApplicationInit and ProductScope
```

### Layer Responsibilities:
1.  **Core Layer (`core/`)**: Completely independent of specific business logic. Contains generalized solutions, base widgets, and external service wrappers (e.g., Network Managers) that can be copied to any other Flutter project.
2.  **Product Layer (`product/`)**: Contains logic and widgets that are specific to *this* product but used globally across multiple features (e.g., App theme, Product-specific buttons). We avoid polluting `main.dart` by keeping all initialization logic inside `product/init/`.
3.  **Feature Layer (`features/`)**: Driven by business logic. Every major functionality (Auth, Room, Call) is isolated here. Inside a feature, we typically separate the UI (`presentation/`) from the State Management (`bloc/` or `manager/`).

---

## 🤝 Contributing

Contributions are what make the open-source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📜 License

Distributed under the MIT License. See the [LICENSE](LICENSE) file for more information.

---
<div align="center">
  <b>Built with ❤️ by Cengizhan KAYA</b>
</div>
