import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/guardian_service.dart';
import '../models/guardian_model.dart';
import '../relationships/services/relationship_service.dart';
import '../relationships/models/relationship_model.dart';

class GuardiansScreen extends StatefulWidget {
  const GuardiansScreen({super.key});

  @override
  State<GuardiansScreen> createState() => _GuardiansScreenState();
}

class _GuardiansScreenState extends State<GuardiansScreen> {
  List<GuardianModel> _guardians = [];
  List<RelationshipModel> _relationships = [];
  String? _pendingInviteCode;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGuardians();
  }

  Future<void> _loadGuardians() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }
    
    // Load legacy guardians
    final guardians = await GuardianService.instance.getGuardians(uid);
    
    // Load relationships and pending invite code from RelationshipService
    final relResult = await RelationshipService.instance.getRelationshipsForUser(uid);
    List<RelationshipModel> relationships = [];
    String? pendingCode;
    
    if (relResult.success && relResult.data != null) {
      // Filter to relationships where current user is the patient
      relationships = relResult.data!.where((r) => r.patientId == uid).toList();
      
      // Find pending invite code
      final pending = relationships.where(
        (r) => r.status == RelationshipStatus.pending && r.caregiverId == null
      ).toList();
      
      if (pending.isNotEmpty) {
        pendingCode = pending.first.inviteCode;
      }
    }
    
    setState(() {
      _guardians = guardians;
      _relationships = relationships;
      _pendingInviteCode = pendingCode;
      _isLoading = false;
    });
  }

  Future<void> _saveGuardian(GuardianModel guardian) async {
    await GuardianService.instance.saveGuardian(guardian);
    await _loadGuardians();
  }

  Future<void> _deleteGuardian(String guardianId) async {
    await GuardianService.instance.deleteGuardian(guardianId);
    await _loadGuardians();
  }

  Future<void> _setPrimaryGuardian(String guardianId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    await GuardianService.instance.setPrimary(uid, guardianId);
    await _loadGuardians();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : const Color(0xFFF2F2F7),
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            backgroundColor: isDarkMode ? Colors.black : const Color(0xFFF2F2F7),
            title: Text(
              'My Guardians',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: isDarkMode ? Colors.white : Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(CupertinoIcons.add_circled, size: 28),
                color: const Color(0xFF007AFF),
                onPressed: _showAddGuardianDialog,
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // === INVITE CODE CARD ===
                  if (_pendingInviteCode != null) ...[
                    Text(
                      'INVITE CODE',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF007AFF).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Share this code with your caregiver:',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _pendingInviteCode!,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 4,
                                  color: Color(0xFF007AFF),
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(Icons.copy, color: Color(0xFF007AFF)),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: _pendingInviteCode!));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Invite code copied to clipboard'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your caregiver enters this code to connect with you',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  // === ACTIVE CAREGIVERS FROM RELATIONSHIPS ===
                  if (_relationships.any((r) => r.status == RelationshipStatus.active && r.caregiverId != null)) ...[
                    Text(
                      'CONNECTED CAREGIVERS',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          for (final rel in _relationships.where((r) => r.status == RelationshipStatus.active && r.caregiverId != null))
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF34C759),
                                child: const Icon(Icons.person, color: Colors.white),
                              ),
                              title: Text(
                                'Connected Caregiver',
                                style: TextStyle(
                                  color: isDarkMode ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                rel.permissions.contains('chat') ? 'Can chat and view your health data' : 'View-only access',
                                style: TextStyle(
                                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                              trailing: Icon(
                                Icons.check_circle,
                                color: const Color(0xFF34C759),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  // === LEGACY GUARDIANS ===
                  Text(
                    'ACTIVE GUARDIANS',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_isLoading)
                    const Center(child: CupertinoActivityIndicator())
                  else if (_guardians.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          'No guardians added yet.\nTap + to add a guardian.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          for (int i = 0; i < _guardians.length; i++) ...[
                            if (i > 0)
                              Divider(
                                height: 1,
                                indent: 60,
                                color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                              ),
                            _buildGuardianTile(_guardians[i], isDarkMode),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    'Guardians receive alerts when you need help or when health anomalies are detected.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuardianTile(GuardianModel guardian, bool isDarkMode) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: guardian.isPrimary 
            ? Colors.green.withOpacity(0.1)
            : const Color(0xFF007AFF).withOpacity(0.1),
        child: Text(
          guardian.name.isNotEmpty ? guardian.name[0] : '?',
          style: TextStyle(
            color: guardian.isPrimary ? Colors.green : const Color(0xFF007AFF),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      title: Row(
        children: [
          Text(
            guardian.name,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          if (guardian.isPrimary) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Primary',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        guardian.email ?? guardian.phoneNumber,
        style: TextStyle(
          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (guardian.status == GuardianStatus.pending)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Pending',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else
            const Icon(CupertinoIcons.chevron_forward, size: 20, color: Colors.grey),
        ],
      ),
      onTap: () {
        HapticFeedback.selectionClick();
        _showGuardianOptions(guardian, isDarkMode);
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _showDeleteConfirmation(guardian, isDarkMode);
      },
    );
  }

  void _showGuardianOptions(GuardianModel guardian, bool isDarkMode) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(guardian.name),
        actions: [
          if (!guardian.isPrimary)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                // Issue #15: Add confirmation for primary change
                _showSetPrimaryConfirmation(guardian);
              },
              child: const Text('Set as Primary'),
            ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              // Edit functionality
              _showEditGuardianDialog(guardian);
            },
            child: const Text('Edit'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _showDeleteConfirmation(guardian, isDarkMode);
            },
            child: const Text('Delete'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
  
  /// Issue #15: Confirmation dialog for setting new primary guardian
  void _showSetPrimaryConfirmation(GuardianModel guardian) {
    // Find current primary guardian
    final currentPrimary = _guardians.where((g) => g.isPrimary).firstOrNull;
    
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Change Primary Guardian'),
        content: Text(
          currentPrimary != null
              ? 'This will change your primary guardian from ${currentPrimary.name} to ${guardian.name}. '
                '${guardian.name} will receive priority alerts and be your main emergency contact.'
              : '${guardian.name} will become your primary guardian and receive priority alerts.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(context);
              _setPrimaryGuardian(guardian.id);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(GuardianModel guardian, bool isDarkMode) {
    // Issue #21: Enhanced warning for primary guardian deletion
    final isPrimary = guardian.isPrimary;
    final isOnlyGuardian = _guardians.length == 1;
    
    String title = 'Delete Guardian';
    String message = 'Are you sure you want to remove ${guardian.name}?';
    
    if (isPrimary && isOnlyGuardian) {
      title = '⚠️ Warning: Last Guardian';
      message = 'Removing ${guardian.name} will leave you without any guardians. '
          'You won\'t receive emergency support until you add a new guardian. '
          'Are you sure you want to continue?';
    } else if (isPrimary) {
      title = '⚠️ Removing Primary Guardian';
      message = '${guardian.name} is your primary guardian. '
          'After removal, you\'ll need to set a new primary guardian. '
          'Are you sure you want to continue?';
    }
    
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              await _deleteGuardian(guardian.id);
              
              // If deleted primary and others exist, prompt to set new primary
              if (isPrimary && !isOnlyGuardian && mounted) {
                final remaining = _guardians.where((g) => g.id != guardian.id).toList();
                if (remaining.isNotEmpty && !remaining.any((g) => g.isPrimary)) {
                  _promptSetNewPrimary(remaining);
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
  
  /// Issue #21: Prompt to set new primary after deleting primary guardian
  void _promptSetNewPrimary(List<GuardianModel> guardians) {
    if (guardians.isEmpty) return;
    
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Set New Primary'),
        content: const Text(
          'You need a primary guardian for emergency alerts. '
          'Would you like to set one now?',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(context);
              if (guardians.length == 1) {
                _setPrimaryGuardian(guardians.first.id);
              } else {
                _showSelectPrimaryDialog(guardians);
              }
            },
            child: const Text('Set Now'),
          ),
        ],
      ),
    );
  }
  
  void _showSelectPrimaryDialog(List<GuardianModel> guardians) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Select New Primary Guardian'),
        actions: guardians.map((g) => CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context);
            _setPrimaryGuardian(g.id);
          },
          child: Text(g.name),
        )).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showAddGuardianDialog() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    String selectedRelation = 'Family';
    String? phoneError;
    
    showCupertinoDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => CupertinoAlertDialog(
          title: const Text('Add Guardian'),
          content: Column(
            children: [
              const SizedBox(height: 16),
              CupertinoTextField(
                controller: nameController,
                placeholder: 'Name',
                padding: const EdgeInsets.all(12),
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CupertinoTextField(
                    controller: phoneController,
                    placeholder: 'Phone Number',
                    keyboardType: TextInputType.phone,
                    padding: const EdgeInsets.all(12),
                    onChanged: (value) {
                      setDialogState(() {
                        phoneError = _validatePhoneNumber(value);
                      });
                    },
                  ),
                  if (phoneError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: Text(
                        phoneError!,
                        style: const TextStyle(
                          color: CupertinoColors.destructiveRed,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: emailController,
                placeholder: 'Email (optional)',
                keyboardType: TextInputType.emailAddress,
                padding: const EdgeInsets.all(12),
              ),
              const SizedBox(height: 12),
              CupertinoSlidingSegmentedControl<String>(
                groupValue: selectedRelation,
                children: const {
                  'Family': Text('Family', style: TextStyle(fontSize: 11)),
                  'Spouse': Text('Spouse', style: TextStyle(fontSize: 11)),
                  'Friend': Text('Friend', style: TextStyle(fontSize: 11)),
                },
                onValueChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedRelation = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                final phone = phoneController.text.trim();
                final validationError = _validatePhoneNumber(phone);
                
                if (nameController.text.trim().isEmpty) return;
                
                if (validationError != null) {
                  setDialogState(() => phoneError = validationError);
                  return;
                }
                
                Navigator.pop(context);
                _saveGuardian(GuardianModel.create(
                  patientId: uid,
                  name: nameController.text.trim(),
                  relation: selectedRelation,
                  phoneNumber: phone,
                  email: emailController.text.isNotEmpty ? emailController.text.trim() : null,
                ));
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Issue #24: Edit guardian dialog
  void _showEditGuardianDialog(GuardianModel guardian) {
    final nameController = TextEditingController(text: guardian.name);
    final phoneController = TextEditingController(text: guardian.phoneNumber);
    final emailController = TextEditingController(text: guardian.email ?? '');
    String selectedRelation = guardian.relation;
    String? phoneError;
    
    showCupertinoDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => CupertinoAlertDialog(
          title: const Text('Edit Guardian'),
          content: Column(
            children: [
              const SizedBox(height: 16),
              CupertinoTextField(
                controller: nameController,
                placeholder: 'Name',
                padding: const EdgeInsets.all(12),
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CupertinoTextField(
                    controller: phoneController,
                    placeholder: 'Phone Number',
                    keyboardType: TextInputType.phone,
                    padding: const EdgeInsets.all(12),
                    onChanged: (value) {
                      setDialogState(() {
                        phoneError = _validatePhoneNumber(value);
                      });
                    },
                  ),
                  if (phoneError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: Text(
                        phoneError!,
                        style: const TextStyle(
                          color: CupertinoColors.destructiveRed,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: emailController,
                placeholder: 'Email (optional)',
                keyboardType: TextInputType.emailAddress,
                padding: const EdgeInsets.all(12),
              ),
              const SizedBox(height: 12),
              CupertinoSlidingSegmentedControl<String>(
                groupValue: selectedRelation,
                children: const {
                  'Family': Text('Family', style: TextStyle(fontSize: 11)),
                  'Spouse': Text('Spouse', style: TextStyle(fontSize: 11)),
                  'Friend': Text('Friend', style: TextStyle(fontSize: 11)),
                },
                onValueChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedRelation = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                final phone = phoneController.text.trim();
                final validationError = _validatePhoneNumber(phone);
                
                if (nameController.text.trim().isEmpty) return;
                
                if (validationError != null) {
                  setDialogState(() => phoneError = validationError);
                  return;
                }
                
                Navigator.pop(context);
                _saveGuardian(guardian.copyWith(
                  name: nameController.text.trim(),
                  relation: selectedRelation,
                  phoneNumber: phone,
                  email: emailController.text.isNotEmpty ? emailController.text.trim() : null,
                ));
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Phone number validation helper (shared with emergency contacts)
  String? _validatePhoneNumber(String phone) {
    if (phone.isEmpty) {
      return 'Phone number is required';
    }
    
    final digitsOnly = phone.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    
    if (digitsOnly.length < 10) {
      return 'Phone number too short (min 10 digits)';
    }
    
    if (digitsOnly.length > 15) {
      return 'Phone number too long (max 15 digits)';
    }
    
    if (!RegExp(r'^[0-9]+$').hasMatch(digitsOnly)) {
      return 'Phone number contains invalid characters';
    }
    
    return null;
  }
}
