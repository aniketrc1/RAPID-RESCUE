const { admin } = require('../config/firebase');

/**
 * Returns the Firestore instance.
 * Firebase Admin must already be initialised via initFirebase() before calling this.
 */
function getFirestore() {
    return admin.firestore();
}

module.exports = { getFirestore };
