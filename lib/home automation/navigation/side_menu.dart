import 'package:flutter/material.dart';
import '../../services/patient_service.dart';
import '../models/menu_item.dart';
import '../components/menu_row.dart';

class SideMenu extends StatefulWidget {
  final Function(String)? onMenuSelected;

  const SideMenu({
    super.key,
    this.onMenuSelected,
  });

  @override
  State<SideMenu> createState() => _SideMenuState();
}

class _SideMenuState extends State<SideMenu> {
  String selectedMenuId = "home";
  
  // Patient data
  String _patientName = 'Patient';
  String _gender = 'male';

  @override
  void initState() {
    super.initState();
    _loadPatientData();
  }
  
  Future<void> _loadPatientData() async {
    final name = await PatientService.instance.getPatientName();
    final gender = await PatientService.instance.getPatientGender();
    if (mounted) {
      setState(() {
        _patientName = name.isNotEmpty ? name : 'Patient';
        _gender = gender.toLowerCase();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 288,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8FA), // Off-white background
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      // Removed SafeArea to allow content to extend under system UI
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Padding(
              padding: EdgeInsets.only(
                // Keep some spacing; previously added status bar padding + 20
                top: 20,
                left: 24,
                right: 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image: AssetImage(
                          _gender == 'female' ? 'images/female.jpg' : 'images/male.jpg',
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Name
                  const Text(
                    'Welcome home,',
                    style: TextStyle(
                      color: Color(0xFF9E9E9E),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Username
                  Text(
                    _patientName,
                    style: const TextStyle(
                      color: Color(0xFF1A1438),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Menu items
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: menuItems.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = menuItems[index];
                  return MenuRow(
                    data: item,
                    isActive: selectedMenuId == item.id,
                    onTap: () {
                      setState(() {
                        selectedMenuId = item.id;
                      });
                      // Notify parent about menu selection
                      widget.onMenuSelected?.call(item.id);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      );
  }
}
