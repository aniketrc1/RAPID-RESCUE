import 'dart:math';
import '../models/sensor_reading.dart';

/// Pure feature extraction functions — no state, fully testable.
class FeatureExtractor {
  FeatureExtractor._(); // static-only class

  /// Total acceleration magnitude: √(ax² + ay² + az²)
  /// Result is in m/s². Divide by 9.81 to convert to g-force.
  static double gForce(double ax, double ay, double az) =>
      sqrt(ax * ax + ay * ay + az * az) / 9.81;

  /// Total angular velocity magnitude: √(rx² + ry² + rz²)
  static double rotation(double rx, double ry, double rz) =>
      sqrt(rx * rx + ry * ry + rz * rz);

  /// Speed decrease: previousSpeed − currentSpeed (positive = deceleration).
  /// Returns 0 if current speed is higher than previous (acceleration).
  static double speedDrop(double previousSpeed, double currentSpeed) =>
      (previousSpeed - currentSpeed).clamp(0.0, double.infinity);

  /// Combines [RawSensorData] + previous speed into a [SensorFeatures] object.
  static SensorFeatures extract(RawSensorData raw, double previousSpeed) {
    return SensorFeatures(
      gForce: gForce(raw.ax, raw.ay, raw.az),
      rotation: rotation(raw.rx, raw.ry, raw.rz),
      speedDrop: speedDrop(previousSpeed, raw.speed),
      speed: raw.speed,
      lat: raw.lat,
      lng: raw.lng,
      ax: raw.ax, ay: raw.ay, az: raw.az,
      rx: raw.rx, ry: raw.ry, rz: raw.rz,
      timestamp: raw.timestamp,
    );
  }
}
