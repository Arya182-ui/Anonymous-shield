/// Production Application Constants
/// Centralized configuration for build variants, security settings, and app behavior
class AppConstants {
  // ===== APPLICATION INFORMATION =====
  static const String appName = 'Privacy VPN Controller';
  static const String appVersion = '1.0.0';
  static const int appBuildNumber = 1;
  static const String packageName = 'com.privacyvpn.privacy_vpn_controller';
  
  // ===== BUILD CONFIGURATION =====
  // Production deployment: Ensure these are correctly set
  static const bool debugMode = bool.fromEnvironment('dart.vm.product') == false;
  static const bool profileMode = bool.fromEnvironment('dart.vm.profile');
  static const bool releaseMode = bool.fromEnvironment('dart.vm.product');
  
  // Build environment detection
  static const String buildEnvironment = String.fromEnvironment('BUILD_ENV', defaultValue: 'production');
  static const bool enableCrashReporting = bool.fromEnvironment('ENABLE_CRASH_REPORTING', defaultValue: !debugMode);
  static const bool enableAnalytics = false; // Privacy-first: Always disabled
  
  // ===== PRIVACY POLICY & PRINCIPLES =====
  static const String privacyPolicy = '''
PRIVACY-FIRST VPN CONTROLLER

Core Privacy Principles:
• NO data collection, logging, or analytics
• NO user tracking, profiling, or behavioral analysis
• NO connection logs, metadata, or usage statistics
• NO third-party integrations, ads, or trackers
• NO backend servers, user accounts, or cloud storage
• NO IP address logging or DNS query monitoring

Technical Privacy Protection:
• All configurations stored locally with AES-256 encryption
• Kill switch prevents traffic leaks during disconnections
• DNS leak protection with trusted resolvers only
• IPv6 leak protection and traffic blocking
• Traffic obfuscation for censorship resistance
• Automatic server rotation for enhanced anonymity

You maintain complete control over your digital privacy.
Your data never leaves your device.
''';

  // ===== SECURITY CONFIGURATION =====
  // Timing and timeout settings
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration vpnConnectionTimeout = Duration(seconds: 45);
  static const Duration killSwitchTimeout = Duration(seconds: 5);
  static const Duration dnsLeakTestTimeout = Duration(seconds: 10);
  
  // Retry logic
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  static const Duration backoffMultiplier = Duration(seconds: 1);
  
  // Security scanning
  static const Duration securityScanInterval = Duration(minutes: 5);
  static const Duration securityCheckInterval = Duration(minutes: 3);
  static const Duration connectionHealthCheckInterval = Duration(seconds: 10);
  static const Duration leakTestInterval = Duration(minutes: 2);
  
  // ===== ENCRYPTION & CRYPTOGRAPHY =====
  static const String defaultEncryption = 'AES-256-GCM';
  static const String backupEncryption = 'ChaCha20-Poly1305';
  static const int keySize = 256; // bits
  static const int saltSize = 32; // bytes
  static const int ivSize = 16; // bytes
  
  // ===== NETWORK CONFIGURATION =====
  // Primary DNS servers (privacy-focused)
  static const List<String> defaultDnsServers = [
    '1.1.1.1',        // Cloudflare (privacy)
    '1.0.0.1',        // Cloudflare (privacy)
    '9.9.9.9',        // Quad9 (security)
    '149.112.112.112', // Quad9 (security)
  ];
  
  // Emergency DNS (reliability fallback)
  static const List<String> emergencyDnsServers = [
    '8.8.8.8',        // Google DNS
    '8.8.4.4',        // Google DNS
    '208.67.222.222', // OpenDNS
    '208.67.220.220', // OpenDNS
  ];
  
  // Network parameters
  static const Duration networkTimeout = Duration(seconds: 15);
  static const Duration heartbeatInterval = Duration(seconds: 30);
  static const int maxConcurrentConnections = 5;
  
  // ===== VPN CONFIGURATION =====
  // WireGuard protocol settings
  static const int wireGuardPort = 51820;
  static const int wireGuardMtu = 1420;
  static const int wireGuardKeepalive = 25;
  static const int maxMtu = 1500;
  static const int minMtu = 1280;
  
  // Supported protocols (priority order)
  static const List<String> supportedProtocols = [
    'WireGuard',
    'OpenVPN',
    'IKEv2/IPSec',
  ];
  
  // Auto-reconnection settings
  static const bool defaultAutoReconnect = true;
  static const Duration autoReconnectDelay = Duration(seconds: 5);
  static const int maxAutoReconnectAttempts = 5;
  static const Duration reconnectionBackoff = Duration(seconds: 10);
  
  // Server rotation settings
  static const Duration rotationInterval = Duration(minutes: 25);
  static const Duration rotationIntervalMax = Duration(minutes: 35);
  static const bool defaultAutoRotation = true;
  
  // ===== SECURITY DEFAULTS =====
  static const bool defaultKillSwitchEnabled = true;
  static const bool defaultDnsLeakProtection = true;
  static const bool defaultIpv6Blocking = true;
  static const bool defaultWebRtcBlocking = true;
  static const bool defaultTrafficObfuscation = false;
  
  // ===== STORAGE CONFIGURATION =====
  static const String secureStoragePrefix = 'pvpc_';  // Privacy VPN Controller
  
  // Storage keys (all encrypted)
  static const String keyUserPreferences = '${secureStoragePrefix}user_prefs';
  static const String keyVpnConfigs = '${secureStoragePrefix}vpn_configs';
  static const String keyProxyConfigs = '${secureStoragePrefix}proxy_configs';
  static const String keyServerList = '${secureStoragePrefix}server_list';
  static const String keySecuritySettings = '${secureStoragePrefix}security';
  static const String keyRotationSettings = '${secureStoragePrefix}rotation';
  static const String keyConnectionHistory = '${secureStoragePrefix}conn_history';
  
  // Aliases for backwards compatibility
  static const String vpnConfigsKey = keyVpnConfigs;
  static const String proxyConfigsKey = keyProxyConfigs;
  
  // Cache settings
  static const Duration cacheExpiry = Duration(hours: 24);
  static const Duration configCacheExpiry = Duration(hours: 1);
  static const Duration serverListCacheExpiry = Duration(hours: 6);
  
  // ===== METHOD CHANNELS =====
  static const String vpnChannelName = 'privacy_vpn_controller/vpn';
  static const String proxyChannelName = 'privacy_vpn_controller/proxy';
  static const String securityChannelName = 'privacy_vpn_controller/security';
  static const String systemChannelName = 'privacy_vpn_controller/system';
  
  // VPN service methods
  static const String methodStartVpn = 'startVpn';
  static const String methodStopVpn = 'stopVpn';
  static const String methodGetVpnStatus = 'getVpnStatus';
  static const String methodStartWireGuardTunnel = 'startWireGuardTunnel';
  static const String methodStopWireGuardTunnel = 'stopWireGuardTunnel';
  static const String methodGenerateWireGuardKeys = 'generateWireGuardKeys';
  
  // Proxy service methods
  static const String methodStartProxy = 'startProxy';
  static const String methodStopProxy = 'stopProxy';
  static const String methodGetProxyStatus = 'getProxyStatus';
  
  // Security service methods
  static const String methodEnableKillSwitch = 'enableKillSwitch';
  static const String methodDisableKillSwitch = 'disableKillSwitch';
  static const String methodEnableDnsProtection = 'enableDnsProtection';
  static const String methodCheckDnsLeaks = 'checkDnsLeaks';
  static const String methodEnableTrafficObfuscation = 'enableTrafficObfuscation';
  
  // System methods
  static const String methodRequestVpnPermission = 'requestVpnPermission';
  static const String methodCheckVpnPermission = 'checkVpnPermission';
  static const String methodGetDeviceInfo = 'getDeviceInfo';
  static const String methodGetNetworkInfo = 'getNetworkInfo';
  
  // ===== ERROR MESSAGES =====
  static const String errorNoConfigs = 'No VPN configurations available. Please add or import configurations.';
  static const String errorInvalidConfig = 'Invalid or corrupted VPN configuration. Please check and try again.';
  static const String errorConnectionFailed = 'VPN connection failed. Check your configuration and network.';
  static const String errorPermissionDenied = 'VPN permission required. Please grant permission to continue.';
  static const String errorNetworkUnavailable = 'Network unavailable. Check your internet connection.';
  static const String errorKillSwitchActive = 'Kill switch is protecting your traffic. Connect to VPN to access internet.';
  static const String errorServerUnreachable = 'VPN server unreachable. Please try a different server.';
  static const String errorAuthenticationFailed = 'Authentication failed. Check your credentials.';
  static const String errorEncryptionFailed = 'Encryption setup failed. Please try again.';
  static const String errorDnsLeakDetected = 'DNS leak detected! Your real IP may be exposed.';
  
  // ===== UI/UX CONSTANTS =====
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration splashDuration = Duration(seconds: 3);
  static const Duration toastDuration = Duration(seconds: 4);
  static const Duration snackBarDuration = Duration(seconds: 6);
  
  // Layout constants
  static const double defaultPadding = 16.0;
  static const double largePadding = 24.0;
  static const double smallPadding = 8.0;
  static const double defaultBorderRadius = 12.0;
  static const double cardElevation = 4.0;
  
  // ===== VALIDATION CONSTANTS =====
  static const int maxConfigNameLength = 50;
  static const int maxServerCount = 50;
  static const int maxConfigFileSize = 10 * 1024; // 10 KB
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 128;
  
  // Regex patterns
  static const String ipv4Regex = r'^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$';
  static const String ipv6Regex = r'^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4})$';
  static const String domainRegex = r'^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9](?:\.[a-zA-Z]{2,})+$';
  static const String wireGuardKeyRegex = r'^[A-Za-z0-9+/]{43}=$';
  
  // File extensions
  static const List<String> supportedConfigExtensions = ['conf', 'wg', 'ovpn'];
  static const String wireGuardExtension = 'conf';
  static const String openVpnExtension = 'ovpn';
  
  // ===== NOTIFICATION CONFIGURATION =====
  static const String vpnNotificationChannelId = 'vpn_service';
  static const String vpnNotificationChannelName = 'VPN Service Status';
  static const String securityNotificationChannelId = 'security_alerts';
  static const String securityNotificationChannelName = 'Security Alerts';
  
  // ===== LOGGING CONFIGURATION =====
  static const bool enableFileLogging = !releaseMode;
  static const bool enablePerformanceLogging = debugMode;
  static const bool enableSecurityLogging = true;
  static const bool enableDetailedLogging = debugMode;
  
  // Log settings
  static const int maxLogFileSize = 10 * 1024 * 1024; // 10 MB
  static const int maxLogFiles = 5;
  static const Duration logRetentionPeriod = Duration(days: 7);
  
  // ===== FEATURE FLAGS =====
  static const bool enableAdvancedMode = true;
  static const bool enableProxyChaining = true;
  static const bool enableMultiHop = false; // Experimental
  static const bool enableBetaFeatures = debugMode;
  
  // Testing flags (disabled in production)
  static const bool enableAutoDemoConnections = false;
  static const bool skipVpnPermissionCheck = false;
  static const bool enableTestMode = debugMode;
  
  // ===== PERFORMANCE CONFIGURATION =====
  static const int connectionPoolSize = 5;
  static const Duration backgroundTaskTimeout = Duration(minutes: 2);
  static const int maxCacheSize = 50 * 1024 * 1024; // 50 MB
  
  // ===== HELPER METHODS =====
  /// Get current build configuration as string
  static String get buildConfig {
    if (debugMode) return 'Debug';
    if (profileMode) return 'Profile';
    return 'Release';
  }
  
  /// Check if running in production environment
  static bool get isProduction => releaseMode && buildEnvironment == 'production';
  
  /// Get appropriate timeout for operation type
  static Duration getTimeoutFor(String operation) {
    switch (operation) {
      case 'vpn_connection':
        return vpnConnectionTimeout;
      case 'kill_switch':
        return killSwitchTimeout;
      case 'dns_leak_test':
        return dnsLeakTestTimeout;
      case 'network':
        return networkTimeout;
      default:
        return connectionTimeout;
    }
  }
  
  /// Check if feature is enabled
  static bool isFeatureEnabled(String feature) {
    switch (feature) {
      case 'advanced_mode':
        return enableAdvancedMode;
      case 'proxy_chaining':
        return enableProxyChaining;
      case 'multi_hop':
        return enableMultiHop;
      case 'beta_features':
        return enableBetaFeatures;
      case 'test_mode':
        return enableTestMode;
      default:
        return false;
    }
  }
}