const express = require('express');
const { verifyFirebaseToken } = require('../middleware/firebaseAuth');
const { getProfile, createProfile, updateProfile } = require('../controllers/userController');

const router = express.Router();

// ── Profile ───────────────────────────────────────────────────────────────────

/**
 * GET /api/user/profile
 * Returns the authenticated user's profile from Firestore.
 */
router.get('/profile', verifyFirebaseToken, getProfile);

/**
 * POST /api/user/profile
 * Creates a new user profile in Firestore.
 * Returns 409 if profile already exists.
 */
router.post('/profile', verifyFirebaseToken, createProfile);

/**
 * PUT /api/user/profile
 * Updates (upserts) the authenticated user's Firestore profile.
 */
router.put('/profile', verifyFirebaseToken, updateProfile);

// ── Account ───────────────────────────────────────────────────────────────────

/**
 * GET /api/user/profile (legacy — kept for backward compat with auth module)
 * DELETE /api/user/account — deletes Firebase Auth account
 */
router.delete('/account', verifyFirebaseToken, async (req, res) => {
    const { admin } = require('../config/firebase');
    const { getFirestore } = require('../config/firestore');
    try {
        // Delete Firestore profile
        await getFirestore().collection('users').doc(req.user.uid).delete();
        // Delete Firebase Auth user
        await admin.auth().deleteUser(req.user.uid);
        console.log(`🗑️  Deleted account: uid=${req.user.uid}`);
        return res.status(200).json({ success: true, message: 'Account deleted.' });
    } catch (error) {
        console.error('Error deleting account:', error);
        return res.status(500).json({ success: false, message: 'Failed to delete account.' });
    }
});

module.exports = router;
