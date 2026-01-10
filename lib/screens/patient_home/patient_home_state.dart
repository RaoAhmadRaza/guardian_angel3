/// PatientHomeState - Screen-level state model for Patient Home Screen.
///
/// This is NOT a Hive model. It's a view-model that combines data from
/// multiple sources (patient details, vitals, medications, etc.) into
/// a single object for the UI.
library;

/// Screen loading states
enum PatientHomeLoadingState {
  /// Initial loading from local database
  loading,
  
  /// New patient - minimal or no data exists
  empty,
  
  /// Some data exists but not all sections populated
  partial,
  
  /// All data sections have content
  full,
}

/// Patient vitals data (from wearable/health monitoring)
class VitalsData {
  final int systolicBP;
  final int diastolicBP;
  final int heartRate;
  final int? oxygenPercent;
  final DateTime? lastUpdated;

  const VitalsData({
    required this.systolicBP,
    required this.diastolicBP,
    required this.heartRate,
    this.oxygenPercent,
    this.lastUpdated,
  });

  /// Default/placeholder vitals when no data available
  static const VitalsData empty = VitalsData(
    systolicBP: 0,
    diastolicBP: 0,
    heartRate: 0,
    oxygenPercent: null,
  );

  /// Check if vitals data is available
  bool get hasData => systolicBP > 0 && diastolicBP > 0 && heartRate > 0;

  /// Check if oxygen saturation data is available
  bool get hasOxygenData => oxygenPercent != null && oxygenPercent! > 0;

  /// Display string for blood pressure
  String get bloodPressureDisplay => hasData 
      ? '$systolicBP / $diastolicBP' 
      : '— / —';

  /// Display string for heart rate
  String get heartRateDisplay => hasData 
      ? '$heartRate / min' 
      : '— / min';

  /// Display string for oxygen saturation (SpO2)
  String get oxygenSaturationDisplay => hasOxygenData 
      ? '$oxygenPercent%' 
      : '— %';
}

/// Doctor information
class DoctorInfo {
  final String name;
  final String specialty;
  final String? phoneNumber;
  final String? imageUrl;

  const DoctorInfo({
    required this.name,
    required this.specialty,
    this.phoneNumber,
    this.imageUrl,
  });

  /// Default placeholder when no doctor assigned
  static const DoctorInfo empty = DoctorInfo(
    name: 'Not Assigned',
    specialty: 'No doctor assigned yet',
  );

  /// Check if doctor is assigned
  bool get isAssigned => name != 'Not Assigned' && name.isNotEmpty;
}

/// Safety status information
class SafetyStatus {
  final String status;
  final bool isAlert;
  final DateTime? lastChecked;

  const SafetyStatus({
    required this.status,
    this.isAlert = false,
    this.lastChecked,
  });

  /// Default safe status
  static const SafetyStatus allClear = SafetyStatus(
    status: 'All Clear',
    isAlert: false,
  );

  /// No data available
  static const SafetyStatus unknown = SafetyStatus(
    status: 'Not Monitored',
    isAlert: false,
  );
}

/// Diagnosis/health summary info
class DiagnosisSummary {
  final String title;
  final String subtitle;
  final DateTime? lastDiagnosisDate;

  const DiagnosisSummary({
    required this.title,
    required this.subtitle,
    this.lastDiagnosisDate,
  });

  /// Default when no diagnosis history
  static const DiagnosisSummary empty = DiagnosisSummary(
    title: 'Health',
    subtitle: 'No health data available yet',
  );

  /// Format for UI display
  String get displaySubtitle {
    if (lastDiagnosisDate != null) {
      final days = DateTime.now().difference(lastDiagnosisDate!).inDays;
      if (days == 0) return 'Last diagnosis today';
      if (days == 1) return 'Last diagnosis yesterday';
      return 'Last diagnosis $days days ago';
    }
    return subtitle;
  }
}

/// Home automation summary for a single card
class AutomationCardData {
  final String title;
  final String subtitle;
  final String value;
  final bool isAvailable;

  const AutomationCardData({
    required this.title,
    required this.subtitle,
    required this.value,
    this.isAvailable = true,
  });

  /// Placeholder when no data
  factory AutomationCardData.placeholder({
    required String title,
    required String subtitle,
  }) => AutomationCardData(
    title: title,
    subtitle: subtitle,
    value: 'Not Available',
    isAvailable: false,
  );
}

/// Single medication entry
class MedicationEntry {
  final String name;
  final String dose;
  final String type; // 'capsule' or 'pill'

  const MedicationEntry({
    required this.name,
    required this.dose,
    required this.type,
  });
}

/// Medication time slot
class MedicationTimeSlot {
  final String time;
  final List<MedicationEntry> medications;

  const MedicationTimeSlot({
    required this.time,
    required this.medications,
  });

  /// Check if slot has medications
  bool get hasMedications => medications.isNotEmpty;
}

/// Complete patient home screen state
class PatientHomeState {
  // === REQUIRED FIELDS ===
  
  /// Patient's display name
  final String patientName;
  
  /// Patient's gender for avatar
  final String gender;
  
  // === OPTIONAL FIELDS ===
  
  /// Profile image URL (nullable, falls back to gender-based avatar)
  final String? profileImageUrl;
  
  /// Current vitals data
  final VitalsData vitals;
  
  /// Safety monitoring status
  final SafetyStatus safetyStatus;
  
  /// Assigned doctor info
  final DoctorInfo doctorInfo;
  
  /// Health/diagnosis summary
  final DiagnosisSummary diagnosisSummary;
  
  /// Home automation cards data
  final List<AutomationCardData> automationCards;
  
  /// Medication schedule (time slots)
  final List<MedicationTimeSlot> medicationSchedule;
  
  /// Current loading state
  final PatientHomeLoadingState loadingState;

  const PatientHomeState({
    required this.patientName,
    required this.gender,
    this.profileImageUrl,
    this.vitals = VitalsData.empty,
    this.safetyStatus = SafetyStatus.unknown,
    this.doctorInfo = DoctorInfo.empty,
    this.diagnosisSummary = DiagnosisSummary.empty,
    this.automationCards = const [],
    this.medicationSchedule = const [],
    this.loadingState = PatientHomeLoadingState.loading,
  });

  /// Initial loading state
  factory PatientHomeState.loading() => const PatientHomeState(
    patientName: 'Patient',
    gender: 'male',
    loadingState: PatientHomeLoadingState.loading,
  );

  /// Calculate the effective loading state based on data availability
  PatientHomeLoadingState get effectiveLoadingState {
    if (loadingState == PatientHomeLoadingState.loading) {
      return PatientHomeLoadingState.loading;
    }
    
    final hasVitals = vitals.hasData;
    final hasDoctor = doctorInfo.isAssigned;
    final hasMeds = medicationSchedule.any((slot) => slot.hasMedications);
    final hasAutomation = automationCards.any((card) => card.isAvailable);
    
    if (!hasVitals && !hasDoctor && !hasMeds && !hasAutomation) {
      return PatientHomeLoadingState.empty;
    }
    
    if (hasVitals && hasDoctor && hasMeds && hasAutomation) {
      return PatientHomeLoadingState.full;
    }
    
    return PatientHomeLoadingState.partial;
  }

  /// First name for greeting
  String get firstName {
    if (patientName.isEmpty || patientName == 'Patient') {
      return 'Patient';
    }
    return patientName.split(' ').first;
  }

  /// Avatar asset path based on gender
  String get avatarAssetPath {
    return gender.toLowerCase() == 'female'
        ? 'images/female.jpg'
        : 'images/male.jpg';
  }

  /// Create a copy with updated fields
  PatientHomeState copyWith({
    String? patientName,
    String? gender,
    String? profileImageUrl,
    VitalsData? vitals,
    SafetyStatus? safetyStatus,
    DoctorInfo? doctorInfo,
    DiagnosisSummary? diagnosisSummary,
    List<AutomationCardData>? automationCards,
    List<MedicationTimeSlot>? medicationSchedule,
    PatientHomeLoadingState? loadingState,
  }) {
    return PatientHomeState(
      patientName: patientName ?? this.patientName,
      gender: gender ?? this.gender,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      vitals: vitals ?? this.vitals,
      safetyStatus: safetyStatus ?? this.safetyStatus,
      doctorInfo: doctorInfo ?? this.doctorInfo,
      diagnosisSummary: diagnosisSummary ?? this.diagnosisSummary,
      automationCards: automationCards ?? this.automationCards,
      medicationSchedule: medicationSchedule ?? this.medicationSchedule,
      loadingState: loadingState ?? this.loadingState,
    );
  }
}
