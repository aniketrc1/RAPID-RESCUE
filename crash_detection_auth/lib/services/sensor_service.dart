import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/sensor_reading.dart';

/// Subscribes to the device accelerometer and gyroscope streams
/// via [sensors_plus] and fuses them into a single [RawSensorData] stream.
///
/// Sampling: both sensors are sampled independently; this service
/// merges the latest gyro reading with each accelerometer event.
class SensorService {
  SensorService();

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  // Latest gyro reading (updated whenever gyro fires)
  double _rx = 0, _ry = 0, _rz = 0;

  final _controller = StreamController<RawSensorData>.broadcast();

  /// Stream of fused [RawSensorData]. GPS fields are populated externally
  /// by [BackgroundSensorService] which combines this stream with location.
  Stream<RawSensorData> get stream => _controller.stream;
  bool get isRunning => _accelSub != null;

  /// Start listening to accelerometer and gyroscope.
  /// [samplingPeriod] controls how fast events come in (default ~10Hz = 100ms).
  void start({
    Duration samplingPeriod = const Duration(milliseconds: 100),
  }) {
    if (isRunning) return;

    // Gyro: just cache last values
    _gyroSub = gyroscopeEventStream(samplingPeriod: samplingPeriod)
        .listen((e) {
      _rx = e.x; _ry = e.y; _rz = e.z;
    });

    // Accelerometer: emit fused reading on each event
    _accelSub = accelerometerEventStream(samplingPeriod: samplingPeriod)
        .listen((e) {
      _controller.add(RawSensorData(
        ax: e.x, ay: e.y, az: e.z,
        rx: _rx, ry: _ry, rz: _rz,
        // lat/lng/speed filled in by BackgroundSensorService
        lat: 0, lng: 0, speed: 0,
        timestamp: DateTime.now(),
      ));
    });
  }

  /// Stop listening and release resources.
  void stop() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _accelSub = null;
    _gyroSub = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }
}
