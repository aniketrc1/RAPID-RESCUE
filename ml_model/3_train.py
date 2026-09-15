"""
Step 3 — Model Training
========================
- Loads data/features.csv
- Trains Random Forest + XGBoost (with class balancing)
- Picks the best by F1-score on validation set
- Saves best model to models/crash_model.pkl
- Saves feature names to models/feature_names.json
"""

import os
import json
import joblib
import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split, StratifiedKFold, cross_val_score
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.pipeline import Pipeline
from sklearn.metrics import f1_score, classification_report
from xgboost import XGBClassifier

# ── Config ─────────────────────────────────────────────────────────────────────
INPUT_FILE   = os.path.join(os.path.dirname(__file__), 'data', 'features.csv')
MODELS_DIR   = os.path.join(os.path.dirname(__file__), 'models')
MODEL_FILE   = os.path.join(MODELS_DIR, 'crash_model.pkl')
FEAT_FILE    = os.path.join(MODELS_DIR, 'feature_names.json')
REPORT_FILE  = os.path.join(MODELS_DIR, 'training_report.txt')

os.makedirs(MODELS_DIR, exist_ok=True)

# ── Load data ──────────────────────────────────────────────────────────────────
print("Loading features.csv...")
df = pd.read_csv(INPUT_FILE)

# Drop non-feature columns
DROP = ['label', 'fall_type']
feature_cols = [c for c in df.columns if c not in DROP]

X = df[feature_cols].values
y = df['label'].values

print(f"  Samples: {len(X)}  |  Features: {len(feature_cols)}")
print(f"  Crash: {y.sum()}  Normal: {(y==0).sum()}")

# ── Train/test split (stratified to preserve class ratio) ─────────────────────
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y
)
print(f"\nTrain: {len(X_train)}  Test: {len(X_test)}")

# ── Model 1: Random Forest ─────────────────────────────────────────────────────
print("\n--- Training Random Forest ---")
rf_pipe = Pipeline([
    ('scaler', StandardScaler()),
    ('clf', RandomForestClassifier(
        n_estimators=200,
        class_weight='balanced',   # handles imbalanced crash/normal ratio
        max_depth=None,
        min_samples_leaf=2,
        random_state=42,
        n_jobs=-1,
    ))
])
rf_pipe.fit(X_train, y_train)
rf_pred  = rf_pipe.predict(X_test)
rf_f1    = f1_score(y_test, rf_pred)
rf_proba = rf_pipe.predict_proba(X_test)[:, 1]
print(f"  F1: {rf_f1:.4f}")
print(classification_report(y_test, rf_pred, target_names=['Normal', 'Crash']))

# ── Model 2: XGBoost ──────────────────────────────────────────────────────────
crash_count  = int((y_train == 1).sum())
normal_count = int((y_train == 0).sum())
scale_pos    = normal_count / max(crash_count, 1)

print(f"\n--- Training XGBoost (scale_pos_weight={scale_pos:.1f}) ---")
xgb_pipe = Pipeline([
    ('scaler', StandardScaler()),
    ('clf', XGBClassifier(
        n_estimators=200,
        scale_pos_weight=scale_pos,
        max_depth=6,
        learning_rate=0.1,
        subsample=0.8,
        colsample_bytree=0.8,
        use_label_encoder=False,
        eval_metric='logloss',
        random_state=42,
        n_jobs=-1,
    ))
])
xgb_pipe.fit(X_train, y_train)
xgb_pred  = xgb_pipe.predict(X_test)
xgb_f1    = f1_score(y_test, xgb_pred)
xgb_proba = xgb_pipe.predict_proba(X_test)[:, 1]
print(f"  F1: {xgb_f1:.4f}")
print(classification_report(y_test, xgb_pred, target_names=['Normal', 'Crash']))

# ── Pick best model ────────────────────────────────────────────────────────────
if rf_f1 >= xgb_f1:
    best_model, best_name, best_f1 = rf_pipe, 'RandomForest', rf_f1
else:
    best_model, best_name, best_f1 = xgb_pipe, 'XGBoost', xgb_f1

print(f"\n🏆 Best model: {best_name}  (F1={best_f1:.4f})")

# ── Cross-validation on full data ─────────────────────────────────────────────
print("\n5-fold cross-validation on full dataset...")
cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)
cv_scores = cross_val_score(best_model, X, y, cv=cv, scoring='f1', n_jobs=-1)
print(f"  CV F1: {cv_scores.mean():.4f} ± {cv_scores.std():.4f}")

# ── Save ───────────────────────────────────────────────────────────────────────
joblib.dump(best_model, MODEL_FILE)
with open(FEAT_FILE, 'w') as f:
    json.dump(feature_cols, f, indent=2)

report = (
    f"Best model:  {best_name}\n"
    f"Test F1:     {best_f1:.4f}\n"
    f"CV F1:       {cv_scores.mean():.4f} ± {cv_scores.std():.4f}\n"
    f"RF F1:       {rf_f1:.4f}\n"
    f"XGB F1:      {xgb_f1:.4f}\n"
    f"Features:    {len(feature_cols)}\n"
    f"Train rows:  {len(X_train)}\n"
    f"Test rows:   {len(X_test)}\n"
)
with open(REPORT_FILE, 'w') as f:
    f.write(report)

print(f"\n✅ Model saved → {MODEL_FILE}")
print(f"✅ Feature names → {FEAT_FILE}")
print(report)
