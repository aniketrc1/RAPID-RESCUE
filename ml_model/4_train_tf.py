"""
Step 4 - On-Device Model (TensorFlow Lite)
===========================================
Trains a Keras 1D-CNN directly on the raw sensor data windows.
Unlike 2_features.py (which extracts 60 statistical features), this model 
takes the raw `(100, 6)` signal representing 1 second of data, learns the physics 
via convolutions, and exports to a highly optimized `.tflite` binary for Flutter.
"""

import os
import pandas as pd
import numpy as np
import tensorflow as tf
from sklearn.model_selection import train_test_split
from sklearn.utils.class_weight import compute_class_weight

# ── Config ───────────────────────────────────────────────────────────────────
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PROCESSED_FILE = os.path.join(BASE_DIR, 'data', 'processed.csv')
MODEL_DIR = os.path.join(BASE_DIR, 'models')
TFLITE_FILE = os.path.join(MODEL_DIR, 'crash_model.tflite')

WINDOW_SIZE = 100   # 1 second at 100Hz
STEP_SIZE   = 50    # 0.5s overlap

os.makedirs(MODEL_DIR, exist_ok=True)

# ── 1. Create Windows ────────────────────────────────────────────────────────
def extract_windows(df):
    windows = []
    labels = []
    
    # Group by fall_type just like we would group by individual riding sessions
    for fall_type, group in df.groupby('fall_type'):
        group = group.sort_values('time').reset_index(drop=True)
        length = len(group)
        
        for start in range(0, length - WINDOW_SIZE + 1, STEP_SIZE):
            end = start + WINDOW_SIZE
            window = group.iloc[start:end]
            
            # The label of the window is 1 if ANY point in the window is a crash
            # Since crashes happen very fast, even a partial window is a crash.
            y = int(window['label'].max())
            
            # Extract the raw 6 axes
            # Shape: (100, 6)
            x = window[['ax', 'ay', 'az', 'rx', 'ry', 'rz']].values
            
            windows.append(x)
            labels.append(y)
            
    return np.array(windows), np.array(labels)

print("Loading data...")
if not os.path.exists(PROCESSED_FILE):
    raise FileNotFoundError(f"Missing {PROCESSED_FILE}. Run 1_preprocess.py first.")

df = pd.read_csv(PROCESSED_FILE)
X, y = extract_windows(df)

print(f"Total windows: {len(X)}")
print(f"Class balance: Normal={np.sum(y==0)}, Crash={np.sum(y==1)}")

# ── 2. Train/Test Split ──────────────────────────────────────────────────────
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y
)

# Compute class weights for severe class imbalance
classes = np.unique(y_train)
class_weights_val = compute_class_weight(class_weight='balanced', classes=classes, y=y_train)
class_weights = dict(zip(classes, class_weights_val))
print("Class weights:", class_weights)

# ── 3. Build Keras 1D-CNN Model ──────────────────────────────────────────────
# Input: (100, 6)
model = tf.keras.Sequential([
    tf.keras.layers.InputLayer(input_shape=(WINDOW_SIZE, 6)),
    
    # Conv Block 1
    tf.keras.layers.Conv1D(filters=32, kernel_size=3, activation='relu', padding='same'),
    tf.keras.layers.BatchNormalization(),
    tf.keras.layers.MaxPooling1D(pool_size=2), # (50, 32)
    
    # Conv Block 2
    tf.keras.layers.Conv1D(filters=64, kernel_size=3, activation='relu', padding='same'),
    tf.keras.layers.BatchNormalization(),
    tf.keras.layers.MaxPooling1D(pool_size=2), # (25, 64)
    
    # Conv Block 3
    tf.keras.layers.Conv1D(filters=128, kernel_size=3, activation='relu', padding='same'),
    tf.keras.layers.BatchNormalization(),
    tf.keras.layers.GlobalAveragePooling1D(),  # (128)
    
    # Dense Classifier
    tf.keras.layers.Dropout(0.5),
    tf.keras.layers.Dense(64, activation='relu'),
    tf.keras.layers.Dense(1, activation='sigmoid') # Probability of crash
])

METRICS = [
    tf.keras.metrics.BinaryAccuracy(name='accuracy'),
    tf.keras.metrics.Precision(name='precision'),
    tf.keras.metrics.Recall(name='recall'),
    tf.keras.metrics.AUC(name='auc')
]

model.compile(
    optimizer=tf.keras.optimizers.Adam(learning_rate=0.001),
    loss='binary_crossentropy',
    metrics=METRICS
)

model.summary()

# ── 4. Train ─────────────────────────────────────────────────────────────────
print("\nTraining Model...")
early_stopping = tf.keras.callbacks.EarlyStopping(
    monitor='val_auc', 
    patience=10, 
    mode='max', 
    restore_best_weights=True
)

history = model.fit(
    X_train, y_train,
    epochs=50,
    batch_size=32,
    validation_data=(X_test, y_test),
    class_weight=class_weights,
    callbacks=[early_stopping],
    verbose=1
)

# ── 5. Evaluate ──────────────────────────────────────────────────────────────
print("\nEvaluating on Test Set:")
loss, acc, prec, rec, auc = model.evaluate(X_test, y_test, verbose=0)
f1 = 2 * (prec * rec) / (prec + rec + 1e-7)

print(f"Accuracy:  {acc:.4f}")
print(f"Precision: {prec:.4f}")
print(f"Recall:    {rec:.4f}")
print(f"F1 Score:  {f1:.4f}")
print(f"AUC:       {auc:.4f}")

# ── 6. Convert to TFLite ─────────────────────────────────────────────────────
print("\nExporting to TensorFlow Lite...")

# Convert the model
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT] # Quantization for size reduction
tflite_model = converter.convert()

# Save the model
with open(TFLITE_FILE, 'wb') as f:
    f.write(tflite_model)

print(f"✅ TFLite model saved to {TFLITE_FILE} ({(os.path.getsize(TFLITE_FILE)/1024):.1f} KB)")
print("   Ready to be imported into Flutter app's assets folder!")
