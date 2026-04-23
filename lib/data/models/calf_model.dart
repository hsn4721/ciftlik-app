class CalfModel {
  final int? id;
  final int? animalId;
  final String earTag;
  final String? name;
  final String gender;
  final String birthDate;
  final int? motherId;
  final String? fatherBreed;
  final double? birthWeight;
  final String status;
  final String? notes;
  final String createdAt;

  // from JOIN
  final String? motherEarTag;

  const CalfModel({
    this.id,
    this.animalId,
    required this.earTag,
    this.name,
    required this.gender,
    required this.birthDate,
    this.motherId,
    this.fatherBreed,
    this.birthWeight,
    required this.status,
    this.notes,
    required this.createdAt,
    this.motherEarTag,
  });

  int get ageInDays => DateTime.now().difference(DateTime.parse(birthDate)).inDays;
  String get ageDisplay {
    final days = ageInDays;
    if (days < 30) return '$days gün';
    final months = days ~/ 30;
    if (months < 12) return '$months ay';
    return '${months ~/ 12} yıl ${months % 12} ay';
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'animalId': animalId,
    'earTag': earTag,
    'name': name,
    'gender': gender,
    'birthDate': birthDate,
    'motherId': motherId,
    'fatherBreed': fatherBreed,
    'birthWeight': birthWeight,
    'status': status,
    'notes': notes,
    'createdAt': createdAt,
  };

  factory CalfModel.fromMap(Map<String, dynamic> m) => CalfModel(
    id: m['id'],
    animalId: m['animalId'],
    earTag: m['earTag'],
    name: m['name'],
    gender: m['gender'],
    birthDate: m['birthDate'],
    motherId: m['motherId'] != null ? (m['motherId'] as num).toInt() : null,
    fatherBreed: m['fatherBreed'],
    birthWeight: m['birthWeight'] != null ? (m['birthWeight'] as num).toDouble() : null,
    status: m['status'],
    notes: m['notes'],
    createdAt: m['createdAt'],
    motherEarTag: m['motherEarTag'],
  );
}

class BreedingModel {
  final int? id;
  final int animalId;
  final String breedingType;
  final String breedingDate;
  final String? bullBreed;
  final String? expectedBirthDate;
  final String status;
  final String? actualBirthDate;
  final String? notes;
  final String createdAt;

  // from JOIN
  final String? animalEarTag;
  final String? animalName;

  const BreedingModel({
    this.id,
    required this.animalId,
    required this.breedingType,
    required this.breedingDate,
    this.bullBreed,
    this.expectedBirthDate,
    required this.status,
    this.actualBirthDate,
    this.notes,
    required this.createdAt,
    this.animalEarTag,
    this.animalName,
  });

  int? get daysUntilBirth {
    if (expectedBirthDate == null) return null;
    return DateTime.parse(expectedBirthDate!).difference(DateTime.now()).inDays;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'animalId': animalId,
    'breedingType': breedingType,
    'breedingDate': breedingDate,
    'bullBreed': bullBreed,
    'expectedBirthDate': expectedBirthDate,
    'status': status,
    'actualBirthDate': actualBirthDate,
    'notes': notes,
    'createdAt': createdAt,
  };

  factory BreedingModel.fromMap(Map<String, dynamic> m) => BreedingModel(
    id: m['id'],
    animalId: m['animalId'],
    breedingType: m['breedingType'],
    breedingDate: m['breedingDate'],
    bullBreed: m['bullBreed'],
    expectedBirthDate: m['expectedBirthDate'],
    status: m['status'],
    actualBirthDate: m['actualBirthDate'],
    notes: m['notes'],
    createdAt: m['createdAt'],
    animalEarTag: m['earTag'],
    animalName: m['name'],
  );
}
