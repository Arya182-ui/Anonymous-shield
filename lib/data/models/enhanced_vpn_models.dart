/// Enhanced VPN Data Models
/// Real connection status and info classes for native VPN integration

enum VpnConnectionState {
  disconnected,
  connecting, 
  connected,
  disconnecting,
  error,
}

class VpnConnectionStatus {
  final VpnConnectionState vpnStatus;
  final String? error;
  final DateTime timestamp;
  final String? details;

  VpnConnectionStatus({
    required this.vpnStatus,
    this.error,
    DateTime? timestamp,
    this.details,
  }) : timestamp = timestamp ?? DateTime.now();

  VpnConnectionStatus copyWith({
    VpnConnectionState? vpnStatus,
    String? error,
    DateTime? timestamp,
    String? details,
  }) {
    return VpnConnectionStatus(
      vpnStatus: vpnStatus ?? this.vpnStatus,
      error: error ?? this.error,
      timestamp: timestamp ?? this.timestamp,
      details: details ?? this.details,
    );
  }

  bool get isConnected => vpnStatus == VpnConnectionState.connected;
  bool get isConnecting => vpnStatus == VpnConnectionState.connecting;
  bool get isDisconnected => vpnStatus == VpnConnectionState.disconnected;
  bool get hasError => vpnStatus == VpnConnectionState.error;

  Map<String, dynamic> toMap() {
    return {
      'vpnStatus': vpnStatus.toString(),
      'error': error,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'details': details,
    };
  }

  factory VpnConnectionStatus.fromMap(Map<String, dynamic> map) {
    return VpnConnectionStatus(
      vpnStatus: VpnConnectionState.values.firstWhere(
        (e) => e.toString() == map['vpnStatus'],
        orElse: () => VpnConnectionState.disconnected,
      ),
      error: map['error'],
      timestamp: map['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'])
          : DateTime.now(),
      details: map['details'],
    );
  }
}

class VpnConnectionInfo {
  final String publicIp;
  final String country;
  final String city; 
  final String isp;
  final String? region;
  final String? countryCode;
  final double? latitude;
  final double? longitude;
  final String? timezone;
  final String? latency;
  final String? dataUsage;
  final DateTime? connectionStartTime;
  final DateTime? lastDataTransfer;
  final String? serverLocation;
  final String? protocol;
  final String? encryption;
  final int? port;
  // Additional constructor parameters for enhanced manager compatibility
  final Duration? connectionTime;
  final int bytesIn;
  final int bytesOut;
  final int? ping;

  VpnConnectionInfo({
    required this.publicIp,
    required this.country,
    required this.city,
    required this.isp,
    this.region,
    this.countryCode,
    this.latitude,
    this.longitude,
    this.timezone,
    this.latency,
    this.dataUsage,
    this.connectionStartTime,
    this.lastDataTransfer,
    this.serverLocation,
    this.protocol,
    this.encryption,
    this.port,
    // Enhanced manager compatibility
    this.connectionTime,
    this.bytesIn = 0,
    this.bytesOut = 0,
    this.ping,
  });

  factory VpnConnectionInfo.fromMap(Map<String, dynamic> map) {
    return VpnConnectionInfo(
      publicIp: map['publicIp'] ?? 'Unknown',
      country: map['country'] ?? 'Unknown',
      city: map['city'] ?? 'Unknown',
      isp: map['isp'] ?? 'Unknown',
      region: map['region'],
      countryCode: map['countryCode'],
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      timezone: map['timezone'],
      latency: map['latency'],
      dataUsage: map['dataUsage'],
      connectionStartTime: map['connectionStartTime'] != null 
        ? DateTime.fromMillisecondsSinceEpoch(map['connectionStartTime'])
        : null,
      lastDataTransfer: map['lastDataTransfer'] != null 
        ? DateTime.fromMillisecondsSinceEpoch(map['lastDataTransfer'])
        : null,
      serverLocation: map['serverLocation'],
      protocol: map['protocol'],
      encryption: map['encryption'],
      port: map['port'],
      // Enhanced manager compatibility
      connectionTime: map['connectionTime'] != null 
        ? Duration(milliseconds: map['connectionTime'])
        : null,
      bytesIn: map['bytesIn'] ?? 0,
      bytesOut: map['bytesOut'] ?? 0,
      ping: map['ping'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'publicIp': publicIp,
      'country': country,
      'city': city,
      'isp': isp,
      'region': region,
      'countryCode': countryCode,
      'latitude': latitude,
      'longitude': longitude,
      'timezone': timezone,
      'latency': latency,
      'dataUsage': dataUsage,
      'connectionStartTime': connectionStartTime?.millisecondsSinceEpoch,
      'lastDataTransfer': lastDataTransfer?.millisecondsSinceEpoch,
      'serverLocation': serverLocation,
      'protocol': protocol,
      'encryption': encryption,
      'port': port,
      // Enhanced manager compatibility
      'connectionTime': connectionTime?.inMilliseconds,
      'bytesIn': bytesIn,
      'bytesOut': bytesOut,
      'ping': ping,
    };
  }

  Duration? get connectionDuration {
    if (connectionStartTime == null) return null;
    return DateTime.now().difference(connectionStartTime!);
  }

  String get formattedLocation => '$city, $country';
  
  String get formattedConnectionTime {
    final duration = connectionDuration;
    if (duration == null) return '00:00';
    
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
    }
  }
}

/// Anonymous chain connection status
class AnonymousChainStatus {
  final int chainId;
  final String mode;
  final int hopCount;
  final List<String> activeProxies;
  final DateTime createdAt;
  final Duration? rotationInterval;
  final DateTime? lastRotation;
  final bool isRotationEnabled;

  AnonymousChainStatus({
    required this.chainId,
    required this.mode,
    required this.hopCount,
    required this.activeProxies,
    required this.createdAt,
    this.rotationInterval,
    this.lastRotation,
    this.isRotationEnabled = false,
  });

  factory AnonymousChainStatus.fromMap(Map<String, dynamic> map) {
    return AnonymousChainStatus(
      chainId: map['chainId'] ?? 0,
      mode: map['mode'] ?? 'unknown',
      hopCount: map['hopCount'] ?? 0,
      activeProxies: List<String>.from(map['activeProxies'] ?? []),
      createdAt: map['createdAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
      rotationInterval: map['rotationInterval'] != null 
          ? Duration(seconds: map['rotationInterval'])
          : null,
      lastRotation: map['lastRotation'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['lastRotation'])
          : null,
      isRotationEnabled: map['isRotationEnabled'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chainId': chainId,
      'mode': mode,
      'hopCount': hopCount,
      'activeProxies': activeProxies,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'rotationInterval': rotationInterval?.inSeconds,
      'lastRotation': lastRotation?.millisecondsSinceEpoch,
      'isRotationEnabled': isRotationEnabled,
    };
  }

  Duration? get timeSinceLastRotation {
    if (lastRotation == null) return null;
    return DateTime.now().difference(lastRotation!);
  }

  bool get needsRotation {
    if (!isRotationEnabled || rotationInterval == null || lastRotation == null) {
      return false;
    }
    return timeSinceLastRotation! >= rotationInterval!;
  }
}

/// Traffic monitoring statistics
class TrafficStats {
  final int bytesUploaded;
  final int bytesDownloaded;
  final int packetsUploaded;
  final int packetsDownloaded;
  final DateTime startTime;
  final DateTime lastActivity;

  TrafficStats({
    required this.bytesUploaded,
    required this.bytesDownloaded,
    required this.packetsUploaded,
    required this.packetsDownloaded,
    required this.startTime,
    required this.lastActivity,
  });

  factory TrafficStats.fromMap(Map<String, dynamic> map) {
    return TrafficStats(
      bytesUploaded: map['bytesUploaded'] ?? 0,
      bytesDownloaded: map['bytesDownloaded'] ?? 0,
      packetsUploaded: map['packetsUploaded'] ?? 0,
      packetsDownloaded: map['packetsDownloaded'] ?? 0,
      startTime: map['startTime'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['startTime'])
          : DateTime.now(),
      lastActivity: map['lastActivity'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['lastActivity'])
          : DateTime.now(),
    );
  }

  int get totalBytes => bytesUploaded + bytesDownloaded;
  int get totalPackets => packetsUploaded + packetsDownloaded;
  
  String get formattedTotalData {
    final total = totalBytes;
    if (total < 1024) return '${total}B';
    if (total < 1024 * 1024) return '${(total / 1024).toStringAsFixed(1)}KB';
    if (total < 1024 * 1024 * 1024) return '${(total / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(total / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB';
  }

  double get uploadRatio {
    if (totalBytes == 0) return 0.0;
    return bytesUploaded / totalBytes;
  }
}