import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sensor_provider.dart';
import 'emergency_countdown_screen.dart';

/// The 'Home' tab of the application displaying the active crash detection status.
class SensorDashboardScreen extends StatefulWidget {
  const SensorDashboardScreen({super.key});
  static const String routeName = '/sensor-dashboard';

  @override
  State<SensorDashboardScreen> createState() => _SensorDashboardScreenState();
}

class _SensorDashboardScreenState extends State<SensorDashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _isRoutingToEmergency = false;
  late AnimationController _pulseController;
  late SensorProvider _sensorProvider;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);

    _sensorProvider = context.read<SensorProvider>();
    _sensorProvider.addListener(_onSensorStateChanged);
  }

  void _onSensorStateChanged() {
    if (!mounted) return;
    
    if (_sensorProvider.isAwaitingConfirmation && !_isRoutingToEmergency) {
      _isRoutingToEmergency = true;
      Navigator.of(context).pushNamed(EmergencyCountdownScreen.routeName).then((_) {
        if (mounted) {
          _isRoutingToEmergency = false;
          _sensorProvider.clearAwaitingConfirmation();
        }
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _sensorProvider.removeListener(_onSensorStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SensorProvider>(
      builder: (context, sensor, _) {
        final f = sensor.latest;
        final isMonitoring = sensor.isMonitoring;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: _buildAppBar(isMonitoring),
          body: Stack(
            children: [
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'SYSTEM STATUS',
                        style: TextStyle(
                            color: Color(0xFF6C757D),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isMonitoring ? 'SYSTEM ACTIVE' : 'SYSTEM OFFLINE',
                        style: const TextStyle(
                            color: Color(0xFF1E293B),
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Radar Pulse Circle
                      _buildRadarScanner(isMonitoring),
                      
                      const SizedBox(height: 50),
                      
                      // Current Speed Card
                      _buildSpeedCard(f?.speed ?? 0.0),
                      
                      const SizedBox(height: 16),
                      
                      // Metrics Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildSmallCard(
                              icon: Icons.check_circle_rounded,
                              iconColor: const Color(0xFF28A745), // Green
                              title: 'LAST SCAN',
                              value: 'No crash\ndetected',
                              subtitle: 'Live actively',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildSmallCard(
                              icon: Icons.location_on_rounded,
                              iconColor: const Color(0xFFDC3545), // Red
                              title: 'LOCATION',
                              value: f != null ? '${f.lat.toStringAsFixed(3)}, ${f.lng.toStringAsFixed(3)}' : 'Acquiring...',
                              subtitle: f != null ? 'GPS Lock Active' : 'Waiting for GPS',
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 80), // Padding for fab
                    ],
                  ),
                ),
              ),
              
              // SOS Floating Button
              Positioned(
                bottom: 24,
                right: 24,
                child: GestureDetector(
                  onTap: () {
                    // Inject a fake massive crash to test the emergency flow
                    sensor.simulateCrash();
                  },
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC3545),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFDC3545).withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 5,
                          offset: const Offset(0, 8),
                        )
                      ]
                    ),
                    child: const Center(
                      child: Text('SOS', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(bool isMonitoring) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.white,
      elevation: 0,
      title: Row(
        children: [
          const Icon(Icons.shield_rounded, color: Color(0xFFDC3545), size: 24),
          const SizedBox(width: 8),
          const Text('RAPID RESCUE', style: TextStyle(color: Color(0xFFDC3545), fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.2)),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isMonitoring ? const Color(0xFF28A745).withOpacity(0.15) : Colors.grey.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  color: isMonitoring ? const Color(0xFF28A745) : Colors.grey[500],
                  shape: BoxShape.circle
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isMonitoring ? 'SAFE' : 'IDLE', 
                style: TextStyle(
                  color: isMonitoring ? const Color(0xFF28A745) : Colors.grey[600], 
                  fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1
                )
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.notifications_rounded, color: Color(0xFF1E293B)),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildRadarScanner(bool isMonitoring) {
    final Color ringColor = isMonitoring ? const Color(0xFFDC3545) : Colors.grey;
    
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer pulsing ring
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ringColor.withOpacity(0.1 * (1.0 - _pulseController.value)), width: 2),
              ),
            );
          },
        ),
        // Middle ring
        Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ringColor.withOpacity(0.05),
          ),
        ),
        // Inner Solid Circle
        Container(
          width: 210,
          height: 210,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ringColor.withOpacity(isMonitoring ? 0.75 : 0.4),
            boxShadow: [
              BoxShadow(
                color: ringColor.withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 5,
              )
            ]
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.radar_rounded, color: Colors.white, size: 40),
              const SizedBox(height: 12),
              const Text(
                'Monitoring your\nsafety',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, height: 1.2),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20)
                ),
                child: Text(
                  isMonitoring ? 'ACTIVE' : 'OFFLINE',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2),
                ),
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildSpeedCard(double speedMps) {
    final int kmh = (speedMps * 3.6).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CURRENT SPEED',
                style: TextStyle(color: Color(0xFF6C757D), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$kmh',
                    style: const TextStyle(color: Color(0xFF1E293B), fontSize: 42, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'KM/H',
                    style: TextStyle(color: Color(0xFF1E293B), fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFDC3545).withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.speed_rounded, color: Color(0xFFDC3545), size: 32),
          )
        ],
      ),
    );
  }

  Widget _buildSmallCard({required IconData icon, required Color iconColor, required String title, required String value, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              shape: BoxShape.circle
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(color: Color(0xFF6C757D), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(color: Color(0xFF1E293B), fontSize: 14, fontWeight: FontWeight.w800, height: 1.3),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF6C757D), fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
