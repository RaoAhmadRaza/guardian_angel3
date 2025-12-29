import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/demo_mode_service.dart';
import '../../services/demo_data.dart';
import 'medication_state.dart';

/// Medication Data Provider
/// 
/// PRODUCTION-SAFE: Loads medication data from local storage ONLY.
/// Supports Demo Mode for showcasing UI with sample data.
/// 
/// NO Firebase reads.
/// NO auto-creation of medications.
/// 
/// If no medication exists → returns hasMedication = false (unless demo mode)
class MedicationDataProvider extends ChangeNotifier {
  MedicationState _state;
  
  MedicationDataProvider({required String sessionName}) 
      : _state = MedicationState.empty(sessionName: sessionName);
  
  /// Current state
  MedicationState get state => _state;
  
  /// Stream controller for state changes
  final _stateController = StreamController<MedicationState>.broadcast();
  Stream<MedicationState> get stateStream => _stateController.stream;
  
  /// Load initial state from local storage
  /// Returns demo data if Demo Mode is enabled
  /// Returns empty state if no medication exists when demo mode is off.
  Future<MedicationState> loadInitialState() async {
    try {
      // Check if demo mode is enabled
      await DemoModeService.instance.initialize();
      if (DemoModeService.instance.isEnabled) {
        _state = MedicationDemoData.state(sessionName: _state.sessionName);
        _notifyStateChange();
        return _state;
      }
      
      // TODO: Replace with actual Hive/local storage read
      // For now, return empty state (first-time user behavior)
      
      // Example of what real implementation would look like:
      // final box = await Hive.openBox<MedicationData>('medications');
      // final medication = box.get('current_medication');
      // final doseHistory = await _loadDoseHistory();
      // final progress = _calculateProgress(doseHistory);
      // 
      // if (medication != null) {
      //   _state = MedicationState(
      //     hasMedication: true,
      //     medication: medication,
      //     progress: progress,
      //     isDoseTaken: _checkIfTakenToday(doseHistory),
      //     isCardFlipped: false,
      //     doseTakenAt: _getTodayDoseTime(doseHistory),
      //     sessionName: _state.sessionName,
      //   );
      // }
      
      // Return current state (empty for first-time users)
      _notifyStateChange();
      return _state;
    } catch (e) {
      // On error, return empty state
      debugPrint('Error loading medication state: $e');
      return _state;
    }
  }
  
  /// Mark dose as taken
  /// 
  /// Updates local storage and state.
  /// Idempotent - calling multiple times won't double-record.
  Future<void> markDoseTaken() async {
    if (!_state.hasMedication || _state.isDoseTaken) {
      // No medication or already taken - no-op
      return;
    }
    
    final now = DateTime.now();
    
    // TODO: Save to local storage
    // final box = await Hive.openBox<DoseRecord>('dose_history');
    // await box.add(DoseRecord(
    //   medicationId: _state.medication!.name, // or actual ID
    //   takenAt: now,
    // ));
    
    // Update state
    _state = _state.copyWith(
      isDoseTaken: true,
      doseTakenAt: now,
      progress: MedicationProgress(
        streakDays: _state.progress.streakDays + (_isNewStreak() ? 1 : 0),
        dailyCompletion: 1.0,
      ),
    );
    
    _notifyStateChange();
  }
  
  /// Toggle card flip state
  void toggleCardFlip() {
    _state = _state.copyWith(isCardFlipped: !_state.isCardFlipped);
    _notifyStateChange();
  }
  
  /// Set card flip state explicitly
  void setCardFlipped(bool flipped) {
    if (_state.isCardFlipped != flipped) {
      _state = _state.copyWith(isCardFlipped: flipped);
      _notifyStateChange();
    }
  }
  
  /// Check if this would be a new streak day
  bool _isNewStreak() {
    // Would need to check dose history to determine
    // For now, assume it's a new streak day
    return true;
  }
  
  // ============================================================
  // METHODS FOR FUTURE IMPLEMENTATION
  // ============================================================
  
  /// Called when medication is added by healthcare provider
  /// This would be triggered by a sync or push notification
  Future<void> onMedicationAdded(MedicationData medication) async {
    _state = _state.copyWith(
      hasMedication: true,
      medication: medication,
    );
    
    // TODO: Save to local storage
    _notifyStateChange();
  }
  
  /// Called when medication is updated
  Future<void> onMedicationUpdated(MedicationData medication) async {
    if (!_state.hasMedication) return;
    
    _state = _state.copyWith(medication: medication);
    
    // TODO: Save to local storage
    _notifyStateChange();
  }
  
  /// Called when medication is removed
  Future<void> onMedicationRemoved() async {
    _state = _state.copyWith(
      hasMedication: false,
      clearMedication: true,
      isDoseTaken: false,
      clearDoseTakenAt: true,
      progress: MedicationProgress.empty,
    );
    
    // TODO: Update local storage
    _notifyStateChange();
  }
  
  /// Refresh progress from dose history
  Future<void> refreshProgress() async {
    if (!_state.hasMedication) return;
    
    // TODO: Load dose history and calculate progress
    // final doseHistory = await _loadDoseHistory();
    // final progress = _calculateProgress(doseHistory);
    // _state = _state.copyWith(progress: progress);
    
    _notifyStateChange();
  }
  
  /// Notify listeners of state change
  void _notifyStateChange() {
    _stateController.add(_state);
    notifyListeners();
  }
  
  @override
  void dispose() {
    _stateController.close();
    super.dispose();
  }
}
