/// Comprehensive input validation utilities for Guardian Angel app
/// 
/// Provides consistent validation across all user input screens
/// with user-friendly error messages and edge case handling.
library;

/// Input validation utility class
/// 
/// Contains static methods for validating various input types
/// with support for custom rules and internationalization-ready messages.
class InputValidators {
  // Private constructor - utility class
  InputValidators._();

  // ============================================================
  // NAME VALIDATION
  // ============================================================

  /// Validates a full name
  /// 
  /// Rules:
  /// - Required (not empty)
  /// - Minimum 2 characters
  /// - Maximum 100 characters
  /// - Only letters, spaces, hyphens, and apostrophes
  /// - No leading/trailing spaces (auto-trimmed)
  /// - No consecutive spaces
  static String? validateName(String? value, {bool isRequired = true}) {
    if (value == null || value.trim().isEmpty) {
      return isRequired ? 'Please enter your full name' : null;
    }

    final trimmed = value.trim();

    if (trimmed.length < 2) {
      return 'Name must be at least 2 characters';
    }

    if (trimmed.length > 100) {
      return 'Name cannot exceed 100 characters';
    }

    // Check for valid characters (letters, spaces, hyphens, apostrophes)
    final nameRegex = RegExp(r"^[a-zA-Z\s\-']+$");
    if (!nameRegex.hasMatch(trimmed)) {
      return 'Name can only contain letters, spaces, hyphens, and apostrophes';
    }

    // Check for consecutive spaces
    if (trimmed.contains('  ')) {
      return 'Name cannot have consecutive spaces';
    }

    // Check for at least one letter
    if (!RegExp(r'[a-zA-Z]').hasMatch(trimmed)) {
      return 'Name must contain at least one letter';
    }

    return null;
  }

  // ============================================================
  // PHONE NUMBER VALIDATION
  // ============================================================

  /// Validates a phone number
  /// 
  /// Rules:
  /// - Required (not empty)
  /// - Minimum 10 digits
  /// - Maximum 15 digits (international standard)
  /// - Only digits, +, -, (, ), and spaces allowed
  /// - Must contain at least 10 digit characters
  static String? validatePhone(String? value, {bool isRequired = true}) {
    if (value == null || value.trim().isEmpty) {
      return isRequired ? 'Please enter your phone number' : null;
    }

    final trimmed = value.trim();

    // Check for valid phone characters
    final phoneCharsRegex = RegExp(r'^[\d\s\+\-\(\)]+$');
    if (!phoneCharsRegex.hasMatch(trimmed)) {
      return 'Phone number can only contain digits, +, -, (, ), and spaces';
    }

    // Extract only digits
    final digitsOnly = trimmed.replaceAll(RegExp(r'[^\d]'), '');

    if (digitsOnly.length < 10) {
      return 'Phone number must have at least 10 digits';
    }

    if (digitsOnly.length > 15) {
      return 'Phone number cannot exceed 15 digits';
    }

    // Check for valid starting character (digit or +)
    if (!RegExp(r'^[\d\+]').hasMatch(trimmed)) {
      return 'Phone number must start with a digit or +';
    }

    return null;
  }

  // ============================================================
  // EMAIL VALIDATION
  // ============================================================

  /// Validates an email address
  /// 
  /// Rules:
  /// - Required (not empty)
  /// - Must contain exactly one @
  /// - Must have local part and domain
  /// - Domain must have at least one dot
  /// - No spaces allowed
  /// - Maximum 254 characters (RFC 5321)
  static String? validateEmail(String? value, {bool isRequired = true}) {
    if (value == null || value.trim().isEmpty) {
      return isRequired ? 'Please enter your email address' : null;
    }

    final trimmed = value.trim().toLowerCase();

    // Check for spaces
    if (trimmed.contains(' ')) {
      return 'Email address cannot contain spaces';
    }

    // Check length
    if (trimmed.length > 254) {
      return 'Email address is too long';
    }

    // Basic structure check
    if (!trimmed.contains('@')) {
      return 'Please enter a valid email address';
    }

    // Split into parts
    final parts = trimmed.split('@');
    if (parts.length != 2) {
      return 'Email must contain exactly one @ symbol';
    }

    final localPart = parts[0];
    final domain = parts[1];

    // Local part validation
    if (localPart.isEmpty) {
      return 'Email must have a username before @';
    }

    if (localPart.length > 64) {
      return 'Email username is too long';
    }

    // Domain validation
    if (domain.isEmpty) {
      return 'Email must have a domain after @';
    }

    if (!domain.contains('.')) {
      return 'Email domain must contain a dot (e.g., .com)';
    }

    // Check domain parts
    final domainParts = domain.split('.');
    if (domainParts.any((part) => part.isEmpty)) {
      return 'Invalid email domain format';
    }

    // Check for valid TLD (at least 2 characters)
    if (domainParts.last.length < 2) {
      return 'Please enter a valid email domain';
    }

    // More comprehensive regex check
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(trimmed)) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  // ============================================================
  // ADDRESS VALIDATION
  // ============================================================

  /// Validates an address
  /// 
  /// Rules:
  /// - Required (not empty) by default
  /// - Minimum 5 characters
  /// - Maximum 500 characters
  /// - Must contain at least one number OR letter
  static String? validateAddress(String? value, {bool isRequired = true}) {
    if (value == null || value.trim().isEmpty) {
      return isRequired ? 'Please enter your address' : null;
    }

    final trimmed = value.trim();

    if (trimmed.length < 5) {
      return 'Address must be at least 5 characters';
    }

    if (trimmed.length > 500) {
      return 'Address cannot exceed 500 characters';
    }

    // Check for at least some meaningful content
    if (!RegExp(r'[a-zA-Z0-9]').hasMatch(trimmed)) {
      return 'Address must contain letters or numbers';
    }

    return null;
  }

  // ============================================================
  // MEDICAL HISTORY VALIDATION
  // ============================================================

  /// Validates medical history text
  /// 
  /// Rules:
  /// - Optional field
  /// - Maximum 2000 characters
  /// - No script tags or malicious content
  static String? validateMedicalHistory(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional field
    }

    final trimmed = value.trim();

    if (trimmed.length > 2000) {
      return 'Medical history cannot exceed 2000 characters';
    }

    // Basic XSS prevention
    if (trimmed.contains('<script') || trimmed.contains('javascript:')) {
      return 'Invalid characters detected';
    }

    return null;
  }

  // ============================================================
  // RELATION VALIDATION
  // ============================================================

  /// Validates relationship type (for caregivers)
  /// 
  /// Rules:
  /// - Required (not empty)
  /// - Minimum 2 characters
  /// - Maximum 50 characters
  /// - Only letters, spaces, and hyphens
  static String? validateRelation(String? value, {bool isRequired = true}) {
    if (value == null || value.trim().isEmpty) {
      return isRequired ? 'Please specify your relation to the patient' : null;
    }

    final trimmed = value.trim();

    if (trimmed.length < 2) {
      return 'Relation must be at least 2 characters';
    }

    if (trimmed.length > 50) {
      return 'Relation cannot exceed 50 characters';
    }

    // Only letters, spaces, and hyphens
    final relationRegex = RegExp(r'^[a-zA-Z\s\-]+$');
    if (!relationRegex.hasMatch(trimmed)) {
      return 'Relation can only contain letters, spaces, and hyphens';
    }

    return null;
  }

  // ============================================================
  // MEDICAL LICENSE VALIDATION
  // ============================================================

  /// Validates a medical license number
  /// 
  /// Rules:
  /// - Required (not empty)
  /// - Minimum 5 characters
  /// - Maximum 30 characters
  /// - Alphanumeric with hyphens and underscores
  static String? validateLicenseNumber(String? value, {bool isRequired = true}) {
    if (value == null || value.trim().isEmpty) {
      return isRequired ? 'Please enter your license number' : null;
    }

    final trimmed = value.trim();

    if (trimmed.length < 5) {
      return 'License number must be at least 5 characters';
    }

    if (trimmed.length > 30) {
      return 'License number cannot exceed 30 characters';
    }

    // Alphanumeric with hyphens and underscores
    final licenseRegex = RegExp(r'^[a-zA-Z0-9\-_]+$');
    if (!licenseRegex.hasMatch(trimmed)) {
      return 'License number can only contain letters, numbers, hyphens, and underscores';
    }

    // Must contain at least one digit
    if (!RegExp(r'\d').hasMatch(trimmed)) {
      return 'License number must contain at least one digit';
    }

    return null;
  }

  // ============================================================
  // SPECIALTY VALIDATION
  // ============================================================

  /// Validates a medical specialty
  /// 
  /// Rules:
  /// - Required (not empty)
  /// - Minimum 3 characters
  /// - Maximum 100 characters
  /// - Only letters, spaces, hyphens, and slashes
  static String? validateSpecialty(String? value, {bool isRequired = true}) {
    if (value == null || value.trim().isEmpty) {
      return isRequired ? 'Please enter your specialty' : null;
    }

    final trimmed = value.trim();

    if (trimmed.length < 3) {
      return 'Specialty must be at least 3 characters';
    }

    if (trimmed.length > 100) {
      return 'Specialty cannot exceed 100 characters';
    }

    // Letters, spaces, hyphens, and slashes
    final specialtyRegex = RegExp(r'^[a-zA-Z\s\-\/]+$');
    if (!specialtyRegex.hasMatch(trimmed)) {
      return 'Specialty can only contain letters, spaces, hyphens, and slashes';
    }

    return null;
  }

  // ============================================================
  // HOSPITAL/CLINIC NAME VALIDATION
  // ============================================================

  /// Validates a hospital or clinic name
  /// 
  /// Rules:
  /// - Required (not empty)
  /// - Minimum 2 characters
  /// - Maximum 200 characters
  static String? validateHospital(String? value, {bool isRequired = true}) {
    if (value == null || value.trim().isEmpty) {
      return isRequired ? 'Please enter your hospital or clinic name' : null;
    }

    final trimmed = value.trim();

    if (trimmed.length < 2) {
      return 'Hospital name must be at least 2 characters';
    }

    if (trimmed.length > 200) {
      return 'Hospital name cannot exceed 200 characters';
    }

    // Must contain at least one letter
    if (!RegExp(r'[a-zA-Z]').hasMatch(trimmed)) {
      return 'Hospital name must contain at least one letter';
    }

    return null;
  }

  // ============================================================
  // INVITE CODE VALIDATION
  // ============================================================

  /// Validates an invite code
  /// 
  /// Rules:
  /// - Optional by default
  /// - If provided, must be 6-20 characters
  /// - Alphanumeric with hyphens
  /// - Case-insensitive (will be normalized)
  static String? validateInviteCode(String? value, {bool isRequired = false}) {
    if (value == null || value.trim().isEmpty) {
      return isRequired ? 'Please enter the invite code' : null;
    }

    final trimmed = value.trim().toUpperCase();

    if (trimmed.length < 6) {
      return 'Invite code must be at least 6 characters';
    }

    if (trimmed.length > 20) {
      return 'Invite code cannot exceed 20 characters';
    }

    // Alphanumeric with hyphens
    final codeRegex = RegExp(r'^[A-Z0-9\-]+$');
    if (!codeRegex.hasMatch(trimmed)) {
      return 'Invite code can only contain letters, numbers, and hyphens';
    }

    return null;
  }

  // ============================================================
  // AGE VALIDATION
  // ============================================================

  /// Validates an age value
  /// 
  /// Rules:
  /// - Must be between min and max
  /// - For patients: minimum 60 (elderly care focus)
  static String? validateAge(
    int value, {
    int minAge = 0,
    int maxAge = 120,
    int? requiredMinAge,
  }) {
    if (value < minAge) {
      return 'Age must be at least $minAge';
    }

    if (value > maxAge) {
      return 'Age cannot exceed $maxAge';
    }

    if (requiredMinAge != null && value < requiredMinAge) {
      return 'You must be at least $requiredMinAge years old to use this service';
    }

    return null;
  }

  // ============================================================
  // GENERIC TEXT VALIDATION
  // ============================================================

  /// Generic text field validation
  /// 
  /// Customizable min/max length and pattern
  static String? validateText(
    String? value, {
    bool isRequired = true,
    int minLength = 1,
    int maxLength = 1000,
    String? fieldName,
    RegExp? pattern,
    String? patternError,
  }) {
    final displayName = fieldName ?? 'This field';

    if (value == null || value.trim().isEmpty) {
      return isRequired ? '$displayName is required' : null;
    }

    final trimmed = value.trim();

    if (trimmed.length < minLength) {
      return '$displayName must be at least $minLength characters';
    }

    if (trimmed.length > maxLength) {
      return '$displayName cannot exceed $maxLength characters';
    }

    if (pattern != null && !pattern.hasMatch(trimmed)) {
      return patternError ?? '$displayName contains invalid characters';
    }

    return null;
  }

  // ============================================================
  // UTILITY METHODS
  // ============================================================

  /// Sanitizes text input by removing dangerous characters
  static String sanitize(String input) {
    return input
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .trim();
  }

  /// Normalizes a phone number to digits only
  static String normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[^\d+]'), '');
  }

  /// Normalizes an email to lowercase
  static String normalizeEmail(String email) {
    return email.trim().toLowerCase();
  }

  /// Formats a name with proper capitalization
  static String formatName(String name) {
    return name.trim().split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  // ============================================================
  // MEDICATION-SPECIFIC VALIDATION
  // ============================================================

  /// Validates medication name
  /// 
  /// Rules:
  /// - Required (not empty)
  /// - Minimum 2 characters
  /// - Maximum 100 characters
  /// - Only letters, numbers, spaces, hyphens, and common symbols
  /// - No leading/trailing spaces
  static String? validateMedicationName(String? value, {bool isRequired = true}) {
    if (value == null || value.trim().isEmpty) {
      return isRequired ? 'Please enter medication name' : null;
    }

    final trimmed = value.trim();

    if (trimmed.length < 2) {
      return 'Medication name must be at least 2 characters';
    }

    if (trimmed.length > 100) {
      return 'Medication name cannot exceed 100 characters';
    }

    // Allow letters, numbers, spaces, hyphens, parentheses, periods
    final nameRegex = RegExp(r"^[a-zA-Z0-9\s\-\(\)\.]+$");
    if (!nameRegex.hasMatch(trimmed)) {
      return 'Medication name contains invalid characters';
    }

    // Must contain at least one letter
    if (!RegExp(r'[a-zA-Z]').hasMatch(trimmed)) {
      return 'Medication name must contain at least one letter';
    }

    // Check for consecutive spaces
    if (trimmed.contains('  ')) {
      return 'Remove extra spaces';
    }

    return null;
  }

  /// Validates medication dosage
  /// 
  /// Rules:
  /// - Required (not empty)
  /// - Minimum 1 character
  /// - Maximum 50 characters
  /// - Must contain a number
  /// - Common formats: "500mg", "10ml", "2 tablets"
  static String? validateDosage(String? value, {bool isRequired = true}) {
    if (value == null || value.trim().isEmpty) {
      return isRequired ? 'Please enter dosage' : null;
    }

    final trimmed = value.trim();

    if (trimmed.length < 1) {
      return 'Dosage is required';
    }

    if (trimmed.length > 50) {
      return 'Dosage cannot exceed 50 characters';
    }

    // Should contain at least one number or be a valid text like "As directed"
    final hasNumber = RegExp(r'\d').hasMatch(trimmed);
    final commonTextDosages = ['as directed', 'as needed', 'prn'];
    final isTextDosage = commonTextDosages.any(
      (text) => trimmed.toLowerCase().contains(text)
    );

    if (!hasNumber && !isTextDosage) {
      return 'Dosage should include amount (e.g., "500mg", "2 tablets")';
    }

    // Only allow safe characters
    final dosageRegex = RegExp(r"^[a-zA-Z0-9\s\-\.\/\(\)]+$");
    if (!dosageRegex.hasMatch(trimmed)) {
      return 'Dosage contains invalid characters';
    }

    return null;
  }

  /// Validates infusion volume in milliliters
  /// 
  /// Rules:
  /// - Minimum 10ml
  /// - Maximum 3000ml (3 liters - reasonable medical limit)
  static String? validateInfusionVolume(int? value) {
    if (value == null) {
      return 'Volume is required';
    }

    if (value < 10) {
      return 'Volume must be at least 10ml';
    }

    if (value > 3000) {
      return 'Volume cannot exceed 3000ml';
    }

    return null;
  }

  /// Validates infusion duration in minutes
  /// 
  /// Rules:
  /// - Minimum 5 minutes
  /// - Maximum 720 minutes (12 hours - reasonable limit)
  static String? validateInfusionDuration(int? value) {
    if (value == null) {
      return 'Duration is required';
    }

    if (value < 5) {
      return 'Duration must be at least 5 minutes';
    }

    if (value > 720) {
      return 'Duration cannot exceed 12 hours (720 minutes)';
    }

    return null;
  }

  /// Validates medication stock count
  /// 
  /// Rules:
  /// - Minimum 0
  /// - Maximum 500 (reasonable home supply)
  static String? validateStockCount(int? value, {String fieldName = 'Stock'}) {
    if (value == null) {
      return '$fieldName is required';
    }

    if (value < 0) {
      return '$fieldName cannot be negative';
    }

    if (value > 500) {
      return '$fieldName cannot exceed 500 units';
    }

    return null;
  }

  /// Validates low stock threshold
  /// 
  /// Rules:
  /// - Minimum 1
  /// - Maximum 100
  /// - Must be less than current stock
  static String? validateLowStockThreshold(int? value, {int? currentStock}) {
    if (value == null) {
      return 'Low stock level is required';
    }

    if (value < 1) {
      return 'Low stock level must be at least 1';
    }

    if (value > 100) {
      return 'Low stock level cannot exceed 100';
    }

    if (currentStock != null && value >= currentStock) {
      return 'Low stock level must be less than current stock';
    }

    return null;
  }

  /// Validates alert threshold in minutes (for infusions)
  /// 
  /// Rules:
  /// - Minimum 1 minute
  /// - Maximum 60 minutes
  static String? validateAlertThreshold(int? value) {
    if (value == null) {
      return 'Alert threshold is required';
    }

    if (value < 1) {
      return 'Alert must be at least 1 minute before';
    }

    if (value > 60) {
      return 'Alert cannot be more than 60 minutes before';
    }

    return null;
  }

  /// Sanitizes medication name for safe storage
  static String sanitizeMedicationName(String input) {
    return input
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll(RegExp(r'[^\w\s\-\(\)\.]'), '') // Keep safe chars only
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize spaces
        .trim();
  }
}
