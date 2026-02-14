import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/anonymous_chain.dart';
import '../../data/models/connection_status.dart';
import '../../business_logic/services/anonymous_chain_service.dart';
import '../managers/vpn_manager.dart';
import '../managers/proxy_manager.dart';

// Current active anonymous chain
final activeAnonymousChainProvider = StateNotifierProvider<ActiveAnonymousChainNotifier, AnonymousChain?>((ref) {
  return ActiveAnonymousChainNotifier();
});

// Available anonymous modes
final anonymousModesProvider = Provider<List<AnonymousMode>>((ref) {
  return AnonymousMode.values;
});

// Anonymous chain service
final anonymousChainServiceProvider = Provider<AnonymousChainService>((ref) {
  return AnonymousChainService();
});

// VPN Manager provider
final vpnManagerProvider = Provider<VpnManager>((ref) {
  return VpnManager();
});

// Proxy Manager provider
final proxyManagerProvider = Provider<ProxyManager>((ref) {
  return ProxyManager();
});

// VPN status stream provider - safely handles uninitialized VpnManager
final vpnStatusProvider = StreamProvider<ConnectionStatus>((ref) {
  final vpnManager = ref.watch(vpnManagerProvider);
  try {
    return vpnManager.statusStream;
  } catch (e) {
    // Return a single disconnected status if manager not initialized yet
    return Stream.value(ConnectionStatus.disconnected());
  }
});

// Proxy status stream provider - safely handles uninitialized ProxyManager
final proxyStatusProvider = StreamProvider<ProxyStatus>((ref) {
  final proxyManager = ref.watch(proxyManagerProvider);
  try {
    return proxyManager.statusStream;
  } catch (e) {
    return Stream.value(ProxyStatus.disabled);
  }
});

// Quick access to predefined chains
final predefinedChainsProvider = Provider<Map<AnonymousMode, AnonymousChain>>((ref) {
  return {
    AnonymousMode.ghost: AnonymousChain.ghostMode(),
    AnonymousMode.stealth: AnonymousChain.stealthMode(),
    AnonymousMode.turbo: AnonymousChain.turboMode(),
  };
});

// Anonymous features state
final anonymousFeaturesProvider = StateNotifierProvider<AnonymousFeaturesNotifier, AnonymousFeatures>((ref) {
  return AnonymousFeaturesNotifier();
});

class ActiveAnonymousChainNotifier extends StateNotifier<AnonymousChain?> {
  ActiveAnonymousChainNotifier() : super(null);

  void setChain(AnonymousChain chain) {
    state = chain;
  }

  void updateChainStatus(ChainStatus status) {
    if (state != null) {
      state = state!.copyWith(status: status);
    }
  }

  void clearChain() {
    state = null;
  }

  bool get isConnected => state?.status == ChainStatus.connected;
  bool get isConnecting => state?.status == ChainStatus.connecting;
  int get hopCount => state?.hopCount ?? 0;
  AnonymousMode? get currentMode => state?.mode;
}

class AnonymousFeatures {
  final bool autoIpRotation;
  final bool trafficObfuscation;
  final bool dpiBypass;
  final bool webrtcBlocking;
  final bool ipv6Blocking;
  final bool dnsLeakProtection;
  final bool fingerprintSpoofing;
  final bool timestampSpoofing;
  final Duration rotationInterval;

  const AnonymousFeatures({
    this.autoIpRotation = true,
    this.trafficObfuscation = true,
    this.dpiBypass = true,
    this.webrtcBlocking = true,
    this.ipv6Blocking = true,
    this.dnsLeakProtection = true,
    this.fingerprintSpoofing = false,
    this.timestampSpoofing = false,
    this.rotationInterval = const Duration(minutes: 10),
  });

  AnonymousFeatures copyWith({
    bool? autoIpRotation,
    bool? trafficObfuscation,
    bool? dpiBypass,
    bool? webrtcBlocking,
    bool? ipv6Blocking,
    bool? dnsLeakProtection,
    bool? fingerprintSpoofing,
    bool? timestampSpoofing,
    Duration? rotationInterval,
  }) {
    return AnonymousFeatures(
      autoIpRotation: autoIpRotation ?? this.autoIpRotation,
      trafficObfuscation: trafficObfuscation ?? this.trafficObfuscation,
      dpiBypass: dpiBypass ?? this.dpiBypass,
      webrtcBlocking: webrtcBlocking ?? this.webrtcBlocking,
      ipv6Blocking: ipv6Blocking ?? this.ipv6Blocking,
      dnsLeakProtection: dnsLeakProtection ?? this.dnsLeakProtection,
      fingerprintSpoofing: fingerprintSpoofing ?? this.fingerprintSpoofing,
      timestampSpoofing: timestampSpoofing ?? this.timestampSpoofing,
      rotationInterval: rotationInterval ?? this.rotationInterval,
    );
  }
}

class AnonymousFeaturesNotifier extends StateNotifier<AnonymousFeatures> {
  AnonymousFeaturesNotifier() : super(const AnonymousFeatures());

  void toggleAutoIpRotation() {
    state = state.copyWith(autoIpRotation: !state.autoIpRotation);
  }

  void toggleTrafficObfuscation() {
    state = state.copyWith(trafficObfuscation: !state.trafficObfuscation);
  }

  void toggleDpiBypass() {
    state = state.copyWith(dpiBypass: !state.dpiBypass);
  }

  void toggleWebrtcBlocking() {
    state = state.copyWith(webrtcBlocking: !state.webrtcBlocking);
  }

  void toggleIpv6Blocking() {
    state = state.copyWith(ipv6Blocking: !state.ipv6Blocking);
  }

  void toggleDnsLeakProtection() {
    state = state.copyWith(dnsLeakProtection: !state.dnsLeakProtection);
  }

  void toggleFingerprintSpoofing() {
    state = state.copyWith(fingerprintSpoofing: !state.fingerprintSpoofing);
  }

  void toggleTimestampSpoofing() {
    state = state.copyWith(timestampSpoofing: !state.timestampSpoofing);
  }

  void setRotationInterval(Duration interval) {
    state = state.copyWith(rotationInterval: interval);
  }

  void enableMaximumAnonymity() {
    state = const AnonymousFeatures(
      autoIpRotation: true,
      trafficObfuscation: true,
      dpiBypass: true,
      webrtcBlocking: true,
      ipv6Blocking: true,
      dnsLeakProtection: true,
      fingerprintSpoofing: true,
      timestampSpoofing: true,
      rotationInterval: Duration(minutes: 5),
    );
  }

  void enableFastMode() {
    state = const AnonymousFeatures(
      autoIpRotation: false,
      trafficObfuscation: false,
      dpiBypass: false,
      webrtcBlocking: true,
      ipv6Blocking: true,
      dnsLeakProtection: true,
      fingerprintSpoofing: false,
      timestampSpoofing: false,
      rotationInterval: Duration(minutes: 30),
    );
  }
}