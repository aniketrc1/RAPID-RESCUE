import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/user_profile.dart';
import '../providers/profile_provider.dart';

/// Screen to manage emergency contacts.
/// Built as a root tab, interacting directly with ProfileProvider.
class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});
  static const String routeName = '/emergency-contacts';

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  // We keep a local copy for optimistic UI updates before saving
  List<EmergencyContact> _contacts = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Load existing contacts into local state for editing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = context.read<ProfileProvider>().profile;
      if (profile != null) {
        setState(() => _contacts = List.from(profile.emergencyContacts));
      }
    });
  }

  Future<void> _saveToBackend(BuildContext context) async {
    final provider = context.read<ProfileProvider>();
    final currentProfile = provider.profile;
    
    // If no profile exists yet, they need to create one in the Profile tab first.
    if (currentProfile == null) return;

    setState(() => _isSaving = true);
    
    UserProfile updatedProfile = currentProfile.copyWith(
      emergencyContacts: _contacts,
    );

    await provider.saveProfile(updatedProfile);
    if (mounted) setState(() => _isSaving = false);
  }

  void _showAddDialog({int? editIndex}) {
    final nameCtrl = TextEditingController(text: editIndex != null ? _contacts[editIndex].name : '');
    final phoneCtrl = TextEditingController(text: editIndex != null ? _contacts[editIndex].phone : '');
    final relationCtrl = TextEditingController(text: editIndex != null ? _contacts[editIndex].relation : '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          editIndex != null ? 'Edit Contact' : 'Add Emergency Contact',
          style: const TextStyle(color: Color(0xFF1E293B), fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(
                controller: nameCtrl,
                label: 'Name',
                icon: Icons.person_rounded,
                validator: (v) => (v?.trim().isEmpty ?? true) ? 'Name required' : null,
              ),
              const SizedBox(height: 12),
              _dialogField(
                controller: phoneCtrl,
                label: 'Phone',
                icon: Icons.phone_rounded,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s]'))],
                validator: (v) => (v?.trim().isEmpty ?? true) ? 'Phone required' : null,
              ),
              const SizedBox(height: 12),
              _dialogField(
                controller: relationCtrl,
                label: 'Relation (e.g. Sibling, Friend)',
                icon: Icons.group_rounded,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB3BA), // Soft pink
              foregroundColor: const Color(0xFFDC3545), // Deep red text
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final contact = EmergencyContact(
                name: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                relation: relationCtrl.text.trim().toUpperCase(),
              );
              
              setState(() {
                if (editIndex != null) {
                  _contacts[editIndex] = contact;
                } else {
                  _contacts.add(contact);
                }
              });
              Navigator.of(ctx).pop();
              await _saveToBackend(context);
            },
            child: const Text('Save Contact', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen to profile updates (e.g. if loaded late)
    final profile = context.watch<ProfileProvider>().profile;
    // We only refresh the local _contacts array if it hasn't been edited locally, or on first load.
    // Realistically, binding directly to provider state is best for production, 
    // but building the pessimistic UI requires this sync.
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Soft light background
      appBar: AppBar(
        automaticallyImplyLeading: false, // Hidden for bottom tab root
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('Emergency Contacts', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text('Help', style: TextStyle(color: Color(0xFFDC3545))),
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isSaving) const LinearProgressIndicator(color: Color(0xFFDC3545), backgroundColor: Colors.white),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Trusted Circle',
                    style: TextStyle(color: Color(0xFF1E293B), fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'These people will be notified instantly if Rapid Rescue detects a serious impact.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.4),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: _contacts.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: _contacts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _buildContactCard(i),
                    ),
            ),
            
            // Pro Tip Box
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F1), // Soft red background
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFB3BA).withOpacity(0.5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: const Color(0xFFFFB3BA), shape: BoxShape.circle),
                      child: const Icon(Icons.info_outline_rounded, color: Color(0xFFDC3545), size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Pro Tip: Ensure these contacts have "Emergency Bypass" enabled on their phones so they hear your alert even if their phone is on silent.',
                        style: TextStyle(color: Colors.black87, fontSize: 13, fontStyle: FontStyle.italic, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(),
        backgroundColor: const Color(0xFFFFB3BA),
        foregroundColor: Colors.white,
        elevation: 2,
        child: const Icon(Icons.add_rounded, size: 32),
      ),
    );
  }

  Widget _buildContactCard(int index) {
    final c = _contacts[index];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFFFFF0F1),
            child: const Icon(Icons.person_rounded, color: Color(0xFFFFB3BA), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.name,
                  style: const TextStyle(color: Color(0xFF1E293B), fontSize: 16, fontWeight: FontWeight.bold)
                ),
                const SizedBox(height: 4),
                if (c.relation.isNotEmpty)
                  Text(
                    c.relation,
                    style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.phone_rounded, size: 14, color: Colors.grey[800]),
                    const SizedBox(width: 4),
                    Text(
                      c.phone,
                      style: TextStyle(color: Colors.grey[800], fontSize: 13, fontWeight: FontWeight.w500)
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: Color(0xFF4A5568)),
            onPressed: () => _showAddDialog(editIndex: index),
          ),
          IconButton(
            icon: const Icon(Icons.delete_rounded, color: Color(0xFF4A5568)),
            onPressed: () async {
              setState(() => _contacts.removeAt(index));
              await _saveToBackend(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.contacts_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No emergency contacts yet', style: TextStyle(color: Colors.grey[500], fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Tap the + button below to add one', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
        ],
      ),
    );
  }

  Widget _dialogField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(color: Colors.black, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.grey[400], size: 20),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDC3545))),
      ),
    );
  }
}
