import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/anonymous_chain.dart';
import '../../../business_logic/services/anonymous_chain_service.dart';

// Anonymous chain service provider
final anonymousChainServiceProvider = Provider<AnonymousChainService>((ref) {
  return AnonymousChainService();
});

// Active anonymous chain provider
final activeChainProvider = StateProvider<AnonymousChain?>((ref) => null);

// Alternative name for compatibility
final activeAnonymousChainProvider = activeChainProvider;

// Connection state providers
final isConnectingProvider = StateProvider<bool>((ref) => false);

final connectionProgressProvider = StateProvider<double>((ref) => 0.0);

// Anonymous features provider
final anonymousFeatures = Provider<AnonymousFeatures>((ref) {
  return const AnonymousFeatures(
    trafficObfuscation: true,
    dpiBypass: true,
    killSwitch: true,
    dnsLeakProtection: true,
    autoRotation: true,
    fingerprintSpoofing: true,
  );
});

// Anonymous chain list provider
final anonymousChainsProvider = StateProvider<List<AnonymousChain>>((ref) {
  return [
    AnonymousChain.ghostMode(),
    AnonymousChain.stealthMode(),
    AnonymousChain.turboMode(),
  ];
});

// Selected anonymous mode provider
final selectedAnonymousModeProvider = StateProvider<AnonymousMode?>((ref) => null);

// Chain connection status provider
final chainConnectionStatusProvider = StateProvider<ChainStatus>((ref) => ChainStatus.inactive);

// Anonymous features model
class AnonymousFeatures {
  final bool trafficObfuscation;
  final bool dpiBypass;
  final bool killSwitch;
  final bool dnsLeakProtection;
  final bool autoRotation;
  final bool fingerprintSpoofing;

  const AnonymousFeatures({
    required this.trafficObfuscation,
    required this.dpiBypass,
    required this.killSwitch,
    required this.dnsLeakProtection,
    required this.autoRotation,
    required this.fingerprintSpoofing,
  });

  AnonymousFeatures copyWith({
    bool? trafficObfuscation,
    bool? dpiBypass,
    bool? killSwitch,
    bool? dnsLeakProtection,
    bool? autoRotation,
    bool? fingerprintSpoofing,
  }) {
    return AnonymousFeatures(
      trafficObfuscation: trafficObfuscation ?? this.trafficObfuscation,
      dpiBypass: dpiBypass ?? this.dpiBypass,
      killSwitch: killSwitch ?? this.killSwitch,
      dnsLeakProtection: dnsLeakProtection ?? this.dnsLeakProtection,
      autoRotation: autoRotation ?? this.autoRotation,
      fingerprintSpoofing: fingerprintSpoofing ?? this.fingerprintSpoofing,
    );
  }
}