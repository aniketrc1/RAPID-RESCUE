import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:dio/dio.dart';
import '../core/constants/app_constants.dart';
import '../models/sensor_reading.dart';
import '../services/feature_extractor.dart';
import '../services/secure_storage_service.dart';
import '../services/window_feature_extractor.dart';
import '../services/crash_model.dart';

/// Manages sensor monitoring state and exposes live [SensorFeatures] to the UI.
/// Collects sensors directly in the main isolate — no background service needed.
class SensorProvider extends ChangeNotifier {
  final SecureStorageService _storageService;

  SensorProvider({required SecureStorageService storageService})
      : _storageService = storageService;

  // ── State ──────────────────────────────────────────────────────────────────
  bool _isMonitoring = false;
  SensorFeatures? _latest;
  String? _errorMessage;

  bool get isMonitoring => _isMonitoring;
  SensorFeatures? get latest => _latest;
  String? get errorMessage => _errorMessage;

  // Track if backend requested countdown screen
  bool _isAwaitingConfirmation = false;
  bool get isAwaitingConfirmation => _isAwaitingConfirmation;

  void clearAwaitingConfirmation() {
    _isAwaitingConfirmation = false;
    notifyListeners();
  }

  // ── Internal sensor state ──────────────────────────────────────────────────
  double _rx = 0, _ry = 0, _rz = 0;
  double _lat = 0, _lng = 0, _speed = 0;
  DateTime? _lastGpsTime;
  double _prevSpeed = 0;

  final List<Map<String, dynamic>> _batch = [];
  static const _batchSize = 30;

  // On-device ML sliding window (100Hz for 1 second)
  final List<SensorFeatures> _windowBuffer = [];
  static const int _windowSize = 100;
  
  // Track high crash probability to update UI
  double _crashProbability = 0.0;
  double get crashProbability => _crashProbability;

  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<Position>? _gpsSub;

  Dio? _dio;
  String? _token;

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> startMonitoring() async {
    if (_isMonitoring) return;
    _errorMessage = null;

    try {
      // Check location services enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _errorMessage = 'Location services are off. Enable GPS in Settings.';
        notifyListeners();
        return;
      }

      // Get JWT for backend calls
      _token = await _storageService.getToken();
      _dio = Dio(BaseOptions(
        baseUrl: AppConstants.backendBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));

      // ── GPS stream ─────────────────────────────────────────────────────────
      try {
        _gpsSub = Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 0,
          ),
        ).listen(
          (pos) {
            _lat = pos.latitude;
            _lng = pos.longitude;
            _speed = pos.speed < 0 ? 0 : pos.speed;
            _lastGpsTime = DateTime.now();
          },
          onError: (_) {}, // silently ignore GPS errors
        );
      } catch (_) {}

      // ── Gyroscope stream ───────────────────────────────────────────────────
      try {
        _gyroSub = gyroscopeEventStream(
          samplingPeriod: const Duration(milliseconds: 100),
        ).listen(
          (e) { _rx = e.x; _ry = e.y; _rz = e.z; },
          onError: (_) {},
        );
      } catch (_) {}

      // ── Accelerometer stream ───────────────────────────────────────────────
      try {
        _accelSub = accelerometerEventStream(
          samplingPeriod: const Duration(milliseconds: 100),
        ).listen(
          (e) => _onAccelerometer(e),
          onError: (err) {
            _errorMessage = 'Sensor error: $err';
            notifyListeners();
          },
        );
      } catch (e) {
        _errorMessage = 'Failed to start accelerometer: $e';
        notifyListeners();
        return;
      }

      _isMonitoring = true;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to start monitoring: $e';
      notifyListeners();
    }
  }

  void _onAccelerometer(AccelerometerEvent e) {
    try {
      final now = DateTime.now();
      
      // If we haven't received a GPS update in >2 seconds, we are likely stationary.
      // Geolocator stops firing events when not moving, so we must reset speed to 0.
      double currentSpeed = _speed;
      if (_lastGpsTime == null || now.difference(_lastGpsTime!).inSeconds > 2) {
        currentSpeed = 0;
      }

      final raw = RawSensorData(
        ax: e.x, ay: e.y, az: e.z,
        rx: _rx,  ry: _ry,  rz: _rz,
        lat: _lat, lng: _lng, speed: currentSpeed,
        timestamp: now,
      );

      final features = FeatureExtractor.extract(raw, _prevSpeed);
      _prevSpeed = currentSpeed;

      _latest = features;
      notifyListeners();

      // ── On-Device ML Evaluation ──────────────────────────────────────────
      _windowBuffer.add(features);
      if (_windowBuffer.length > _windowSize) {
        _windowBuffer.removeAt(0); // keep it sliding
      }

      if (_windowBuffer.length == _windowSize) {
        // Speed Gate: Prevent false positives from dropping/shaking the phone while walking.
        // If speed is < 10 km/h (or GPS has no fix), it cannot be a vehicular crash.
        final currentSpeedKmh = features.speed * 3.6;
        
        if (currentSpeedKmh < 10.0) {
          if (_crashProbability != 0.0) {
            _crashProbability = 0.0;
            notifyListeners();
          }
        } else {
          final windowFeatures = WindowFeatureExtractor.extract(_windowBuffer);
          final prob = CrashModel.predict(windowFeatures);
          
          // Only update UI wildly if probability changes significantly
          if ((prob - _crashProbability).abs() > 0.05) {
            _crashProbability = prob;
            notifyListeners();
          }

          // Trigger emergency if probability is very high
          if (prob >= 0.90) {
            print("🚨 ON-DEVICE CRASH DETECTED! Probability: $prob");
            // In a real app, this should trigger a delayed alert screen before calling contacts
          }
        }
      }
      // ───────────────────────────────────────────────────────────────────

      // Batch and send to backend
      _batch.add(features.toJson());
      if (_batch.length >= _batchSize) {
        final payload = List<Map<String, dynamic>>.from(_batch);
        _batch.clear();
        _sendBatch(payload, _crashProbability);
      }
    } catch (_) {}
  }

  Future<void> _sendBatch(List<Map<String, dynamic>> readings, double crashProb) async {
    if (_token == null || _dio == null) return;
    try {
      print("Sending batch to backend: ${readings.length} readings, prob=$crashProb");
      final res = await _dio!.post(
        AppConstants.sensorDataEndpoint,
        data: {
          'readings': readings,
          'crashProbability': crashProb,
        },
        options: Options(headers: {'Authorization': 'Bearer $_token'}),
      );

      // Check state machine from backend
      if (res.data != null && res.data['success'] == true) {
        final String? serverState = res.data['currentState'];
        print("Backend returned state: $serverState");
        if (serverState == 'AWAITING_CONFIRMATION' && !_isAwaitingConfirmation) {
          _isAwaitingConfirmation = true;
          notifyListeners();
        }
      }
    } catch (e) {
      print("Network error sending batch: $e");
    }
  }

  Future<void> stopMonitoring() async {
    if (!_isMonitoring) return;
    await _accelSub?.cancel();
    await _gyroSub?.cancel();
    await _gpsSub?.cancel();
    _accelSub = null;
    _gyroSub = null;
    _gpsSub = null;
    _batch.clear();
    _isMonitoring = false;
    notifyListeners();
  }

  /// FOR TESTING: Instantly injects a simulated massive crash payload
  /// and flushes the batch to the backend to trigger the Emergency state machine.
  Future<void> simulateCrash() async {
    final fakeCrashFeature = SensorFeatures(
      gForce: 6.5,
      rotation: 8.0,
      speedDrop: 15.0,
      speed: 25.0, // moving ~90km/h
      lat: _lat,
      lng: _lng,
      ax: 65.0, ay: 0.0, az: 0.0,
      rx: 8.0, ry: 0.0, rz: 0.0,
      timestamp: DateTime.now(),
    );

    _batch.clear();
    _batch.add(fakeCrashFeature.toJson());
    
    final payload = List<Map<String, dynamic>>.from(_batch);
    _batch.clear();
    
    print("🚀 Triggering simulateCrash() force payload...");
    
    // Force a 1.0 ML probability directly to the backend
    await _sendBatch(payload, 1.0);
    
    // Force trigger the UI locally in case backend is offline during testing
    _isAwaitingConfirmation = true;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _gpsSub?.cancel();
    super.dispose();
  }
}
