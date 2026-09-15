const admin = require('firebase-admin');
const path = require('path');

/**
 * Initialises the Firebase Admin SDK using the service account key file.
 *
 * Steps to get the key:
 *   Firebase Console → ⚙ Project Settings → Service Accounts
 *   → Generate new private key → save as serviceAccountKey.json
 *   in the backend root directory (it is .gitignored).
 */
function initFirebase() {
  if (admin.apps.length > 0) return; // already initialised (hot-reload safety)

  const keyPath = path.resolve(
    process.env.FIREBASE_SERVICE_ACCOUNT_PATH || './serviceAccountKey.json'
  );

  try {
    const serviceAccount = require(keyPath);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    console.log('✅ Firebase Admin SDK initialised successfully.');
  } catch (err) {
    console.error('❌ Firebase Admin initialisation failed.');
    console.error('   Make sure serviceAccountKey.json exists in the backend root.');
    console.error('   Download it from: Firebase Console → Project Settings → Service Accounts');
    console.error(err.message);
    process.exit(1);
  }
}

module.exports = { initFirebase, admin };
