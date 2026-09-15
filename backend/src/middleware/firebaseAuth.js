const { admin } = require('../config/firebase');

/**
 * Express middleware that verifies the Firebase ID token from the
 * Authorization header and attaches the decoded claims to req.user.
 *
 * Expected header:  Authorization: Bearer <firebase-id-token>
 *
 * On success  → calls next() with req.user = { uid, email, name, ... }
 * On failure  → responds with 401 Unauthorized
 */
async function verifyFirebaseToken(req, res, next) {
    const authHeader = req.headers['authorization'];

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({
            success: false,
            message: 'Missing or malformed Authorization header. Expected: Bearer <token>',
        });
    }

    const idToken = authHeader.substring(7); // strip "Bearer "

    try {
        const decodedToken = await admin.auth().verifyIdToken(idToken);

        // Attach user info to the request for downstream handlers.
        req.user = {
            uid: decodedToken.uid,
            email: decodedToken.email || null,
            name: decodedToken.name || null,
            picture: decodedToken.picture || null,
            phone: decodedToken.phone_number || null,
            emailVerified: decodedToken.email_verified || false,
            // Token metadata
            tokenIssuedAt: new Date(decodedToken.iat * 1000).toISOString(),
            tokenExpiresAt: new Date(decodedToken.exp * 1000).toISOString(),
        };

        next();
    } catch (error) {
        console.error('Token verification failed:', error.code, error.message);

        const message = _mapFirebaseError(error.code);
        return res.status(401).json({ success: false, message });
    }
}

function _mapFirebaseError(code) {
    switch (code) {
        case 'auth/id-token-expired':
            return 'Token has expired. Please refresh and try again.';
        case 'auth/id-token-revoked':
            return 'Token has been revoked. Please sign in again.';
        case 'auth/invalid-id-token':
            return 'Invalid token. Please sign in again.';
        case 'auth/user-disabled':
            return 'This account has been disabled.';
        default:
            return 'Authentication failed. Invalid token.';
    }
}

module.exports = { verifyFirebaseToken };
