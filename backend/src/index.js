'use strict';

require('dotenv').config();

const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const morgan = require('morgan');

const { initFirebase } = require('./config/firebase');
const authRoutes = require('./routes/auth');
const userRoutes = require('./routes/user');
const sensorRoutes = require('./routes/sensor');

// ── Initialise Firebase Admin SDK ─────────────────────────────────────────────
initFirebase();

// ── Express App ───────────────────────────────────────────────────────────────
const app = express();
const PORT = process.env.PORT || 8080;

// ── Security & Parsing Middleware ─────────────────────────────────────────────
app.use(helmet());                        // sets secure HTTP headers
app.use(cors({
    origin: process.env.CORS_ORIGIN || '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.use(express.json({ limit: '1mb' })); // parse JSON bodies
app.use(morgan('dev'));                   // request logging

// ── Health Check ──────────────────────────────────────────────────────────────
app.get('/health', (req, res) => {
    res.status(200).json({
        status: 'ok',
        service: 'crash-detection-backend',
        timestamp: new Date().toISOString(),
    });
});

// ── API Routes ────────────────────────────────────────────────────────────────
app.use('/api/auth', authRoutes);    // POST /api/auth/firebase
app.use('/api/user', userRoutes);    // GET  /api/user/profile
app.use('/api/sensor', sensorRoutes); // POST /api/sensor/data

// ── 404 Handler ───────────────────────────────────────────────────────────────
app.use((req, res) => {
    res.status(404).json({ success: false, message: `Route ${req.method} ${req.path} not found.` });
});

// ── Global Error Handler ──────────────────────────────────────────────────────
app.use((err, req, res, next) => {
    console.error('Unhandled error:', err);
    res.status(500).json({ success: false, message: 'Internal server error.' });
});

// ── Start Server ──────────────────────────────────────────────────────────────
app.listen(PORT, () => {
    console.log('');
    console.log('🚀 Crash Detection Backend running');
    console.log(`   Local:   http://localhost:${PORT}`);
    console.log(`   Health:  http://localhost:${PORT}/health`);
    console.log('');
    console.log('   Endpoints:');
    console.log(`   POST  http://localhost:${PORT}/api/auth/firebase`);
    console.log(`   POST  http://localhost:${PORT}/api/auth/logout`);
    console.log(`   GET   http://localhost:${PORT}/api/user/profile`);
    console.log('');
});

module.exports = app;
