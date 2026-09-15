import 'dart:math';
import '../models/sensor_reading.dart';

/// Helper to extract rolling statistical features over a 1-second window
/// to match the exact keys expected by the Decision Tree ML model.
class WindowFeatureExtractor {
  
  /// Extracts the required features for `CrashModel.predict()` from a buffer of 100 readings.
  static Map<String, double> extract(List<SensorFeatures> window) {
    if (window.isEmpty) return {};

    int n = window.length;

    // Arrays for easy math
    List<double> gForce = window.map((e) => e.gForce).toList();
    List<double> az = window.map((e) => e.az).toList();
    List<double> rz = window.map((e) => e.rz).toList();
    List<double> rx = window.map((e) => e.rx).toList();
    List<double> rotation = window.map((e) => e.rotation).toList();

    // Sorting for IQR / Min / Max
    List<double> sortedRotation = List.from(rotation)..sort();
    
    // Extracted Features required by the ML Tree
    
    // 1. gForce_max
    double gForceMax = gForce.reduce(max);
    
    // 2. az_min
    double azMin = az.reduce(min);
    
    // 3. az_mean
    double azMean = az.reduce((a, b) => a + b) / n;
    
    // 4. az_range
    double azMax = az.reduce(max);
    double azRange = azMax - azMin;
    
    // 5. rz_range
    double rzMax = rz.reduce(max);
    double rzMin = rz.reduce(min);
    double rzRange = rzMax - rzMin;
    
    // 6. rotation_iqr (75th percentile - 25th percentile)
    double rotationQ1 = sortedRotation[(n * 0.25).toInt()];
    double rotationQ3 = sortedRotation[(n * 0.75).toInt()];
    double rotationIqr = rotationQ3 - rotationQ1;
    
    // 7. rx_rms (Root Mean Square)
    double rxSqrSum = rx.fold(0.0, (sum, val) => sum + (val * val));
    double rxRms = sqrt(rxSqrSum / n);
    
    return {
      'gForce_max': gForceMax,
      'az_min': azMin,
      'az_mean': azMean,
      'az_range': azRange,
      'rz_range': rzRange,
      'rotation_iqr': rotationIqr,
      'rx_rms': rxRms,
    };
  }
}
