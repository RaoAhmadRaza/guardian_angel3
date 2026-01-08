import 'package:flutter/material.dart';
import 'screens/caregiver_portal/caregiver_portal_screen.dart';

class CaregiverMainScreen extends StatelessWidget {
  final String? caregiverName;
  final String? patientName;
  final String? relationship;
  final String? phone;
  final String? email;

  const CaregiverMainScreen({
    super.key,
    this.caregiverName,
    this.patientName,
    this.relationship,
    this.phone,
    this.email,
  });

  @override
  Widget build(BuildContext context) {
    return const CaregiverPortalScreen();
  }
}
