"""
Step 1 — Data Preprocessing
============================
- Loads all synthetic CSVs from data/raw/
- Also loads the 4 original motorcycle files from ../dataset/ if they exist
- Downsamples 1000Hz -> 100Hz for original files. Synthetics are already 100Hz.
- Labels last N seconds of each file as crash (label=1), rest as normal (label=0)
    - If the filename says "normal" or "hardbrake", no crash happened, so label=0 for the whole file.
- Saves merged result to data/processed.csv
"""

import os
import math
import pandas as pd

# ── Config ─────────────────────────────────────────────────────────────────────
BASE_DIR    = os.path.dirname(__file__)
DATASET_DIR = os.path.join(BASE_DIR, '..', 'dataset')
RAW_DIR     = os.path.join(BASE_DIR, 'data', 'raw')
OUTPUT_DIR  = os.path.join(BASE_DIR, 'data')
OUTPUT_FILE = os.path.join(OUTPUT_DIR, 'processed.csv')

DOWNSAMPLE_FACTOR   = 10    # 1000Hz → 100Hz (only for original real files)
CRASH_WINDOW_SEC    = 2.0   # last N seconds = crash label

ORIGINAL_FILES = {
    'moto_curve':       'Fall in a curve_V1.csv',
    'moto_roundabout':  'Fall in the roundabout_V1.csv',
    'moto_slippery':    'Fall on a slippery straight road section_V1.csv',
    'moto_leaning':     'Fall with leaning of the motorcycle_V1.csv',
}

COL_NAMES = ['time', 'ax', 'ay', 'az', 'rx', 'ry', 'rz']

os.makedirs(OUTPUT_DIR, exist_ok=True)

# ── Process each file ─────────────────────────────────────────────────────────
all_frames = []

def process_dataframe(df, fall_type, is_1000hz, is_crash_scenario):
    # Keep only the first 7 columns (time + 3-axis accel + 3-axis gyro)
    df = df.iloc[:, :7]
    df.columns = COL_NAMES

    # Convert all to numeric, drop bad rows
    df = df.apply(pd.to_numeric, errors='coerce').dropna()

    if is_1000hz:
        # Downsample: keep every Nth row
        df = df.iloc[::DOWNSAMPLE_FACTOR].reset_index(drop=True)

    # Derived columns
    df['gForce']   = (df['ax']**2 + df['ay']**2 + df['az']**2).apply(math.sqrt) / 9.81
    df['rotation'] = (df['rx']**2 + df['ry']**2 + df['rz']**2).apply(math.sqrt)

    # Label: last CRASH_WINDOW_SEC seconds = 1, rest = 0
    max_time = df['time'].max()
    
    if is_crash_scenario:
        df['label'] = (df['time'] >= (max_time - CRASH_WINDOW_SEC)).astype(int)
    else:
        df['label'] = 0
        
    df['fall_type'] = fall_type
    
    return df, max_time

# 1. Process Real Motorcycle Files
for fall_type, filename in ORIGINAL_FILES.items():
    path = os.path.join(DATASET_DIR, filename)
    if os.path.exists(path):
        print(f"Loading real data: {filename}...")
        df = pd.read_csv(path, sep=r'\s+', header=0, encoding='latin-1', engine='python', on_bad_lines='skip')
        processed_df, max_time = process_dataframe(df, fall_type, is_1000hz=True, is_crash_scenario=True)
        crash_rows = processed_df['label'].sum()
        all_frames.append(processed_df)
        print(f"  -> {len(processed_df):,} rows | crash={crash_rows} normal={len(processed_df)-crash_rows} (duration={max_time:.1f}s)")

# 2. Process Synthetic Files (Cars & Motorcycles)
if os.path.exists(RAW_DIR):
    syn_files = [f for f in os.listdir(RAW_DIR) if f.startswith('syn_') and f.endswith('.csv')]
    for filename in syn_files:
        path = os.path.join(RAW_DIR, filename)
        
        # Parse scenario type from filename: syn_moto_normal_001.csv -> moto_normal
        parts = filename.replace('.csv', '').split('_')
        if len(parts) >= 3:
            fall_type = f"{parts[1]}_{parts[2]}" 
        else:
            fall_type = "synthetic"
            
        is_crash = not ("normal" in filename or "hardbrake" in filename)
        
        df = pd.read_csv(path)
        processed_df, max_time = process_dataframe(df, fall_type, is_1000hz=False, is_crash_scenario=is_crash)
        all_frames.append(processed_df)

# ── Merge & save ───────────────────────────────────────────────────────────────
if all_frames:
    merged = pd.concat(all_frames, ignore_index=True)
    merged.to_csv(OUTPUT_FILE, index=False)
    
    print(f"\n✅ Done. Saved {len(merged):,} rows -> {OUTPUT_FILE}")
    print(f"   Class balance:  crash={merged['label'].sum():,} | normal={(merged['label']==0).sum():,}")
else:
    print("❌ No data found to process!")
