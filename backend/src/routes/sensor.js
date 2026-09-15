const express = require('express');
const { verifyFirebaseToken } = require('../middleware/firebaseAuth');
const { receiveSensorData, cancelEmergency } = require('../controllers/sensorController');

const router = express.Router();

/**
 * POST /api/sensor/data
 * Receives a batch of SensorFeatures from the Flutter background service.
 * Body: { readings: SensorFeatures[] }
 *
 * Returns: { success, saved, crashDetected, confidence, severity }
 */
router.post('/data', verifyFirebaseToken, receiveSensorData);

/**
 * POST /api/sensor/cancel
 * Aborts an active emergency countdown and resets the state machine.
 */
router.post('/cancel', verifyFirebaseToken, cancelEmergency);

module.exports = router;
