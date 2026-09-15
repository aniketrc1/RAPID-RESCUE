"""
Step 2 — Feature Extraction
============================
- Reads data/processed.csv (output of 1_preprocess.py)
- Applies a 1-second sliding window with 50% overlap (at 100Hz → 100 rows/window)
- Extracts statistical + physics features per window
- Saves to data/features.csv
"""

import math
import numpy as np
import pandas as pd
import os

# ── Config ─────────────────────────────────────────────────────────────────────
INPUT_FILE  = os.path.join(os.path.dirname(__file__), 'data', 'processed.csv')
OUTPUT_FILE = os.path.join(os.path.dirname(__file__), 'data', 'features.csv')

SAMPLE_RATE  = 100         # Hz after downsampling
WINDOW_SEC   = 1.0         # 1-second window
OVERLAP      = 0.5         # 50% overlap
WINDOW_SIZE  = int(SAMPLE_RATE * WINDOW_SEC)          # 100 samples
STEP_SIZE    = int(WINDOW_SIZE * (1 - OVERLAP))        # 50 samples

SENSOR_COLS  = ['ax', 'ay', 'az', 'rx', 'ry', 'rz', 'gForce', 'rotation']

# ── Feature extraction function ────────────────────────────────────────────────

def extract_window_features(window: pd.DataFrame) -> dict:
    feats = {}

    for col in SENSOR_COLS:
        vals = window[col].values
        feats[f'{col}_mean'] = np.mean(vals)
        feats[f'{col}_std']  = np.std(vals)
        feats[f'{col}_min']  = np.min(vals)
        feats[f'{col}_max']  = np.max(vals)
        feats[f'{col}_rms']  = np.sqrt(np.mean(vals**2))   # Root Mean Square
        feats[f'{col}_range'] = np.max(vals) - np.min(vals)
        feats[f'{col}_iqr']  = np.percentile(vals, 75) - np.percentile(vals, 25)

    # Cross-axis correlation (useful for fall direction)
    feats['corr_ax_ay'] = np.corrcoef(window['ax'], window['ay'])[0, 1]
    feats['corr_ax_az'] = np.corrcoef(window['ax'], window['az'])[0, 1]
    feats['corr_rx_ry'] = np.corrcoef(window['rx'], window['ry'])[0, 1]

    # Speed drop proxy: difference of consecutive gForce mean (not GPS-based)
    gf = window['gForce'].values
    feats['gForce_slope'] = (gf[-1] - gf[0]) / max(len(gf), 1)

    # Label: majority vote in window
    feats['label'] = int(window['label'].mode()[0])

    # Keep fall_type for analysis
    feats['fall_type'] = window['fall_type'].mode()[0]

    return feats


# ── Main ───────────────────────────────────────────────────────────────────────

print("Loading processed.csv...")
df = pd.read_csv(INPUT_FILE)
print(f"  {len(df):,} rows loaded")

records = []

# Group by fall_type to avoid mixing files in one window
for fall_type, group in df.groupby('fall_type'):
    group = group.reset_index(drop=True)
    n = len(group)
    windows = 0
    for start in range(0, n - WINDOW_SIZE + 1, STEP_SIZE):
        window = group.iloc[start:start + WINDOW_SIZE]
        feats = extract_window_features(window)
        records.append(feats)
        windows += 1
    print(f"  {fall_type}: {windows} windows extracted")

features_df = pd.DataFrame(records)

# Fill any NaN correlations (can happen on zero-variance windows)
features_df = features_df.fillna(0)

features_df.to_csv(OUTPUT_FILE, index=False)

print(f"Done. Saved {len(features_df):,} windows -> {OUTPUT_FILE}")
print(f"   Features per window: {len(features_df.columns) - 2}")
print(f"   Class balance:  crash={features_df['label'].sum()}  "
      f"normal={(features_df['label']==0).sum()}")
