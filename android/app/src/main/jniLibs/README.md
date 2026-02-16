# Native Libraries for Tor / tun2socks

Only `arm64-v8a` is needed — covers 99%+ of modern Android devices.
The app's `build.gradle.kts` has `abiFilters = ["arm64-v8a"]`.

## Required binaries (in `arm64-v8a/`)

| Binary | Purpose | Status |
|--------|---------|--------|
| `libtor.so` | Tor daemon | ✅ Present |
| `libtun2socks.so` | Routes TUN traffic → SOCKS5 | ✅ Present |

## Optional (for bridge/censorship bypass)

| Binary | Purpose | Source |
|--------|---------|--------|
| `libobfs4proxy.so` | obfs4 pluggable transport | [AnyTor](https://github.com/nickclaw/AnyTor) or [obfs4proxy repo](https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/obfs4) |
| `libsnowflake.so` | Snowflake pluggable transport | [AnyTor](https://github.com/nickclaw/AnyTor) or [snowflake repo](https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake) |

## Directory structure

```
jniLibs/
├── arm64-v8a/
│   ├── libtor.so          ✅
│   └── libtun2socks.so    ✅
└── README.md
```

Other arch folders (armeabi-v7a, x86_64) are not needed since
`abiFilters` is set to `arm64-v8a` only in build.gradle.kts.

## Building from source

### libtor.so (recommended: use pre-built)
```bash
# Option 1: AnyTor pre-built (easiest)
# Download from: https://github.com/nickclaw/AnyTor/releases
# Extract libtor.so for each architecture

# Option 2: Build from Tor source (advanced)
# Requires: Android NDK, autoconf, automake, libevent, openssl, zlib
```

### libtun2socks.so (requires Go + gomobile)
```bash
# Install Go and gomobile
go install golang.org/x/mobile/cmd/gomobile@latest
gomobile init

# Clone tun2socks
git clone https://github.com/xjasonlyu/tun2socks.git
cd tun2socks

# Build for Android with JNI exports
# Must export: nativeStartTun2Socks, nativeStopTun2Socks
gomobile bind -target=android -o tun2socks.aar .
# Extract .so files from the .aar
```

## Important notes

- Android only extracts files named `lib*.so` from jniLibs automatically
- The app's `build.gradle.kts` has `useLegacyPackaging = true` to extract .so to filesystem
- `TorEngine.kt` looks for `libtor.so` in `context.applicationInfo.nativeLibraryDir`
- `Tun2SocksEngine.kt` loads `libtun2socks.so` via `System.loadLibrary("tun2socks")`
