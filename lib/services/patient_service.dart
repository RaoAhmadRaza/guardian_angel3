import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing patient data persistence
class PatientService {
  static const String _keyFullName = 'patient_full_name';
  static const String _keyGender = 'patient_gender';
  static const String _keyAge = 'patient_age';
  static const String _keyPhoneNumber = 'patient_phone_number';
  static const String _keyAddress = 'patient_address';
  static const String _keyMedicalHistory = 'patient_medical_history';
  static const String _keyCreatedAt = 'patient_created_at';

  static PatientService? _instance;
  static PatientService get instance => _instance ??= PatientService._();
  PatientService._();

  /// Save patient data to local storage
  Future<void> savePatientData({
    required String fullName,
    required String gender,
    required int age,
    required String phoneNumber,
    required String address,
    required String medicalHistory,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_keyFullName, fullName);
    await prefs.setString(_keyGender, gender);
    await prefs.setInt(_keyAge, age);
    await prefs.setString(_keyPhoneNumber, phoneNumber);
    await prefs.setString(_keyAddress, address);
    await prefs.setString(_keyMedicalHistory, medicalHistory);
    await prefs.setString(_keyCreatedAt, DateTime.now().toIso8601String());
  }

  /// Get patient's full name
  Future<String> getPatientName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFullName) ?? 'Patient';
  }

  /// Get patient's first name for greeting
  Future<String> getPatientFirstName() async {
    final fullName = await getPatientName();
    if (fullName.isEmpty || fullName == 'Patient') {
      return 'Patient';
    }
    return fullName.split(' ').first;
  }

  /// Get patient's gender
  Future<String> getPatientGender() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyGender) ?? 'male';
  }

  /// Get patient's age
  Future<int> getPatientAge() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyAge) ?? 0;
  }

  /// Get patient's phone number
  Future<String> getPatientPhoneNumber() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPhoneNumber) ?? '';
  }

  /// Get patient's address
  Future<String> getPatientAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAddress) ?? '';
  }

  /// Get patient's medical history
  Future<String> getPatientMedicalHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyMedicalHistory) ?? '';
  }

  /// Check if patient data exists
  Future<bool> hasPatientData() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_keyFullName);
  }

  /// Get complete patient data
  Future<Map<String, dynamic>> getPatientData() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'fullName': prefs.getString(_keyFullName) ?? 'Patient',
      'gender': prefs.getString(_keyGender) ?? 'male',
      'age': prefs.getInt(_keyAge) ?? 0,
      'phoneNumber': prefs.getString(_keyPhoneNumber) ?? '',
      'address': prefs.getString(_keyAddress) ?? '',
      'medicalHistory': prefs.getString(_keyMedicalHistory) ?? '',
      'createdAt': prefs.getString(_keyCreatedAt) ?? '',
    };
  }

  /// Clear all patient data
  Future<void> clearPatientData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_keyFullName);
    await prefs.remove(_keyGender);
    await prefs.remove(_keyAge);
    await prefs.remove(_keyPhoneNumber);
    await prefs.remove(_keyAddress);
    await prefs.remove(_keyMedicalHistory);
    await prefs.remove(_keyCreatedAt);
  }
}
