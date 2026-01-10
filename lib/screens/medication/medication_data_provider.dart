import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/demo_mode_service.dart';
import '../../services/demo_data.dart';
import '../../services/medication_service.dart';
import '../../models/medication_model.dart';
import '../../services/session_service.dart';
import 'medication_state.dart';

/// Medication Data Provider
/// 
/// PRODUCTION-READY: Loads medication data from MedicationService.
/// Supports Demo Mode for showcasing UI with sample data.
/// 
/// Bridges MedicationModel (storage) with MedicationData (UI).
class MedicationDataProvider extends ChangeNotifier {
  MedicationState _state;
  String? _patientId;
  MedicationModel? _currentMedicationModel;
  
  // Keys for dose history persistence
  static const String _keyDoseHistory = 'medication_dose_history';
  static const String _keyStreakCount = 'medication_streak_count';
  static const String _keyLastDoseDate = 'medication_last_dose_date';
  
  MedicationDataProvider({required String sessionName}) 
      : _state = MedicationState.empty(sessionName: sessionName);
  
  /// Current state
  MedicationState get state => _state;
  
  /// Stream controller for state changes
  final _stateController = StreamController<MedicationState>.broadcast();
  Stream<MedicationState> get stateStream => _stateController.stream;
  
  /// Load initial state from MedicationService
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
      
      // Get patient ID from session
      _patientId = await SessionService.instance.getCurrentUid();
      if (_patientId == null || _patientId!.isEmpty) {
        debugPrint('[MedicationDataProvider] No patient ID found');
        _notifyStateChange();
        return _state;
      }
      
      // Load medications from MedicationService
      final medications = await MedicationService.instance.getMedications(_patientId!);
      
      if (medications.isEmpty) {
        debugPrint('[MedicationDataProvider] No medications found for patient');
        _notifyStateChange();
        return _state;
      }
      
      // Find medication that matches current hour, otherwise use first
      final currentHour = DateTime.now().hour;
      _currentMedicationModel = medications.firstWhere(
        (med) {
          final timeParts = med.time.split(':');
          final medHour = int.tryParse(timeParts[0]) ?? -1;
          return medHour == currentHour;
        },
        orElse: () => medications.first,
      );
      
      debugPrint('[MedicationDataProvider] Current hour: $currentHour, selected medication time: ${_currentMedicationModel!.time}');
      
      // Load dose history and progress
      final progress = await _loadProgress();
      final isDoseTaken = await _checkIfTakenToday();
      final doseTakenAt = await _getTodayDoseTime();
      
      // Convert MedicationModel to MedicationData for UI
      final medicationData = _convertToMedicationData(_currentMedicationModel!);
      
      _state = MedicationState(
        hasMedication: true,
        medication: medicationData,
        progress: progress,
        isDoseTaken: isDoseTaken,
        isCardFlipped: false,
        doseTakenAt: doseTakenAt,
        sessionName: _state.sessionName,
      );
      
      debugPrint('[MedicationDataProvider] Loaded medication: ${_currentMedicationModel!.name}');
      _notifyStateChange();
      return _state;
    } catch (e) {
      debugPrint('[MedicationDataProvider] Error loading medication state: $e');
      return _state;
    }
  }
  
  /// Convert MedicationModel (storage) to MedicationData (UI)
  MedicationData _convertToMedicationData(MedicationModel model) {
    // Parse time from 24h format "HH:mm"
    final timeParts = model.time.split(':');
    final hour = int.tryParse(timeParts[0]) ?? 8;
    final minute = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;
    
    // Determine inventory status based on stock
    InventoryStatus inventoryStatus;
    if (model.currentStock <= model.lowStockThreshold) {
      inventoryStatus = InventoryStatus.refill;
    } else if (model.currentStock <= model.lowStockThreshold * 2) {
      inventoryStatus = InventoryStatus.low;
    } else {
      inventoryStatus = InventoryStatus.ok;
    }
    
    // Get pill color based on medication type
    Color pillColor;
    switch (model.type.toLowerCase()) {
      case 'capsule':
        pillColor = const Color(0xFFBBDEFB); // Blue
        break;
      case 'liquid':
        pillColor = const Color(0xFFFFE0B2); // Orange
        break;
      case 'injection':
        pillColor = const Color(0xFFC8E6C9); // Green
        break;
      default:
        pillColor = const Color(0xFFE1BEE7); // Purple for pills
    }
    
    return MedicationData(
      name: model.name,
      dosage: model.dose,
      context: null, // Could be added to model if needed
      scheduledTime: TimeOfDay(hour: hour, minute: minute),
      inventory: Inventory(
        remaining: model.currentStock,
        total: model.currentStock + 30, // Estimate total based on current + refill
        status: inventoryStatus,
      ),
      doctorName: null, // Could be added to model if needed
      doctorNotes: null,
      sideEffects: const [],
      pillColor: pillColor,
      refillId: null,
      insertUrl: null,
    );
  }
  
  /// Load progress data from SharedPreferences
  Future<MedicationProgress> _loadProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final streakCount = prefs.getInt(_keyStreakCount) ?? 0;
      
      // Calculate daily completion based on whether dose was taken
      final isTakenToday = await _checkIfTakenToday();
      
      return MedicationProgress(
        streakDays: streakCount,
        dailyCompletion: isTakenToday ? 1.0 : 0.0,
      );
    } catch (e) {
      debugPrint('[MedicationDataProvider] Error loading progress: $e');
      return MedicationProgress.empty;
    }
  }
  
  /// Check if dose was taken today
  Future<bool> _checkIfTakenToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastDoseDateStr = prefs.getString(_keyLastDoseDate);
      if (lastDoseDateStr == null) return false;
      
      final lastDoseDate = DateTime.tryParse(lastDoseDateStr);
      if (lastDoseDate == null) return false;
      
      final today = DateTime.now();
      return lastDoseDate.year == today.year &&
             lastDoseDate.month == today.month &&
             lastDoseDate.day == today.day;
    } catch (e) {
      debugPrint('[MedicationDataProvider] Error checking today dose: $e');
      return false;
    }
  }
  
  /// Get the time when today's dose was taken
  Future<DateTime?> _getTodayDoseTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastDoseDateStr = prefs.getString(_keyLastDoseDate);
      if (lastDoseDateStr == null) return null;
      
      final lastDoseDate = DateTime.tryParse(lastDoseDateStr);
      if (lastDoseDate == null) return null;
      
      final today = DateTime.now();
      if (lastDoseDate.year == today.year &&
          lastDoseDate.month == today.month &&
          lastDoseDate.day == today.day) {
        return lastDoseDate;
      }
      return null;
    } catch (e) {
      debugPrint('[MedicationDataProvider] Error getting dose time: $e');
      return null;
    }
  }
  
  /// Mark dose as taken
  /// 
  /// Updates local storage and state.
  /// Idempotent - calling multiple times won't double-record.
  Future<void> markDoseTaken() async {
    if (!_state.hasMedication || _state.isDoseTaken) {
      return;
    }
    
    final now = DateTime.now();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if this is a consecutive day (for streak)
      final lastDoseDateStr = prefs.getString(_keyLastDoseDate);
      bool isConsecutiveDay = false;
      
      if (lastDoseDateStr != null) {
        final lastDoseDate = DateTime.tryParse(lastDoseDateStr);
        if (lastDoseDate != null) {
          final yesterday = DateTime(now.year, now.month, now.day - 1);
          isConsecutiveDay = lastDoseDate.year == yesterday.year &&
                            lastDoseDate.month == yesterday.month &&
                            lastDoseDate.day == yesterday.day;
        }
      }
      
      // Update streak count
      int currentStreak = prefs.getInt(_keyStreakCount) ?? 0;
      if (isConsecutiveDay) {
        currentStreak++;
      } else if (!(await _checkIfTakenToday())) {
        // Reset streak if not consecutive (but don't reset if same day)
        currentStreak = 1;
      }
      
      // Save to SharedPreferences
      await prefs.setString(_keyLastDoseDate, now.toIso8601String());
      await prefs.setInt(_keyStreakCount, currentStreak);
      
      // Update medication stock in MedicationService
      if (_currentMedicationModel != null) {
        final newStock = (_currentMedicationModel!.currentStock - 1).clamp(0, 500);
        await MedicationService.instance.updateStock(_currentMedicationModel!.id, newStock);
        
        // Update local model
        _currentMedicationModel = _currentMedicationModel!.copyWith(currentStock: newStock);
      }
      
      debugPrint('[MedicationDataProvider] Dose marked as taken. Streak: $currentStreak');
      
      // Update state
      _state = _state.copyWith(
        isDoseTaken: true,
        doseTakenAt: now,
        progress: MedicationProgress(
          streakDays: currentStreak,
          dailyCompletion: 1.0,
        ),
        // Update inventory in medication data
        medication: _currentMedicationModel != null 
            ? _convertToMedicationData(_currentMedicationModel!)
            : _state.medication,
      );
      
      _notifyStateChange();
    } catch (e) {
      debugPrint('[MedicationDataProvider] Error marking dose: $e');
    }
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
  
  /// Called when medication is added
  Future<void> onMedicationAdded(MedicationModel medication) async {
    _currentMedicationModel = medication;
    final medicationData = _convertToMedicationData(medication);
    
    _state = _state.copyWith(
      hasMedication: true,
      medication: medicationData,
    );
    
    _notifyStateChange();
  }
  
  /// Called when medication is updated
  Future<void> onMedicationUpdated(MedicationModel medication) async {
    if (!_state.hasMedication) return;
    
    _currentMedicationModel = medication;
    final medicationData = _convertToMedicationData(medication);
    
    _state = _state.copyWith(medication: medicationData);
    _notifyStateChange();
  }
  
  /// Called when medication is removed
  Future<void> onMedicationRemoved() async {
    _currentMedicationModel = null;
    
    _state = _state.copyWith(
      hasMedication: false,
      clearMedication: true,
      isDoseTaken: false,
      clearDoseTakenAt: true,
      progress: MedicationProgress.empty,
    );
    
    _notifyStateChange();
  }
  
  /// Refresh progress from dose history
  Future<void> refreshProgress() async {
    if (!_state.hasMedication) return;
    
    final progress = await _loadProgress();
    _state = _state.copyWith(progress: progress);
    
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
