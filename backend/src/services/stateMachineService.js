'use strict';

/**
 * Valid states for the Crash Detection State Machine
 */
const CRASH_STATES = {
    NORMAL: 'NORMAL',
    SUSPICIOUS: 'SUSPICIOUS',
    POTENTIAL_CRASH: 'POTENTIAL_CRASH',
    CONFIRMED_CRASH: 'CONFIRMED_CRASH',
    AWAITING_CONFIRMATION: 'AWAITING_CONFIRMATION',
    DISPATCHED: 'DISPATCHED'
};

/**
 * StateMachineService
 * Maintains a finite state machine per user for managing the crash response lifecycle.
 */
class StateMachineService {
    constructor() {
        // In-memory state tracking: Map<userId, state>
        // In a production environment, this should ideally be backed by Redis or Firestore
        this.userStates = new Map();

        // Timers to handle auto-transitions (e.g., AWAITING_CONFIRMATION -> DISPATCHED if no response)
        this.userTimers = new Map();
    }

    /**
     * Retrieves the active state for a user.
     * @param {string} userId 
     * @returns {string} The current CRASH_STATE
     */
    getState(userId) {
        if (!this.userStates.has(userId)) {
            this.userStates.set(userId, CRASH_STATES.NORMAL);
        }
        return this.userStates.get(userId);
    }

    /**
     * Evaluates a new risk score and transitions the state machine accordingly.
     * 
     * @param {string} userId - User identifier
     * @param {number} riskScore - Calculated risk score (0.0 to 1.0)
     * @returns {{ previousState: string, newState: string, transitioned: boolean }}
     */
    evaluateRiskAndTransition(userId, riskScore) {
        const currentState = this.getState(userId);

        // Do not automatically downgrade from active emergency flows via risk score alone.
        // Once confirmed/dispatched, the flow requires explicit user or admin action.
        if ([CRASH_STATES.CONFIRMED_CRASH, CRASH_STATES.AWAITING_CONFIRMATION, CRASH_STATES.DISPATCHED].includes(currentState)) {
            return { previousState: currentState, newState: currentState, transitioned: false };
        }

        let nextState = CRASH_STATES.NORMAL;

        // Define thresholds
        if (riskScore >= 0.85) {
            nextState = CRASH_STATES.CONFIRMED_CRASH;
        } else if (riskScore >= 0.60) {
            nextState = CRASH_STATES.POTENTIAL_CRASH;
        } else if (riskScore >= 0.35) {
            nextState = CRASH_STATES.SUSPICIOUS;
        }

        // Transition logic
        if (nextState !== currentState) {
            this.forceTransition(userId, nextState);
            return { previousState: currentState, newState: nextState, transitioned: true };
        }

        return { previousState: currentState, newState: currentState, transitioned: false };
    }

    /**
     * Explicitly forces a state transition, ignoring thresholds (used by UI buttons, timeouts, etc.)
     * @param {string} userId 
     * @param {string} newState 
     */
    forceTransition(userId, newState) {
        // Clean up any existing timeout
        this.clearTimer(userId);

        this.userStates.set(userId, newState);
        console.log(`[StateMachine] UID=${userId} transitioned to ${newState}`);

        // Handle entry actions for specific states
        if (newState === CRASH_STATES.CONFIRMED_CRASH) {
            // Automatically move to AWAITING_CONFIRMATION
            this.forceTransition(userId, CRASH_STATES.AWAITING_CONFIRMATION);
        }
        else if (newState === CRASH_STATES.AWAITING_CONFIRMATION) {
            // Set 20-second timer to auto-dispatch if the user doesn't respond
            const timer = setTimeout(() => {
                this.forceTransition(userId, CRASH_STATES.DISPATCHED);
            }, 20000);
            this.userTimers.set(userId, timer);
        }
        else if (newState === CRASH_STATES.DISPATCHED) {
            // Logic to actually trigger external SOS / SMS APIs would hook in here
            console.log(`[StateMachine] 🚨 EMERGENCY DISPATCH TRIGGERED FOR UID=${userId}`);
        }
    }

    /**
     * Utility to clear pending timers.
     */
    clearTimer(userId) {
        if (this.userTimers.has(userId)) {
            clearTimeout(this.userTimers.get(userId));
            this.userTimers.delete(userId);
        }
    }

    /**
     * Resets the user's state back to normal.
     */
    resetState(userId) {
        this.forceTransition(userId, CRASH_STATES.NORMAL);
    }

    static get STATES() {
        return CRASH_STATES;
    }
}

// Export as a singleton
module.exports = new StateMachineService();
