/// Patient Vitals Ingestion Service — Automatic Health Data Pipeline
///
/// This service automatically:
/// 1. Fetches health data from Apple Health / Health Connect
/// 2. Persists to local Hive storage
/// 3. Mirrors to Firestore for caregiver/doctor access
/// 4. Triggers arrhythmia analysis when RR data is available
/// 5. Sends alerts when anomalies are detected
///
/// RUNS AUTOMATICALLY - No manual triggers required.
///
/// USAGE:
/// ```dart
/// await PatientVitalsIngestionService.instance.initialize(patientUid: 'uid123');
/// ```
library;

import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/normalized_health_data.dart';
import '../repositories/health_data_repository_hive.dart';
import 'patient_health_extraction_service.dart';
import '../../ml/services/arrhythmia_analysis_service.dart';
import '../../ml/models/arrhythmia_analysis_state.dart';
import '../../services/push_notification_sender.dart';
import '../../relationships/services/relationship_service.dart';
import '../../relationships/services/doctor_relationship_service.dart';
import '../../relationships/models/doctor_relationship_model.dart';

/// Ingestion interval
const Duration _ingestionInterval = Duration(minutes: 15);

/// Minimum RR intervals for arrhythmia analysis
const int _minRRIntervalsForAnalysis = 40;

/// Arrhythmia risk threshold for alerts
const double _arrhythmiaAlertThreshold = 0.7;

/// Vitals ingestion result
class VitalsIngestionResult {
  final bool success;
  final int vitalsCount;
  final bool arrhythmiaAnalyzed;
  final bool alertSent;
  final String? error;

  const VitalsIngestionResult({
    required this.success,
    required this.vitalsCount,
    this.arrhythmiaAnalyzed = false,
    this.alertSent = false,
    this.error,
  });

  factory VitalsIngestionResult.failure(String error) => VitalsIngestionResult(
        success: false,
        vitalsCount: 0,
        error: error,
      );
}

/// Automatic vitals ingestion service
class PatientVitalsIngestionService {
  PatientVitalsIngestionService._();

  static final PatientVitalsIngestionService _instance =
      PatientVitalsIngestionService._();
  static PatientVitalsIngestionService get instance => _instance;

  final PatientHealthExtractionService _extractionService =
      PatientHealthExtractionService.instance;
  late final HealthDataRepositoryHive _repository;
  final ArrhythmiaAnalysisService _arrhythmiaService =
      ArrhythmiaAnalysisService();
  final PushNotificationSender _pushSender = PushNotificationSender.instance;
  final RelationshipService _relationshipService = RelationshipService.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  String? _patientUid;
  Timer? _ingestionTimer;
  bool _isInitialized = false;
  bool _isRunning = false;
  DateTime? _lastIngestionTime;

  /// Whether service is initialized
  bool get isInitialized => _isInitialized;

  /// Whether ingestion is currently running
  bool get isRunning => _isRunning;

  /// Last successful ingestion time
  DateTime? get lastIngestionTime => _lastIngestionTime;

  // ═══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Initialize the ingestion service for a patient.
  ///
  /// This starts the automatic ingestion loop.
  Future<bool> initialize({String? patientUid}) async {
    if (_isInitialized) {
      debugPrint('[VitalsIngestion] Already initialized');
      return true;
    }

    _patientUid = patientUid ?? FirebaseAuth.instance.currentUser?.uid;
    if (_patientUid == null) {
      debugPrint('[VitalsIngestion] No patient UID available');
      return false;
    }

    debugPrint('[VitalsIngestion] Initializing for patient: $_patientUid');

    // Initialize repository
    _repository = HealthDataRepositoryHive();

    // Check platform availability
    final availability = await _extractionService.checkAvailability();
    if (!availability.platformSupported) {
      debugPrint('[VitalsIngestion] Health platform not available');
      return false;
    }

    // Request permissions if not already granted
    final permissions = await _extractionService.requestPermissions();
    if (!permissions.hasAnyPermission) {
      debugPrint('[VitalsIngestion] No health permissions granted');
      return false;
    }

    // Start periodic ingestion
    _startIngestionLoop();

    // Run initial ingestion immediately
    await _runIngestion();

    _isInitialized = true;
    debugPrint('[VitalsIngestion] Initialized successfully');
    return true;
  }

  /// Stop the ingestion service
  void dispose() {
    _ingestionTimer?.cancel();
    _ingestionTimer = null;
    _isInitialized = false;
    _isRunning = false;
    debugPrint('[VitalsIngestion] Disposed');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INGESTION LOOP
  // ═══════════════════════════════════════════════════════════════════════════

  /// Start the periodic ingestion loop
  void _startIngestionLoop() {
    _ingestionTimer?.cancel();
    _ingestionTimer = Timer.periodic(_ingestionInterval, (_) async {
      await _runIngestion();
    });
    debugPrint('[VitalsIngestion] Started ingestion loop (interval: ${_ingestionInterval.inMinutes}min)');
  }

  /// Run a single ingestion cycle
  Future<VitalsIngestionResult> _runIngestion() async {
    if (_isRunning) {
      debugPrint('[VitalsIngestion] Ingestion already running, skipping');
      return VitalsIngestionResult.failure('Already running');
    }

    if (_patientUid == null) {
      return VitalsIngestionResult.failure('No patient UID');
    }

    _isRunning = true;
    debugPrint('[VitalsIngestion] Starting ingestion cycle...');

    try {
      int totalVitals = 0;
      List<int> collectedRRIntervals = [];
      bool arrhythmiaAnalyzed = false;
      bool alertSent = false;

      // 1. Fetch recent vitals (heart rate, SpO2)
      final vitalsResult = await _extractionService.fetchRecentVitals(
        patientUid: _patientUid!,
        windowMinutes: 60,
      );

      if (vitalsResult.success && vitalsResult.data != null) {
        final snapshot = vitalsResult.data!;
        
        // Persist heart rate
        if (snapshot.latestHeartRate != null) {
          await _persistHeartRate(snapshot.latestHeartRate!);
          totalVitals++;
        }

        // Persist SpO2
        if (snapshot.latestOxygen != null) {
          await _persistBloodOxygen(snapshot.latestOxygen!);
          totalVitals++;
        }

        // Persist HRV and collect RR intervals
        if (snapshot.latestHRV != null) {
          await _persistHRV(snapshot.latestHRV!);
          totalVitals++;
          
          // Collect RR intervals for arrhythmia analysis
          if (snapshot.latestHRV!.rrIntervals != null) {
            collectedRRIntervals.addAll(snapshot.latestHRV!.rrIntervals!);
          }
        }
      }

      // 2. Fetch HRV data separately (for more RR intervals)
      final hrvResult = await _extractionService.fetchHRVData(
        patientUid: _patientUid!,
        windowMinutes: 120, // Look back 2 hours for HRV
      );

      if (hrvResult.success && hrvResult.data != null) {
        for (final hrv in hrvResult.data!) {
          await _persistHRV(hrv);
          totalVitals++;
          
          if (hrv.rrIntervals != null) {
            collectedRRIntervals.addAll(hrv.rrIntervals!);
          }
        }
      }

      // 3. Trigger arrhythmia analysis if enough RR data
      if (collectedRRIntervals.length >= _minRRIntervalsForAnalysis) {
        final analysisResult = await _analyzeForArrhythmia(collectedRRIntervals);
        arrhythmiaAnalyzed = true;
        
        if (analysisResult.alertSent) {
          alertSent = true;
        }
      }

      _lastIngestionTime = DateTime.now();
      _isRunning = false;

      debugPrint('[VitalsIngestion] Cycle complete: $totalVitals vitals, '
          'arrhythmia: $arrhythmiaAnalyzed, alert: $alertSent');

      return VitalsIngestionResult(
        success: true,
        vitalsCount: totalVitals,
        arrhythmiaAnalyzed: arrhythmiaAnalyzed,
        alertSent: alertSent,
      );
    } catch (e) {
      _isRunning = false;
      debugPrint('[VitalsIngestion] Error: $e');
      return VitalsIngestionResult.failure(e.toString());
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PERSISTENCE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Persist a heart rate reading
  Future<void> _persistHeartRate(NormalizedHeartRateReading hr) async {
    // Save via repository
    await _repository.saveHeartRate(hr);

    // Mirror to Firestore (fire-and-forget)
    _mirrorToFirestore('heart_rate', {
      'patient_uid': _patientUid,
      'bpm': hr.bpm,
      'timestamp': hr.timestamp.toIso8601String(),
      'is_resting': hr.isResting,
      'data_source': hr.dataSource.name,
      'device_type': hr.deviceType.name,
    });
  }

  /// Persist a blood oxygen reading
  Future<void> _persistBloodOxygen(NormalizedOxygenReading o2) async {
    // Save via repository
    await _repository.saveOxygenReading(o2);

    // Mirror to Firestore
    _mirrorToFirestore('blood_oxygen', {
      'patient_uid': _patientUid,
      'percentage': o2.percentage,
      'timestamp': o2.timestamp.toIso8601String(),
      'data_source': o2.dataSource.name,
      'device_type': o2.deviceType.name,
    });
  }

  /// Persist an HRV reading
  Future<void> _persistHRV(NormalizedHRVReading hrv) async {
    // Save via repository
    await _repository.saveHRVReading(hrv);

    // Mirror to Firestore
    _mirrorToFirestore('hrv', {
      'patient_uid': _patientUid,
      'sdnn_ms': hrv.sdnnMs,
      'rr_count': hrv.rrIntervals?.length ?? 0,
      'timestamp': hrv.timestamp.toIso8601String(),
      'data_source': hrv.dataSource.name,
      'device_type': hrv.deviceType.name,
    });
  }

  /// Mirror a reading to Firestore (fire-and-forget)
  void _mirrorToFirestore(String type, Map<String, dynamic> data) {
    _firestore
        .collection('patients')
        .doc(_patientUid)
        .collection('health_readings')
        .doc(_uuid.v4())
        .set({
      ...data,
      'type': type,
      'created_at': FieldValue.serverTimestamp(),
    }).catchError((e) {
      debugPrint('[VitalsIngestion] Firestore mirror failed: $e');
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ARRHYTHMIA ANALYSIS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Analyze RR intervals for arrhythmia
  Future<({bool analyzed, bool alertSent})> _analyzeForArrhythmia(
    List<int> rrIntervals,
  ) async {
    debugPrint('[VitalsIngestion] Analyzing ${rrIntervals.length} RR intervals for arrhythmia');

    final result = await _arrhythmiaService.analyze(
      rrIntervalsMs: rrIntervals,
      patientUid: _patientUid,
      sourceDevice: Platform.isIOS ? 'apple_watch' : 'health_connect',
      useCacheOnFailure: true,
    );

    bool alertSent = false;

    if (result is ArrhythmiaAnalysisSuccess) {
      final riskScore = result.riskProbability;
      final riskLevel = result.riskLevel;
      
      debugPrint('[VitalsIngestion] Arrhythmia analysis: risk=$riskScore, level=$riskLevel');

      // Persist analysis result
      await _persistArrhythmiaAnalysis(result);

      // Send alert if risk exceeds threshold
      if (riskScore >= _arrhythmiaAlertThreshold) {
        alertSent = await _sendArrhythmiaAlert(result);
      }
    } else if (result is ArrhythmiaAnalysisFailure) {
      debugPrint('[VitalsIngestion] Arrhythmia analysis failed: ${result.message}');
    }

    return (analyzed: true, alertSent: alertSent);
  }

  /// Persist arrhythmia analysis result to Firestore
  Future<void> _persistArrhythmiaAnalysis(ArrhythmiaAnalysisSuccess analysis) async {
    try {
      final alertId = _uuid.v4();
      
      await _firestore
          .collection('patients')
          .doc(_patientUid)
          .collection('arrhythmia_analyses')
          .doc(alertId)
          .set({
        'request_id': analysis.requestId,
        'risk_score': analysis.riskProbability,
        'risk_level': analysis.riskLevel.name,
        'recommendation': analysis.recommendation.displayMessage,
        'confidence': analysis.confidence.name,
        'analyzed_at': FieldValue.serverTimestamp(),
        'model_version': analysis.modelVersion,
      });

      debugPrint('[VitalsIngestion] Arrhythmia analysis persisted: $alertId');
    } catch (e) {
      debugPrint('[VitalsIngestion] Failed to persist arrhythmia analysis: $e');
    }
  }

  /// Send arrhythmia alert to caregivers and doctors
  Future<bool> _sendArrhythmiaAlert(ArrhythmiaAnalysisSuccess analysis) async {
    debugPrint('[VitalsIngestion] Sending arrhythmia alert...');

    try {
      // Get patient name
      final patientDoc = await _firestore.collection('users').doc(_patientUid).get();
      final patientName = patientDoc.data()?['name'] as String? ?? 'Patient';

      // Get linked caregivers
      final caregiverUids = <String>[];
      final relationships = await _relationshipService.getRelationshipsForUser(_patientUid!);
      if (relationships.success && relationships.data != null) {
        for (final rel in relationships.data!) {
          if (rel.caregiverId != null && rel.caregiverId!.isNotEmpty) {
            caregiverUids.add(rel.caregiverId!);
          }
        }
      }

      // Get linked doctors
      final doctorUids = <String>[];
      final doctorRelationships = await DoctorRelationshipService.instance
          .getRelationshipsForUser(_patientUid!);
      if (doctorRelationships.success && doctorRelationships.data != null) {
        for (final rel in doctorRelationships.data!) {
          if (rel.status == DoctorRelationshipStatus.active &&
              rel.doctorId != null &&
              rel.doctorId!.isNotEmpty) {
            doctorUids.add(rel.doctorId!);
          }
        }
      }

      // Combine all recipients
      final recipientUids = [...caregiverUids, ...doctorUids];

      if (recipientUids.isEmpty) {
        debugPrint('[VitalsIngestion] No recipients for arrhythmia alert');
        return false;
      }
      
      debugPrint('[VitalsIngestion] Alert recipients: ${caregiverUids.length} caregivers, ${doctorUids.length} doctors');

      // Create alert in Firestore
      final alertId = _uuid.v4();
      await _firestore
          .collection('patients')
          .doc(_patientUid)
          .collection('health_alerts')
          .doc(alertId)
          .set({
        'type': 'arrhythmia',
        'risk_score': analysis.riskProbability,
        'risk_level': analysis.riskLevel.name,
        'recommendation': analysis.recommendation.displayMessage,
        'created_at': FieldValue.serverTimestamp(),
        'acknowledged': false,
        'recipients': recipientUids,
        'notified_caregivers': caregiverUids,
        'notified_doctors': doctorUids,
      });

      // Send push notifications
      final result = await _pushSender.sendHealthAlert(
        patientUid: _patientUid!,
        patientName: patientName,
        alertType: 'arrhythmia',
        alertMessage: '${analysis.riskLevel.displayLabel} (${(analysis.riskProbability * 100).toInt()}% risk)',
        recipientUids: recipientUids,
        alertId: alertId,
        alertData: {
          'risk_score': analysis.riskProbability,
          'risk_level': analysis.riskLevel.name,
        },
      );

      debugPrint('[VitalsIngestion] Arrhythmia alert sent: success=${result.success}');
      return result.success;
    } catch (e) {
      debugPrint('[VitalsIngestion] Failed to send arrhythmia alert: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MANUAL TRIGGER (for testing/debugging)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Manually trigger an ingestion cycle (for testing)
  Future<VitalsIngestionResult> triggerManualIngestion() async {
    if (!_isInitialized) {
      return VitalsIngestionResult.failure('Service not initialized');
    }
    return _runIngestion();
  }
}
