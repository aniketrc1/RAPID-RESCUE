import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../providers/sensor_provider.dart';
import '../services/secure_storage_service.dart';
import '../core/constants/app_constants.dart';

/// Full-screen emergency countdown overlay.
/// Triggers when the backend State Machine transitions to AWAITING_CONFIRMATION.
class EmergencyCountdownScreen extends StatefulWidget {
  const EmergencyCountdownScreen({super.key});
  static const String routeName = '/emergency-countdown';

  @override
  State<EmergencyCountdownScreen> createState() => _EmergencyCountdownScreenState();
}

class _EmergencyCountdownScreenState extends State<EmergencyCountdownScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  Timer? _countdownTimer;
  int _secondsRemaining = 20; // Matches the backend 20s dispatch timer
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);

    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
        // Time is up — backend state machine will transition to DISPATCHED.
        _showDispatchedDialog();
      }
    });
  }

  void _cancelEmergency() {
    setState(() => _isCancelling = true);
    final storage = Provider.of<SecureStorageService>(context, listen: false);

    _countdownTimer?.cancel();
    
    // Clear trigger and pop immediately so UI doesn't hang
    if (mounted) {
      Provider.of<SensorProvider>(context, listen: false).clearAwaitingConfirmation();
      Navigator.of(context).pop();
    }

    // Attempt to notify backend in the background without blocking the UI Pop
    storage.getToken().then((token) {
      if (token != null) {
        Dio().post(
          '${AppConstants.backendBaseUrl}/api/sensor/cancel',
          options: Options(
            headers: {'Authorization': 'Bearer $token'},
            sendTimeout: const Duration(seconds: 3),
            receiveTimeout: const Duration(seconds: 3),
          ),
        ).catchError((e) {
          debugPrint('Failed to cancel emergency on backend: $e');
        });
      }
    });
  }
  
  void _sendSOSNow() {
    _countdownTimer?.cancel();
    // In a real scenario, this would notify the backend instantly.
    _showDispatchedDialog();
  }

  void _showDispatchedDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Emergency Dispatched', style: TextStyle(color: Colors.redAccent)),
        content: const Text(
          'Emergency contacts have been notified with your live location.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Provider.of<SensorProvider>(context, listen: false).clearAwaitingConfirmation();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Understood', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Container(
             decoration: BoxDecoration(
               color: Colors.redAccent.withOpacity(0.3), 
               borderRadius: BorderRadius.circular(10)
             ),
             child: const Icon(Icons.shield_rounded, color: Colors.redAccent, size: 22),
          ),
        ),
        title: const Text('Rapid Rescue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 10),
                
                // Pulsing Warning Icon
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withOpacity(0.4 * _pulseController.value),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFDC3545),
                        ),
                        child: const Icon(Icons.warning_rounded, color: Colors.white, size: 60),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 24),
                
                const Text(
                  'CRASH DETECTED',
                  style: TextStyle(
                    color: Color(0xFFDC3545),
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                
                const SizedBox(height: 8),
                const Text(
                  'Are you safe?',
                  style: TextStyle(color: Color(0xFF6C757D), fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'We sensed a sudden high-impact event.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                ),
                
                const SizedBox(height: 30),
                
                // Circular Progress Timer
                SizedBox(
                  width: 160,
                  height: 160,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: _secondsRemaining / 20.0,
                        strokeWidth: 15,
                        backgroundColor: const Color(0xFF1E293B), // Dark slate
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFDC3545)), // Red
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$_secondsRemaining',
                            style: TextStyle(
                              color: Colors.grey[300], // Adjust color to be lighter so it's readable
                              fontSize: 56,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            ),
                          ),
                          const Text(
                            'SECONDS',
                            style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                
                const Text(
                  'Contacting emergency services automatically in 20s...',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                ),
                
                const SizedBox(height: 24),
                
                // I'm Safe Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isCancelling ? null : _cancelEmergency,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF28A745), // Green
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _isCancelling 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check_circle_rounded, size: 24),
                    label: const Text(
                      "I'M SAFE",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Send SOS Now Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _sendSOSNow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC3545), // Red
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.sos_rounded, size: 28),
                    label: const Text(
                      "SEND SOS NOW",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Bottom broadcasting info
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.location_on, color: Color(0xFF9CA3AF), size: 16),
                    const SizedBox(width: 8),
                    const Text(
                      'BROADCASTING LOCATION',
                      style: TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                const Text(
                  "If you don't respond, we will automatically share your precise location with emergency responders and your 3 emergency contacts.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                ),
                
                const SizedBox(height: 20),
                
                // GPS Lock banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E1E1E), Color(0xFF2A2A2A)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'ESTABLISHING GPS LOCK...',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
