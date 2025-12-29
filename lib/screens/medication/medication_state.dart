import 'package:flutter/material.dart';

/// Medication Screen State Model
/// 
/// PRODUCTION-SAFE: All fields that depend on external data are nullable.
/// First-time users will see an empty state with no fake medications.

/// Inventory status for medication supply
enum InventoryStatus {
  /// Plenty of supply remaining
  ok,
  
  /// Running low (< 7 days)
  low,
  
  /// Needs immediate refill
  refill,
}

/// Inventory tracking for medication
class Inventory {
  /// Pills/doses remaining
  final int remaining;
  
  /// Total prescription quantity
  final int total;
  
  /// Current supply status
  final InventoryStatus status;

  const Inventory({
    required this.remaining,
    required this.total,
    required this.status,
  });

  /// Calculate fill percentage (0.0 - 1.0)
  double get fillPercentage => total > 0 ? remaining / total : 0.0;

  /// Display text for remaining supply
  String get displayText => '$remaining left';

  /// Empty inventory state
  static const Inventory empty = Inventory(
    remaining: 0,
    total: 0,
    status: InventoryStatus.refill,
  );
}

/// Medication progress tracking
class MedicationProgress {
  /// Consecutive days of adherence
  final int streakDays;
  
  /// Daily completion percentage (0.0 - 1.0)
  final double dailyCompletion;

  const MedicationProgress({
    required this.streakDays,
    required this.dailyCompletion,
  });

  /// Empty progress for new users
  static const MedicationProgress empty = MedicationProgress(
    streakDays: 0,
    dailyCompletion: 0.0,
  );

  /// Display text for streak
  String get streakDisplayText => '$streakDays Day Streak';

  /// Whether to show streak badge (only if > 0)
  bool get showStreak => streakDays > 0;

  /// Display text for daily progress
  String get dailyProgressText {
    if (dailyCompletion >= 1.0) {
      return 'All meds taken today';
    } else if (dailyCompletion > 0) {
      return '${(dailyCompletion * 100).round()}% for today';
    } else {
      return 'No medications taken yet';
    }
  }
}

/// Core medication data
class MedicationData {
  /// Medication name (e.g., "Lisinopril")
  final String name;
  
  /// Dosage amount (e.g., "10mg")
  final String dosage;
  
  /// Context/instructions (e.g., "With food") - optional
  final String? context;
  
  /// Scheduled time for this dose
  final TimeOfDay scheduledTime;
  
  /// Current inventory status
  final Inventory inventory;
  
  /// Prescribing doctor's name - optional
  final String? doctorName;
  
  /// Doctor's notes/instructions - optional
  final String? doctorNotes;
  
  /// Known side effects - may be empty
  final List<String> sideEffects;
  
  /// Pill color for visual representation
  final Color pillColor;
  
  /// Refill ID from pharmacy - optional
  final String? refillId;
  
  /// Link to full medication insert - optional
  final String? insertUrl;

  const MedicationData({
    required this.name,
    required this.dosage,
    this.context,
    required this.scheduledTime,
    required this.inventory,
    this.doctorName,
    this.doctorNotes,
    this.sideEffects = const [],
    this.pillColor = const Color(0xFFBBDEFB), // Default blue
    this.refillId,
    this.insertUrl,
  });

  /// Format scheduled time for display
  String formatScheduledTime(BuildContext context) {
    return scheduledTime.format(context);
  }

  /// Get dosage display text (dosage + context if available)
  String get dosageDisplayText {
    if (context != null && context!.isNotEmpty) {
      return '$dosage • $context';
    }
    return dosage;
  }

  /// Whether doctor notes are available
  bool get hasDoctorNotes => doctorNotes != null && doctorNotes!.isNotEmpty;

  /// Whether side effects are available
  bool get hasSideEffects => sideEffects.isNotEmpty;

  /// Whether refill ID is available
  bool get hasRefillId => refillId != null && refillId!.isNotEmpty;

  /// Whether insert URL is available
  bool get hasInsertUrl => insertUrl != null && insertUrl!.isNotEmpty;
}

/// Dose record for tracking when doses were taken
class DoseRecord {
  final String medicationId;
  final DateTime takenAt;
  final String? notes;

  const DoseRecord({
    required this.medicationId,
    required this.takenAt,
    this.notes,
  });
}

/// Main state for Medication Screen
class MedicationState {
  /// Whether user has any medication assigned
  final bool hasMedication;
  
  /// Current medication data (null if none)
  final MedicationData? medication;
  
  /// Progress tracking
  final MedicationProgress progress;
  
  /// Whether today's dose has been taken
  final bool isDoseTaken;
  
  /// Whether the card is showing back side
  final bool isCardFlipped;
  
  /// Time when dose was taken today (null if not taken)
  final DateTime? doseTakenAt;
  
  /// Session name from navigation
  final String sessionName;

  const MedicationState({
    required this.hasMedication,
    this.medication,
    required this.progress,
    required this.isDoseTaken,
    required this.isCardFlipped,
    this.doseTakenAt,
    required this.sessionName,
  });

  /// Initial empty state for first-time users
  factory MedicationState.empty({required String sessionName}) {
    return MedicationState(
      hasMedication: false,
      medication: null,
      progress: MedicationProgress.empty,
      isDoseTaken: false,
      isCardFlipped: false,
      doseTakenAt: null,
      sessionName: sessionName,
    );
  }

  /// Create a copy with updated fields
  MedicationState copyWith({
    bool? hasMedication,
    MedicationData? medication,
    MedicationProgress? progress,
    bool? isDoseTaken,
    bool? isCardFlipped,
    DateTime? doseTakenAt,
    String? sessionName,
    bool clearMedication = false,
    bool clearDoseTakenAt = false,
  }) {
    return MedicationState(
      hasMedication: hasMedication ?? this.hasMedication,
      medication: clearMedication ? null : (medication ?? this.medication),
      progress: progress ?? this.progress,
      isDoseTaken: isDoseTaken ?? this.isDoseTaken,
      isCardFlipped: isCardFlipped ?? this.isCardFlipped,
      doseTakenAt: clearDoseTakenAt ? null : (doseTakenAt ?? this.doseTakenAt),
      sessionName: sessionName ?? this.sessionName,
    );
  }

  // ============================================================
  // COMPUTED PROPERTIES FOR UI
  // ============================================================

  /// Adherence ring value (0.0 - 1.0)
  double get adherenceRingValue {
    if (!hasMedication) return 0.0;
    return isDoseTaken ? 1.0 : progress.dailyCompletion;
  }

  /// Header progress text
  String get headerProgressText {
    if (!hasMedication) {
      return 'No medications added yet';
    }
    if (isDoseTaken) {
      return 'All meds taken today';
    }
    return progress.dailyProgressText;
  }

  /// Whether to show streak badge
  bool get showStreakBadge => hasMedication && progress.showStreak;

  /// Schedule label text for card
  String getScheduleLabel(BuildContext context) {
    if (isDoseTaken) {
      return 'COMPLETED';
    }
    if (medication != null) {
      return 'SCHEDULED FOR ${medication!.formatScheduledTime(context).toUpperCase()}';
    }
    return '';
  }

  /// Whether slide-to-take is enabled
  bool get isSlideEnabled => hasMedication && !isDoseTaken;

  /// Whether footer buttons are enabled
  bool get canLogSideEffect => hasMedication;
  bool get canContactDoctor => hasMedication && medication?.doctorName != null;

  /// Contact doctor button text
  String get contactDoctorText {
    if (medication?.doctorName != null) {
      return 'Contact ${medication!.doctorName}';
    }
    return 'Contact Doctor';
  }

  /// System message for empty state
  static const String emptyStateMessage = 
      'Your medications will appear here once added by your healthcare provider.';
}
