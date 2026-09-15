import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'phone_otp_screen.dart';

/// Login screen presenting two sign-in options:
/// 1. Google Sign-In (OAuth)
/// 2. Phone OTP
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const String routeName = '/login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  void initState() {
    super.initState();
    // Attach listener after the first frame so context is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppAuthProvider>().addListener(_onAuthChanged);
    });
  }

  void _onAuthChanged() {
    final auth = context.read<AppAuthProvider>();
    if (auth.authState == AuthState.authenticated && mounted) {
      auth.removeListener(_onAuthChanged);
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  void dispose() {
    try {
      context.read<AppAuthProvider>().removeListener(_onAuthChanged);
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Logo ────────────────────────────────────────────────
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFFEEF0),
                    border: Border.all(
                      color: const Color(0xFFFFB3BA),
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.shield_rounded,
                      size: 64,
                      color: Color(0xFFDC3545),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ── Headline ─────────────────────────────────────────────
                const Text(
                  'RAPID RESCUE',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B),
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your personal safety companion',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 64),

                // ── Error Message ────────────────────────────────────────
                Consumer<AppAuthProvider>(
                  builder: (context, auth, _) {
                    if (auth.errorMessage == null) return const SizedBox.shrink();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE5E5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFFB3BA)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Color(0xFFDC3545), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              auth.errorMessage!,
                              style: const TextStyle(
                                  color: Color(0xFFDC3545), fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => auth.clearError(),
                            child: const Icon(Icons.close,
                                color: Color(0xFFDC3545), size: 18),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // ── Google Sign-In Button ────────────────────────────────
                Consumer<AppAuthProvider>(
                  builder: (context, auth, _) {
                    return _SignInButton(
                      id: 'btn_google_signin',
                      label: 'Continue with Google',
                      isLoading: auth.isLoading,
                      icon: _GoogleIcon(),
                      backgroundColor: Colors.white,
                      textColor: const Color(0xFF1E293B),
                      borderColor: Colors.grey[300],
                      onPressed: auth.isLoading
                          ? null
                          : () => auth.signInWithGoogle(),
                    );
                  },
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: Divider(color: Colors.grey[300], thickness: 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'or',
                        style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: Divider(color: Colors.grey[300], thickness: 1),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Phone OTP Button ─────────────────────────────────────
                Consumer<AppAuthProvider>(
                  builder: (context, auth, _) {
                    return _SignInButton(
                      id: 'btn_phone_signin',
                      label: 'Continue with Phone',
                      isLoading: false,
                      icon: const Icon(Icons.phone_android_rounded,
                          color: Colors.white, size: 22),
                      backgroundColor: const Color(0xFFDC3545),
                      textColor: Colors.white,
                      onPressed: auth.isLoading
                          ? null
                          : () => Navigator.of(context)
                              .pushNamed(PhoneOtpScreen.routeName),
                    );
                  },
                ),

                const SizedBox(height: 56),
                Text(
                  'By signing in you agree to our Terms & Privacy Policy',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// ── Reusable Sign-In Button ───────────────────────────────────────────────────

class _SignInButton extends StatelessWidget {
  const _SignInButton({
    required this.id,
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.backgroundColor,
    required this.textColor,
    required this.onPressed,
    this.borderColor,
  });

  final String id;
  final String label;
  final Widget icon;
  final bool isLoading;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        key: Key(id),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: borderColor != null
                ? BorderSide(color: borderColor!)
                : BorderSide.none,
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: textColor,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Google 'G' Icon (painted, no asset needed) ────────────────────────────────

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 22,
      height: 22,
      child: _GoogleIconPainter(),
    );
  }
}

class _GoogleIconPainter extends StatelessWidget {
  const _GoogleIconPainter();

  @override
  Widget build(BuildContext context) {
    // Google 'G' using colored text — no SVG asset needed.
    return const Text(
      'G',
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Color(0xFF4285F4),
      ),
    );
  }
}
