
class MockPatient {
  static const String name = 'Eleanor Pena';
  // Using a reliable placeholder since network images can fail
  static const String? photoUrl = null; // Set to null to use fallback icon
  static const String id = 'GA-8829';
  static const int age = 78;
}

class MockAlerts {
  static const List<Map<String, dynamic>> data = [
    {
      'id': '1',
      'type': 'SOS',
      'description': 'Emergency button pressed in Living Room',
      'timestamp': '2m ago',
      'resolved': false,
    },
    {
      'id': '2',
      'type': 'Fall',
      'description': 'Fall detected in Kitchen area',
      'timestamp': '15m ago',
      'resolved': false,
    },
    {
      'id': '3',
      'type': 'Geo-Fence',
      'description': 'Patient left designated safe zone',
      'timestamp': '1h ago',
      'resolved': true,
    },
    {
      'id': '4',
      'type': 'Medication',
      'description': 'Missed afternoon dose: Heart Medication',
      'timestamp': '3h ago',
      'resolved': true,
    },
  ];
}
