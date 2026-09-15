'use strict';

const RiskScoreService = require('./riskScoreService');
const StateMachineService = require('./stateMachineService');

/**
 * ML Service — crash detection from sensor feature batches and ML Probability.
 *
 * It combines the client-side ML crash probability with peak sensor physics
 * to generate a unified risk score. It then evaluates the state machine
 * for crash confirmation flows.
 */
async function analyzeSensorData(readings, uid, clientCrashProbability) {
    if (!readings || readings.length === 0) {
        return {
            riskScore: 0,
            currentState: StateMachineService.STATES.NORMAL,
            transitioned: false
        };
    }

    // Find peak values in the batch for physics reinforcement
    const maxGForce = Math.max(...readings.map((r) => r.gForce || 0));
    const maxSpeedDrop = Math.max(...readings.map((r) => r.speedDrop || 0));
    const maxRotation = Math.max(...readings.map((r) => r.rotation || 0));

    // Determine unified risk score
    const riskScore = RiskScoreService.calculateRiskScore(
        clientCrashProbability,
        maxGForce,
        maxSpeedDrop,
        maxRotation
    );

    // Run state machine transition based on risk score
    const stateResult = StateMachineService.evaluateRiskAndTransition(uid, riskScore);

    return {
        riskScore: parseFloat(riskScore.toFixed(3)),
        currentState: stateResult.newState,
        transitioned: stateResult.transitioned
    };
}

module.exports = {
    mlService: { analyzeSensorData },
};
