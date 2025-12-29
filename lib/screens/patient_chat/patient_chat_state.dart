/// Patient Chat Screen State Model
/// 
/// Production-safe state model for patient chat screen.
/// First-time users see empty states with helpful guidance messages.
/// 
/// NO FAKE DATA - All fields are nullable or empty by default.

import 'package:guardian_angel_fyp/screens/patient_chat_screen.dart';

/// Status model for medication tracking
class MedicationStatus {
  final String status; // e.g., "On track", "1 missed", etc.
  final int progressPercent; // 0-100
  final String? nextDose; // e.g., "2:00 PM"
  
  const MedicationStatus({
    required this.status,
    required this.progressPercent,
    this.nextDose,
  });
  
  /// Empty status for first-time users
  static const MedicationStatus empty = MedicationStatus(
    status: 'No medications added',
    progressPercent: 0,
    nextDose: null,
  );
}

/// Status model for peace of mind / mindfulness tracking
class PeaceStatus {
  final String status; // e.g., "Daily streak: 5 days"
  final int progressPercent; // 0-100
  final String? timeRemaining; // e.g., "2 mins left"
  
  const PeaceStatus({
    required this.status,
    required this.progressPercent,
    this.timeRemaining,
  });
  
  /// Empty status for first-time users
  static const PeaceStatus empty = PeaceStatus(
    status: 'Start your wellness journey',
    progressPercent: 0,
    timeRemaining: null,
  );
}

/// Status model for community engagement
class CommunityStatus {
  final String status; // e.g., "3 active discussions"
  final int activeDiscussions;
  final int unreadNotifications;
  
  const CommunityStatus({
    required this.status,
    required this.activeDiscussions,
    required this.unreadNotifications,
  });
  
  /// Empty status for first-time users
  static const CommunityStatus empty = CommunityStatus(
    status: 'Join the community',
    activeDiscussions: 0,
    unreadNotifications: 0,
  );
}

/// Main state model for Patient Chat Screen
class PatientChatState {
  /// Patient's display name (from onboarding or profile)
  final String patientName;
  
  /// Today's date for greeting display
  final DateTime today;
  
  /// List of care team members (caregivers, doctors)
  /// Empty list for first-time users
  final List<ChatSession> careTeam;
  
  /// Total unread messages across all chats
  final int totalUnreadMessages;
  
  /// Medication tracking status - null if no medications configured
  final MedicationStatus? medicationStatus;
  
  /// Peace of mind / mindfulness status - null if not started
  final PeaceStatus? peaceStatus;
  
  /// Community engagement status - null if not joined
  final CommunityStatus? communityStatus;
  
  /// Dynamic Island subtitle text
  final String dynamicIslandSubtitle;
  
  const PatientChatState({
    required this.patientName,
    required this.today,
    required this.careTeam,
    required this.totalUnreadMessages,
    this.medicationStatus,
    this.peaceStatus,
    this.communityStatus,
    required this.dynamicIslandSubtitle,
  });
  
  /// Create initial empty state for first-time users
  /// 
  /// Returns a state with:
  /// - Empty care team list
  /// - Zero unread messages
  /// - Null status fields (triggers empty state UI)
  /// - "Ready when you need help" dynamic island message
  factory PatientChatState.initial(String patientName) {
    return PatientChatState(
      patientName: patientName,
      today: DateTime.now(),
      careTeam: const [],
      totalUnreadMessages: 0,
      medicationStatus: null,
      peaceStatus: null,
      communityStatus: null,
      dynamicIslandSubtitle: 'Ready when you need help',
    );
  }
  
  /// Check if user has any care team members
  bool get hasCareTeam => careTeam.isNotEmpty;
  
  /// Check if user has any active chats
  bool get hasAnyChats => totalUnreadMessages > 0 || careTeam.any((s) => s.unreadCount > 0);
  
  /// Check if medication tracking is set up
  bool get hasMedication => medicationStatus != null;
  
  /// Check if peace of mind features are active
  bool get hasPeaceSetup => peaceStatus != null;
  
  /// Check if community is joined
  bool get hasCommunity => communityStatus != null;
  
  /// Get greeting based on time of day
  String get timeBasedGreeting {
    final hour = today.hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }
  
  /// Get formatted date string
  String get formattedDate {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    
    final weekday = weekdays[today.weekday - 1];
    final month = months[today.month - 1];
    final day = today.day;
    
    return '$weekday, $month $day';
  }
  
  /// Create a copy with updated fields
  PatientChatState copyWith({
    String? patientName,
    DateTime? today,
    List<ChatSession>? careTeam,
    int? totalUnreadMessages,
    MedicationStatus? medicationStatus,
    PeaceStatus? peaceStatus,
    CommunityStatus? communityStatus,
    String? dynamicIslandSubtitle,
    bool clearMedicationStatus = false,
    bool clearPeaceStatus = false,
    bool clearCommunityStatus = false,
  }) {
    return PatientChatState(
      patientName: patientName ?? this.patientName,
      today: today ?? this.today,
      careTeam: careTeam ?? this.careTeam,
      totalUnreadMessages: totalUnreadMessages ?? this.totalUnreadMessages,
      medicationStatus: clearMedicationStatus ? null : (medicationStatus ?? this.medicationStatus),
      peaceStatus: clearPeaceStatus ? null : (peaceStatus ?? this.peaceStatus),
      communityStatus: clearCommunityStatus ? null : (communityStatus ?? this.communityStatus),
      dynamicIslandSubtitle: dynamicIslandSubtitle ?? this.dynamicIslandSubtitle,
    );
  }
}
