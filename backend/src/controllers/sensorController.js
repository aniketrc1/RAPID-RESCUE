'use strict';

const { getFirestore } = require('../config/firestore');

const SENSOR_COLLECTION = 'sensorReadings';
const MAX_BATCH = 100; // guard against oversized payloads

// ── Helpers ────────────────────────────────────────────────────────────────────

function validateReading(r) {
    const required = ['gForce', 'rotation', 'speedDrop', 'speed', 'lat', 'lng', 'timestamp'];
    for (const key of required) {
        if (r[key] === undefined || r[key] === null) return false;
    }
    return true;
}

// ── Controllers ────────────────────────────────────────────────────────────────

/**
 * POST /api/sensor/data
 *
 * Receives a batch of SensorFeatures from the Flutter background service.
 * Body: { readings: SensorFeatures[] }
 *
 * 1. Verifies JWT (done by middleware)
 * 2. Validates each reading
 * 3. Stores to Firestore: sensorReadings/{uid}/readings/{auto-id}
 * 4. Forwards to ML service for crash detection
 * 5. Returns { saved, crashDetected, confidence, severity }
 */
async function receiveSensorData(req, res) {
    const db = getFirestore();
    const uid = req.user.uid;
    const { readings, crashProbability } = req.body;

    if (!Array.isArray(readings) || readings.length === 0) {
        return res.status(400).json({
            success: false,
            message: 'Body must contain a non-empty "readings" array.',
        });
    }

    const trimmed = readings.slice(0, MAX_BATCH);
    const valid = trimmed.filter(validateReading);

    if (valid.length === 0) {
        return res.status(400).json({
            success: false,
            message: 'No valid readings found. Each must have gForce, rotation, speedDrop, speed, lat, lng, timestamp.',
        });
    }

    try {
        // ── Write to Firestore in a batch ──────────────────────────────────────
        const colRef = db
            .collection(SENSOR_COLLECTION)
            .doc(uid)
            .collection('readings');

        const batch = db.batch();
        for (const reading of valid) {
            const docRef = colRef.doc();
            batch.set(docRef, { ...reading, uid, savedAt: new Date().toISOString() });
        }
        await batch.commit();

        // ── ML Analysis & State Machine ───────────────────────────────────────
        const { mlService } = require('../services/mlService');
        // Extract the client ML model probability (defaults to 0 if not sent)
        const clientProb = (typeof crashProbability === 'number') ? crashProbability : 0;
        const mlResult = await mlService.analyzeSensorData(valid, uid, clientProb);

        console.log(
            `📡 uid=${uid} → saved ${valid.length} readings | ` +
            `riskScore=${mlResult.riskScore} | state=${mlResult.currentState} ` +
            `(transitioned: ${mlResult.transitioned})`
        );

        return res.status(200).json({
            success: true,
            saved: valid.length,
            ...mlResult,
        });
    } catch (error) {
        console.error(`[receiveSensorData] uid=${uid}`, error);
        return res.status(500).json({ success: false, message: 'Failed to save sensor data.' });
    }
}

/**
 * POST /api/sensor/cancel
 * Aborts an active emergency countdown.
 */
async function cancelEmergency(req, res) {
    const uid = req.user.uid;
    const StateMachineService = require('../services/stateMachineService');

    StateMachineService.resetState(uid);
    console.log(`[SensorController] 🛑 Emergency cancelled for UID=${uid}`);

    return res.status(200).json({ success: true, message: 'Emergency cancelled, state reset to NORMAL' });
}

module.exports = { receiveSensorData, cancelEmergency };
