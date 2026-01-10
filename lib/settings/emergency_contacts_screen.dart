import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/emergency_contact_service.dart';
import '../models/emergency_contact_model.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  List<EmergencyContactModel> _contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }
    
    final contacts = await EmergencyContactService.instance.getContacts(uid);
    setState(() {
      _contacts = contacts;
      _isLoading = false;
    });
  }

  Future<void> _saveContact(EmergencyContactModel contact) async {
    await EmergencyContactService.instance.saveContact(contact);
    await _loadContacts();
  }

  Future<void> _deleteContact(String contactId) async {
    await EmergencyContactService.instance.deleteContact(contactId);
    await _loadContacts();
  }

  Future<void> _reorderContacts(int oldIndex, int newIndex) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _contacts.removeAt(oldIndex);
    _contacts.insert(newIndex, item);
    
    // Update priorities
    final reorderedIds = _contacts.map((c) => c.id).toList();
    await EmergencyContactService.instance.reorderContacts(uid, reorderedIds);
    
    setState(() {});
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
              'Emergency Contacts',
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
                icon: const Icon(CupertinoIcons.add, size: 28),
                color: const Color(0xFF007AFF),
                onPressed: _showAddContactDialog,
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'These contacts will be notified immediately when an SOS is triggered. Drag to reorder priority.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
          ),
          if (_isLoading)
            const SliverToBoxAdapter(
              child: Center(child: CupertinoActivityIndicator()),
            )
          else if (_contacts.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      'No emergency contacts added yet.\nTap + to add a contact.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              sliver: SliverReorderableList(
                itemCount: _contacts.length,
                onReorder: _reorderContacts,
                itemBuilder: (context, index) {
                  final contact = _contacts[index];
                  final isLast = index == _contacts.length - 1;
                  
                  return Container(
                    key: ValueKey(contact.id),
                    margin: const EdgeInsets.only(bottom: 1),
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: index == 0 ? const Radius.circular(10) : Radius.zero,
                        bottom: isLast ? const Radius.circular(10) : Radius.zero,
                      ),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: contact.type == EmergencyContactType.emergency 
                                  ? Colors.red.withOpacity(0.1) 
                                  : const Color(0xFF007AFF).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              contact.type == EmergencyContactType.emergency 
                                  ? CupertinoIcons.heart_fill 
                                  : contact.type == EmergencyContactType.doctor
                                      ? CupertinoIcons.person_crop_circle_fill
                                      : CupertinoIcons.phone_fill,
                              color: contact.type == EmergencyContactType.emergency 
                                  ? Colors.red 
                                  : const Color(0xFF007AFF),
                              size: 20,
                            ),
                          ),
                          title: Text(
                            contact.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                          subtitle: Text(
                            contact.phoneNumber,
                            style: TextStyle(
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          trailing: ReorderableDragStartListener(
                            index: index,
                            child: const Icon(Icons.drag_handle, color: Colors.grey),
                          ),
                          onLongPress: () {
                            HapticFeedback.mediumImpact();
                            _showDeleteConfirmation(contact, isDarkMode);
                          },
                        ),
                        if (!isLast)
                          Divider(
                            height: 1,
                            indent: 60,
                            color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(EmergencyContactModel contact, bool isDarkMode) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Contact'),
        content: Text('Are you sure you want to remove ${contact.name}?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _deleteContact(contact.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddContactDialog() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    EmergencyContactType selectedType = EmergencyContactType.family;
    String? phoneError;
    
    showCupertinoDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => CupertinoAlertDialog(
          title: const Text('Add Emergency Contact'),
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
                      // Issue #14: Validate phone number on change
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
              CupertinoSlidingSegmentedControl<EmergencyContactType>(
                groupValue: selectedType,
                children: const {
                  EmergencyContactType.family: Text('Family', style: TextStyle(fontSize: 12)),
                  EmergencyContactType.doctor: Text('Doctor', style: TextStyle(fontSize: 12)),
                  EmergencyContactType.emergency: Text('Emergency', style: TextStyle(fontSize: 12)),
                },
                onValueChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedType = value);
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
                // Issue #14: Validate before saving
                final phone = phoneController.text.trim();
                final validationError = _validatePhoneNumber(phone);
                
                if (nameController.text.trim().isEmpty) {
                  setDialogState(() {});
                  return;
                }
                
                if (validationError != null) {
                  setDialogState(() => phoneError = validationError);
                  return;
                }
                
                Navigator.pop(context);
                _saveContact(EmergencyContactModel.create(
                  patientId: uid,
                  name: nameController.text.trim(),
                  phoneNumber: phone,
                  type: selectedType,
                  priority: _contacts.length,
                ));
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Issue #14: Phone number validation helper
  String? _validatePhoneNumber(String phone) {
    if (phone.isEmpty) {
      return 'Phone number is required';
    }
    
    // Remove common formatting characters
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
