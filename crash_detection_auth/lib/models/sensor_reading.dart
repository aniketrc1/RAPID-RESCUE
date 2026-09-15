import 'dart:math';

// ── Raw Sensor Data ───────────────────────────────────────────────────────────

/// One fused snapshot of accelerometer + gyroscope + GPS at a single timestamp.
class RawSensorData {
  final double ax, ay, az;       // Accelerometer (m/s²)
  final double rx, ry, rz;       // Gyroscope (rad/s)
  final double lat, lng;         // GPS coordinates
  final double speed;            // GPS speed (m/s)
  final DateTime timestamp;

  const RawSensorData({
    required this.ax, required this.ay, required this.az,
    required this.rx, required this.ry, required this.rz,
    required this.lat, required this.lng,
    required this.speed,
    required this.timestamp,
  });

  static RawSensorData empty() => RawSensorData(
    ax: 0, ay: 0, az: 0,
    rx: 0, ry: 0, rz: 0,
    lat: 0, lng: 0, speed: 0,
    timestamp: DateTime.now(),
  );
}

// ── Sensor Features ───────────────────────────────────────────────────────────

/// Derived features computed by [FeatureExtractor] from [RawSensorData].
class SensorFeatures {
  /// √(ax² + ay² + az²) — total acceleration magnitude in g
  final double gForce;

  /// √(rx² + ry² + rz²) — total rotational velocity magnitude
  final double rotation;

  /// previousSpeed − currentSpeed (positive = deceleration)
  final double speedDrop;

  /// Current speed in m/s from GPS
  final double speed;

  final double lat, lng;
  final double ax, ay, az;
  final double rx, ry, rz;

  final DateTime timestamp;

  const SensorFeatures({
    required this.gForce,
    required this.rotation,
    required this.speedDrop,
    required this.speed,
    required this.lat,
    required this.lng,
    required this.ax, required this.ay, required this.az,
    required this.rx, required this.ry, required this.rz,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'gForce': _round(gForce),
    'rotation': _round(rotation),
    'speedDrop': _round(speedDrop),
    'speed': _round(speed),
    'lat': lat,
    'lng': lng,
    'ax': _round(ax), 'ay': _round(ay), 'az': _round(az),
    'rx': _round(rx), 'ry': _round(ry), 'rz': _round(rz),
    'timestamp': timestamp.toIso8601String(),
  };

  static double _round(double v) =>
      (v * 10000).roundToDouble() / 10000;

  factory SensorFeatures.fromJson(Map<String, dynamic> j) => SensorFeatures(
    gForce: (j['gForce'] as num).toDouble(),
    rotation: (j['rotation'] as num).toDouble(),
    speedDrop: (j['speedDrop'] as num).toDouble(),
    speed: (j['speed'] as num).toDouble(),
    lat: (j['lat'] as num).toDouble(),
    lng: (j['lng'] as num).toDouble(),
    ax: (j['ax'] as num).toDouble(),
    ay: (j['ay'] as num).toDouble(),
    az: (j['az'] as num).toDouble(),
    rx: (j['rx'] as num).toDouble(),
    ry: (j['ry'] as num).toDouble(),
    rz: (j['rz'] as num).toDouble(),
    timestamp: DateTime.parse(j['timestamp'] as String),
  );

  /// Heuristic crash flag — tune thresholds for your vehicle type.
  bool get isPossibleCrash => gForce > 3.0 || speedDrop > 8.0;

  @override
  String toString() =>
    'SensorFeatures(gForce: ${gForce.toStringAsFixed(2)}, '
    'rotation: ${rotation.toStringAsFixed(2)}, '
    'speedDrop: ${speedDrop.toStringAsFixed(2)}, '
    'speed: ${speed.toStringAsFixed(1)} m/s)';
}
