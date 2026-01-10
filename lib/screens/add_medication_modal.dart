import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../utils/input_validators.dart';

class AddMedicationModal extends StatefulWidget {
  final VoidCallback onClose;
  final Function(Map<String, dynamic>) onSave;

  const AddMedicationModal({
    Key? key,
    required this.onClose,
    required this.onSave,
  }) : super(key: key);

  @override
  _AddMedicationModalState createState() => _AddMedicationModalState();
}

class _AddMedicationModalState extends State<AddMedicationModal> {
  int _step = 0;
  final int _totalSteps = 4;

  // Form Data
  String _name = '';
  String _type = 'pill'; // pill, infusion, injection
  String _dosage = '';
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  String _instructions = 'As directed';
  int _volumeML = 500;
  int _durationMinutes = 120;
  int _alertThreshold = 10;
  int _initialStock = 30;
  int _lowStockLevel = 5;

  // Validation error messages
  String? _nameError;
  String? _dosageError;
  String? _volumeError;
  String? _durationError;
  String? _stockError;

  // Text controllers for input formatting
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    super.dispose();
  }

  /// Validates current step and returns true if valid
  bool _validateCurrentStep() {
    setState(() {
      _nameError = null;
      _dosageError = null;
      _volumeError = null;
      _durationError = null;
      _stockError = null;
    });

    switch (_step) {
      case 0: // Name & Type
        final nameValidation = InputValidators.validateMedicationName(_name);
        if (nameValidation != null) {
          setState(() => _nameError = nameValidation);
          return false;
        }
        return true;

      case 1: // Dosage / Volume
        if (_type == 'infusion') {
          final volumeValidation = InputValidators.validateInfusionVolume(_volumeML);
          final durationValidation = InputValidators.validateInfusionDuration(_durationMinutes);
          if (volumeValidation != null) {
            setState(() => _volumeError = volumeValidation);
            return false;
          }
          if (durationValidation != null) {
            setState(() => _durationError = durationValidation);
            return false;
          }
        } else {
          final dosageValidation = InputValidators.validateDosage(_dosage);
          if (dosageValidation != null) {
            setState(() => _dosageError = dosageValidation);
            return false;
          }
        }
        return true;

      case 2: // Stock
        final stockValidation = InputValidators.validateStockCount(_initialStock);
        if (stockValidation != null) {
          setState(() => _stockError = stockValidation);
          return false;
        }
        return true;

      default:
        return true;
    }
  }

  void _handleNext() {
    // Validate current step before proceeding
    if (!_validateCurrentStep()) {
      return;
    }

    if (_step < _totalSteps - 1) {
      setState(() {
        _step++;
      });
    } else {
      // Final validation before save
      if (!_validateCurrentStep()) return;

      // Sanitize inputs before saving
      final sanitizedName = InputValidators.sanitizeMedicationName(_name);
      
      final isInfusion = _type == 'infusion';
      final newMed = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': sanitizedName,
        'dosage': isInfusion ? '${_volumeML}ml' : InputValidators.sanitize(_dosage),
        'dailyDosage': isInfusion ? '${_volumeML}ml / ${_durationMinutes}m' : 'N/A',
        'type': isInfusion ? 'IV Infusion' : 'Medication',
        'subType': _type,
        'instructions': isInfusion ? 'Infuse over $_durationMinutes minutes' : _instructions,
        'time': '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
        'iconType': _type == 'pill' ? 'pill' : _type == 'infusion' ? 'infusion' : 'bottle',
        'isInfusion': isInfusion,
        'totalVolumeML': isInfusion ? _volumeML : null,
        'durationMinutes': isInfusion ? _durationMinutes : null,
        'alertThresholdMinutes': isInfusion ? _alertThreshold : null,
        'currentStock': _initialStock,
        'lowStockThreshold': _lowStockLevel,
      };
      widget.onSave(newMed);
      widget.onClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFDFD),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildProgressIndicators(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: _buildStepContent(),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Add New',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          GestureDetector(
            onTap: widget.onClose,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(
                CupertinoIcons.xmark,
                color: Color(0xFF0F172A),
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicators() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Row(
        children: List.generate(_totalSteps, (index) {
          return Expanded(
            child: Container(
              height: 5,
              margin: EdgeInsets.only(right: index < _totalSteps - 1 ? 8 : 0),
              decoration: BoxDecoration(
                color: index <= _step ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _buildStep1Label();
      case 1:
        return _buildStep2Dosage();
      case 2:
        return _buildStep3Stock();
      case 3:
        return _buildStep4Review();
      default:
        return const SizedBox.shrink();
    }
  }

  // Step 1: Label & Type
  Widget _buildStep1Label() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('Medicine Name'),
        const SizedBox(height: 16),
        Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _nameError != null ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0), 
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.centerLeft,
          child: TextField(
            controller: _nameController,
            autofocus: true,
            maxLength: 100,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z0-9\s\-\(\)\.]")),
              LengthLimitingTextInputFormatter(100),
            ],
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'e.g. Amoxicillin',
              counterText: '', // Hide character counter
              hintStyle: GoogleFonts.inter(
                color: const Color(0xFF94A3B8),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _name = value;
                _nameError = null; // Clear error on change
              });
            },
          ),
        ),
        // Error message display
        if (_nameError != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              _nameError!,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFFDC2626),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        const SizedBox(height: 40),
        _buildSectionLabel('Type'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _TypeCard(
                active: _type == 'pill',
                icon: CupertinoIcons.capsule_fill,
                label: 'Pill',
                onTap: () => setState(() => _type = 'pill'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _TypeCard(
                active: _type == 'infusion',
                icon: CupertinoIcons.drop_fill,
                label: 'Drip',
                onTap: () => setState(() => _type = 'infusion'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _TypeCard(
                active: _type == 'injection',
                icon: Icons.vaccines, // Material icon for syringe
                label: 'Shot',
                onTap: () => setState(() => _type = 'injection'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Step 2: Dosage / Volume
  Widget _buildStep2Dosage() {
    if (_type == 'infusion') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('Total Volume (ml)'),
          const SizedBox(height: 16),
          Row(
            children: [
              _AdjustButton(
                label: '-',
                onTap: () => setState(() {
                  _volumeML = (_volumeML - 50).clamp(10, 3000);
                  _volumeError = null;
                }),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _volumeError != null ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0), 
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '$_volumeML',
                          style: GoogleFonts.inter(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        TextSpan(
                          text: ' ml',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              _AdjustButton(
                label: '+',
                onTap: () => setState(() {
                  _volumeML = (_volumeML + 50).clamp(10, 3000);
                  _volumeError = null;
                }),
              ),
            ],
          ),
          // Volume error message
          if (_volumeError != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                _volumeError!,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFFDC2626),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          // Volume range hint
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              'Range: 10ml - 3000ml',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ),
          const SizedBox(height: 32),
          _buildSectionLabel('Time Duration (minutes)'),
          const SizedBox(height: 16),
          Row(
            children: [
              _AdjustButton(
                label: '-',
                onTap: () => setState(() {
                  _durationMinutes = (_durationMinutes - 15).clamp(5, 720);
                  _durationError = null;
                }),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _durationError != null ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0), 
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '$_durationMinutes',
                          style: GoogleFonts.inter(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        TextSpan(
                          text: ' min',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              _AdjustButton(
                label: '+',
                onTap: () => setState(() {
                  _durationMinutes = (_durationMinutes + 15).clamp(5, 720);
                  _durationError = null;
                }),
              ),
            ],
          ),
          // Duration error message
          if (_durationError != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                _durationError!,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFFDC2626),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          // Duration range hint
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              'Range: 5 min - 12 hours (720 min)',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('Log Time'),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () async {
              final TimeOfDay? picked = await showTimePicker(
                context: context,
                initialTime: _time,
              );
              if (picked != null && picked != _time) {
                setState(() {
                  _time = picked;
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.clock, color: Color(0xFF2563EB), size: 32),
                  const SizedBox(width: 16),
                  Text(
                    _time.format(context),
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
          _buildSectionLabel('Daily Dosage'),
          const SizedBox(height: 16),
          Container(
            height: 80,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _dosageError != null ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0), 
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.centerLeft,
            child: TextField(
              controller: _dosageController,
              maxLength: 50,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z0-9\s\-\.\/\(\)]")),
                LengthLimitingTextInputFormatter(50),
              ],
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                counterText: '', // Hide character counter
                hintText: 'e.g. 500mg or 2 tablets',
                hintStyle: GoogleFonts.inter(
                  color: const Color(0xFF94A3B8),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _dosage = value;
                  _dosageError = null;
                });
              },
            ),
          ),
          // Dosage error message
          if (_dosageError != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                _dosageError!,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFFDC2626),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      );
    }
  }

  // Step 3: Stock
  Widget _buildStep3Stock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFDBEAFE)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(CupertinoIcons.cube_box, color: Color(0xFF2563EB), size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  "Set current stock to get a reminder when it's time to refill.",
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E40AF),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        _buildSectionLabel('Units Available'),
        const SizedBox(height: 16),
        Row(
          children: [
            _AdjustButton(
              label: '-',
              onTap: () => setState(() {
                _initialStock = (_initialStock - 5).clamp(0, 500);
                _stockError = null;
              }),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _stockError != null ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0), 
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  '$_initialStock',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            _AdjustButton(
              label: '+',
              onTap: () => setState(() {
                _initialStock = (_initialStock + 5).clamp(0, 500);
                _stockError = null;
              }),
            ),
          ],
        ),
        // Stock error message
        if (_stockError != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              _stockError!,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFFDC2626),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        // Stock range hint
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text(
            'Range: 0 - 500 units',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ),
      ],
    );
  }

  // Step 4: Review
  Widget _buildStep4Review() {
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFD1FAE5), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            CupertinoIcons.check_mark,
            color: Color(0xFF059669),
            size: 48,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Confirm Details',
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SummaryRow(label: 'Treatment', value: _name.isNotEmpty ? _name : 'Untitled'),
              const SizedBox(height: 24),
              const Divider(color: Color(0xFFF1F5F9), thickness: 1),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _SummaryRow(
                      label: 'Amount',
                      value: _type == 'infusion' ? '${_volumeML}ml' : _dosage,
                    ),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    child: _SummaryRow(
                      label: 'Time',
                      value: _type == 'infusion'
                          ? '${_durationMinutes}m'
                          : '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFFFDFDFD),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: (_step == 0 && _name.isEmpty) ? null : _handleNext,
        child: Opacity(
          opacity: (_step == 0 && _name.isEmpty) ? 0.3 : 1.0,
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _step == _totalSteps - 1 ? 'Save & Start' : 'Continue',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  CupertinoIcons.right_chevron,
                  color: Colors.white,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF64748B),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final bool active;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _TypeCard({
    Key? key,
    required this.active,
    required this.icon,
    required this.label,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: active ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
            width: 2,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: active ? Colors.white : const Color(0xFF94A3B8),
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : const Color(0xFF94A3B8),
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdjustButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AdjustButton({
    Key? key,
    required this.label,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({
    Key? key,
    required this.label,
    required this.value,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF94A3B8),
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
            height: 1.2,
          ),
        ),
      ],
    );
  }
}
