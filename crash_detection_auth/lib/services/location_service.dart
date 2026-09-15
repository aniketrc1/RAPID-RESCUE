import 'dart:async';
import 'package:geolocator/geolocator.dart';

/// Streams high-frequency GPS position updates using [geolocator].
/// Handles permission requests and provides current speed in m/s.
class LocationService {
  LocationService();

  StreamSubscription<Position>? _positionSub;
  Position? _lastPosition;
  final _controller = StreamController<Position>.broadcast();

  Stream<Position> get stream => _controller.stream;
  Position? get lastPosition => _lastPosition;
  /// Current speed in m/s clamped to >= 0.
  /// GPS returns -1.0 on Android when speed is unavailable.
  double get currentSpeed => (_lastPosition?.speed ?? 0.0).clamp(0.0, double.infinity);
  bool get isRunning => _positionSub != null;

  /// Requests location permission and starts the GPS stream.
  /// Returns false if permissions are denied.
  Future<bool> start() async {
    final permission = await _checkPermission();
    if (!permission) return false;

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,           // fire on every update
      timeLimit: null,
    );

    _positionSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen((pos) {
      _lastPosition = pos;
      _controller.add(pos);
    }, onError: (_) {});
    // Note: speed from GPS is only accurate outdoors while moving.
    // Indoors or when stationary it may read 0 or -1 (clamped to 0).

    return true;
  }

  void stop() {
    _positionSub?.cancel();
    _positionSub = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }

  // ── Permission helpers ─────────────────────────────────────────────────────

  Future<bool> _checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }

  /// Opens the device location settings so the user can enable GPS.
  static Future<void> openSettings() => Geolocator.openLocationSettings();
}
