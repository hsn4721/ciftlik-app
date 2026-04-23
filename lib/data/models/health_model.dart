class HealthModel {
  final int? id;
  final int animalId;
  final String animalEarTag;
  final String animalName;
  final String date;
  final String type;
  final String? diagnosis;
  final String? treatment;
  final String? medicine;
  final String? dose;
  final int milkWithdrawal;
  final String? milkWithdrawalEnd;
  final String? vetName;
  final double? cost;
  final String? nextVisit;
  final String? notes;
  final String createdAt;

  const HealthModel({
    this.id,
    required this.animalId,
    this.animalEarTag = '',
    this.animalName = '',
    required this.date,
    required this.type,
    this.diagnosis,
    this.treatment,
    this.medicine,
    this.dose,
    this.milkWithdrawal = 0,
    this.milkWithdrawalEnd,
    this.vetName,
    this.cost,
    this.nextVisit,
    this.notes,
    required this.createdAt,
  });

  HealthModel copyWith({
    int? id,
    int? animalId,
    String? animalEarTag,
    String? animalName,
    String? date,
    String? type,
    String? diagnosis,
    String? treatment,
    String? medicine,
    String? dose,
    int? milkWithdrawal,
    String? milkWithdrawalEnd,
    String? vetName,
    double? cost,
    String? nextVisit,
    String? notes,
    String? createdAt,
  }) => HealthModel(
    id: id ?? this.id,
    animalId: animalId ?? this.animalId,
    animalEarTag: animalEarTag ?? this.animalEarTag,
    animalName: animalName ?? this.animalName,
    date: date ?? this.date,
    type: type ?? this.type,
    diagnosis: diagnosis ?? this.diagnosis,
    treatment: treatment ?? this.treatment,
    medicine: medicine ?? this.medicine,
    dose: dose ?? this.dose,
    milkWithdrawal: milkWithdrawal ?? this.milkWithdrawal,
    milkWithdrawalEnd: milkWithdrawalEnd ?? this.milkWithdrawalEnd,
    vetName: vetName ?? this.vetName,
    cost: cost ?? this.cost,
    nextVisit: nextVisit ?? this.nextVisit,
    notes: notes ?? this.notes,
    createdAt: createdAt ?? this.createdAt,
  );

  Map<String, dynamic> toMap() => {
        'id': id,
        'animalId': animalId,
        'date': date,
        'type': type,
        'diagnosis': diagnosis,
        'treatment': treatment,
        'medicine': medicine,
        'dose': dose,
        'milkWithdrawal': milkWithdrawal,
        'milkWithdrawalEnd': milkWithdrawalEnd,
        'vetName': vetName,
        'cost': cost,
        'nextVisit': nextVisit,
        'notes': notes,
        'createdAt': createdAt,
      };

  factory HealthModel.fromMap(Map<String, dynamic> map) => HealthModel(
        id: map['id'],
        animalId: map['animalId'],
        animalEarTag: map['earTag'] ?? '',
        animalName: map['name'] ?? map['earTag'] ?? '',
        date: map['date'],
        type: map['type'],
        diagnosis: map['diagnosis'],
        treatment: map['treatment'],
        medicine: map['medicine'],
        dose: map['dose'],
        milkWithdrawal: map['milkWithdrawal'] ?? 0,
        milkWithdrawalEnd: map['milkWithdrawalEnd'],
        vetName: map['vetName'],
        cost: map['cost'] != null ? (map['cost'] as num).toDouble() : null,
        nextVisit: map['nextVisit'],
        notes: map['notes'],
        createdAt: map['createdAt'],
      );
}

class VaccineModel {
  final int? id;
  final int? animalId;
  final String? animalEarTag;
  final String? animalName;
  final bool isHerdWide;
  final String vaccineName;
  final String vaccineDate;
  final String? nextVaccineDate;
  final String? dose;
  final String? vetName;
  final double? cost;
  final String? batchNumber;
  final String? notes;
  final String createdAt;

  const VaccineModel({
    this.id,
    this.animalId,
    this.animalEarTag,
    this.animalName,
    this.isHerdWide = false,
    required this.vaccineName,
    required this.vaccineDate,
    this.nextVaccineDate,
    this.dose,
    this.vetName,
    this.cost,
    this.batchNumber,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'animalId': animalId,
        'isHerdWide': isHerdWide ? 1 : 0,
        'vaccineName': vaccineName,
        'vaccineDate': vaccineDate,
        'nextVaccineDate': nextVaccineDate,
        'dose': dose,
        'vetName': vetName,
        'cost': cost,
        'batchNumber': batchNumber,
        'notes': notes,
        'createdAt': createdAt,
      };

  factory VaccineModel.fromMap(Map<String, dynamic> map) => VaccineModel(
        id: map['id'],
        animalId: map['animalId'],
        animalEarTag: map['earTag'],
        animalName: map['name'] ?? map['earTag'],
        isHerdWide: (map['isHerdWide'] ?? 0) == 1,
        vaccineName: map['vaccineName'],
        vaccineDate: map['vaccineDate'],
        nextVaccineDate: map['nextVaccineDate'],
        dose: map['dose'],
        vetName: map['vetName'],
        cost: map['cost'] != null ? (map['cost'] as num).toDouble() : null,
        batchNumber: map['batchNumber'],
        notes: map['notes'],
        createdAt: map['createdAt'],
      );

  bool get isOverdue {
    if (nextVaccineDate == null) return false;
    return DateTime.parse(nextVaccineDate!).isBefore(DateTime.now());
  }

  int? get daysUntilNext {
    if (nextVaccineDate == null) return null;
    return DateTime.parse(nextVaccineDate!).difference(DateTime.now()).inDays;
  }
}
