/// Demo Data Definitions
///
/// Contains all fake/sample data used when Demo Mode is enabled.
/// This file centralizes demo content so it can be easily modified.
library;

import 'package:flutter/material.dart';
import 'package:guardian_angel_fyp/screens/community/community_discovery_state.dart';
import 'package:guardian_angel_fyp/screens/peace_of_mind/peace_of_mind_state.dart';
import 'package:guardian_angel_fyp/screens/medication/medication_state.dart';
import 'package:guardian_angel_fyp/screens/patient_sos/patient_sos_state.dart';
import 'package:guardian_angel_fyp/screens/patient_home/patient_home_state.dart';
import 'package:guardian_angel_fyp/screens/diagnostic/diagnostic_state.dart';

/// Demo data for Community Discovery Screen
class CommunityDemoData {
  static List<StoryItem> get stories => [
    StoryItem(
      id: 'story-1',
      name: 'Dr. Emily',
      imageUrl: 'https://images.unsplash.com/photo-1559839734-2b71ea197ec2?auto=format&fit=crop&w=300&q=80',
      isNew: true,
    ),
    StoryItem(
      id: 'story-2',
      name: 'Sarah',
      imageUrl: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?auto=format&fit=crop&w=300&q=80',
      isNew: true,
    ),
    StoryItem(
      id: 'story-3',
      name: 'Mom',
      imageUrl: 'https://images.unsplash.com/photo-1551836022-d5d88e9218df?auto=format&fit=crop&w=300&q=80',
      isNew: false,
    ),
    StoryItem(
      id: 'story-4',
      name: 'David',
      imageUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=300&q=80',
      isNew: false,
    ),
  ];

  static FeaturedCommunity get featured => FeaturedCommunity(
    id: 'featured-1',
    name: 'Heart Health Warriors',
    prompt: 'Share your morning heart-healthy breakfast!',
    onlineCount: 42,
    imageUrl: 'https://images.unsplash.com/photo-1505576399279-565b52d4ac71?auto=format&fit=crop&w=800&q=80',
  );

  static List<CommunityGroup> get communities => [
    CommunityGroup(
      id: 'community-1',
      name: 'Morning Walks',
      subtitle: '324 members',
      memberCount: 324,
      imageUrl: 'https://images.unsplash.com/photo-1476480862126-209bfaa8edc8?auto=format&fit=crop&w=800&q=80',
      isLive: true,
      latestActivity: 'Active now',
    ),
    CommunityGroup(
      id: 'community-2',
      name: 'Book Club',
      subtitle: '89 members',
      memberCount: 89,
      imageUrl: 'https://images.unsplash.com/photo-1481627834876-b7833e8f5570?auto=format&fit=crop&w=800&q=80',
      isLive: false,
      latestActivity: null,
    ),
    CommunityGroup(
      id: 'community-3',
      name: 'Prayer Circle',
      subtitle: '156 members',
      memberCount: 156,
      imageUrl: 'https://images.unsplash.com/photo-1490730141103-6cac27aaab94?auto=format&fit=crop&w=800&q=80',
      isLive: true,
      latestActivity: '7:00 AM Daily',
    ),
  ];

  static CommunityEvent get upcomingEvent => CommunityEvent(
    id: 'event-1',
    title: 'Heart Health Webinar',
    host: 'Dr. Sarah Chen',
    startTime: DateTime.now().add(const Duration(hours: 2, minutes: 45, seconds: 30)),
    imageUrl: 'https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?auto=format&fit=crop&w=800&q=80',
  );

  static CommunityDiscoveryState get state => CommunityDiscoveryState(
    stories: stories,
    featured: featured,
    communities: communities,
    upcomingEvent: upcomingEvent,
    isLoading: false,
  );
}

/// Demo data for Peace of Mind Screen
class PeaceOfMindDemoData {
  static SoundscapeData get activeSoundscape => const SoundscapeData(
    id: 'sound-1',
    name: 'Rain on Leaves',
  );

  static ReflectionPrompt get dailyPrompt => const ReflectionPrompt(
    id: 'prompt-1',
    question: 'What brought you joy today?',
  );

  static PeaceOfMindState get state => PeaceOfMindState(
    mood: MoodLevel.sunny,
    activeSoundscape: activeSoundscape,
    todayPrompt: dailyPrompt,
    isPlayingSound: false,
    isRecordingReflection: false,
  );
}

/// Demo data for Medication Screen
class MedicationDemoData {
  static MedicationData get medication => MedicationData(
    name: 'Lisinopril',
    dosage: '10mg',
    context: 'With food',
    scheduledTime: const TimeOfDay(hour: 8, minute: 0),
    inventory: const Inventory(
      remaining: 24,
      total: 30,
      status: InventoryStatus.ok,
    ),
    doctorName: 'Dr. Sarah Wilson',
    doctorNotes: 'Take in the morning with breakfast. Monitor blood pressure.',
    sideEffects: ['Dizziness', 'Dry cough', 'Fatigue'],
    pillColor: const Color(0xFFBBDEFB),
  );

  static MedicationProgress get progress => const MedicationProgress(
    streakDays: 12,
    dailyCompletion: 0.67,
  );

  static MedicationState state({required String sessionName}) => MedicationState(
    hasMedication: true,
    medication: medication,
    progress: progress,
    isDoseTaken: false,
    isCardFlipped: false,
    doseTakenAt: null,
    sessionName: sessionName,
  );
}

/// Demo data for Patient SOS Screen
class PatientSOSDemoData {
  static PatientSosState get state => PatientSosState(
    phase: SosPhase.caregiverNotified,
    elapsed: const Duration(seconds: 45),
    heartRate: 78,
    caregiverName: 'Sarah Wilson',
    locationText: '123 Main Street, Apt 4B',
    transcript: [
      'Help, I\'ve fallen...',
      'I can\'t get up...',
    ],
    medicalIdShared: true,
    isRecording: true,
    locationDenied: false,
    microphoneDenied: false,
  );
}

/// Demo data for Patient Home Dashboard Screen
class PatientHomeDemoData {
  static VitalsData get vitals => VitalsData(
    systolicBP: 120,
    diastolicBP: 80,
    heartRate: 72,
    lastUpdated: DateTime.now().subtract(const Duration(minutes: 15)),
  );

  static DoctorInfo get doctorInfo => const DoctorInfo(
    name: 'Dr. Sarah Wilson',
    specialty: 'Cardiologist',
    phoneNumber: '+1 (555) 123-4567',
    imageUrl: 'https://images.unsplash.com/photo-1559839734-2b71ea197ec2?auto=format&fit=crop&w=300&q=80',
  );

  static SafetyStatus get safetyStatus => SafetyStatus(
    status: 'All Clear',
    isAlert: false,
    lastChecked: DateTime.now().subtract(const Duration(minutes: 5)),
  );

  static DiagnosisSummary get diagnosisSummary => DiagnosisSummary(
    title: 'Heart Health',
    subtitle: 'Normal sinus rhythm detected',
    lastDiagnosisDate: DateTime.now().subtract(const Duration(days: 2)),
  );

  static List<AutomationCardData> get automationCards => const [
    AutomationCardData(
      title: 'Living Room',
      subtitle: 'Lights & AC',
      value: '72°F',
      isAvailable: true,
    ),
    AutomationCardData(
      title: 'Bedroom',
      subtitle: 'Lights',
      value: 'ON',
      isAvailable: true,
    ),
    AutomationCardData(
      title: 'Kitchen',
      subtitle: 'Appliances',
      value: 'Safe',
      isAvailable: true,
    ),
  ];

  static List<MedicationTimeSlot> get medicationSchedule => const [
    MedicationTimeSlot(
      time: '8:00 AM',
      medications: [
        MedicationEntry(
          name: 'Lisinopril',
          dose: '10mg',
          type: 'pill',
        ),
        MedicationEntry(
          name: 'Metformin',
          dose: '500mg',
          type: 'capsule',
        ),
      ],
    ),
    MedicationTimeSlot(
      time: '8:00 PM',
      medications: [
        MedicationEntry(
          name: 'Metformin',
          dose: '500mg',
          type: 'capsule',
        ),
      ],
    ),
  ];

  static PatientHomeState state({
    required String patientName,
    required String gender,
  }) => PatientHomeState(
    patientName: patientName,
    gender: gender,
    profileImageUrl: null,
    vitals: vitals,
    safetyStatus: safetyStatus,
    doctorInfo: doctorInfo,
    diagnosisSummary: diagnosisSummary,
    automationCards: automationCards,
    medicationSchedule: medicationSchedule,
    loadingState: PatientHomeLoadingState.full,
  );
}

/// Demo data for Diagnostic Screen
class DiagnosticDemoData {
  static BloodPressureData get bloodPressure => BloodPressureData(
    systolic: 118,
    diastolic: 76,
    measurementTime: DateTime.now().subtract(const Duration(hours: 1)),
    status: 'Optimal',
  );

  static TemperatureData get temperature => TemperatureData(
    value: 98.6,
    unit: 'F',
    measurementTime: DateTime.now().subtract(const Duration(hours: 2)),
    status: 'Normal',
  );

  static SleepQualityData get sleepData => SleepQualityData(
    qualityScore: 85,
    hoursSlept: 7.5,
    date: DateTime.now().subtract(const Duration(days: 1)),
    quality: 'Good',
  );

  static AIConfidenceBreakdown get confidenceBreakdown => const AIConfidenceBreakdown(
    rhythm: 0.95,
    variability: 0.88,
    pattern: 0.92,
    overall: 0.91,
  );

  /// Sample ECG data points for visualization
  static List<double> get ecgSamples {
    // Simulated ECG waveform pattern (one heartbeat cycle)
    final List<double> basePattern = [
      0.0, 0.1, 0.05, 0.0, -0.1, // P wave
      0.0, 0.2, 1.0, -0.3, 0.0, // QRS complex
      0.0, 0.1, 0.2, 0.15, 0.0, // T wave
      0.0, 0.0, 0.0, 0.0, 0.0, // baseline
    ];
    
    // Repeat pattern to create longer strip
    final List<double> samples = [];
    for (int i = 0; i < 10; i++) {
      samples.addAll(basePattern);
    }
    return samples;
  }

  /// Sample R-R intervals in milliseconds
  static List<int> get rrIntervals => const [
    856, 862, 848, 870, 855, 863, 850, 868, 857, 865,
  ];

  static DiagnosticState get state => DiagnosticState(
    hasDeviceConnected: true,
    hasAnyDiagnosticData: true,
    heartRate: 72,
    targetHeartRate: 75,
    rrIntervals: rrIntervals,
    ecgSamples: ecgSamples,
    selectedLead: 'Lead I',
    heartRhythm: 'Normal Sinus Rhythm',
    aiStatusMessage: 'Your heart rhythm appears normal',
    aiAnalysisStatus: 'Analysis complete',
    aiConfidence: 0.91,
    confidenceBreakdown: confidenceBreakdown,
    isStressDetected: false,
    hasCriticalAlert: false,
    bloodPressure: bloodPressure,
    temperature: temperature,
    sleep: sleepData,
    hasDiagnosticHistory: true,
  );
}
