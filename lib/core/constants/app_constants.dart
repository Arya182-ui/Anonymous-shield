// Application Constants
class AppConstants {
  // App Information
  static const String appName = 'Privacy VPN Controller';
  static const String appVersion = '1.0.0';
  static const String packageName = 'com.privacyvpn.privacy_vpn_controller';
  
  // Debug configuration - CRITICAL: Set to false for production!
  static const bool debugMode = false; // ← PRODUCTION: Must be false
  static const bool enableDetailedLogging = false; // ← No sensitive logs in production
  static const bool skipVpnPermissionCheck = false; // ← Never skip in production
  static const String privacyPolicy = '''
This application is designed with privacy as the core principle:

• NO data collection or analytics
• NO user tracking or profiling  
• NO connection logs or metadata storage
• NO third-party integrations or ads
• NO backend servers or user accounts

All VPN configurations are stored locally and encrypted.
You maintain complete control over your privacy.
''';
  
  // VPN Configuration
  static const Duration rotationInterval = Duration(minutes: 25);
  static const Duration rotationIntervalMax = Duration(minutes: 30);
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration reconnectionDelay = Duration(seconds: 5);
  
  // Network Settings
  static const List<String> defaultDnsServers = ['1.1.1.1', '1.0.0.1'];
  static const List<String> fallbackDnsServers = ['8.8.8.8', '8.8.4.4'];
  static const int defaultMtu = 1420;
  static const int maxMtu = 1500;
  static const int minMtu = 1280;
  
  // Security Settings
  static const bool defaultKillSwitchEnabled = true;
  static const bool defaultDnsLeakProtection = true;
  static const bool defaultIpv6Blocking = true;
  static const Duration securityCheckInterval = Duration(seconds: 10);
  
  // Storage Keys (Encrypted)
  static const String vpnConfigsKey = 'encrypted_vpn_configs';
  static const String proxyConfigsKey = 'encrypted_proxy_configs';
  static const String userPreferencesKey = 'encrypted_user_preferences';
  static const String rotationSettingsKey = 'encrypted_rotation_settings';
  
  // Method Channel Names
  static const String vpnChannelName = 'com.privacyvpn.vpn_controller/vpn';
  static const String proxyChannelName = 'com.privacyvpn.vpn_controller/proxy';
  static const String systemChannelName = 'com.privacyvpn.vpn_controller/system';
  
  // VPN Service Methods
  static const String methodStartVpn = 'startVpn';
  static const String methodStopVpn = 'stopVpn';
  static const String methodGetVpnStatus = 'getVpnStatus';
  static const String methodEnableKillSwitch = 'enableKillSwitch';
  static const String methodDisableKillSwitch = 'disableKillSwitch';
  
  // Proxy Service Methods
  static const String methodStartProxy = 'startProxy';
  static const String methodStopProxy = 'stopProxy';
  static const String methodGetProxyStatus = 'getProxyStatus';
  
  // System Methods
  static const String methodRequestVpnPermission = 'requestVpnPermission';
  static const String methodCheckVpnPermission = 'checkVpnPermission';
  static const String methodGetDeviceInfo = 'getDeviceInfo';
  static const String methodGetNetworkInfo = 'getNetworkInfo';
  
  // Error Messages
  static const String errorNoConfigs = 'No VPN configurations found. Please add at least one.';
  static const String errorInvalidConfig = 'Invalid VPN configuration format.';
  static const String errorConnectionFailed = 'Failed to establish VPN connection.';
  static const String errorPermissionDenied = 'VPN permission is required for this app to function.';
  static const String errorNetworkUnavailable = 'Network connection is not available.';
  static const String errorKillSwitchActive = 'Kill switch is blocking traffic. Connect to VPN first.';
  
  // UI Constants
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration splashDuration = Duration(seconds: 3);
  static const double defaultPadding = 16.0;
  static const double defaultBorderRadius = 12.0;
  
  // Rotation Settings
  static const int minRotationIntervalMinutes = 15;
  static const int maxRotationIntervalMinutes = 60;
  static const int defaultRotationIntervalMinutes = 27;
  
  // File Extensions
  static const List<String> supportedConfigExtensions = ['conf', 'wg'];
  static const String wireGuardConfigExtension = 'conf';
  
  // Validation
  static const int maxConfigNameLength = 50;
  static const int maxServerCount = 20;
  static const String ipv4Regex = r'^([0-9]{1,3}\.){3}[0-9]{1,3}$';
  static const String ipv6Regex = r'^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$';
  
  // Notifications
  static const String vpnNotificationChannelId = 'vpn_status_channel';
  static const String vpnNotificationChannelName = 'VPN Status';
  static const String proxyNotificationChannelId = 'proxy_status_channel';
  static const String proxyNotificationChannelName = 'Proxy Status';
  
  // Testing & Debug (Production: false)
  static const bool enableAutoDemoConnections = false; // Disable auto demo connections
}