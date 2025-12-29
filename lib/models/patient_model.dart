enum PatientStatus { stable, critical }

class Patient {
  final String id;
  final String name;
  final int age;
  final String photo;
  final PatientStatus status;
  final String lastUpdate;
  final List<String> conditions;
  final String caregiverName;

  Patient({
    required this.id,
    required this.name,
    required this.age,
    required this.photo,
    required this.status,
    required this.lastUpdate,
    required this.conditions,
    required this.caregiverName,
  });
}
