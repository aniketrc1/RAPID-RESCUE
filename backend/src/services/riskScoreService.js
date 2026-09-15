'use strict';

/**
 * RiskScoreService
 * Calculates a unified risk score based on ML probability and raw sensor physics.
 */
class RiskScoreService {
    /**
     * Normalizes a sensor value between 0 and 1 based on an expected maximum.
     */
    static normalize(value, maxVal) {
        if (!value || value < 0) return 0;
        return Math.min(value / maxVal, 1.0);
    }

    /**
     * Calculates the overall risk score given vehicle telemetry and ML output.
     * Formula: 0.5 * crashProbability + 0.2 * normalizedGForce + 0.2 * normalizedSpeedDrop + 0.1 * normalizedRotation
     *
     * @param {number} crashProbability - The ML model's prediction confidence (0.0 to 1.0)
     * @param {number} gForce - Peak G-Force (m/s^2 or g)
     * @param {number} speedDrop - Peak speed deceleration (m/s)
     * @param {number} rotation - Peak angular velocity (rad/s)
     * @returns {number} Risk score between 0.0 and 1.0
     */
    static calculateRiskScore(crashProbability = 0, gForce = 0, speedDrop = 0, rotation = 0) {
        // Normalization thresholds (tuned based on typical severe crash metrics)
        const MAX_GFORCE = 6.0;      // ~6g impact
        const MAX_SPEED_DROP = 15.0; // ~54 km/h instantaneous deceleration
        const MAX_ROTATION = 8.0;    // ~8 rad/s tumbling

        const normGForce = this.normalize(gForce, MAX_GFORCE);
        const normSpeedDrop = this.normalize(speedDrop, MAX_SPEED_DROP);
        const normRotation = this.normalize(rotation, MAX_ROTATION);

        const score =
            (0.5 * crashProbability) +
            (0.2 * normGForce) +
            (0.2 * normSpeedDrop) +
            (0.1 * normRotation);

        // Ensure clamped to 0.0 - 1.0
        return Math.min(Math.max(score, 0.0), 1.0);
    }
}

module.exports = RiskScoreService;
