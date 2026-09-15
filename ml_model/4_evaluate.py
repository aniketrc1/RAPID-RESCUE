"""
Step 4 — Evaluation & Visualisation
======================================
- Loads the saved model and test set
- Prints full classification report
- Plots confusion matrix and ROC curve (saved as PNG)
"""

import os
import json
import joblib
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')   # no display needed
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.model_selection import train_test_split
from sklearn.metrics import (
    classification_report, confusion_matrix,
    roc_curve, auc, f1_score
)

# ── Config ─────────────────────────────────────────────────────────────────────
MODEL_FILE   = os.path.join(os.path.dirname(__file__), 'models', 'crash_model.pkl')
FEAT_FILE    = os.path.join(os.path.dirname(__file__), 'models', 'feature_names.json')
INPUT_FILE   = os.path.join(os.path.dirname(__file__), 'data', 'features.csv')
OUT_DIR      = os.path.join(os.path.dirname(__file__), 'models')

# ── Load ───────────────────────────────────────────────────────────────────────
model         = joblib.load(MODEL_FILE)
feature_cols  = json.load(open(FEAT_FILE))
df            = pd.read_csv(INPUT_FILE)

X = df[feature_cols].values
y = df['label'].values

_, X_test, _, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y
)

y_pred  = model.predict(X_test)
y_proba = model.predict_proba(X_test)[:, 1]

# ── Classification report ──────────────────────────────────────────────────────
print("=" * 50)
print("CLASSIFICATION REPORT")
print("=" * 50)
print(classification_report(y_test, y_pred, target_names=['Normal', 'Crash']))

# ── Confusion matrix ───────────────────────────────────────────────────────────
cm = confusion_matrix(y_test, y_pred)
fig, axes = plt.subplots(1, 2, figsize=(12, 5))

sns.heatmap(cm, annot=True, fmt='d', cmap='Blues',
            xticklabels=['Normal', 'Crash'],
            yticklabels=['Normal', 'Crash'], ax=axes[0])
axes[0].set_title('Confusion Matrix')
axes[0].set_ylabel('Actual')
axes[0].set_xlabel('Predicted')

# ── ROC Curve ─────────────────────────────────────────────────────────────────
fpr, tpr, _ = roc_curve(y_test, y_proba)
roc_auc      = auc(fpr, tpr)

axes[1].plot(fpr, tpr, color='darkorange', lw=2,
             label=f'ROC curve (AUC = {roc_auc:.3f})')
axes[1].plot([0, 1], [0, 1], color='navy', lw=1, linestyle='--')
axes[1].set_xlim([0.0, 1.0])
axes[1].set_ylim([0.0, 1.05])
axes[1].set_xlabel('False Positive Rate')
axes[1].set_ylabel('True Positive Rate')
axes[1].set_title('ROC Curve')
axes[1].legend(loc='lower right')

plt.tight_layout()
plot_path = os.path.join(OUT_DIR, 'evaluation.png')
plt.savefig(plot_path, dpi=150)
print(f"✅ Evaluation plot saved → {plot_path}")
print(f"   AUC: {roc_auc:.4f}  F1: {f1_score(y_test, y_pred):.4f}")

# ── Feature importance (RF only) ──────────────────────────────────────────────
try:
    clf = model.named_steps['clf']
    importances = clf.feature_importances_
    idx = np.argsort(importances)[::-1][:20]  # top 20

    fig2, ax = plt.subplots(figsize=(10, 6))
    ax.barh([feature_cols[i] for i in idx[::-1]],
            importances[idx[::-1]], color='steelblue')
    ax.set_title('Top 20 Feature Importances')
    ax.set_xlabel('Importance')
    plt.tight_layout()
    fi_path = os.path.join(OUT_DIR, 'feature_importance.png')
    plt.savefig(fi_path, dpi=150)
    print(f"✅ Feature importance plot → {fi_path}")
except AttributeError:
    pass   # XGBoost handles this differently
