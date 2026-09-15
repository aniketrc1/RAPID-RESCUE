'use strict';

const { getFirestore } = require('../config/firestore');
const { FieldValue } = require('firebase-admin/firestore');

const USERS_COLLECTION = 'users';

// ── Helpers ───────────────────────────────────────────────────────────────────

/**
 * Validates and sanitises an emergency contact object.
 * Returns null if invalid.
 */
function sanitiseContact(c) {
    if (!c || typeof c !== 'object') return null;
    const name = (c.name || '').trim();
    const phone = (c.phone || '').trim();
    const relation = (c.relation || '').trim();
    if (!name || !phone) return null;
    return { name, phone, relation };
}

/**
 * Validates and sanitises the profile payload from the request body.
 */
function sanitiseProfile(body) {
    const errors = [];

    const name = (body.name || '').trim();
    if (!name) errors.push('name is required.');

    const age = parseInt(body.age, 10);
    if (isNaN(age) || age < 0 || age > 120) errors.push('age must be a number between 0 and 120.');

    const GENDERS = ['Male', 'Female', 'Other', 'Prefer not to say'];
    const gender = (body.gender || '').trim();
    if (!GENDERS.includes(gender)) errors.push(`gender must be one of: ${GENDERS.join(', ')}.`);

    const BLOOD_GROUPS = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'Unknown'];
    const bloodGroup = (body.bloodGroup || '').trim();
    if (!BLOOD_GROUPS.includes(bloodGroup))
        errors.push(`bloodGroup must be one of: ${BLOOD_GROUPS.join(', ')}.`);

    const phoneNumber = (body.phoneNumber || '').trim();
    if (!phoneNumber) {
        errors.push('phoneNumber is required.');
    } else {
        // Enforce +91 followed by exactly 10 digits
        const phoneRegex = /^\+91\s?\d{10}$/;
        if (!phoneRegex.test(phoneNumber.replace(/[-\s]/g, ''))) {
            errors.push('phoneNumber must start with +91 and followed by exactly 10 digits.');
        }
    }

    const rawContacts = Array.isArray(body.emergencyContacts) ? body.emergencyContacts : [];
    const emergencyContacts = rawContacts
        .map(sanitiseContact)
        .filter(Boolean);

    return { errors, data: { name, age, gender, bloodGroup, phoneNumber, emergencyContacts } };
}

// ── Controllers ───────────────────────────────────────────────────────────────

/**
 * GET /api/user/profile
 * Returns the authenticated user's Firestore profile document.
 */
async function getProfile(req, res) {
    const db = getFirestore();
    const uid = req.user.uid;

    try {
        const doc = await db.collection(USERS_COLLECTION).doc(uid).get();

        if (!doc.exists) {
            return res.status(404).json({
                success: false,
                message: 'Profile not found. Please create one first.',
            });
        }

        return res.status(200).json({ success: true, profile: doc.data() });
    } catch (error) {
        console.error(`[getProfile] uid=${uid}`, error);
        return res.status(500).json({ success: false, message: 'Failed to fetch profile.' });
    }
}

/**
 * POST /api/user/profile
 * Creates a new Firestore profile for the authenticated user.
 * Returns 409 if a profile already exists.
 */
async function createProfile(req, res) {
    const db = getFirestore();
    const uid = req.user.uid;

    // Validate
    const { errors, data } = sanitiseProfile(req.body);
    if (errors.length > 0) {
        return res.status(400).json({ success: false, message: 'Validation failed.', errors });
    }

    try {
        const ref = db.collection(USERS_COLLECTION).doc(uid);
        const existing = await ref.get();

        if (existing.exists) {
            return res.status(409).json({
                success: false,
                message: 'Profile already exists. Use PUT to update it.',
            });
        }

        const profile = {
            uid,
            ...data,
            createdAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
        };

        await ref.set(profile);
        console.log(`✅ Created profile for uid=${uid}`);

        // Return without server timestamps (they resolve async)
        return res.status(201).json({ success: true, message: 'Profile created.', profile: { uid, ...data } });
    } catch (error) {
        console.error(`[createProfile] uid=${uid}`, error);
        return res.status(500).json({ success: false, message: 'Failed to create profile.' });
    }
}

/**
 * PUT /api/user/profile
 * Updates the authenticated user's Firestore profile.
 * Creates the document if it doesn't exist (upsert).
 */
async function updateProfile(req, res) {
    const db = getFirestore();
    const uid = req.user.uid;

    // Validate
    const { errors, data } = sanitiseProfile(req.body);
    if (errors.length > 0) {
        return res.status(400).json({ success: false, message: 'Validation failed.', errors });
    }

    try {
        const ref = db.collection(USERS_COLLECTION).doc(uid);

        await ref.set(
            {
                uid,
                ...data,
                updatedAt: FieldValue.serverTimestamp(),
            },
            { merge: true } // upsert — creates if missing, merges if exists
        );

        console.log(`✏️  Updated profile for uid=${uid}`);
        return res.status(200).json({ success: true, message: 'Profile updated.', profile: { uid, ...data } });
    } catch (error) {
        console.error(`[updateProfile] uid=${uid}`, error);
        return res.status(500).json({ success: false, message: 'Failed to update profile.' });
    }
}

module.exports = { getProfile, createProfile, updateProfile };
