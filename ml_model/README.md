# Crash Detection ML Model

Standalone Python ML pipeline for motorcycle crash detection using IMU sensor data.

> **Isolated from the Flutter/Node.js project.** Integration happens only when requested.

## Structure
```
ml_model/
├── 1_preprocess.py     ← Load, label, downsample CSVs → data/processed.csv
├── 2_features.py       ← Sliding window feature extraction → data/features.csv
├── 3_train.py          ← Train RF + XGBoost, save best → models/crash_model.pkl
├── 4_evaluate.py       ← Confusion matrix, ROC curve → models/evaluation.png
├── api/
│   └── app.py          ← Flask API: POST /predict
├── data/               ← Generated CSVs (git-ignored)
├── models/             ← Saved model + feature names + plots
└── requirements.txt
```

## Results (from 4 motorcycle fall CSVs)

| Model | Test F1 | CV F1 (5-fold) |
|-------|---------|----------------|
| XGBoost | **0.769** | 0.529 ± 0.22 |
| Random Forest | 0.545 | — |

**Winner: XGBoost** saved to `models/crash_model.pkl`

> CV F1 variance is expected — only 4 fall scenarios (small dataset). More data = better generalisation.

## Run the pipeline

```bash
pip install -r requirements.txt

python 1_preprocess.py   # ~30s
python 2_features.py     # ~5s
python 3_train.py        # ~30s
python 4_evaluate.py     # generates evaluation.png + feature_importance.png
```

## Start the Flask API

```bash
cd api
pip install -r requirements.txt
python app.py
# Listening on http://localhost:5000
```

### Test it
```bash
curl -X POST http://localhost:5000/health
curl -X POST http://localhost:5000/predict ^
  -H "Content-Type: application/json" ^
  -d "{\"readings\": [{\"ax\":2.1,\"ay\":15.3,\"az\":3.2,\"rx\":45,\"ry\":80,\"rz\":20,\"gForce\":1.8,\"rotation\":92}]}"
```

### Response format
```json
{
  "crashDetected": true,
  "confidence": 0.87,
  "severity": "moderate",
  "model": "RandomForest/XGBoost",
  "windowSize": 1
}
```

## Integration (when ready)
In `backend/src/services/mlService.js`, replace the `TODO` with:
```js
const res = await axios.post('http://localhost:5000/predict', { readings });
return res.data;
```
