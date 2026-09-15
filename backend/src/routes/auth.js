const express = require('express');
const { admin } = require('../config/firebase');
const { verifyFirebaseToken } = require('../middleware/firebaseAuth');

const router = express.Router();

/**
 * POST /api/auth/firebase
 *
 * Called by the Flutter app immediately after sign-in.
 * The Flutter BackendApiService sends: { "idToken": "<firebase-jwt>" }
 *
 * This endpoint:
 *   1. Verifies the token via Firebase Admin (done in middleware)
 *   2. Upserts the user in your database (add your DB logic here)
 *   3. Returns user info + confirmation
 */
router.post('/firebase', verifyFirebaseToken, async (req, res) => {
    try {
        const { uid, email, name, picture, phone, emailVerified } = req.user;

        console.log(`✅ Authenticated user: uid=${uid}, email=${email || phone}`);

        // ── TODO: Upsert user in your database here ──────────────────────────
        // Example with a hypothetical DB module:
        // const user = await db.users.upsert({ uid, email, name, picture });
        // ─────────────────────────────────────────────────────────────────────

        return res.status(200).json({
            success: true,
            message: 'Authentication successful.',
            user: {
                uid,
                email,
                name,
                picture,
                phone,
                emailVerified,
            },
        });
    } catch (error) {
        console.error('Error in POST /api/auth/firebase:', error);
        return res.status(500).json({
            success: false,
            message: 'Internal server error.',
        });
    }
});

/**
 * POST /api/auth/logout  (optional)
 *
 * Revokes all refresh tokens for the user, forcing re-authentication
 * on all devices. Call this if you want server-side logout.
 */
router.post('/logout', verifyFirebaseToken, async (req, res) => {
    try {
        await admin.auth().revokeRefreshTokens(req.user.uid);
        console.log(`🚪 Revoked tokens for uid=${req.user.uid}`);
        return res.status(200).json({ success: true, message: 'Logged out successfully.' });
    } catch (error) {
        console.error('Error revoking tokens:', error);
        return res.status(500).json({ success: false, message: 'Logout failed.' });
    }
});

module.exports = router;
