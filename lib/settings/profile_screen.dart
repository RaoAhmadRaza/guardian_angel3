import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/patient_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Critical Issue #8: Remove hardcoded values, initialize empty
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  bool _isEditing = false;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }
  
  /// Load profile data from PatientService (Critical Issue #8)
  Future<void> _loadProfileData() async {
    try {
      final patientData = await PatientService.instance.getPatientData();
      
      if (mounted) {
        setState(() {
          _nameController.text = patientData['fullName'] as String? ?? '';
          _phoneController.text = patientData['phoneNumber'] as String? ?? '';
          _addressController.text = patientData['address'] as String? ?? '';
          // Email might be stored separately or from Firebase Auth
          _emailController.text = patientData['email'] as String? ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[ProfileScreen] Error loading profile data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  /// Save profile data to PatientService (Critical Issue #8)
  Future<bool> _saveProfileData() async {
    setState(() => _isSaving = true);
    
    try {
      final existingData = await PatientService.instance.getPatientData();
      
      await PatientService.instance.savePatientData(
        fullName: _nameController.text.trim(),
        gender: existingData['gender'] as String? ?? 'male',
        age: existingData['age'] as int? ?? 0,
        phoneNumber: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        medicalHistory: existingData['medicalHistory'] as String? ?? '',
      );
      
      debugPrint('[ProfileScreen] Profile saved successfully');
      return true;
    } catch (e) {
      debugPrint('[ProfileScreen] Error saving profile: $e');
      return false;
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
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
              'Profile Details',
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
              TextButton(
                onPressed: _isSaving ? null : () async {
                  if (_isEditing) {
                    if (_formKey.currentState!.validate()) {
                      // Critical Issue #8: Actually save the data
                      final success = await _saveProfileData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success 
                                ? 'Profile updated successfully' 
                                : 'Failed to save profile'),
                          ),
                        );
                        if (success) {
                          setState(() => _isEditing = false);
                        }
                      }
                    }
                  } else {
                    setState(() => _isEditing = true);
                  }
                },
                child: _isSaving
                    ? const CupertinoActivityIndicator()
                    : Text(
                        _isEditing ? 'Done' : 'Edit',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF007AFF),
                        ),
                      ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: _isLoading 
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CupertinoActivityIndicator(),
                    ),
                  )
                : Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: const Color(0xFF007AFF).withOpacity(0.1),
                          child: const Icon(CupertinoIcons.person_fill, size: 60, color: Color(0xFF007AFF)),
                        ),
                        if (_isEditing)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFF007AFF),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(CupertinoIcons.camera_fill, size: 16, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          _buildTextField(
                            controller: _nameController,
                            label: 'Full Name',
                            enabled: _isEditing,
                            isDarkMode: isDarkMode,
                            isFirst: true,
                          ),
                          Divider(height: 1, indent: 16, color: isDarkMode ? Colors.grey[800] : Colors.grey[200]),
                          _buildTextField(
                            controller: _emailController,
                            label: 'Email',
                            enabled: _isEditing,
                            keyboardType: TextInputType.emailAddress,
                            isDarkMode: isDarkMode,
                          ),
                          Divider(height: 1, indent: 16, color: isDarkMode ? Colors.grey[800] : Colors.grey[200]),
                          _buildTextField(
                            controller: _phoneController,
                            label: 'Phone',
                            enabled: _isEditing,
                            keyboardType: TextInputType.phone,
                            isDarkMode: isDarkMode,
                          ),
                          Divider(height: 1, indent: 16, color: isDarkMode ? Colors.grey[800] : Colors.grey[200]),
                          _buildTextField(
                            controller: _addressController,
                            label: 'Address',
                            enabled: _isEditing,
                            maxLines: 3,
                            isDarkMode: isDarkMode,
                            isLast: true,
                          ),
                        ],
                      ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool enabled = true,
    TextInputType? keyboardType,
    int maxLines = 1,
    required bool isDarkMode,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextFormField(
              controller: controller,
              enabled: enabled,
              keyboardType: keyboardType,
              maxLines: maxLines,
              style: TextStyle(
                fontSize: 16,
                color: enabled 
                    ? (const Color(0xFF007AFF)) 
                    : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
              ),
              decoration: const InputDecoration.collapsed(
                hintText: '',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Required';
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }
}
