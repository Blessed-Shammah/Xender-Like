# 🗄️ FileVault

A cross-platform file sharing app with a **Node.js backend**, **Web App**, and **Flutter mobile app**.

## Project Structure

```
mine/
├── server/          # Node.js + Express backend API
├── webapp/          # Vite + Vanilla JS web app
├── mobile/          # Flutter mobile app
└── README.md
```

## Quick Start

### 1. Backend Server

```bash
cd server
npm install
node index.js
```

The server will start on `http://localhost:3000` and display your network IP for mobile access.

### 2. Web App

```bash
cd webapp
npm install
npm run dev
```

Open `http://localhost:5173` in your browser.

### 3. Flutter Mobile App

First, initialize the Flutter project scaffolding (one-time setup):

```bash
cd mobile
flutter create --project-name filevault --org com.filevault .
```

> **Important**: This copies the platform-specific files (Android/iOS). Your Dart source code in `lib/` is already written.

Then add internet permission for Android. Open `mobile/android/app/src/main/AndroidManifest.xml` and add this **above** the `<application>` tag:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

Then run:

```bash
cd mobile
flutter pub get
flutter run
```

### Connecting Mobile to Server

- **Android Emulator**: Server URL is `http://10.0.2.2:3000` (default)
- **Physical Device**: Use your computer's local IP (shown when server starts), e.g. `http://192.168.1.x:3000`
- Configure the server URL in the app's **Settings** screen

## Features

- 📤 Upload files (drag & drop on web, file picker on mobile)
- 📥 Download files
- 🔍 Search files by name
- 🏷️ Filter by category (images, videos, documents, etc.)
- 🗑️ Delete files with confirmation
- 📊 Storage stats
- 🌐 Works across devices on the same network
