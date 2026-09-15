import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/user_profile.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';

/// The 'Profile' tab, matching the Create Profile mockup.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  static const String routeName = '/profile';

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  String _gender = UserProfile.genderOptions.first;
  String _bloodGroup = UserProfile.bloodGroupOptions.first;

  bool _isEditing = false; // Prevents network fetch from overwriting active user input

  // Snapshot of the last-saved / last-fetched values, used to detect changes.
  String _origName = '';
  String _origAge = '';
  String _origPhone = '';
  String _origGender = UserProfile.genderOptions.first;
  String _origBloodGroup = UserProfile.bloodGroupOptions.first;

  /// Returns true only when at least one field differs from the last saved state.
  bool get _hasChanges =>
      _nameCtrl.text.trim() != _origName ||
      _ageCtrl.text.trim() != _origAge ||
      _phoneCtrl.text.trim() != _origPhone ||
      _gender != _origGender ||
      _bloodGroup != _origBloodGroup;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AppAuthProvider>();
      final profileProvider = context.read<ProfileProvider>();

      // Programmatic pre-fill BEFORE adding dirty-tracking listeners,
      // so these assignments don't set _isEditing = true.
      if (profileProvider.profile == null && auth.currentUser?.phoneNumber != null) {
        _phoneCtrl.text = auth.currentUser!.phoneNumber!;
      } else if (profileProvider.profile == null) {
        _phoneCtrl.text = '+91 ';
      }

      // Only NOW attach dirty-tracking — any further user edits will lock the form
      // AND trigger a rebuild so the save button reacts immediately.
      void markDirty() {
        _isEditing = true;
        if (mounted) setState(() {});
      }
      _nameCtrl.addListener(markDirty);
      _ageCtrl.addListener(markDirty);
      _phoneCtrl.addListener(markDirty);

      // Listen for network load completion
      profileProvider.addListener(_onProfileUpdated);
      // Trigger an immediate check in case profile is already loaded
      _onProfileUpdated();
    });
  }

  void _onProfileUpdated() {
    if (!mounted || _isEditing) return; // Don't wipe form if user started typing
    final profile = context.read<ProfileProvider>().profile;
    // Fill whenever a profile arrives — the _isEditing guard above is
    // sufficient to protect against overwriting active user input.
    if (profile != null) {
      _fillForm(profile);
    }
  }

  void _fillForm(UserProfile p) {
    _nameCtrl.text = p.name;
    _ageCtrl.text = p.age.toString();
    _phoneCtrl.text = p.phoneNumber;
    _gender = UserProfile.genderOptions.contains(p.gender)
        ? p.gender
        : UserProfile.genderOptions.first;
    _bloodGroup = UserProfile.bloodGroupOptions.contains(p.bloodGroup)
        ? p.bloodGroup
        : UserProfile.bloodGroupOptions.first;
    // Snapshot the freshly loaded values so _hasChanges starts false.
    _origName = _nameCtrl.text.trim();
    _origAge = _ageCtrl.text.trim();
    _origPhone = _phoneCtrl.text.trim();
    _origGender = _gender;
    _origBloodGroup = _bloodGroup;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    context.read<ProfileProvider>().removeListener(_onProfileUpdated);
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_hasChanges) return; // Nothing changed — skip the network call.

    final provider = context.read<ProfileProvider>();
    final uid = provider.profile?.uid ?? '';

    // Preserve existing emergency contacts since they are edited on another tab
    final existingContacts = provider.profile?.emergencyContacts ?? [];

    final profile = UserProfile(
      uid: uid,
      name: _nameCtrl.text.trim(),
      age: int.parse(_ageCtrl.text.trim()),
      gender: _gender,
      bloodGroup: _bloodGroup,
      phoneNumber: _phoneCtrl.text.trim(),
      emergencyContacts: existingContacts,
    );

    final success = await provider.saveProfile(profile);
    if (!mounted) return;

    if (success) {
      // Reflect the server-confirmed values immediately and reset dirty state.
      final saved = provider.profile;
      if (saved != null) {
        _isEditing = false; // Allow _fillForm to run without the guard.
        _fillForm(saved);   // Updates form + resets _orig* snapshot.
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Profile updated successfully!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Color(0xFF28A745),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(color: Color(0xFF1E293B), fontSize: 20, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF1E293B)),
            onPressed: () {},
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Icon Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.badge_rounded, color: Color(0xFFFFB3BA), size: 36),
                ),
                
                const SizedBox(height: 24),
                
                const Text(
                  'Personal Information',
                  style: TextStyle(color: Color(0xFF1E293B), fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  'Provide your medical and contact details to help us protect you in an emergency. This data is stored securely.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.5),
                ),
                
                const SizedBox(height: 32),
                
                // Form Fields
                _buildField(
                  key: const Key('field_name'),
                  controller: _nameCtrl,
                  title: 'FULL NAME',
                  label: 'John Doe',
                  icon: Icons.person_rounded,
                  validator: (v) => (v?.trim().isEmpty ?? true) ? 'Name required' : null,
                ),
                
                const SizedBox(height: 20),
                
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 1,
                      child: _buildField(
                        key: const Key('field_age'),
                        controller: _ageCtrl,
                        title: 'AGE',
                        label: '25',
                        icon: Icons.calendar_today_rounded,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          if (n == null || n < 0 || n > 120) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: _buildDropdown(
                        key: const Key('field_gender'),
                        title: 'GENDER',
                        icon: Icons.people_rounded,
                        value: _gender,
                        items: UserProfile.genderOptions,
                        onChanged: (v) => setState(() => _gender = v!),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildDropdown(
                        key: const Key('field_blood'),
                        title: 'BLOOD',
                        icon: Icons.water_drop_rounded,
                        value: _bloodGroup,
                        items: UserProfile.bloodGroupOptions,
                        onChanged: (v) => setState(() => _bloodGroup = v!),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 5,
                      child: _buildField(
                        key: const Key('field_phone'),
                        controller: _phoneCtrl,
                        title: 'PHONE NUMBER',
                        label: '+91 XXXXXXXXXX',
                        icon: Icons.call_rounded,
                        keyboardType: TextInputType.phone,
                        validator: (v) {
                           if (v == null || v.trim().isEmpty) return 'Required';
                           final phoneRegex = RegExp(r'^\+91\s?\d{10}$');
                           if (!phoneRegex.hasMatch(v.replaceAll(RegExp(r'[-\s]'), ''))) {
                             return 'Must be +91 and 10 digits';
                           }
                           return null;
                        },
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 48),
                
                // Error display
                Consumer<ProfileProvider>(
                  builder: (_, p, __) {
                    if (p.errorMessage == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Text(
                        p.errorMessage!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
                
                // Save / Update Button
                Consumer<ProfileProvider>(
                  builder: (_, p, __) {
                    final canSave = !p.isLoading && _hasChanges;
                    return SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        key: const Key('btn_save_profile'),
                        onPressed: canSave ? _save : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: canSave
                              ? const Color(0xFFDC3545)
                              : Colors.grey,
                          side: BorderSide(
                            color: canSave
                                ? const Color(0xFFDC3545).withAlpha(180)
                                : Colors.grey.shade300,
                            width: 1.5,
                          ),
                          backgroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: p.isLoading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFDC3545)))
                            : Icon(Icons.save_rounded, size: 20, color: canSave ? const Color(0xFFDC3545) : Colors.grey),
                        label: Text(
                          p.isLoading
                              ? (p.hasProfile ? 'Updating...' : 'Saving...')
                              : (p.hasProfile ? 'Update Profile' : 'Save Profile'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: canSave ? const Color(0xFFDC3545) : Colors.grey,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 24),
                
                const Center(
                  child: Text(
                    'SECURED BY RAPID RESCUE END-TO-END ENCRYPTION',
                    style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required Key key,
    required TextEditingController controller,
    required String title,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: key,
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: const TextStyle(color: Color(0xFF1E293B), fontSize: 16, fontWeight: FontWeight.w600),
          validator: validator,
          decoration: _inputDecoration(label, icon),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required Key key,
    required String title,
    required IconData icon,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: key,
          value: value,
          onChanged: onChanged,
          isExpanded: true,
          dropdownColor: Colors.white,
          style: const TextStyle(color: Color(0xFF1E293B), fontSize: 16, fontWeight: FontWeight.w600),
          decoration: _inputDecoration('', null),
          items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint, IconData? icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.normal),
      prefixIcon: icon != null ? Icon(icon, color: const Color(0xFFFFB3BA), size: 22) : null,
      filled: true,
      fillColor: const Color(0xFFFAFAFA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDC3545), width: 1.5),
      ),
      errorStyle: const TextStyle(color: Colors.redAccent),
    );
  }
}
