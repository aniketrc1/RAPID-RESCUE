import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import 'package:country_code_picker/country_code_picker.dart';

import '../providers/auth_provider.dart';
import '../core/constants/app_constants.dart';

/// Two-step screen for Phone OTP authentication.
///
/// Step 1: User enters phone number with country code → sends OTP.
/// Step 2: User enters 6-digit OTP → verifies and signs in.
class PhoneOtpScreen extends StatefulWidget {
  const PhoneOtpScreen({super.key});

  static const String routeName = '/phone-otp';

  @override
  State<PhoneOtpScreen> createState() => _PhoneOtpScreenState();
}

class _PhoneOtpScreenState extends State<PhoneOtpScreen> {
  // ── State ─────────────────────────────────────────────────────────────────
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();

  String _countryCode = '+91'; // India default
  bool _otpSent = false;
  String? _verificationId;
  int? _resendToken;

  int _resendCountdown = 0;
  Timer? _resendTimer;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Listen for auth state → navigate as soon as authenticated.
    // Using addPostFrameCallback so context is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppAuthProvider>().addListener(_onAuthChanged);
    });
  }

  void _onAuthChanged() {
    final auth = context.read<AppAuthProvider>();
    if (auth.authState == AuthState.authenticated && mounted) {
      // Remove listener before navigating to avoid calling it on a disposed widget
      auth.removeListener(_onAuthChanged);
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  void dispose() {
    // Safely remove listener if screen is disposed before auth completes
    try {
      context.read<AppAuthProvider>().removeListener(_onAuthChanged);
    } catch (_) {}
    _phoneController.dispose();
    _otpController.dispose();
    _otpFocusNode.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  // ── Logic ─────────────────────────────────────────────────────────────────

  String get _fullPhoneNumber =>
      '$_countryCode${_phoneController.text.trim()}';

  void _startResendTimer() {
    setState(() => _resendCountdown = AppConstants.otpResendCooldownSeconds);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCountdown <= 1) {
        t.cancel();
        setState(() => _resendCountdown = 0);
      } else {
        setState(() => _resendCountdown--);
      }
    });
  }

  Future<void> _sendOtp({bool resend = false}) async {
    final phoneRaw = _phoneController.text.trim();
    final digitsOnly = phoneRaw.replaceAll(RegExp(r'\D'), '');
    
    if (digitsOnly.length != 10) {
      _showSnack('Phone number must be exactly 10 digits.');
      return;
    }

    final auth = context.read<AppAuthProvider>();
    await auth.sendPhoneOtp(
      phoneNumber: _fullPhoneNumber,
      resendToken: resend ? _resendToken : null,
      onCodeSent: (id, resendTok) {
        setState(() {
          _verificationId = id;
          _resendToken = resendTok;
          _otpSent = true;
        });
        _startResendTimer();
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _otpFocusNode.requestFocus(),
        );
        _showSnack('OTP sent to $_fullPhoneNumber');
      },
      onAutoVerified: (_) {
        Navigator.of(context).pushReplacementNamed('/home');
      },
    );
  }

  Future<void> _verifyOtp(String otp) async {
    if (_verificationId == null) return;
    final auth = context.read<AppAuthProvider>();
    await auth.verifyPhoneOtp(
      verificationId: _verificationId!,
      smsCode: otp,
    );
    // Navigation is handled by _onAuthChanged listener — no need to check here.
    // If there's an error it will be shown via auth.errorMessage.
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
          child: Column(
            children: [
              // ── App Bar ──────────────────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Color(0xFF1E293B)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Text(
                      _otpSent ? 'Enter OTP' : 'Phone Sign-In',
                      style: const TextStyle(
                        color: Color(0xFF1E293B),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: _otpSent
                        ? _buildOtpStep(key: const ValueKey('otp'))
                        : _buildPhoneStep(key: const ValueKey('phone')),
                  ),
                ),
              ),
            ],
          ),
      ),
    );
  }

  // ── Step 1: Phone Number ──────────────────────────────────────────────────

  Widget _buildPhoneStep({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Icon(Icons.phone_android_rounded, color: Color(0xFFDC3545), size: 52),
        const SizedBox(height: 24),
        const Text(
          'What\'s your phone number?',
          style: TextStyle(
              color: Color(0xFF1E293B), fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'We\'ll send a one-time code to verify your identity.',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        const SizedBox(height: 40),

        // Phone input with country code picker
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: Colors.grey[300]!, width: 1.5),
          ),
          child: Row(
            children: [
              CountryCodePicker(
                onChanged: (c) =>
                    setState(() => _countryCode = c.dialCode ?? '+91'),
                initialSelection: 'IN',
                favorite: const ['+91', 'IN', '+1', 'US'],
                showCountryOnly: false,
                showOnlyCountryWhenClosed: false,
                alignLeft: false,
                textStyle: const TextStyle(color: Color(0xFF1E293B), fontSize: 15, fontWeight: FontWeight.w600),
                dialogBackgroundColor: Colors.white,
                searchDecoration: InputDecoration(
                  hintText: 'Search country',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[200]!)),
                ),
              ),
              Container(
                  width: 1,
                  height: 30,
                  color: Colors.grey[300]),
              Expanded(
                child: TextField(
                  key: const Key('phone_input'),
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: Color(0xFF1E293B), fontSize: 16, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: '9876543210',
                    hintStyle:
                        TextStyle(color: Colors.grey[400]),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Error display
        Consumer<AppAuthProvider>(
          builder: (context, auth, _) {
            if (auth.errorMessage == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                auth.errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            );
          },
        ),

        const SizedBox(height: 8),
        Consumer<AppAuthProvider>(
          builder: (context, auth, _) {
            return SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                key: const Key('btn_send_otp'),
                onPressed: auth.isLoading ? null : () => _sendOtp(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC3545),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: auth.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('Send OTP',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            );
          },
        ),
      ],
    );
  }

  // ── Step 2: OTP Verification ──────────────────────────────────────────────

  Widget _buildOtpStep({Key? key}) {
    final defaultPinTheme = PinTheme(
      width: 52,
      height: 60,
      textStyle: const TextStyle(
        fontSize: 22,
        color: Color(0xFF1E293B),
        fontWeight: FontWeight.w800,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1.5),
      ),
    );

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Icon(Icons.sms_rounded, color: Color(0xFFDC3545), size: 52),
        const SizedBox(height: 24),
        const Text(
          'Enter the OTP',
          style: TextStyle(
              color: Color(0xFF1E293B), fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'We sent a 6-digit code to $_fullPhoneNumber',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        const SizedBox(height: 40),

        // OTP input
        Center(
          child: Pinput(
            key: const Key('otp_input'),
            controller: _otpController,
            focusNode: _otpFocusNode,
            length: AppConstants.otpLength,
            defaultPinTheme: defaultPinTheme,
            focusedPinTheme: defaultPinTheme.copyWith(
              decoration: defaultPinTheme.decoration!.copyWith(
                border: Border.all(color: const Color(0xFFDC3545), width: 2),
              ),
            ),
            errorPinTheme: defaultPinTheme.copyWith(
              decoration: defaultPinTheme.decoration!.copyWith(
                border: Border.all(color: Colors.redAccent, width: 2),
              ),
            ),
            onCompleted: _verifyOtp,
          ),
        ),

        const SizedBox(height: 20),

        // Error display
        Consumer<AppAuthProvider>(
          builder: (context, auth, _) {
            if (auth.errorMessage == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                auth.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            );
          },
        ),

        const SizedBox(height: 12),

        Consumer<AppAuthProvider>(
          builder: (context, auth, _) {
            return SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                key: const Key('btn_verify_otp'),
                onPressed: auth.isLoading
                    ? null
                    : () => _verifyOtp(_otpController.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC3545),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: auth.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('Verify OTP',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            );
          },
        ),

        const SizedBox(height: 24),

        // Resend
        Center(
          child: _resendCountdown > 0
              ? Text(
                  'Resend OTP in $_resendCountdown s',
                  style: TextStyle(
                      color: Colors.grey[500], fontSize: 14, fontWeight: FontWeight.bold),
                )
              : TextButton(
                  key: const Key('btn_resend_otp'),
                  onPressed: () => _sendOtp(resend: true),
                  child: const Text(
                    'Resend OTP',
                    style: TextStyle(
                      color: Color(0xFFDC3545),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
        ),

        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () {
              setState(() {
                _otpSent = false;
                _otpController.clear();
                _resendTimer?.cancel();
                _resendCountdown = 0;
              });
            },
            child: Text(
              'Change phone number',
              style: TextStyle(
                  color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
