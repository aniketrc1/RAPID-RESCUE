"""
Flask Prediction API
=====================
Accepts POST /predict with a batch of sensor readings (same format as Flutter app).
Returns crash detection result.

Start:  python app.py
Port:   5000

Integration with Node.js:
  In mlService.js, replace the TODO with:
    const res = await axios.post('http://localhost:5000/predict', { readings });
    return res.data;
"""

import os
import json
import math
import joblib
import numpy as np
from flask import Flask, request, jsonify
from flask_cors import CORS

# ── Load model ─────────────────────────────────────────────────────────────────
BASE_DIR    = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODEL_FILE  = os.path.join(BASE_DIR, 'models', 'crash_model.pkl')
FEAT_FILE   = os.path.join(BASE_DIR, 'models', 'feature_names.json')

model        = joblib.load(MODEL_FILE)
feature_cols = json.load(open(FEAT_FILE))

print(f"✅ Model loaded: {MODEL_FILE}")
print(f"   Expects {len(feature_cols)} features per window")

app = Flask(__name__)
CORS(app)

# ── Thresholds for severity labelling ─────────────────────────────────────────
SEVERITY_THRESHOLDS = {
    'severe':   {'gForce': 2.0, 'rotation': 150.0},
    'moderate': {'gForce': 1.5, 'rotation': 100.0},
    'minor':    {'gForce': 1.2, 'rotation': 60.0},
}

def classify_severity(peak_gf, peak_rot, confidence):
    if confidence < 0.3:
        return 'none'
    for level, t in SEVERITY_THRESHOLDS.items():
        if peak_gf >= t['gForce'] or peak_rot >= t['rotation']:
            return level
    return 'minor' if confidence > 0.5 else 'none'

# ── Feature extraction from raw readings ──────────────────────────────────────
def readings_to_features(readings: list) -> np.ndarray:
    """
    Converts a list of sensor dicts (from Flutter toJson) into the feature
    vector expected by the model.
    """
    ax = np.array([r.get('ax', 0) for r in readings])
    ay = np.array([r.get('ay', 0) for r in readings])
    az = np.array([r.get('az', 0) for r in readings])
    rx = np.array([r.get('rx', 0) for r in readings])
    ry = np.array([r.get('ry', 0) for r in readings])
    rz = np.array([r.get('rz', 0) for r in readings])
    gf = np.array([r.get('gForce', math.sqrt(x**2+y**2+z**2)/9.81)
                   for r, x, y, z in zip(readings, ax, ay, az)])
    rot = np.array([r.get('rotation', math.sqrt(x**2+y**2+z**2))
                    for r, x, y, z in zip(readings, rx, ry, rz)])

    sensor_arrays = {
        'ax': ax, 'ay': ay, 'az': az,
        'rx': rx, 'ry': ry, 'rz': rz,
        'gForce': gf, 'rotation': rot,
    }

    feats = {}
    for name, arr in sensor_arrays.items():
        feats[f'{name}_mean']  = np.mean(arr)
        feats[f'{name}_std']   = np.std(arr)
        feats[f'{name}_min']   = np.min(arr)
        feats[f'{name}_max']   = np.max(arr)
        feats[f'{name}_rms']   = np.sqrt(np.mean(arr**2))
        feats[f'{name}_range'] = np.max(arr) - np.min(arr)
        feats[f'{name}_iqr']   = np.percentile(arr, 75) - np.percentile(arr, 25)

    feats['corr_ax_ay']   = float(np.corrcoef(ax, ay)[0, 1]) if len(ax) > 1 else 0
    feats['corr_ax_az']   = float(np.corrcoef(ax, az)[0, 1]) if len(ax) > 1 else 0
    feats['corr_rx_ry']   = float(np.corrcoef(rx, ry)[0, 1]) if len(rx) > 1 else 0
    feats['gForce_slope'] = (gf[-1] - gf[0]) / max(len(gf), 1) if len(gf) > 1 else 0

    # Build in the exact order the model was trained on
    vector = np.array([feats.get(col, 0) for col in feature_cols])
    vector = np.nan_to_num(vector, nan=0.0)
    return vector.reshape(1, -1)


# ── Routes ─────────────────────────────────────────────────────────────────────

@app.get('/health')
def health():
    return jsonify({'status': 'ok', 'model': 'crash_detection', 'features': len(feature_cols)})


@app.post('/predict')
def predict():
    data = request.get_json(silent=True)
    if not data or 'readings' not in data:
        return jsonify({'error': 'Body must contain "readings" array'}), 400

    readings = data['readings']
    if not isinstance(readings, list) or len(readings) < 5:
        return jsonify({'error': 'Need at least 5 readings to predict'}), 400

    try:
        X = readings_to_features(readings)
        crash_detected = bool(model.predict(X)[0])
        confidence     = float(model.predict_proba(X)[0][1])

        peak_gf  = max(r.get('gForce', 0) for r in readings)
        peak_rot = max(r.get('rotation', 0) for r in readings)
        severity = classify_severity(peak_gf, peak_rot, confidence)

        return jsonify({
            'crashDetected': crash_detected,
            'confidence':    round(confidence, 4),
            'severity':      severity,
            'model':         'RandomForest/XGBoost',
            'windowSize':    len(readings),
        })

    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ── Main ───────────────────────────────────────────────────────────────────────
if __name__ == '__main__':
    print("\n🚀 Crash Detection ML API")
    print("   POST http://localhost:5000/predict")
    print("   GET  http://localhost:5000/health\n")
    app.run(host='0.0.0.0', port=5000, debug=False)
