# Privacy VPN Controller - Architecture Documentation

## 1. Project Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         PRIVACY VPN CONTROLLER                  │
├─────────────────────────────────────────────────────────────────┤
│                          FLUTTER LAYER                         │
├─────────────┬─────────────┬─────────────┬─────────────────────┤
│    UI       │   Business  │   Data      │       Platform      │
│  Widgets    │   Logic     │   Layer     │      Channels       │
│             │             │             │                     │
│ ┌─────────┐ │ ┌─────────┐ │ ┌─────────┐ │ ┌─────────────────┐ │
│ │Intro    │ │ │VPN      │ │ │Config   │ │ │VPN Method       │ │
│ │Screen   │ │ │Manager  │ │ │Repository│ │ │Channel          │ │
│ │         │ │ │         │ │ │         │ │ │                 │ │
│ ├─────────┤ │ ├─────────┤ │ ├─────────┤ │ ├─────────────────┤ │
│ │Config   │ │ │Proxy    │ │ │Secure   │ │ │Proxy Method     │ │
│ │Screen   │ │ │Manager  │ │ │Storage  │ │ │Channel          │ │
│ │         │ │ │         │ │ │         │ │ │                 │ │
│ ├─────────┤ │ ├─────────┤ │ ├─────────┤ │ ├─────────────────┤ │
│ │Control  │ │ │Rotation │ │ │Network  │ │ │System Method    │ │
│ │Screen   │ │ │Service  │ │ │Monitor  │ │ │Channel          │ │
│ │         │ │ │         │ │ │         │ │ │                 │ │
│ ├─────────┤ │ ├─────────┤ │ └─────────┘ │ └─────────────────┘ │
│ │Status   │ │ │Security │ │             │                     │
│ │Screen   │ │ │Manager  │ │             │                     │
│ └─────────┘ │ └─────────┘ │             │                     │
└─────────────┴─────────────┴─────────────┴─────────────────────┤
├─────────────────────────────────────────────────────────────────┤
│                     ANDROID NATIVE LAYER                       │
├─────────────────────────────────────────────────────────────────┤
│ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ │
│ │             │ │             │ │             │ │             │ │
│ │ VPN Service │ │WireGuard-Go │ │Proxy Client │ │Kill Switch │ │
│ │   Manager   │ │ Integration │ │   Manager   │ │   Manager   │ │
│ │             │ │             │ │             │ │             │ │
│ ├─────────────┤ ├─────────────┤ ├─────────────┤ ├─────────────┤ │
│ │             │ │             │ │             │ │             │ │
│ │   Tunnel    │ │   Native    │ │   SOCKS5/   │ │   DNS       │ │
│ │ Controller  │ │  Bindings   │ │ Shadowsocks │ │ Protection  │ │
│ │             │ │             │ │             │ │             │ │
│ └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘ │
└─────────────────────────────────────────────────────────────────┘
├─────────────────────────────────────────────────────────────────┤
│                        NETWORK LAYER                           │
├─────────────────────────────────────────────────────────────────┤
│                           TRAFFIC FLOW                         │
│                                                                 │
│  App Traffic → Android VpnService → WireGuard → Proxy → Internet│
│               ↑                     ↑          ↑               │
│          Intercept All         Encrypt &    Optional           │
│          Device Traffic        Tunnel       SOCKS5/SS          │
└─────────────────────────────────────────────────────────────────┘
```

## 2. Clean Architecture Layers

### 2.1 Presentation Layer (UI)
- **Purpose**: Flutter widgets and screens
- **Responsibilities**: User interactions, UI state management
- **Components**:
  - Splash/Intro Screen
  - Configuration Screen
  - Main Control Screen  
  - Status/Monitoring Screen
  - Settings Screen

### 2.2 Business Logic Layer
- **Purpose**: Core application logic, state management
- **Responsibilities**: VPN management, server rotation, security policies
- **Components**:
  - VPN Manager (connection lifecycle)
  - Proxy Manager (SOCKS5/Shadowsocks handling)
  - Rotation Service (server switching)
  - Security Manager (kill-switch, leak protection)
  - Configuration Manager (user configs)

### 2.3 Data Layer
- **Purpose**: Data persistence and external communications
- **Responsibilities**: Config storage, network monitoring, platform channels
- **Components**:
  - Configuration Repository
  - Secure Storage (encrypted configs)
  - Network Monitor
  - Platform Channel Handlers

### 2.4 Platform Layer (Android Native)
- **Purpose**: OS-level VPN operations
- **Responsibilities**: VpnService management, WireGuard integration
- **Components**:
  - VPN Service Implementation
  - WireGuard Go Integration
  - Proxy Client (Netty/OkHttp)
  - Kill Switch Implementation

## 3. Security Architecture

### 3.1 Kill Switch Implementation
```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   VPN State     │────▶│  Kill Switch    │────▶│  Network Rules  │
│   Monitor       │     │   Controller    │     │   Enforcement   │
└─────────────────┘     └─────────────────┘     └─────────────────┘
         │                        │                        │
         ▼                        ▼                        ▼
  ┌─────────────┐        ┌─────────────┐        ┌─────────────┐
  │  Realtime   │        │  Block All  │        │  IPTables   │  
  │ Connection  │        │ Traffic on  │        │    Rules    │
  │ Monitoring  │        │   Failure   │        │ Management  │
  └─────────────┘        └─────────────┘        └─────────────┘
```

### 3.2 DNS Leak Protection
- Override system DNS with VPN DNS servers
- Block direct DNS queries to system resolvers
- Force all DNS through encrypted VPN tunnel
- Validate DNS responses for location consistency

### 3.3 IPv6 Handling
- Disable IPv6 by default to prevent leaks
- Block IPv6 traffic when VPN is active
- Option to enable IPv6 through VPN tunnel only

## 4. Server Rotation Strategy

### 4.1 Rotation Logic
```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│    Timer        │────▶│  Pre-rotation   │────▶│  Execute        │
│  (25-30 min)   │     │   Preparation   │     │  Rotation       │
└─────────────────┘     └─────────────────┘     └─────────────────┘
         │                        │                        │
         ▼                        ▼                        ▼
  ┌─────────────┐        ┌─────────────┐        ┌─────────────┐
  │ Randomized  │        │ Graceful    │        │ Select Next │
  │  Interval   │        │ Disconnect  │        │ Config &    │
  │             │        │             │        │ Reconnect   │
  └─────────────┘        └─────────────┘        └─────────────┘
```

### 4.2 Rotation Phases
1. **Pre-rotation Notification**: Warn user of upcoming rotation
2. **Graceful Disconnect**: Properly close current tunnel
3. **Config Selection**: Choose next server randomly
4. **Tunnel Recreation**: Establish new WireGuard tunnel
5. **Verification**: Confirm new connection is secure

## 5. Privacy & Security Guarantees

### 5.1 Zero Logging Policy
- No connection logs
- No traffic analysis
- No user behavior tracking
- No IP address logging
- No DNS query logging

### 5.2 Local Data Protection
- Encrypt all user configurations using Android Keystore
- Secure deletion of sensitive data
- Memory protection for keys
- No plaintext config storage

### 5.3 Network Security
- Perfect Forward Secrecy through WireGuard
- Certificate pinning for proxy connections
- Traffic obfuscation options
- Protection against traffic analysis

## 6. State Management Architecture (Riverpod)

### 6.1 Provider Hierarchy
```
Application Root
├── VPN State Provider
│   ├── Connection Status
│   ├── Current Server
│   └── Traffic Statistics
├── Configuration Provider  
│   ├── WireGuard Configs
│   ├── Proxy Settings
│   └── Server Rotation Rules
├── Security Provider
│   ├── Kill Switch Status
│   ├── DNS Leak Protection
│   └── IPv6 Blocking
└── UI State Provider
    ├── Screen Navigation
    ├── Theme Settings
    └── User Preferences
```

### 6.2 State Flow
1. **User Actions** → UI Widgets
2. **UI Events** → Business Logic Providers  
3. **Provider Updates** → Platform Channels
4. **Platform Response** → Provider State Updates
5. **State Changes** → UI Rebuilds

This architecture ensures complete separation of concerns, robust security, and maintainable code structure while delivering a privacy-first VPN controller experience.