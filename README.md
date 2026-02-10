# Privacy VPN Controller 🛡️

**A privacy-first Android VPN/Proxy controller built with Flutter - Zero tracking, complete user control**

[![Flutter](https://img.shields.io/badge/Flutter-3.24.0+-02569B?logo=flutter)](https://flutter.dev)
[![Android](https://img.shields.io/badge/Android-5.1+-3DDC84?logo=android)](https://developer.android.com)
[![WireGuard](https://img.shields.io/badge/WireGuard-Enabled-88171A?logo=wireguard)](https://www.wireguard.com)
[![Privacy](https://img.shields.io/badge/Privacy-First-00C853)](https://github.com)

## 🎯 Core Concept

This is **NOT a VPN service provider** - it's a privacy-focused controller app that manages VPN connections using configurations **YOU provide**. Think of it as a secure, private alternative to commercial VPN apps, but you bring your own WireGuard servers.

### Key Differentiators:
- ✅ **Zero backend cost** - No owned servers or infrastructure
- ✅ **Complete privacy** - No analytics, tracking, or data collection
- ✅ **User-controlled** - You provide WireGuard configurations
- ✅ **Open source friendly** - Clean, auditable codebase
- ✅ **Android-only focus** - Optimized for phones and tablets

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    FLUTTER APP LAYER                   │
├─────────────┬─────────────┬─────────────┬─────────────┤
│ Presentation│ Business    │ Data        │ Platform    │
│ Layer       │ Logic       │ Layer       │ Channels    │
├─────────────┼─────────────┼─────────────┼─────────────┤
│ • Screens   │ • VPN Mgmt  │ • Secure    │ • Method    │
│ • Widgets   │ • Proxy     │   Storage   │   Channels  │
│ • Themes    │ • Rotation  │ • Config    │ • Native    │
│ • Providers │ • Security  │   Repos     │   Bridge    │
└─────────────┴─────────────┴─────────────┴─────────────┘
                              ↓
┌─────────────────────────────────────────────────────────┐
│                ANDROID NATIVE LAYER                    │
├─────────────┬─────────────┬─────────────┬─────────────┤
│ VpnService  │ WireGuard-Go│ Kill Switch │ Proxy       │
│ Manager     │ Integration │ Manager     │ Client      │
└─────────────┴─────────────┴─────────────┴─────────────┘
                              ↓
┌─────────────────────────────────────────────────────────┐
│  User Traffic → VpnService → WireGuard → Proxy → Web   │
└─────────────────────────────────────────────────────────┘
```

## 🚀 Features

### Core VPN Functionality
- **WireGuard Integration**: Modern, secure VPN protocol with perfect forward secrecy
- **Server Rotation**: Automatic rotation every 25-30 minutes for enhanced privacy
- **Multi-Configuration Support**: Manage multiple WireGuard server configurations
- **Kill Switch**: Automatic traffic blocking when VPN disconnects
- **DNS Leak Protection**: Force all DNS queries through VPN tunnel

### Proxy Support
- **SOCKS5 Proxy**: Standard SOCKS5 proxy integration
- **Shadowsocks**: Support for Shadowsocks obfuscation
- **Proxy Chains**: Route VPN traffic through additional proxy layers
- **Authentication**: Username/password and key-based authentication

### Privacy & Security
- **Zero Logging**: No connection logs, IP tracking, or metadata collection
- **Local Encryption**: AES-256 encryption for all stored configurations
- **IPv6 Blocking**: Prevent IPv6 leaks by default
- **No Analytics**: Zero telemetry, crash reporting, or user tracking
- **Offline Operation**: Full configuration management without internet

### Project Structure

```
lib/
├── core/                    # Core utilities and constants
│   ├── constants/          # App constants and configuration
│   ├── theme/             # Material 3 theming
│   └── utils/             # Utility functions
├── data/                    # Data layer
│   ├── models/            # Data models (VPN config, connection status)
│   ├── repositories/      # Data repositories
│   └── storage/          # Secure local storage
├── business_logic/          # Business logic layer
│   ├── managers/         # VPN and proxy managers
│   └── services/         # Background services
├── presentation/           # Presentation layer
│   ├── screens/          # App screens
│   ├── widgets/          # Reusable widgets
│   └── providers/        # Riverpod state providers
└── platform/              # Platform channels
    └── channels/          # Method channels for Android communication

android/app/src/main/kotlin/com/privacyvpn/privacy_vpn_controller/
├── MainActivity.kt          # Main Flutter activity with method channels
├── vpn/                    # VPN service implementation
│   ├── VpnControllerService.kt    # Core VPN service
│   ├── VpnConfiguration.kt        # Configuration data class
│   └── VpnState.kt               # VPN state management
├── channels/               # Method channel handlers
│   ├── VpnMethodChannelHandler.kt # VPN method channel
│   └── ProxyMethodChannelHandler.kt # Proxy method channel
├── proxy/                  # Proxy implementation
├── security/              # Security and kill switch
└── utils/                 # Utility classes
```

## 🛠️ Getting Started

### Prerequisites
- Flutter SDK 3.24.0 or higher
- Android SDK with API 22+ support
- Android NDK for native library compilation

### Installation
```bash
# Install Flutter dependencies
flutter pub get

# Run the app
flutter run

# Build for release
flutter build apk --release
```

## 📚 Documentation

- [**Architecture Guide**](ARCHITECTURE.md) - Detailed technical architecture and design decisions
- [**Security & Testing**](SECURITY_TESTING.md) - Comprehensive security documentation and testing strategies

## 🔒 Privacy Guarantees

- **No Data Collection**: Zero analytics, tracking, or user profiling
- **No Backend Servers**: All data stored locally on your device
- **No User Accounts**: No registration, login, or cloud synchronization
- **No Third-Party SDKs**: No Firebase, Crashlytics, or advertising frameworks
- **Open Source Friendly**: Clean, auditable codebase

## 🧪 Testing

```bash
# Run all tests
flutter test --coverage

# Security testing
flutter test test/security/

# Android integration tests
cd android && ./gradlew connectedAndroidTest
```

## 📄 License

This project is designed to be **open source friendly** with clean, auditable code and no vendor lock-in.

---

**Built with privacy in mind. No compromises. No tracking. Your VPN, your control.** 🛡️
