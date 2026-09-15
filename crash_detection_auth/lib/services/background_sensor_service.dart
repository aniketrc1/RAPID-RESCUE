import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../core/constants/app_constants.dart';
import '../models/sensor_reading.dart';
import '../services/feature_extractor.dart';

// ── Background service entry point ────────────────────────────────────────────
// Runs in a separate Dart isolate on Android.
// Rules for this function:
//   • No WidgetsFlutterBinding — that is main-isolate only.
//   • No direct import of flutter_background_service_android.
//   • All exceptions must be caught — an uncaught exception kills the process.

@pragma('vm:entry-point')
void backgroundServiceEntryPoint(ServiceInstance service) async {
  double _prevSpeed = 0;
  double _rx = 0, _ry = 0, _rz = 0;
  double _lat = 0, _lng = 0, _speed = 0;

  final List<Map<String, dynamic>> _batch = [];
  const _batchSize = 30; // one batch every 3 s (30 × 100 ms)

  // ── Dio ───────────────────────────────────────────────────────────────────
  final dio = Dio(BaseOptions(
    baseUrl: AppConstants.backendBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  // ── GPS ───────────────────────────────────────────────────────────────────
  try {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    ).listen(
      (pos) {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _speed = pos.speed < 0 ? 0 : pos.speed;
      },
      onError: (_) {}, // permission denied or unavailable — keep running
    );
  } catch (_) {}

  // ── Gyroscope ─────────────────────────────────────────────────────────────
  try {
    gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen(
      (e) { _rx = e.x; _ry = e.y; _rz = e.z; },
      onError: (_) {},
    );
  } catch (_) {}

  // ── Accelerometer → feature extraction ────────────────────────────────────
  try {
    accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen(
      (e) {
        try {
          final raw = RawSensorData(
            ax: e.x, ay: e.y, az: e.z,
            rx: _rx, ry: _ry, rz: _rz,
            lat: _lat, lng: _lng, speed: _speed,
            timestamp: DateTime.now(),
          );

          final features = FeatureExtractor.extract(raw, _prevSpeed);
          _prevSpeed = _speed;

          service.invoke('sensor_update', features.toJson());

          _batch.add(features.toJson());
          if (_batch.length >= _batchSize) {
            final payload = List<Map<String, dynamic>>.from(_batch);
            _batch.clear();
            _sendBatch(dio, payload);
          }
        } catch (_) {}
      },
      onError: (_) {},
    );
  } catch (_) {}

  // ── Stop command ──────────────────────────────────────────────────────────
  service.on('stop').listen((_) => service.stopSelf());
}

// ── Batch sender ──────────────────────────────────────────────────────────────

Future<void> _sendBatch(
    Dio dio, List<Map<String, dynamic>> readings) async {
  try {
    await dio.post(
      AppConstants.sensorDataEndpoint,
      data: {'readings': readings},
    );
  } catch (_) {
    // Silently ignore — network may be unavailable in background
  }
}

// ── BackgroundSensorService — main-isolate API ────────────────────────────────

class BackgroundSensorService {
  BackgroundSensorService._();
  static final BackgroundSensorService instance = BackgroundSensorService._();

  final _service = FlutterBackgroundService();
  bool _configured = false;

  Future<void> configure() async {
    if (_configured) return;
    _configured = true;

    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: backgroundServiceEntryPoint,
        isForegroundMode: true,
        autoStart: false,
        notificationChannelId: 'crash_detection_sensor',
        initialNotificationTitle: 'Crash Detection',
        initialNotificationContent: 'Monitoring motion sensors…',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: backgroundServiceEntryPoint,
        onBackground: _onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> _onIosBackground(ServiceInstance service) async => true;

  Future<void> start(String jwtToken) async {
    await configure();
    await _service.startService();
  }

  Future<void> stop() async {
    _service.invoke('stop');
  }

  Future<bool> get isRunning async => _service.isRunning();

  Stream<Map<String, dynamic>?> get sensorUpdateStream =>
      _service.on('sensor_update');
}
