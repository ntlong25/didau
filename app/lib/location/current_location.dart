import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Android's system provider also works on devices without Google Play location
/// services and accepts GPS fixes from the Android emulator.
Future<Position> currentLocation() => Geolocator.getCurrentPosition(
  locationSettings: !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? AndroidSettings(
          forceLocationManager: true,
          timeLimit: const Duration(seconds: 12),
        )
      : const LocationSettings(timeLimit: Duration(seconds: 12)),
);
