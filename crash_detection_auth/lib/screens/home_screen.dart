import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';

import '../providers/auth_provider.dart';
import '../providers/sensor_provider.dart';
import '../providers/profile_provider.dart';
import '../screens/sensor_dashboard_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/emergency_contacts_screen.dart';
import '../screens/settings_screen.dart';

/// Root navigation screen holding the bottom NavigationBar and persistent tabs.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const String routeName = '/home';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  VoidCallback? _authListener;

  final List<Widget> _screens = [
    const SensorDashboardScreen(),
    const ProfileScreen(),
    const EmergencyContactsScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAppWideTelemetry();
      _scheduleProfileLoad();
    });
  }

  /// Loads the user profile only AFTER the auth token is confirmed saved.
  /// This avoids the race condition where loadProfile() fires before
  /// AppAuthProvider has written the JWT to SecureStorage.
  void _scheduleProfileLoad() {
    final auth = context.read<AppAuthProvider>();
    final profileProv = context.read<ProfileProvider>();

    if (auth.authState == AuthState.authenticated) {
      // Token is already saved — load immediately.
      profileProv.loadProfile();
      return;
    }

    // Otherwise wait for the authenticated signal.
    _authListener = () {
      if (!mounted) return;
      final a = context.read<AppAuthProvider>();
      if (a.authState == AuthState.authenticated) {
        context.read<ProfileProvider>().loadProfile();
        a.removeListener(_authListener!);
        _authListener = null;
      }
    };
    auth.addListener(_authListener!);
  }

  Future<void> _initializeAppWideTelemetry() async {
    // Ask for location permission on start
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    // Automatically start monitoring telemetry if we have permission
    if (mounted && perm != LocationPermission.denied && perm != LocationPermission.deniedForever) {
      context.read<SensorProvider>().startMonitoring();
    }
    // Profile load is handled by _scheduleProfileLoad() — see initState.
  }

  @override
  void dispose() {
    if (_authListener != null) {
      // Clean up listener if auth never reached authenticated during lifetime.
      try {
        context.read<AppAuthProvider>().removeListener(_authListener!);
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            )
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (idx) => setState(() => _currentIndex = idx),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: const Color(0xFFDC3545), // Red
          unselectedItemColor: const Color(0xFF9CA3AF), // Grey
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.5),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, letterSpacing: 0.5),
          items: const [
            BottomNavigationBarItem(
              icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.home_rounded)), 
              label: 'HOME'
            ),
            BottomNavigationBarItem(
              icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.person_rounded)), 
              label: 'PROFILE'
            ),
            BottomNavigationBarItem(
              icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.contact_mail_rounded)), 
              label: 'CONTACTS'
            ),
            BottomNavigationBarItem(
              icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.settings_rounded)), 
              label: 'SETTINGS'
            ),
          ],
        ),
      ),
    );
  }
}
