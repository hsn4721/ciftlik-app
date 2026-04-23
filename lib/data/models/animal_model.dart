class AnimalModel {
  final int? id;
  final String earTag;
  final String? name;
  final String breed;
  final String gender;
  final String birthDate;
  final String status;
  final double? weight;
  final String? photoPath;
  final int? motherId;
  final int? fatherId;
  final String entryDate;
  final String entryType;
  final double? purchasePrice;
  final String? exitType;
  final String? exitDate;
  final double? exitPrice;
  final String? notes;
  final String createdAt;
  final String updatedAt;

  const AnimalModel({
    this.id,
    required this.earTag,
    this.name,
    required this.breed,
    required this.gender,
    required this.birthDate,
    required this.status,
    this.weight,
    this.photoPath,
    this.motherId,
    this.fatherId,
    required this.entryDate,
    required this.entryType,
    this.purchasePrice,
    this.exitType,
    this.exitDate,
    this.exitPrice,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => exitType == null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'earTag': earTag,
        'name': name,
        'breed': breed,
        'gender': gender,
        'birthDate': birthDate,
        'status': status,
        'weight': weight,
        'photoPath': photoPath,
        'motherId': motherId,
        'fatherId': fatherId,
        'entryDate': entryDate,
        'entryType': entryType,
        'purchasePrice': purchasePrice,
        'exitType': exitType,
        'exitDate': exitDate,
        'exitPrice': exitPrice,
        'notes': notes,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory AnimalModel.fromMap(Map<String, dynamic> map) => AnimalModel(
        id: map['id'],
        earTag: map['earTag'],
        name: map['name'],
        breed: map['breed'],
        gender: map['gender'],
        birthDate: map['birthDate'],
        status: map['status'],
        weight: map['weight'] != null ? (map['weight'] as num).toDouble() : null,
        photoPath: map['photoPath'],
        motherId: map['motherId'],
        fatherId: map['fatherId'],
        entryDate: map['entryDate'],
        entryType: map['entryType'],
        purchasePrice: map['purchasePrice'] != null ? (map['purchasePrice'] as num).toDouble() : null,
        exitType: map['exitType'],
        exitDate: map['exitDate'],
        exitPrice: map['exitPrice'] != null ? (map['exitPrice'] as num).toDouble() : null,
        notes: map['notes'],
        createdAt: map['createdAt'],
        updatedAt: map['updatedAt'],
      );

  AnimalModel copyWith({
    int? id,
    String? earTag,
    String? name,
    String? breed,
    String? gender,
    String? birthDate,
    String? status,
    double? weight,
    String? photoPath,
    int? motherId,
    int? fatherId,
    String? entryDate,
    String? entryType,
    double? purchasePrice,
    String? exitType,
    String? exitDate,
    double? exitPrice,
    String? notes,
    String? createdAt,
    String? updatedAt,
  }) =>
      AnimalModel(
        id: id ?? this.id,
        earTag: earTag ?? this.earTag,
        name: name ?? this.name,
        breed: breed ?? this.breed,
        gender: gender ?? this.gender,
        birthDate: birthDate ?? this.birthDate,
        status: status ?? this.status,
        weight: weight ?? this.weight,
        photoPath: photoPath ?? this.photoPath,
        motherId: motherId ?? this.motherId,
        fatherId: fatherId ?? this.fatherId,
        entryDate: entryDate ?? this.entryDate,
        entryType: entryType ?? this.entryType,
        purchasePrice: purchasePrice ?? this.purchasePrice,
        exitType: exitType ?? this.exitType,
        exitDate: exitDate ?? this.exitDate,
        exitPrice: exitPrice ?? this.exitPrice,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  int get ageInMonths {
    final birth = DateTime.parse(birthDate);
    final now = DateTime.now();
    return (now.difference(birth).inDays / 30).floor();
  }

  String get ageDisplay {
    final months = ageInMonths;
    if (months < 12) return '$months ay';
    final years = months ~/ 12;
    final rem = months % 12;
    return rem > 0 ? '$years yıl $rem ay' : '$years yıl';
  }
}
